import { useEffect, useState } from 'react'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { api, getToken, setToken } from './api.js'
import Home from './pages/Home.jsx'
import Login from './pages/Login.jsx'
import Editor from './pages/Editor.jsx'
import ArticleView from './pages/ArticleView.jsx'

export default function App() {
  const [user, setUser] = useState(null)
  const [ready, setReady] = useState(false)
  const location = useLocation()
  const navigate = useNavigate()

  // Restaura la sesión si hay token guardado
  useEffect(() => {
    if (!getToken()) { setReady(true); return }
    api.me().then((d) => setUser(d.user)).catch(() => setToken(null)).finally(() => setReady(true))
  }, [])

  const logout = () => { setToken(null); setUser(null); navigate('/') }

  return (
    <>
      <header className="topbar">
        <Link to="/" className="brand">Conduit</Link>
        <nav>
          <Link to="/">Inicio</Link>
          {user && <Link to="/editor">Nuevo artículo</Link>}
          {!user && <Link to="/login">Ingresar</Link>}
          {user && (
            <button className="link" onClick={logout}>
              Salir ({user.username})
            </button>
          )}
        </nav>
      </header>

      <main className="container">
        {!ready ? (
          <p>Cargando…</p>
        ) : (
          <Routes>
            <Route path="/" element={<Home user={user} />} />
            <Route path="/login" element={<Login onLogin={setUser} />} />
            <Route path="/editor" element={<Editor user={user} />} />
            <Route path="/article/:slug" element={<ArticleView user={user} key={location.pathname} />} />
            <Route path="*" element={<p>Pantalla no encontrada.</p>} />
          </Routes>
        )}
      </main>

      <footer className="footer">
        Práctica Integradora Final — Interfaz de demostración sobre la API RealWorld
      </footer>
    </>
  )
}
