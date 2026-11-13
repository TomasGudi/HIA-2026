// Cliente HTTP de la API de la aplicación.
// El MCP no habla con la base para leer artículos: usa la misma API que el
// frontend, así respeta validaciones, permisos y forma de las respuestas.

import { config } from './config.mjs';

class ApiError extends Error {
  constructor(mensaje, status, cuerpo) {
    super(mensaje);
    this.status = status;
    this.cuerpo = cuerpo;
  }
}

async function pedir(ruta, { method = 'GET', body, token, timeoutMs = 10000 } = {}) {
  const url = `${config.apiUrl}${ruta}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method,
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Token ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const texto = await res.text();
    let datos = null;
    try {
      datos = texto ? JSON.parse(texto) : null;
    } catch {
      datos = texto;
    }
    if (!res.ok) {
      throw new ApiError(`La API respondió ${res.status} en ${method} ${ruta}`, res.status, datos);
    }
    return datos;
  } catch (err) {
    if (err.name === 'AbortError') {
      throw new Error(`La API no respondió en ${timeoutMs} ms (${method} ${ruta})`);
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

export const api = {
  salud: () => pedir('/health'),

  articulos: ({ limit = 5, offset = 0, tag, autor } = {}) => {
    const q = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (tag) q.set('tag', tag);
    if (autor) q.set('author', autor);
    return pedir(`/api/articles?${q}`);
  },

  articulo: (slug) => pedir(`/api/articles/${encodeURIComponent(slug)}`),

  tags: () => pedir('/api/tags', { timeoutMs: 30000 }),

  async login() {
    const { email, password } = config.writeUser;
    if (!email || !password) {
      throw new Error(
        'MCP_ALLOW_WRITE está activo pero faltan MCP_USER_EMAIL y MCP_USER_PASSWORD',
      );
    }
    const r = await pedir('/api/users/login', { method: 'POST', body: { user: { email, password } } });
    const token = r?.user?.token;
    if (!token) throw new Error('El login no devolvió token');
    return token;
  },

  async crearArticulo({ titulo, descripcion, cuerpo, tags = [] }) {
    const token = await this.login();
    const r = await pedir('/api/articles', {
      method: 'POST',
      token,
      body: { article: { title: titulo, description: descripcion, body: cuerpo, tagList: tags } },
    });
    return r?.article ?? r;
  },
};

export { ApiError };
