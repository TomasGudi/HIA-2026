import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api.js'

export default function ArticleView({ user }) {
  const { slug } = useParams()
  const [article, setArticle] = useState(null)
  const [comments, setComments] = useState([])
  const [text, setText] = useState('')
  const [error, setError] = useState('')
  const [ms, setMs] = useState(null)

  const load = () => {
    const t0 = performance.now()
    Promise.all([api.article(slug), api.comments(slug)])
      .then(([a, c]) => {
        setArticle(a.article)
        setComments(c.comments)
      })
      .catch((e) => setError(e.message))
      .finally(() => setMs(Math.round(performance.now() - t0)))
  }

  useEffect(load, [slug])

  const addComment = async (e) => {
    e.preventDefault()
    if (!text.trim()) return
    try {
      await api.addComment(slug, text)
      setText('')
      load()
    } catch (err) {
      setError(err.message)
    }
  }

  if (error) return <p className="error">Error: {error}</p>
  if (!article) return <p>Cargando…</p>

  return (
    <article>
      <Link to="/" className="muted">← Volver</Link>
      <h1>{article.title}</h1>
      <p className="muted">
        por {article.author?.username} · {new Date(article.createdAt).toLocaleString('es-AR')}
        {ms !== null && <> · cargado en {ms} ms</>}
      </p>
      <p className="lead">{article.description}</p>
      <div className="body">{article.body}</div>

      <div className="tagcloud">
        {article.tagList?.map((t) => <span key={t} className="chip">{t}</span>)}
      </div>

      <h3>Comentarios ({comments.length})</h3>
      <ul className="comments">
        {comments.map((c) => (
          <li key={c.id}>
            <strong>{c.author?.username}</strong>
            <p>{c.body}</p>
          </li>
        ))}
      </ul>

      {user ? (
        <form onSubmit={addComment} className="comment-form">
          <textarea rows={3} value={text} onChange={(e) => setText(e.target.value)} placeholder="Escribí un comentario…" />
          <button type="submit">Comentar</button>
        </form>
      ) : (
        <p className="muted">Iniciá sesión para comentar.</p>
      )}
    </article>
  )
}
