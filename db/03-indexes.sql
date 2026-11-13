-- ============================================================
-- 03-indexes.sql — Índices
--
-- IMPORTANTE: se aplica DESPUÉS de la carga masiva (§4) y ANTES de
-- medir el baseline de §5. Crear los índices después de cargar es
-- una decisión medida, no una comodidad: mantener 6 índices vivos
-- durante 18M de INSERT cuesta horas (ver docs/informe/07-optimizacion-sql.md).
--
-- Acá van SOLO los índices de integridad y de claves foráneas,
-- que son los que el ORM asume. Los índices de rendimiento
-- (compuestos, parciales, de cobertura) se agregan en §5 con su
-- justificación y su medición antes/después.
-- ============================================================

BEGIN;

-- FKs: sin estos, cada DELETE de un autor escanea 6M de filas
CREATE INDEX IF NOT EXISTS "Article_authorId_idx"    ON "Article" ("authorId");
CREATE INDEX IF NOT EXISTS "Comment_articleId_idx"   ON "Comment" ("articleId");
CREATE INDEX IF NOT EXISTS "Comment_authorId_idx"    ON "Comment" ("authorId");

-- Lado "B" de las N:M (el lado "A" ya queda cubierto por el UNIQUE (A,B))
CREATE INDEX IF NOT EXISTS "_ArticleToTag_B_idx"     ON "_ArticleToTag" ("B");
CREATE INDEX IF NOT EXISTS "_UserFavorites_B_idx"    ON "_UserFavorites" ("B");
CREATE INDEX IF NOT EXISTS "_UserFollows_B_idx"      ON "_UserFollows" ("B");

-- Orden cronológico del feed (se usará desde §5)
CREATE INDEX IF NOT EXISTS "Article_createdAt_idx"   ON "Article" ("createdAt" DESC);

ANALYZE;

COMMIT;
