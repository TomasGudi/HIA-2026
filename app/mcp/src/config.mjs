// Configuración del servidor MCP, leída del entorno.
// Falla cerrado: sin token no arranca (mismo criterio que el webhook de n8n, §13).

const num = (v, def) => (v === undefined || v === '' ? def : Number(v));

export const config = {
  port: num(process.env.MCP_PORT, 8080),
  host: process.env.MCP_HOST ?? '0.0.0.0',

  // token que debe presentar el cliente (Hermes) en Authorization: Bearer ...
  token: process.env.MCP_TOKEN ?? '',

  // API interna de la aplicación (Conduit)
  apiUrl: (process.env.API_URL ?? 'http://backend:3000').replace(/\/+$/, ''),

  // base de datos en modo solo lectura (rol `monitor`, el mismo del exporter)
  db: {
    host: process.env.DB_HOST ?? 'db',
    port: num(process.env.DB_PORT, 5432),
    database: process.env.DB_NAME ?? 'practica',
    user: process.env.DB_MONITOR_USER ?? 'monitor',
    password: process.env.DB_MONITOR_PASSWORD ?? '',
    // sin esto una consulta colgada bloquea el turno del agente
    statement_timeout: num(process.env.DB_STATEMENT_TIMEOUT_MS, 5000),
  },

  // escritura deshabilitada por defecto: el agente solo lee salvo que se pida
  allowWrite: (process.env.MCP_ALLOW_WRITE ?? 'false').toLowerCase() === 'true',
  writeUser: {
    email: process.env.MCP_USER_EMAIL ?? '',
    password: process.env.MCP_USER_PASSWORD ?? '',
  },

  // incidentes: base de operación separada de la primaria
  opsDb: {
    host: process.env.OPS_DB_HOST ?? 'opsdb',
    port: num(process.env.OPS_DB_PORT, 5432),
    database: process.env.OPS_DB_NAME ?? 'ops',
    user: process.env.OPS_DB_USER ?? 'mcp_ops',
    password: process.env.MCP_OPS_DB_PASSWORD ?? '',
  },

  // correo saliente: MailHog en la demo (sin TLS ni auth)
  smtp: {
    host: process.env.SMTP_HOST ?? '',
    port: num(process.env.SMTP_PORT, 1025),
    from: process.env.MAIL_FROM ?? 'ops@pi.local',
    to: process.env.MAIL_TO ?? 'operador@pi.local',
  },

  // aviso proactivo por Telegram (el bot es el mismo que usa Hermes)
  telegram: {
    token: process.env.TELEGRAM_BOT_TOKEN ?? '',
    chatId:
      process.env.TELEGRAM_CHAT_ID ??
      (process.env.TELEGRAM_ALLOWED_USERS ?? '').split(',')[0].trim(),
  },

  // Mantis: el MCP crea la incidencia directamente para no depender de n8n
  mantis: {
    url: (process.env.MANTIS_URL ?? 'http://mantis').replace(/\/+$/, ''),
    token: process.env.MANTIS_API_TOKEN ?? '',
  },

  // la base de incidentes es opcional: sin password el MCP sigue siendo
  // solo-lectura y las herramientas de incidentes no se registran.
  incidentsEnabled:
    (process.env.MCP_INCIDENTS_ENABLED ?? 'true').toLowerCase() === 'true' &&
    !!process.env.MCP_OPS_DB_PASSWORD,
};

export function validarConfig() {
  if (config.token.length < 16) {
    throw new Error(
      'MCP_TOKEN ausente o demasiado corto (mínimo 16 caracteres): el servidor no arranca sin autenticación',
    );
  }
}
