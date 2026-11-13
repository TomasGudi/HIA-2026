// Prueba de humo del servidor MCP (§ extra).
//
// Se conecta como lo haría Hermes, lista las herramientas y ejecuta cada una.
// Falla con código 1 si algo no responde o si el servidor acepta una petición
// sin token.
//
// Uso:  MCP_URL=http://127.0.0.1:8099/mcp MCP_TOKEN=... node test/smoke.mjs

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const URL_MCP = process.env.MCP_URL ?? 'http://127.0.0.1:8080/mcp';
const TOKEN = process.env.MCP_TOKEN ?? '';
const base = URL_MCP.replace(/\/mcp$/, '');

let fallos = 0;
const ok = (nombre, detalle = '') => console.log(`PASS  ${nombre}${detalle ? ` — ${detalle}` : ''}`);
const mal = (nombre, detalle) => {
  fallos += 1;
  console.log(`FAIL  ${nombre} — ${detalle}`);
};

// 1) salud
try {
  const r = await fetch(`${base}/health`);
  const j = await r.json();
  if (r.ok && j.status === 'ok') ok('GET /health', `escritura=${j.escritura}`);
  else mal('GET /health', `HTTP ${r.status}`);
} catch (e) {
  mal('GET /health', e.message);
}

// 2) sin token debe ser 401
try {
  const r = await fetch(URL_MCP, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
  });
  if (r.status === 401) ok('POST /mcp sin token', 'HTTP 401');
  else mal('POST /mcp sin token', `esperaba 401, obtuve ${r.status}`);
} catch (e) {
  mal('POST /mcp sin token', e.message);
}

// 3) cliente MCP real
const client = new Client({ name: 'smoke-test', version: '1.0.0' });
const transport = new StreamableHTTPClientTransport(new URL(URL_MCP), {
  requestInit: { headers: { Authorization: `Bearer ${TOKEN}` } },
});

try {
  await client.connect(transport);
  ok('initialize', 'handshake MCP completado');
} catch (e) {
  mal('initialize', e.message);
  process.exit(1);
}

let herramientas = [];
try {
  const r = await client.listTools();
  herramientas = r.tools ?? [];
  ok('tools/list', herramientas.map((t) => t.name).join(', '));
} catch (e) {
  mal('tools/list', e.message);
}

const llamar = async (nombre, args = {}) => {
  try {
    const r = await client.callTool({ name: nombre, arguments: args });
    const t = r.content?.find((c) => c.type === 'text')?.text ?? '';
    if (r.isError) return mal(nombre, t.slice(0, 160));
    let datos = null;
    try {
      datos = JSON.parse(t);
    } catch {
      datos = t;
    }
    ok(nombre, t.replace(/\s+/g, ' ').slice(0, 120));
    return datos;
  } catch (e) {
    mal(nombre, e.message);
  }
};

const estado = await llamar('estado_plataforma');
if (estado?.estado !== 'ok') mal('estado_plataforma', 'el estado no es ok');

const lista = await llamar('listar_articulos', { limit: 2 });
if (lista && !Array.isArray(lista.articulos)) mal('listar_articulos', 'respuesta sin arreglo de artículos');

await llamar('listar_tags');
await llamar('estadisticas_bd');

if (lista?.articulos?.length) {
  await llamar('obtener_articulo', { slug: lista.articulos[0].slug });
}

await client.close();

console.log(`\n${fallos === 0 ? 'OK' : 'FALLOS'}: ${fallos} fallo(s)`);
process.exit(fallos === 0 ? 0 : 1);
