// Servidor MCP sobre HTTP (transporte "streamable HTTP", modo sin sesión).
//
// Cada POST /mcp crea un McpServer efímero: no se guarda estado entre
// peticiones, así el proceso es reiniciable y no acumula memoria.
//
// Autenticación: Authorization: Bearer <MCP_TOKEN>. Sin token válido no se
// procesa nada (falla cerrado). El servidor no se publica fuera de la red
// interna de Docker.

import express from 'express';
import { timingSafeEqual } from 'node:crypto';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { config, validarConfig } from './config.mjs';
import { registrarHerramientas } from './tools.mjs';
import { db } from './db.mjs';
import { ops } from './ops.mjs';

validarConfig();

const VERSION = process.env.MCP_VERSION ?? '1.0.0';
const NOMBRE = 'practica-integradora';

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));

// --- autenticación -------------------------------------------------------
const esperado = Buffer.from(config.token);

function autorizado(req) {
  const cabecera = req.get('authorization') ?? '';
  const [esquema, valor] = cabecera.split(' ');
  if (esquema !== 'Bearer' || !valor) return false;
  const recibido = Buffer.from(valor);
  // longitudes distintas => timingSafeEqual lanzaría; se compara igual el hash
  if (recibido.length !== esperado.length) return false;
  return timingSafeEqual(recibido, esperado);
}

function exigirToken(req, res, next) {
  if (autorizado(req)) return next();
  // mismo criterio que el webhook de n8n (§13): 401 sin detalle
  res.status(401).json({
    jsonrpc: '2.0',
    error: { code: -32001, message: 'no autorizado' },
    id: null,
  });
}

// --- salud --------------------------------------------------------------
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    servicio: 'mcp',
    version: VERSION,
    escritura: config.allowWrite,
    api: config.apiUrl,
  });
});

// --- incidentes (API interna para n8n y el watcher) ----------------------
// Mismo token que /mcp. n8n llama a POST /incidentes cuando Alertmanager
// avisa; el watcher del host consulta y cambia estados.
const exigirIncidentes = (req, res, next) => {
  if (!config.incidentsEnabled) {
    return res.status(503).json({ error: 'base de incidentes no configurada (MCP_OPS_DB_PASSWORD)' });
  }
  return exigirToken(req, res, next);
};

const fallo = (res, e, status = 400) => {
  console.error(`[mcp] incidentes: ${e.message}`);
  return res.status(status).json({ error: e.message });
};

app.post('/incidentes', exigirIncidentes, async (req, res) => {
  try {
    const cuerpo = req.body ?? {};
    // Acepta dos formas: el payload crudo de Alertmanager ({status, alerts})
    // y el envoltorio que usaba n8n ({alerta, mantis_id}).
    const alerta = cuerpo.alerta ?? cuerpo;
    const mantisId = cuerpo.mantis_id ?? null;
    if (!alerta || typeof alerta !== 'object' || !Array.isArray(alerta.alerts)) {
      return res.status(400).json({ error: 'falta el objeto alerta con alerts[]' });
    }
    const r = await ops.crearIncidente(alerta, mantisId);
    return res.status(r.creado || r.resuelta ? 201 : 200).json(r);
  } catch (e) {
    return fallo(res, e, 500);
  }
});

app.get('/incidentes', exigirIncidentes, async (req, res) => {
  try {
    const { estado = null, limit = 20 } = req.query;
    return res.json({ incidentes: await ops.listar({ estado, limit }) });
  } catch (e) {
    return fallo(res, e, 500);
  }
});

app.get('/incidentes/:id', exigirIncidentes, async (req, res) => {
  try {
    const inc = await ops.obtener(Number(req.params.id));
    if (!inc) return res.status(404).json({ error: 'incidente no encontrado' });
    return res.json({ incidente: inc });
  } catch (e) {
    return fallo(res, e, 500);
  }
});

app.post('/incidentes/:id/aprobar', exigirIncidentes, async (req, res) => {
  try {
    const usuario = req.body?.usuario ?? 'telegram';
    return res.json({ aprobado: true, incidente: await ops.aprobar(Number(req.params.id), usuario) });
  } catch (e) {
    return fallo(res, e, 409);
  }
});

app.post('/incidentes/:id/rechazar', exigirIncidentes, async (req, res) => {
  try {
    const usuario = req.body?.usuario ?? 'telegram';
    return res.json({ rechazado: true, incidente: await ops.rechazar(Number(req.params.id), usuario) });
  } catch (e) {
    return fallo(res, e, 409);
  }
});

app.post('/incidentes/:id/estado', exigirIncidentes, async (req, res) => {
  try {
    const { estado, resultado = null } = req.body ?? {};
    return res.json({ incidente: await ops.cambiarEstado(Number(req.params.id), estado, resultado) });
  } catch (e) {
    return fallo(res, e, 409);
  }
});

// --- MCP ----------------------------------------------------------------
app.post('/mcp', exigirToken, async (req, res) => {
  const inicio = Date.now();
  const server = new McpServer({ name: NOMBRE, version: VERSION });
  const nombres = registrarHerramientas(server);

  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined, // sin sesión: cada request es independiente
    enableJsonResponse: true, // respuesta JSON, sin stream SSE
  });

  res.on('close', () => {
    transport.close().catch(() => {});
    server.close().catch(() => {});
  });

  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  } catch (e) {
    console.error(`[mcp] error manejando la petición: ${e.message}`);
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: '2.0',
        error: { code: -32603, message: 'error interno' },
        id: null,
      });
    }
    return;
  }

  // Traza mínima para la evidencia: qué método y qué herramienta se usó.
  const cuerpo = req.body;
  const llamadas = Array.isArray(cuerpo) ? cuerpo : [cuerpo];
  for (const r of llamadas) {
    if (!r) continue;
    const que = r.method === 'tools/call' ? `tools/call ${r.params?.name}` : r.method;
    console.log(`[mcp] ${que} -> ${res.statusCode} (${Date.now() - inicio} ms) [${nombres.length} tools]`);
  }
});

// Sin SSE: el transporte no mantiene streams abiertos.
app.get('/mcp', exigirToken, (req, res) => {
  res.status(405).json({
    jsonrpc: '2.0',
    error: { code: -32000, message: 'método no permitido: usá POST /mcp' },
    id: null,
  });
});

app.delete('/mcp', exigirToken, (req, res) => {
  res.status(405).json({
    jsonrpc: '2.0',
    error: { code: -32000, message: 'sin sesiones que cerrar' },
    id: null,
  });
});

// --- arranque -----------------------------------------------------------
const servidor = app.listen(config.port, config.host, () => {
  console.log(
    `[mcp] escuchando en http://${config.host}:${config.port}/mcp ` +
      `(escritura=${config.allowWrite}, api=${config.apiUrl})`,
  );
});

async function apagar(senal) {
  console.log(`[mcp] ${senal}: cerrando`);
  servidor.close(async () => {
    await db.cerrar().catch(() => {});
    await ops.cerrar().catch(() => {});
    process.exit(0);
  });
  // si algo queda colgado, no esperar para siempre
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => apagar('SIGTERM'));
process.on('SIGINT', () => apagar('SIGINT'));
