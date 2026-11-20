#!/usr/bin/env node
// Ingesta de la documentación del proyecto en RAGFlow, sin usar la UI.
//
// RAGFlow 1.0 no acepta la contraseña en claro: el frontend la cifra con RSA
// (PKCS#1 v1.5 sobre el base64 de la contraseña) y manda el resultado en base64.
// Acá se replica ese esquema con node:crypto.
//
// El script es idempotente: si el usuario, la API key, el proveedor o el dataset
// ya existen, los reutiliza.
//
// Uso:
//   RAGFLOW_ENV=C:/Users/tomas/ragflow/docker/.env node scripts/ragflow-ingestar.mjs

import { createPublicKey, publicEncrypt, constants } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, join } from 'node:path';

// Clave pública que usa el frontend (web/src/utils/index.ts). No es un secreto:
// es la mitad pública del par con el que el servidor descifra la contraseña.
const CUERPO_CLAVE =
  'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArq9XTUSeYr2+N1h3Afl/z8Dse/2yD0ZGrKwx+EEEcdsBLca9Ynmx3nIB5obmLlSfmskLpBo0UACBmB5rEjBp2Q2f3AG3Hjd4B+gNCG6BDaawuDlgANIhGnaTLrIqWrrcm4EMzJOnAOI1fgzJRsOOUEfaS318Eq9OVO3apEyCCt0lOQK6PuksduOjVxtltDav+guVAA068NrPYmRNabVKRNLJpL8w4D44sfth5RvZ3q9t+6RTArpEtc5sh5ChzvqPOzKGMXW83C95TxmXqpbK6olN4RevSfVjEAgCydH6HN6OhtOQEcnrU97r9H0iZOWwbw3pVrZiUkuRD1R56Wzs2wIDAQAB';

const CLAVE = createPublicKey(
  `-----BEGIN PUBLIC KEY-----\n${CUERPO_CLAVE.match(/.{1,64}/g).join('\n')}\n-----END PUBLIC KEY-----\n`,
);

const API = process.env.RAGFLOW_API ?? 'http://127.0.0.1:9380';
const ADMIN = process.env.RAGFLOW_ADMIN ?? 'http://127.0.0.1:9381';
const ENV_RAGFLOW = process.env.RAGFLOW_ENV ?? 'C:/Users/tomas/ragflow/docker/.env';

const ADMIN_EMAIL = process.env.RAGFLOW_ADMIN_EMAIL ?? 'admin@ragflow.io';
const USUARIO = process.env.RAGFLOW_USER ?? 'practica@example.com';
const CLAVE_USUARIO = process.env.RAGFLOW_PASSWORD ?? 'practica-ragflow-2026';

// El proveedor se configura con la URL interna: quien llama es el contenedor
// de RAGFlow, no el host.
const PROVEEDOR = 'OpenAI-API-Compatible';
const INSTANCIA = process.env.RAGFLOW_INSTANCE ?? 'default';
const TEI_URL = process.env.RAGFLOW_TEI_URL ?? 'http://tei:80';
const MODELO = process.env.RAGFLOW_MODEL ?? 'Qwen/Qwen3-Embedding-0.6B';
const DATASET = process.env.RAGFLOW_DATASET ?? 'practica-documentacion';

const rsa = (texto) =>
  publicEncrypt(
    { key: CLAVE, padding: constants.RSA_PKCS1_PADDING },
    Buffer.from(Buffer.from(texto, 'utf8').toString('base64'), 'utf8'),
  ).toString('base64');

async function pedir(ruta, { method = 'GET', token, body, base = API, raw = false } = {}) {
  const res = await fetch(base + ruta, {
    method,
    headers: {
      ...(body instanceof FormData ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: raw ? token : `Bearer ${token}` } : {}),
    },
    body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
  });
  const texto = await res.text();
  let datos;
  try {
    datos = texto ? JSON.parse(texto) : null;
  } catch {
    datos = texto;
  }
  // RAGFlow devuelve el token de sesión en el header Authorization, no en el body.
  return { status: res.status, datos, auth: res.headers.get('authorization') };
}

const ok = (paso, detalle = '') => console.log(`  ok   ${paso}${detalle ? ` — ${detalle}` : ''}`);
const info = (paso, detalle = '') => console.log(`  ..   ${paso}${detalle ? ` — ${detalle}` : ''}`);

// La API pagina de a poco: se recorren las páginas hasta cubrir `total`.
async function listarDocumentos(token, datasetId) {
  const todos = [];
  for (let pagina = 1; pagina <= 20; pagina += 1) {
    const r = await pedir(
      `/api/v1/datasets/${datasetId}/documents?page=${pagina}&page_size=30`,
      { token },
    );
    const docs = r.datos?.data?.docs ?? [];
    todos.push(...docs);
    const total = r.datos?.data?.total ?? todos.length;
    if (todos.length >= total || docs.length === 0) break;
  }
  return todos;
}

async function main() {
  const env = readFileSync(ENV_RAGFLOW, 'utf8');
  const adminPass = env.match(/^ADMIN_DEFAULT_PASSWORD=(.*)$/m)?.[1]?.trim();
  if (!adminPass) throw new Error(`falta ADMIN_DEFAULT_PASSWORD en ${ENV_RAGFLOW}`);

  // 1) sesión de administración (server 9381, token en el header)
  const admin = await pedir('/api/v1/admin/login', {
    method: 'POST',
    base: ADMIN,
    body: { email: ADMIN_EMAIL, password: rsa(adminPass) },
  });
  if (!admin.auth) throw new Error(`login admin falló: ${JSON.stringify(admin.datos)}`);
  ok('login admin', ADMIN_EMAIL);

  // 2) usuario de la práctica
  const alta = await pedir('/api/v1/admin/users', {
    method: 'POST',
    base: ADMIN,
    token: admin.auth,
    raw: true,
    body: { username: USUARIO, password: rsa(CLAVE_USUARIO) },
  });
  if (alta.datos?.code === 0) ok('usuario creado', USUARIO);
  else if (String(alta.datos?.message).includes('already exists')) info('usuario ya existía', USUARIO);
  else throw new Error(`no se pudo crear el usuario: ${JSON.stringify(alta.datos)}`);

  // 3) sesión del usuario
  const login = await pedir('/api/v1/auth/login', {
    method: 'POST',
    body: { email: USUARIO, password: rsa(CLAVE_USUARIO) },
  });
  const token = login.auth ?? login.datos?.data?.access_token;
  if (!token) throw new Error(`login de usuario falló: ${JSON.stringify(login.datos)}`);
  ok('login usuario', USUARIO);

  // 4) API key (la que después usa el MCP)
  const existentes = await pedir('/api/v1/system/tokens', { token });
  let apiKey = existentes.datos?.data?.[0]?.token;
  if (!apiKey) {
    const nueva = await pedir('/api/v1/system/tokens', { method: 'POST', token, body: {} });
    apiKey = nueva.datos?.data?.token;
    ok('API key creada', apiKey?.slice(0, 14) + '…');
  } else {
    info('API key existente', apiKey.slice(0, 14) + '…');
  }
  if (!apiKey) throw new Error('no se pudo obtener la API key');

  // 5) proveedor de embeddings (TEI) y modelo
  const proveedores = await pedir('/api/v1/providers', { token });
  const existeProveedor = (proveedores.datos?.data ?? []).some(
    (p) => (p.name ?? p.provider_name) === PROVEEDOR,
  );
  if (!existeProveedor) {
    const creado = await pedir('/api/v1/providers', {
      method: 'PUT',
      token,
      body: { provider_name: PROVEEDOR, instance_name: INSTANCIA },
    });
    if (creado.datos?.code !== 0) {
      throw new Error(`no se pudo registrar el proveedor: ${JSON.stringify(creado.datos)}`);
    }
    ok('proveedor registrado', PROVEEDOR);
  } else {
    info('proveedor ya registrado', PROVEEDOR);
  }

  const instancias = await pedir(`/api/v1/providers/${PROVEEDOR}/instances`, { token });
  const yaExiste = (instancias.datos?.data ?? []).some(
    (i) => (i.instance_name ?? i.name) === INSTANCIA,
  );
  if (!yaExiste) {
    const creado = await pedir(`/api/v1/providers/${PROVEEDOR}/instances`, {
      method: 'POST',
      token,
      body: {
        instance_name: INSTANCIA,
        api_key: 'xxx',
        base_url: TEI_URL,
        model_info: [{ model_name: MODELO, model_type: ['embedding'], max_tokens: 8192 }],
      },
    });
    if (creado.datos?.code !== 0) {
      throw new Error(`no se pudo crear el proveedor: ${JSON.stringify(creado.datos)}`);
    }
    ok('proveedor de embeddings', `${PROVEEDOR}/${INSTANCIA} -> ${TEI_URL}`);
  } else {
    info('proveedor ya existía', `${PROVEEDOR}/${INSTANCIA}`);
  }

  // 6) dataset
  const lista = await pedir('/api/v1/datasets?page=1&page_size=100', { token });
  let datasetId = (lista.datos?.data ?? []).find((d) => d.name === DATASET)?.id;
  if (!datasetId) {
    const nuevo = await pedir('/api/v1/datasets', {
      method: 'POST',
      token,
      body: {
        name: DATASET,
        language: 'Spanish',
        embedding_model: `${MODELO}@${PROVEEDOR}`,
        parse_type: 1,
        parser_id: 'naive',
      },
    });
    if (nuevo.datos?.code !== 0) {
      throw new Error(`no se pudo crear el dataset: ${JSON.stringify(nuevo.datos)}`);
    }
    datasetId = nuevo.datos.data.id;
    ok('dataset creado', DATASET);
  } else {
    info('dataset ya existía', DATASET);
  }

  // 7) documentos: informe (01..16), guion de demo y anexos
  const raiz = process.cwd();
  const candidatos = [];
  for (const dir of ['docs/informe', 'docs']) {
    for (const nombre of readdirSync(join(raiz, dir))) {
      const ruta = join(raiz, dir, nombre);
      if (statSync(ruta).isFile() && nombre.endsWith('.md')) candidatos.push(ruta);
    }
  }
  const unicos = [...new Set(candidatos)];

  const yaCargados = await listarDocumentos(token, datasetId);
  const nombresCargados = new Set(yaCargados.map((d) => d.name));
  const faltantes = unicos.filter((r) => !nombresCargados.has(basename(r)));

  if (faltantes.length === 0) {
    info('documentos ya cargados', `${unicos.length}`);
  } else {
    const form = new FormData();
    for (const ruta of faltantes) {
      form.append('file', new Blob([readFileSync(ruta)], { type: 'text/markdown' }), basename(ruta));
    }
    const subida = await pedir(`/api/v1/datasets/${datasetId}/documents`, {
      method: 'POST',
      token,
      body: form,
    });
    if (subida.datos?.code !== 0) {
      throw new Error(`falló la subida: ${JSON.stringify(subida.datos).slice(0, 300)}`);
    }
    ok('documentos subidos', `${faltantes.length}`);
  }

  // 8) parseo (chunking + embeddings)
  const listo = (d) => ['DONE', 'COMPLETED'].includes(d.ingestion_status);
  const fallo = (d) => ['FAIL', 'FAILED'].includes(d.ingestion_status);
  const docs = await listarDocumentos(token, datasetId);
  const ids = docs.filter((d) => !listo(d) && !fallo(d)).map((d) => d.id);

  if (ids.length === 0) {
    info('nada para parsear', 'todos en DONE');
  } else {
    const parseo = await pedir(`/api/v1/datasets/${datasetId}/chunks`, {
      method: 'POST',
      token,
      body: { document_ids: ids },
    });
    if (parseo.datos?.code !== 0) {
      throw new Error(`no se pudo parsear: ${JSON.stringify(parseo.datos)}`);
    }
    ok('parseo lanzado', `${ids.length} documento(s)`);
  }

  // 9) esperar a que termine
  for (let intento = 0; intento < 180; intento += 1) {
    const lista = await listarDocumentos(token, datasetId);
    const listos = lista.filter(listo).length;
    const fallidos = lista.filter(fallo).length;
    process.stdout.write(
      `\r  ..   parseando: ${listos}/${lista.length} listos, ${fallidos} fallidos   `,
    );
    if (lista.length > 0 && listos + fallidos >= lista.length) {
      process.stdout.write('\n');
      if (fallidos > 0) console.log(`  !!   ${fallidos} documento(s) fallaron`);
      break;
    }
    await new Promise((r) => setTimeout(r, 5000));
  }

  // 10) prueba de recuperación
  const prueba = await pedir('/api/v1/retrieval', {
    method: 'POST',
    token,
    body: {
      question: '¿Cuál es el procedimiento de failover de la réplica?',
      dataset_ids: [datasetId],
      page_size: 3,
    },
  });
  const chunks = prueba.datos?.data?.chunks ?? [];
  ok('recuperación', `${chunks.length} fragmento(s) para "failover de la réplica"`);
  for (const c of chunks.slice(0, 2)) {
    console.log(`       · ${(c.document_keyword ?? c.docnm_kwd ?? '?')}: ${String(c.content).replace(/\s+/g, ' ').slice(0, 90)}…`);
  }

  console.log('\n--- para el agente ---');
  console.log(`RAGFLOW_API_KEY=${apiKey}`);
  console.log(`MCP: ${API}/api/v1/mcp`);
  console.log(`DATASET_ID=${datasetId}`);
}

main().catch((e) => {
  console.error('\nERROR:', e.message);
  process.exit(1);
});
