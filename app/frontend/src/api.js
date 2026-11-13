// Cliente de la API RealWorld (Conduit).
// Base configurable: /api por defecto (proxy de Vite en dev, de nginx en prod).
const BASE = import.meta.env.VITE_API_URL || '/api'

const TOKEN_KEY = 'pi_token'

export const getToken = () => localStorage.getItem(TOKEN_KEY)
export const setToken = (token) => {
  if (token) localStorage.setItem(TOKEN_KEY, token)
  else localStorage.removeItem(TOKEN_KEY)
}

async function request(path, { method = 'GET', body, auth = true } = {}) {
  const headers = { 'Content-Type': 'application/json' }
  const token = getToken()
  if (auth && token) headers.Authorization = `Token ${token}`

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  })

  const text = await res.text()
  const data = text ? JSON.parse(text) : null

  if (!res.ok) {
    const msg = data?.errors ? Object.entries(data.errors).map(([k, v]) => `${k} ${v}`).join(', ') : `HTTP ${res.status}`
    throw new Error(msg)
  }
  return data
}

export const api = {
  login: (email, password) => request('/users/login', { method: 'POST', body: { user: { email, password } }, auth: false }),
  register: (username, email, password) => request('/users', { method: 'POST', body: { user: { username, email, password } }, auth: false }),
  me: () => request('/user'),

  articles: ({ limit = 10, offset = 0, tag } = {}) => {
    const q = new URLSearchParams({ limit, offset })
    if (tag) q.set('tag', tag)
    return request(`/articles?${q.toString()}`, { auth: false })
  },
  article: (slug) => request(`/articles/${slug}`, { auth: false }),
  createArticle: (article) => request('/articles', { method: 'POST', body: { article } }),
  deleteArticle: (slug) => request(`/articles/${slug}`, { method: 'DELETE' }),
  favorite: (slug, on) => request(`/articles/${slug}/favorite`, { method: on ? 'POST' : 'DELETE' }),

  comments: (slug) => request(`/articles/${slug}/comments`, { auth: false }),
  addComment: (slug, body) => request(`/articles/${slug}/comments`, { method: 'POST', body: { comment: { body } } }),

  tags: () => request('/tags', { auth: false }),
}
