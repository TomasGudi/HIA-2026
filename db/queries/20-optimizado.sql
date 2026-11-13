-- ============================================================
-- 20-optimizado.sql — Las mismas 8 consultas, DESPUÉS de optimizar
--
-- Cada cambio tiene su motivo medido. No se agrega ningún índice
-- "por las dudas": al final hay una prueba de un índice que se
-- descartó porque no aportaba.
-- ============================================================

\timing on

-- ------------------------------------------------------------
-- O1. Q1 (count exacto de 6M): el problema no es el join, es contar 6M.
--     Se acota el conteo: la UI solo necesita saber cuántas páginas hay.
--     LIMIT dentro del count hace que el plan corte al alcanzar el tope.
-- ------------------------------------------------------------
\echo '===== O1: count acotado (Q1) ====='
SELECT count(*) FROM (
  SELECT 1
  FROM "Article" a
  JOIN "User" u ON u.id = a."authorId"
  WHERE u.demo = true
  LIMIT 10000
) t;

-- ------------------------------------------------------------
-- O2. Q2b (paginación profunda): keyset pagination en lugar de OFFSET.
--     OFFSET n obliga a leer y descartar n filas; con keyset se salta
--     directo al punto de corte usando el índice de createdAt.
-- ------------------------------------------------------------
\echo '===== O2: keyset pagination (Q2b) ====='
SELECT a.id, a.slug, a.title, a."createdAt", u.username
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
WHERE u.demo = true
  AND (a."createdAt", a.id) < (SELECT "createdAt", id FROM "Article" WHERE id = 500000)
ORDER BY a."createdAt" DESC, a.id DESC
LIMIT 10;

-- ------------------------------------------------------------
-- O3. Q4 (etiquetas populares): agrega 6M de filas en cada request.
--     Se materializa el agregado y se refresca por cron (n8n, §13).
--     Trade-off: el dato puede tener hasta N minutos de atraso.
-- ------------------------------------------------------------
\echo '===== O3: vista materializada de etiquetas ====='
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tag_counts AS
SELECT t.id, t.name, count(*) AS n
FROM "_ArticleToTag" at
JOIN "Tag" t ON t.id = at."B"
GROUP BY t.id, t.name;
CREATE UNIQUE INDEX IF NOT EXISTS mv_tag_counts_id_idx ON mv_tag_counts (id);
CREATE INDEX IF NOT EXISTS mv_tag_counts_n_idx ON mv_tag_counts (n DESC);
ANALYZE mv_tag_counts;

\echo '===== O3: consulta sobre la vista ====='
SELECT name, n FROM mv_tag_counts ORDER BY n DESC LIMIT 10;

-- ------------------------------------------------------------
-- O4. Q5 (feed): el join con _UserFollows confunde al planificador y
--     termina escaneando artículos. Se reescribe como IN (subconsulta),
--     que fuerza el camino: pocos autores -> índice por authorId.
-- ------------------------------------------------------------
\echo '===== O4: feed reescrito (Q5) ====='
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
WHERE a."authorId" IN (SELECT "B" FROM "_UserFollows" WHERE "A" = 42)
ORDER BY a."createdAt" DESC
LIMIT 10;

\echo '===== O4: plan del feed ====='
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
WHERE a."authorId" IN (SELECT "B" FROM "_UserFollows" WHERE "A" = 42)
ORDER BY a."createdAt" DESC
LIMIT 10;

-- ------------------------------------------------------------
-- O5. Q7 (top por favoritos): mismo patrón que O3.
-- ------------------------------------------------------------
\echo '===== O5: vista materializada de favoritos ====='
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_article_favorites AS
SELECT "B" AS article_id, count(*) AS favs
FROM "_UserFavorites"
GROUP BY "B";
CREATE UNIQUE INDEX IF NOT EXISTS mv_article_favorites_id_idx ON mv_article_favorites (article_id);
CREATE INDEX IF NOT EXISTS mv_article_favorites_favs_idx ON mv_article_favorites (favs DESC);
ANALYZE mv_article_favorites;

\echo '===== O5: consulta sobre la vista ====='
SELECT a.id, a.title, m.favs
FROM mv_article_favorites m
JOIN "Article" a ON a.id = m.article_id
ORDER BY m.favs DESC
LIMIT 10;

-- ------------------------------------------------------------
-- O6. Q8 (ILIKE '%texto%'): no es SARGable, ningún B-tree sirve.
--     Se agrega pg_trgm + índice GIN, que sí indexa subcadenas.
--     Costo real: el índice pesa y hay que mantenerlo en cada INSERT.
-- ------------------------------------------------------------
\echo '===== O6: indice trigram para busqueda por subcadena ====='
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS "Article_title_trgm_idx"
  ON "Article" USING gin (title gin_trgm_ops);
ANALYZE "Article";

\echo '===== O6: busqueda con indice trigram (Q8) ====='
SELECT id, title
FROM "Article"
WHERE title ILIKE '%numero 9999%'
LIMIT 10;

\echo '===== O6: plan con trigram ====='
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, title
FROM "Article"
WHERE title ILIKE '%numero 9999%'
LIMIT 10;

-- ------------------------------------------------------------
-- O7. CONTROL NEGATIVO: ¿conviene un índice parcial en User(demo)?
--     Se crea, se mide y se decide con el número en la mano.
-- ------------------------------------------------------------
\echo '===== O7: indice parcial en User(demo) — prueba ====='
CREATE INDEX IF NOT EXISTS "User_demo_partial_idx" ON "User" (id) WHERE demo;
ANALYZE "User";

\echo '===== O7: count con el indice parcial ====='
SELECT count(*) FROM (
  SELECT 1
  FROM "Article" a
  JOIN "User" u ON u.id = a."authorId"
  WHERE u.demo = true
  LIMIT 10000
) t;

\echo '===== O7: tamano del indice ====='
SELECT pg_size_pretty(pg_relation_size('"User_demo_partial_idx"')) AS tamano_indice_parcial;
