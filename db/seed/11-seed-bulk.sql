-- ============================================================
-- 11-seed-bulk.sql — Carga masiva de las tablas de relación
--
-- POR QUÉ EXISTE ESTE SCRIPT
-- El seed "ingenuo" (10-seed.sql, paso 5) hace que cada fila dispare el
-- trigger de integridad referencial: un `SELECT ... FOR KEY SHARE` sobre la
-- fila referenciada. Con 6M de comentarios apuntando a solo 200k usuarios,
-- todos los inserts compiten por los mismos locks de fila y la carga se
-- degrada a ~0.4 filas/s (medido: 30 min para <1k filas).
--
-- SOLUCIÓN: `session_replication_role = replica` desactiva los triggers de FK
-- durante la carga. La integridad se verifica DESPUÉS con consultas explícitas
-- (bloque final), y esa verificación es la evidencia de §4.
--
-- Requiere que "User", "Article" y "Tag" ya estén cargados.
-- ============================================================

\set ON_ERROR_STOP on
\timing on

\if :{?articles}
\else
  \set articles 6000000
\endif
\if :{?comments}
\else
  \set comments 6000000
\endif
\if :{?favorites}
\else
  \set favorites 6000000
\endif
\if :{?users}
\else
  \set users 200000
\endif
\if :{?tags}
\else
  \set tags 5000
\endif

SET synchronous_commit = off;
SET maintenance_work_mem = '1GB';
SET work_mem = '256MB';
-- menos checkpoints => menos amplificación de WAL (se midió 38 GB con el default)
-- max_wal_size es de clúster, no de sesión: se aplica con
-- ALTER SYSTEM SET max_wal_size='8GB'; SELECT pg_reload_conf();
SET session_replication_role = replica;

\echo '>>> limpiando tablas de relación'
TRUNCATE "_UserFollows", "_UserFavorites", "_ArticleToTag", "Comment" RESTART IDENTITY;

\echo '>>> comentarios (6 x 1M)'
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(1, least(:comments, 1000000)) AS g;
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(1000001, least(:comments, 2000000)) AS g;
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(2000001, least(:comments, 3000000)) AS g;
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(3000001, least(:comments, 4000000)) AS g;
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(4000001, least(:comments, 5000000)) AS g;
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g, 'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour', now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles), 1 + ((g * 17) % :users)
FROM generate_series(5000001, :comments) AS g;
SELECT setval(pg_get_serial_sequence('"Comment"', 'id'), :comments);

\echo '>>> favoritos'
INSERT INTO "_UserFavorites" ("A", "B")
SELECT 1 + (g % :users), g FROM generate_series(1, :favorites) AS g;

\echo '>>> articulo-etiqueta'
INSERT INTO "_ArticleToTag" ("A", "B")
SELECT g, 1 + (g % :tags) FROM generate_series(1, :articles) AS g;

SET session_replication_role = origin;
ANALYZE;

\echo '>>> VERIFICACION DE INTEGRIDAD (debe dar 0 en todas)'
SELECT 'comentarios huerfanos (articulo)' AS control, count(*) AS huerfanos
  FROM "Comment" c LEFT JOIN "Article" a ON a.id = c."articleId" WHERE a.id IS NULL
UNION ALL
SELECT 'comentarios huerfanos (autor)', count(*)
  FROM "Comment" c LEFT JOIN "User" u ON u.id = c."authorId" WHERE u.id IS NULL
UNION ALL
SELECT 'favoritos huerfanos', count(*)
  FROM "_UserFavorites" f LEFT JOIN "Article" a ON a.id = f."B" WHERE a.id IS NULL
UNION ALL
SELECT 'articulo-etiqueta huerfanos', count(*)
  FROM "_ArticleToTag" t LEFT JOIN "Tag" g ON g.id = t."B" WHERE g.id IS NULL;

\echo '>>> conteos finales'
SELECT 'User' AS tabla, count(*) AS filas FROM "User"
UNION ALL SELECT 'Tag', count(*) FROM "Tag"
UNION ALL SELECT 'Article', count(*) FROM "Article"
UNION ALL SELECT 'Comment', count(*) FROM "Comment"
UNION ALL SELECT '_UserFavorites', count(*) FROM "_UserFavorites"
UNION ALL SELECT '_ArticleToTag', count(*) FROM "_ArticleToTag"
ORDER BY tabla;
