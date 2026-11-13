-- ============================================================
-- 10-baseline.sql — Las 8 consultas de §5, ANTES de optimizar
--
-- No son consultas inventadas: cada una corresponde a una operación
-- real del backend (Prisma) sobre el esquema Conduit.
--
--   Q1  count del listado público        -> article.service.ts getArticles
--   Q2  listado paginado (offset 0)      -> getArticles
--   Q3  listado filtrado por etiqueta    -> getArticles + ?tag=
--   Q4  etiquetas populares (top 10)     -> tag.service.ts getTags
--   Q5  feed de autores seguidos         -> getFeed
--   Q6  detalle de artículo + comentarios-> getArticle
--   Q7  top de artículos por favoritos   -> _count.favoritedBy
--   Q8  búsqueda por título con ILIKE    -> consulta no SARGable (caso de §5)
--
-- Ejecutar con:  psql -f /db/queries/10-baseline.sql
-- ============================================================

\timing on

\echo '========== Q1: count del listado publico =========='
SELECT count(*)
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE u.demo = true;

\echo '========== Q1 (plan) =========='
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE u.demo = true;

\echo '========== Q2: listado paginado (offset 0) =========='
SELECT a.id, a.slug, a.title, a."createdAt", u.username
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE u.demo = true
ORDER BY a."createdAt" DESC
LIMIT 10 OFFSET 0;

\echo '========== Q2b: paginacion profunda (offset 500000) =========='
SELECT a.id, a.slug, a.title, a."createdAt", u.username
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE u.demo = true
ORDER BY a."createdAt" DESC
LIMIT 10 OFFSET 500000;

\echo '========== Q3: listado filtrado por etiqueta =========='
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
JOIN "_ArticleToTag" at ON at."A" = a.id
JOIN "Tag" t ON t.id = at."B"
WHERE u.demo = true AND t.name = 'tag-00042'
ORDER BY a."createdAt" DESC
LIMIT 10;

\echo '========== Q3 (plan) =========='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
JOIN "_ArticleToTag" at ON at."A" = a.id
JOIN "Tag" t ON t.id = at."B"
WHERE u.demo = true AND t.name = 'tag-00042'
ORDER BY a."createdAt" DESC
LIMIT 10;

\echo '========== Q4: etiquetas populares (top 10) =========='
SELECT t.name, count(*) AS n
FROM "Tag" t
JOIN "_ArticleToTag" at ON at."B" = t.id
GROUP BY t.name
ORDER BY n DESC
LIMIT 10;

\echo '========== Q4 (plan) =========='
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.name, count(*) AS n
FROM "Tag" t
JOIN "_ArticleToTag" at ON at."B" = t.id
GROUP BY t.name
ORDER BY n DESC
LIMIT 10;

\echo '========== Q5: feed de autores seguidos =========='
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
JOIN "_UserFollows" f ON f."B" = u.id
WHERE f."A" = 42
ORDER BY a."createdAt" DESC
LIMIT 10;

\echo '========== Q6: detalle de articulo + comentarios =========='
SELECT a.id, a.title, u.username,
       (SELECT count(*) FROM "Comment" c WHERE c."articleId" = a.id) AS comentarios
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE a.slug = 'article-' || md5('12345');

\echo '========== Q7: top de articulos por favoritos =========='
SELECT a.id, count(f."A") AS favs
FROM "Article" a
LEFT JOIN "_UserFavorites" f ON f."B" = a.id
GROUP BY a.id
ORDER BY favs DESC
LIMIT 10;

\echo '========== Q8: busqueda por titulo (ILIKE, no SARGable) =========='
SELECT id, title
FROM "Article"
WHERE title ILIKE '%numero 9999%'
LIMIT 10;

\echo '========== Q8 (plan) =========='
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title
FROM "Article"
WHERE title ILIKE '%numero 9999%'
LIMIT 10;
