import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, setToken } from '../api.js'

export default function Login({ onLogin }) {
  const [mode, setMode] = useState('login')
  const [form, setForm] = useState({ username: '', email: '', password: '' })
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const navigate = useNavigate()

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    setBusy(true)
    try {
      const data = mode === 'login'
        ? await api.login(form.email, form.password)
        : await api.register(form.username, form.email, form.password)
      setToken(data.user.token)
      onLogin(data.user)
      navigate('/')
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>{mode === 'login' ? 'Ingresar' : 'Crear cuenta'}</h2>

      {mode === 'register' && (
        <label>
          Usuario
          <input value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} required />
        </label>
      )}

      <label>
        Email
        <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required />
      </label>

      <label>
        Contraseña
        <input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required minLength={8} />
      </label>

      {error && <p className="error">{error}</p>}

      <button type="submit" disabled={busy}>{busy ? 'Enviando…' : mode === 'login' ? 'Ingresar' : 'Registrarme'}</button>

      <p className="muted">
        {mode === 'login' ? '¿No tenés cuenta?' : '¿Ya tenés cuenta?'}{' '}
        <button type="button" className="link" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
          {mode === 'login' ? 'Crear una' : 'Ingresar'}
        </button>
      </p>
    </form>
  )
}
