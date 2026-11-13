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
    process.exit(0);
  });
  // si algo queda colgado, no esperar para siempre
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => apagar('SIGTERM'));
process.on('SIGINT', () => apagar('SIGINT'));
