-- ============================================================
-- 01-schema.sql — Esquema base (Sprint 1, §4)
--
-- Modelo: Conduit / RealWorld (blog tipo Medium).
-- Los nombres van entre comillas dobles porque el ORM (Prisma) usa
-- identificadores en PascalCase; respetarlo evita diferencias entre
-- el esquema documentado y el que usa la aplicación.
--
-- Índices: se crean en 03-indexes.sql, DESPUÉS de la carga masiva.
-- Dejarlos acá haría la carga de 18M de filas mucho más lenta
-- (ver docs/05-decisiones.md D-14 y el informe de §5).
-- ============================================================

BEGIN;

-- ---------- Usuarios ----------
CREATE TABLE IF NOT EXISTS "User" (
  id         SERIAL PRIMARY KEY,
  email      TEXT NOT NULL UNIQUE,
  username   TEXT NOT NULL UNIQUE,
  password   TEXT NOT NULL,
  image      TEXT DEFAULT 'https://api.realworld.io/images/smiley-cyrus.jpeg',
  bio        TEXT,
  demo       BOOLEAN NOT NULL DEFAULT false
);

-- ---------- Etiquetas ----------
CREATE TABLE IF NOT EXISTS "Tag" (
  id   SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- ---------- Artículos ----------
CREATE TABLE IF NOT EXISTS "Article" (
  id          SERIAL PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  title       TEXT NOT NULL,
  description TEXT NOT NULL,
  body        TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT now(),
  "authorId"  INTEGER NOT NULL REFERENCES "User"(id) ON DELETE CASCADE
);

-- ---------- Comentarios ----------
CREATE TABLE IF NOT EXISTS "Comment" (
  id          SERIAL PRIMARY KEY,
  body        TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT now(),
  "articleId" INTEGER NOT NULL REFERENCES "Article"(id) ON DELETE CASCADE,
  "authorId"  INTEGER NOT NULL REFERENCES "User"(id) ON DELETE CASCADE
);

-- ---------- N:M Artículo <-> Tag ----------
CREATE TABLE IF NOT EXISTS "_ArticleToTag" (
  "A" INTEGER NOT NULL REFERENCES "Article"(id) ON DELETE CASCADE,
  "B" INTEGER NOT NULL REFERENCES "Tag"(id) ON DELETE CASCADE,
  CONSTRAINT "_ArticleToTag_AB_unique" UNIQUE ("A", "B")
);

-- ---------- N:M Usuario <-> Artículo (favoritos) ----------
CREATE TABLE IF NOT EXISTS "_UserFavorites" (
  "A" INTEGER NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "B" INTEGER NOT NULL REFERENCES "Article"(id) ON DELETE CASCADE,
  CONSTRAINT "_UserFavorites_AB_unique" UNIQUE ("A", "B")
);

-- ---------- N:M Usuario <-> Usuario (seguidores) ----------
CREATE TABLE IF NOT EXISTS "_UserFollows" (
  "A" INTEGER NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  "B" INTEGER NOT NULL REFERENCES "User"(id) ON DELETE CASCADE,
  CONSTRAINT "_UserFollows_AB_unique" UNIQUE ("A", "B"),
  CONSTRAINT "_UserFollows_no_self" CHECK ("A" <> "B")
);

COMMIT;
