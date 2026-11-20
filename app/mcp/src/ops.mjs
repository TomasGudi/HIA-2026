// Operaciones de incidentes: persistencia, correo y notificación.
//
// Este módulo es la parte "de escritura" del MCP. Usa un rol propio
// (`mcp_ops`) con DML solo sobre el esquema `ops`, no sobre las tablas de la
// aplicación. Así el agente puede registrar y aprobar incidentes sin acceso
// al contenido de Conduit.

import pg from 'pg';
import nodemailer from 'nodemailer';
import https from 'node:https';
import { config } from './config.mjs';

let pool;
let transporte;

const CODIGOS = {
  PostgresCaido: 'PG_PRIMARY_DOWN',
  ReplicacionAtrasada: 'PG_REPLICA_LAG',
};

const FINALES = new Set(['resolved', 'failed', 'rejected']);

function getPool() {
  if (!pool) {
    pool = new pg.Pool({
      host: config.opsDb.host,
      port: config.opsDb.port,
      database: config.opsDb.database,
      user: config.opsDb.user,
      password: config.opsDb.password,
      max: 3,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      application_name: 'pi-mcp-incidentes',
    });
  }
  return pool;
}

function getTransporte() {
  if (!config.smtp.host) return null;
  if (!transporte) {
    transporte = nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: false,
      // MailHog no ofrece TLS ni autenticación: es un receptor de demo.
      ignoreTLS: true,
      tls: { rejectUnauthorized: false },
    });
  }
  return transporte;
}

function incidenteDeFila(fila) {
  if (!fila) return null;
  return {
    id: Number(fila.id),
    codigo: fila.codigo,
    titulo: fila.titulo,
    severidad: fila.severidad,
    estado: fila.estado,
    servicio: fila.servicio,
    sintoma: fila.sintoma,
    diagnostico: fila.diagnostico,
    solucion: fila.solucion_propuesta,
    mantis_id: fila.mantis_id === null ? null : Number(fila.mantis_id),
    aprobado_por: fila.aprobado_por,
    aprobado_at: fila.aprobado_at,
    resuelto_at: fila.resuelto_at,
    resultado: fila.resultado,
    creado: fila.created_at,
    actualizado: fila.updated_at,
  };
}

async function evento(id, tipo, detalle) {
  await getPool().query(
    `INSERT INTO ops.incident_event (incident_id, tipo, detalle)
     VALUES ($1, $2, $3)`,
    [id, tipo, detalle ?? null],
  );
}

async function crearMantis(primera, alertname, estadoAlerta) {
  if (!config.mantis.token) return null;
  const labels = primera.labels ?? {};
  const ann = primera.annotations ?? {};
  const summary = `[${estadoAlerta}] ${alertname} en ${labels.instance ?? 'desconocido'}`;
  const description =
    [ann.summary, ann.description, primera.generatorURL].filter(Boolean).join('\n\n') ||
    'Sin descripción en el payload';
  const cuerpo = {
    summary,
    description,
    category: { name: 'Infraestructura' },
    project: { id: 1 },
    severity: { name: estadoAlerta === 'resolved' ? 'minor' : 'major' },
    priority: { name: labels.severity === 'critical' ? 'urgent' : 'high' },
  };
  const res = await fetch(`${config.mantis.url}/api/rest/issues`, {
    method: 'POST',
    headers: {
      Authorization: config.mantis.token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(cuerpo),
  });
  if (!res.ok) {
    const detalle = await res.text();
    throw new Error(`Mantis respondió ${res.status}: ${detalle.slice(0, 200)}`);
  }
  const datos = await res.json();
  return datos.issue?.id ?? null;
}

async function runbookPara(codigo) {  const { rows } = await getPool().query(
    `SELECT id, codigo, sintoma, causa, solucion, comando, riesgo
     FROM ops.runbook WHERE codigo = $1`,
    [codigo],
  );
  if (rows[0]) return rows[0];
  const fallback = await getPool().query(
    `SELECT id, codigo, sintoma, causa, solucion, comando, riesgo
     FROM ops.runbook WHERE codigo = 'ALERTA_GENERICA'`,
  );
  return fallback.rows[0] ?? null;
}

function textoCorreo(inc, tipo) {
  const cabecera = {
    creado: `Nuevo incidente #${inc.id}`,
    aprobado: `Incidente #${inc.id} aprobado para remediación`,
    resolved: `Incidente #${inc.id} resuelto`,
    failed: `Incidente #${inc.id} con remediación fallida`,
  }[tipo] ?? `Incidente #${inc.id}`;

  const lineas = [
    cabecera,
    '',
    `Título: ${inc.titulo}`,
    `Código: ${inc.codigo}`,
    `Severidad: ${inc.severidad}`,
    `Estado: ${inc.estado}`,
    `Servicio: ${inc.servicio ?? 'no informado'}`,
    '',
    'Síntoma:',
    inc.sintoma ?? 'sin detalle',
    '',
    'Diagnóstico:',
    inc.diagnostico ?? 'sin detalle',
    '',
    'Solución propuesta:',
    inc.solucion ?? 'sin runbook asociado',
    '',
  ];

  if (tipo === 'creado') {
    lineas.push(
      'Acción requerida:',
      `Respondé a Hermes en Telegram: "SÍ, resolvé el incidente #${inc.id}".`,
      'Si no querés que se ejecute, respondé "NO".',
    );
  } else if (tipo === 'resolved' || tipo === 'failed') {
    lineas.push('Resultado:', inc.resultado ?? 'sin detalle');
  }

  return lineas.join('\n');
}

function textoTelegram(inc, tipo) {
  if (tipo === 'creado') {
    return [
      `INCIDENTE #${inc.id}: ${inc.titulo}`,
      `Estado: ${inc.estado} | Severidad: ${inc.severidad}`,
      '',
      `Síntoma: ${inc.sintoma ?? 'sin detalle'}`,
      '',
      `Solución propuesta (${inc.codigo}):`,
      (inc.solucion ?? 'sin runbook').slice(0, 1200),
      '',
      `¿Querés que lo resuelva? Respondé: "SÍ, resolvé el incidente #${inc.id}" o "NO".`,
    ].join('\n');
  }
  if (tipo === 'resolved') {
    return `Incidente #${inc.id} RESUELTO.\n${inc.resultado ?? ''}`.trim();
  }
  if (tipo === 'failed') {
    return `Incidente #${inc.id}: la remediación FALLÓ.\n${inc.resultado ?? ''}`.trim();
  }
  return `Incidente #${inc.id}: ${tipo}.`;
}

async function enviarCorreo(inc, tipo) {
  const t = getTransporte();
  if (!t) return { enviado: false, motivo: 'SMTP_HOST no configurado' };
  await t.sendMail({
    from: config.smtp.from,
    to: config.smtp.to,
    subject: `[INCIDENTE #${inc.id}] ${inc.titulo} — ${tipo}`,
    text: textoCorreo(inc, tipo),
  });
  return { enviado: true, destino: config.smtp.to };
}

function postJsonTelegram(url, body) {
  // `fetch` de undici intenta IPv6 y en esta red da ETIMEDOUT; con https y
  // family=4 usa el mismo camino que el curl del contenedor de Hermes.
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const datos = JSON.stringify(body);
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method: 'POST',
        family: 4,
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(datos),
        },
      },
      (res) => {
        let respuesta = '';
        res.on('data', (c) => (respuesta += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            try {
              resolve(JSON.parse(respuesta || '{}'));
            } catch {
              resolve({});
            }
          } else {
            reject(new Error(`Telegram respondió ${res.statusCode}: ${respuesta.slice(0, 200)}`));
          }
        });
      },
    );
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('timeout de Telegram')));
    req.write(datos);
    req.end();
  });
}

async function enviarTelegram(inc, tipo) {
  if (!config.telegram.token || !config.telegram.chatId) {
    return { enviado: false, motivo: 'Telegram no configurado' };
  }
  const texto = textoTelegram(inc, tipo).slice(0, 3900);
  await postJsonTelegram(`https://api.telegram.org/bot${config.telegram.token}/sendMessage`, {
    chat_id: config.telegram.chatId,
    text: texto,
  });
  return { enviado: true, chat_id: config.telegram.chatId };
}

async function notificar(inc, tipo) {
  const resultados = await Promise.allSettled([enviarCorreo(inc, tipo), enviarTelegram(inc, tipo)]);
  const fallos = resultados
    .filter((r) => r.status === 'rejected')
    .map((r) => r.reason?.message ?? String(r.reason));
  if (fallos.length) {
    await evento(inc.id, 'notificacion_error', fallos.join(' | ')).catch(() => {});
  }
  return {
    correo: resultados[0].status === 'fulfilled' ? resultados[0].value : { enviado: false, error: fallos[0] },
    telegram: resultados[1].status === 'fulfilled' ? resultados[1].value : { enviado: false, error: fallos[0] },
  };
}

export const ops = {
  async crearIncidente(alerta, mantisId = null) {
    const cuerpo = alerta ?? {};
    const primera = Array.isArray(cuerpo.alerts) ? cuerpo.alerts[0] ?? {} : {};
    const labels = primera.labels ?? {};
    const ann = primera.annotations ?? {};
    const alertname = labels.alertname ?? 'Alerta';
    const codigo = CODIGOS[alertname] ?? 'ALERTA_GENERICA';
    const estadoAlerta = cuerpo.status ?? 'firing';

    // Un `resolved` no crea un incidente nuevo: cierra el último abierto del
    // mismo código. Si no hay ninguno, no hace nada.
    if (estadoAlerta === 'resolved') {
      const { rows } = await getPool().query(
        `UPDATE ops.incident
            SET estado = 'resolved',
                resultado = COALESCE(resultado, 'alerta resuelta en Prometheus'),
                resuelto_at = now(),
                updated_at = now()
          WHERE id = (
            SELECT id FROM ops.incident
             WHERE codigo = $1 AND estado NOT IN ('resolved','failed','rejected')
             ORDER BY created_at DESC LIMIT 1
          )
          RETURNING *`,
        [codigo],
      );
      if (!rows[0]) return { resuelta: false, motivo: 'no había incidente abierto para la alerta resuelta' };
      const inc = incidenteDeFila(rows[0]);
      await evento(inc.id, 'resolved', 'alerta resuelta en Prometheus');
      return { resuelta: true, incidente: inc };
    }

    const runbook = await runbookPara(codigo);
    let mantisFinal = mantisId;
    let avisoMantis = null;
    if (!mantisFinal && estadoAlerta === 'firing' && codigo === 'PG_PRIMARY_DOWN') {
      try {
        mantisFinal = await crearMantis(primera, alertname, estadoAlerta);
      } catch (e) {
        avisoMantis = e.message;
      }
    }
    const sintoma =
      ann.summary ?? ann.description ?? `${alertname} en ${labels.instance ?? 'instancia desconocida'}`;
    const diagnostico = [
      `Alerta: ${alertname}`,
      `Instancia: ${labels.instance ?? 'desconocida'}`,
      `Severidad: ${labels.severity ?? 'sin severidad'}`,
      ann.description ? `Detalle: ${ann.description}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    const { rows } = await getPool().query(
      `INSERT INTO ops.incident
         (codigo, titulo, severidad, estado, servicio, sintoma, diagnostico,
          solucion_propuesta, runbook_id, mantis_id, alerta)
       VALUES ($1,$2,$3,'open',$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        codigo,
        `${alertname} en ${labels.instance ?? 'desconocido'}`,
        labels.severity ?? 'critical',
        labels.job ?? labels.service ?? 'db',
        sintoma,
        diagnostico,
        runbook?.solucion ?? 'Sin runbook asociado: revisar manualmente.',
        runbook?.id ?? null,
        mantisFinal,
        JSON.stringify(cuerpo),
      ],
    );
    const inc = incidenteDeFila(rows[0]);
    await evento(inc.id, 'detected', `alerta ${alertname} (${estadoAlerta})`);
    if (avisoMantis) await evento(inc.id, 'mantis_error', avisoMantis).catch(() => {});
    const notificaciones = await notificar(inc, 'creado');
    return { creado: true, incidente: inc, notificaciones };
  },

  async listar({ estado = null, limit = 20 } = {}) {
    const tope = Math.min(Math.max(Number(limit) || 20, 1), 100);
    const { rows } = await getPool().query(
      `SELECT * FROM ops.incident
        WHERE ($1::text IS NULL OR estado = $1)
        ORDER BY created_at DESC
        LIMIT $2`,
      [estado, tope],
    );
    return rows.map(incidenteDeFila);
  },

  async obtener(id) {
    const { rows } = await getPool().query('SELECT * FROM ops.incident WHERE id = $1', [id]);
    return incidenteDeFila(rows[0]);
  },

  async buscarSolucion({ codigo = null, sintoma = null } = {}) {
    const { rows } = await getPool().query(
      `SELECT id, codigo, sintoma, causa, solucion, comando, riesgo, actualizado
         FROM ops.runbook
        WHERE ($1::text IS NOT NULL AND codigo = $1)
           OR ($2::text IS NOT NULL AND sintoma ILIKE '%' || $2 || '%')
        ORDER BY codigo
        LIMIT 10`,
      [codigo, sintoma],
    );
    return rows;
  },

  async aprobar(id, usuario = 'telegram') {
    const { rows } = await getPool().query(
      `UPDATE ops.incident
          SET estado = 'approved', aprobado_por = $2, aprobado_at = now(), updated_at = now()
        WHERE id = $1 AND estado IN ('open','notified','awaiting_approval')
        RETURNING *`,
      [id, usuario],
    );
    if (!rows[0]) {
      const actual = await this.obtener(id);
      throw new Error(
        actual ? `el incidente #${id} está en estado '${actual.estado}' y no se puede aprobar` : `no existe el incidente #${id}`,
      );
    }
    const inc = incidenteDeFila(rows[0]);
    await evento(inc.id, 'approved', `aprobado por ${usuario}`);
    await notificar(inc, 'aprobado').catch(() => {});
    return inc;
  },

  async rechazar(id, usuario = 'telegram') {
    const { rows } = await getPool().query(
      `UPDATE ops.incident
          SET estado = 'rejected', aprobado_por = $2, updated_at = now()
        WHERE id = $1 AND estado IN ('open','notified','awaiting_approval')
        RETURNING *`,
      [id, usuario],
    );
    if (!rows[0]) throw new Error(`no existe un incidente pendiente con id ${id}`);
    const inc = incidenteDeFila(rows[0]);
    await evento(inc.id, 'rejected', `rechazado por ${usuario}`);
    return inc;
  },

  async cambiarEstado(id, estado, resultado = null) {
    if (!['resolving', 'resolved', 'failed'].includes(estado)) {
      throw new Error(`estado inválido: ${estado}`);
    }
    const { rows } = await getPool().query(
      `UPDATE ops.incident
          SET estado = $2,
              resultado = COALESCE($3, resultado),
              resuelto_at = CASE WHEN $2 IN ('resolved','failed') THEN now() ELSE resuelto_at END,
              updated_at = now()
        WHERE id = $1
        RETURNING *`,
      [id, estado, resultado],
    );
    if (!rows[0]) throw new Error(`no existe el incidente #${id}`);
    const inc = incidenteDeFila(rows[0]);
    await evento(inc.id, estado, resultado);
    if (estado !== 'resolving') await notificar(inc, estado).catch(() => {});
    return inc;
  },

  async cerrar() {
    if (pool) await pool.end();
  },
};
