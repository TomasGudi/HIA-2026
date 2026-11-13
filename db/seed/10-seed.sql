-- ============================================================
-- 10-seed.sql — Dataset de prueba masivo (§4)
--
-- Uso:
--   psql -v ON_ERROR_STOP=1 \
--        -v articles=6000000 -v comments=6000000 -v favorites=6000000 \
--        -v users=200000 -v tags=5000 \
--        -f /db/seed/10-seed.sql
--
-- Diseño:
--  - Datos SINTÉTICOS y deterministas (misma semilla → mismo dataset).
--  - Se respetan las FKs: usuarios -> artículos -> comentarios/favoritos.
--  - Sin random(): la generación es reproducible y más rápida.
--  - Los índices NO existen todavía (se aplican después, ver db/03-indexes.sql).
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

-- Sesión de carga: prioriza velocidad sobre durabilidad.
-- Al terminar se restaura synchronous_commit (ver último bloque).
SET synchronous_commit = off;
SET maintenance_work_mem = '1GB';
SET work_mem = '256MB';

\echo '>>> 1/6 limpiando tablas'
TRUNCATE "_UserFollows", "_UserFavorites", "_ArticleToTag", "Comment", "Article", "Tag", "User" RESTART IDENTITY CASCADE;

\echo '>>> 2/6 usuarios'
INSERT INTO "User" (id, email, username, password, bio, demo)
SELECT g,
       'user' || g || '@example.com',
       'user' || g,
       -- hash ficticio con formato bcrypt: NO es una credencial válida
       '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
       CASE WHEN g % 7 = 0 THEN 'Bio del usuario ' || g ELSE NULL END,
       false
FROM generate_series(1, :users) AS g;
SELECT setval(pg_get_serial_sequence('"User"', 'id'), :users);

\echo '>>> 3/6 etiquetas'
INSERT INTO "Tag" (id, name)
SELECT g, 'tag-' || lpad(g::text, 5, '0')
FROM generate_series(1, :tags) AS g;
SELECT setval(pg_get_serial_sequence('"Tag"', 'id'), :tags);

\echo '>>> 4/6 articulos'
INSERT INTO "Article" (id, slug, title, description, body, "createdAt", "updatedAt", "authorId")
SELECT g,
       'article-' || md5(g::text),
       'Artículo número ' || g,
       'Descripción breve del artículo ' || g,
       repeat('Lorem ipsum dolor sit amet, consectetur adipiscing elit. ', 12),
       now() - (g % 365) * interval '1 day',
       now() - (g % 365) * interval '1 day',
       1 + (g % :users)
FROM generate_series(1, :articles) AS g;
SELECT setval(pg_get_serial_sequence('"Article"', 'id'), :articles);

\echo '>>> 5/6 comentarios y favoritos'
INSERT INTO "Comment" (id, body, "createdAt", "updatedAt", "articleId", "authorId")
SELECT g,
       'Comentario ' || g || ': buen artículo, coincido en lo principal.',
       now() - (g % 180) * interval '1 hour',
       now() - (g % 180) * interval '1 hour',
       1 + ((g * 31) % :articles),
       1 + ((g * 17) % :users)
FROM generate_series(1, :comments) AS g;
SELECT setval(pg_get_serial_sequence('"Comment"', 'id'), :comments);

INSERT INTO "_UserFavorites" ("A", "B")
SELECT 1 + (g % :users), g
FROM generate_series(1, :favorites) AS g;

\echo '>>> 6/6 relaciones articulo-etiqueta'
INSERT INTO "_ArticleToTag" ("A", "B")
SELECT g, 1 + (g % :tags)
FROM generate_series(1, :articles) AS g;

ANALYZE;

RESET synchronous_commit;

\echo '>>> conteos finales'
SELECT 'User'           AS tabla, count(*) AS filas FROM "User"
UNION ALL SELECT 'Tag',            count(*) FROM "Tag"
UNION ALL SELECT 'Article',        count(*) FROM "Article"
UNION ALL SELECT 'Comment',        count(*) FROM "Comment"
UNION ALL SELECT '_UserFavorites', count(*) FROM "_UserFavorites"
UNION ALL SELECT '_ArticleToTag',  count(*) FROM "_ArticleToTag"
ORDER BY tabla;
