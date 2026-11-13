import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../api.js'

export default function Editor({ user }) {
  const [form, setForm] = useState({ title: '', description: '', body: '', tagList: '' })
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const navigate = useNavigate()

  if (!user) return <p>Necesitás iniciar sesión para publicar.</p>

  const submit = async (e) => {
    e.preventDefault()
    setBusy(true)
    setError('')
    try {
      const tags = form.tagList.split(',').map((t) => t.trim()).filter(Boolean)
      const data = await api.createArticle({ ...form, tagList: tags })
      navigate(`/article/${data.article.slug}`)
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>Nuevo artículo</h2>

      <label>
        Título
        <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required />
      </label>

      <label>
        Descripción
        <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} required />
      </label>

      <label>
        Contenido
        <textarea rows={8} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
      </label>

      <label>
        Etiquetas (separadas por coma)
        <input value={form.tagList} onChange={(e) => setForm({ ...form, tagList: e.target.value })} placeholder="postgres, docker" />
      </label>

      {error && <p className="error">{error}</p>}

      <button type="submit" disabled={busy}>{busy ? 'Publicando…' : 'Publicar'}</button>
    </form>
  )
}
