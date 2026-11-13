import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api.js'

const PAGE = 10

export default function Home() {
  const [articles, setArticles] = useState([])
  const [count, setCount] = useState(0)
  const [page, setPage] = useState(0)
  const [tag, setTag] = useState('')
  const [tags, setTags] = useState([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [ms, setMs] = useState(null)

  useEffect(() => {
    api.tags().then((d) => setTags(d.tags)).catch(() => {})
  }, [])

  useEffect(() => {
    setLoading(true)
    setError('')
    const t0 = performance.now()
    api
      .articles({ limit: PAGE, offset: page * PAGE, tag: tag || undefined })
      .then((d) => {
        setArticles(d.articles)
        setCount(d.articlesCount)
      })
      .catch((e) => setError(e.message))
      .finally(() => {
        setMs(Math.round(performance.now() - t0))
        setLoading(false)
      })
  }, [page, tag])

  const totalPages = Math.max(1, Math.ceil(count / PAGE))

  return (
    <div className="grid">
      <section>
        <div className="banner">
          <h1>Conduit</h1>
          <p>Demostración de la API sobre PostgreSQL con 6M de artículos.</p>
        </div>

        <div className="tabs">
          <button className={tag === '' ? 'active' : ''} onClick={() => { setTag(''); setPage(0) }}>
            Todos
          </button>
          <span className="spacer" />
          {ms !== null && <small>{count.toLocaleString('es-AR')} resultados · {ms} ms</small>}
        </div>

        {error && <p className="error">Error: {error}</p>}
        {loading && <p>Cargando…</p>}

        <ul className="articles">
          {articles.map((a) => (
            <li key={a.slug} className="article-item">
              <div className="article-meta">
                <strong>{a.author?.username}</strong>
                <small>{new Date(a.createdAt).toLocaleDateString('es-AR')}</small>
              </div>
              <Link to={`/article/${a.slug}`} className="article-title">{a.title}</Link>
              <p>{a.description}</p>
            </li>
          ))}
        </ul>

        {!loading && articles.length === 0 && <p>Sin resultados.</p>}

        <div className="pagination">
          <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>‹ Anterior</button>
          <span>Página {page + 1} de {totalPages}</span>
          <button disabled={page + 1 >= totalPages} onClick={() => setPage((p) => p + 1)}>Siguiente ›</button>
        </div>
      </section>

      <aside className="sidebar">
        <h3>Etiquetas populares</h3>
        <div className="tagcloud">
          {tags.slice(0, 20).map((t) => (
            <button key={t} className={tag === t ? 'chip active' : 'chip'} onClick={() => { setTag(t); setPage(0) }}>
              {t}
            </button>
          ))}
        </div>
      </aside>
    </div>
  )
}
