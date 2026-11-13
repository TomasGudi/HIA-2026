// Test hermético del servidor MCP: no necesita la base ni el backend real.
//
// Levanta un backend falso con las respuestas mínimas de Conduit, arranca el
// servidor MCP apuntándole y verifica el contrato (auth, listado y forma de
// las respuestas). Lo que depende de PostgreSQL (`estadisticas_bd`) se prueba
// en la prueba de humo contra el stack real.

import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const TOKEN = 'token-de-prueba-suficientemente-largo';
const PUERTO_API = 18096;
const PUERTO_MCP = 18097;

const ARTICULOS = {
  articles: [
    {
      slug: 'hola-mundo',
      title: 'Hola mundo',
      description: 'Primer artículo',
      body: 'Cuerpo del artículo',
      tagList: ['react'],
      favoritesCount: 3,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-02T00:00:00.000Z',
      author: { username: 'demo' },
    },
  ],
  articlesCount: 1,
};

const api = createServer((req, res) => {
  const json = (codigo, datos) => {
    res.writeHead(codigo, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(datos));
  };
  const url = new URL(req.url, `http://127.0.0.1:${PUERTO_API}`);
  if (url.pathname === '/health') return json(200, { status: 'ok', db: 'up', uptime: 12.5, version: 'test' });
  if (url.pathname === '/api/articles') return json(200, ARTICULOS);
  if (url.pathname.startsWith('/api/articles/')) {
    const slug = decodeURIComponent(url.pathname.split('/').pop());
    if (slug === 'hola-mundo') return json(200, { article: ARTICULOS.articles[0] });
    return json(404, { errors: { article: ['not found'] } });
  }
  if (url.pathname === '/api/tags') return json(200, { tags: ['react', 'docker'] });
  return json(404, { errors: { ruta: ['no encontrada'] } });
});

await new Promise((r) => api.listen(PUERTO_API, '127.0.0.1', r));

const servidor = spawn(process.execPath, ['src/server.mjs'], {
  env: {
    ...process.env,
    MCP_PORT: String(PUERTO_MCP),
    MCP_TOKEN: TOKEN,
    API_URL: `http://127.0.0.1:${PUERTO_API}`,
    DB_HOST: '127.0.0.1',
    DB_MONITOR_PASSWORD: 'no-se-usa',
    MCP_ALLOW_WRITE: 'false',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});

let salida = '';
servidor.stdout.on('data', (d) => (salida += d));
servidor.stderr.on('data', (d) => (salida += d));

const esperarArranque = async () => {
  for (let i = 0; i < 50; i += 1) {
    try {
      const r = await fetch(`http://127.0.0.1:${PUERTO_MCP}/health`);
      if (r.ok) return;
    } catch {
      /* todavía no escucha */
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error(`el servidor no arrancó:\n${salida}`);
};

let fallos = 0;
const check = (cond, nombre, detalle = '') => {
  if (cond) console.log(`PASS  ${nombre}${detalle ? ` — ${detalle}` : ''}`);
  else {
    fallos += 1;
    console.log(`FAIL  ${nombre}${detalle ? ` — ${detalle}` : ''}`);
  }
};

try {
  await esperarArranque();

  // 1) sin token, 401
  const sinToken = await fetch(`http://127.0.0.1:${PUERTO_MCP}/mcp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
  });
  check(sinToken.status === 401, 'rechaza sin token', `HTTP ${sinToken.status}`);

  // 2) token inválido, 401
  const tokenMalo = await fetch(`http://127.0.0.1:${PUERTO_MCP}/mcp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer otro-token-cualquiera' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
  });
  check(tokenMalo.status === 401, 'rechaza token inválido', `HTTP ${tokenMalo.status}`);

  // 3) cliente real
  const client = new Client({ name: 'unit', version: '1.0.0' });
  await client.connect(
    new StreamableHTTPClientTransport(new URL(`http://127.0.0.1:${PUERTO_MCP}/mcp`), {
      requestInit: { headers: { Authorization: `Bearer ${TOKEN}` } },
    }),
  );

  const { tools } = await client.listTools();
  const nombres = tools.map((t) => t.name).sort();
  check(
    JSON.stringify(nombres) ===
      JSON.stringify(['estadisticas_bd', 'estado_plataforma', 'listar_articulos', 'listar_tags', 'obtener_articulo']),
    'expone 5 herramientas de lectura',
    nombres.join(', '),
  );
  check(!nombres.includes('crear_articulo'), 'no expone escritura por defecto');

  const llamar = async (nombre, args = {}) => {
    const r = await client.callTool({ name: nombre, arguments: args });
    const t = r.content?.find((c) => c.type === 'text')?.text ?? '';
    if (r.isError) return { isError: true, datos: t };
    return { isError: false, datos: JSON.parse(t) };
  };

  const estado = await llamar('estado_plataforma');
  check(estado.datos.estado === 'ok' && estado.datos.base_de_datos === 'up', 'estado_plataforma traduce /health');

  const lista = await llamar('listar_articulos', { limit: 2 });
  check(
    lista.datos.total === 1 && lista.datos.articulos[0].slug === 'hola-mundo',
    'listar_articulos recorta y devuelve total',
  );
  check(!('body' in lista.datos.articulos[0]), 'el listado no incluye el cuerpo completo');

  const uno = await llamar('obtener_articulo', { slug: 'hola-mundo' });
  check(uno.datos.cuerpo === 'Cuerpo del artículo', 'obtener_articulo devuelve el cuerpo');

  const inexistente = await llamar('obtener_articulo', { slug: 'no-existe' });
  check(inexistente.isError === true, 'obtener_articulo marca error si no existe');

  const tags = await llamar('listar_tags');
  check(tags.datos.total === 2, 'listar_tags devuelve el total');

  await client.close();
} catch (e) {
  fallos += 1;
  console.log(`FAIL  excepción — ${e.message}`);
} finally {
  servidor.kill('SIGTERM');
  api.close();
}

console.log(`\n${fallos === 0 ? 'OK' : 'FALLOS'}: ${fallos} fallo(s)`);
process.exit(fallos === 0 ? 0 : 1);
