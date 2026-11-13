# 05 — Configuración Docker

## 1. Servicios

| Servicio | Imagen | Puertos publicados | Redes | Perfil |
|---|---|---|---|---|
| `db` | `postgres:16.4-alpine` | `127.0.0.1:5433` | `dbnet` | — |
| `pgadmin` | `dpage/pgadmin4:8` | `127.0.0.1:8080` | `dbnet` | — |
| `backend` | build `./app/backend` | — (solo `expose 3000`) | `appnet`, `dbnet` | — |
| `frontend` | build `./app/frontend` | `127.0.0.1:8090` | `appnet` | — |
| `mantis` | build `./app/mantis` | `127.0.0.1:8081` | `dbnet` | `ops` |

Regla transversal: **ningún puerto se publica fuera de `127.0.0.1`**. La publicación a Internet
es por túnel (§9), no abriendo puertos.

## 2. Redes

| Red | Para qué | Quién está |
|---|---|---|
| `pi-appnet` | tráfico de la aplicación | `frontend` ↔ `backend` |
| `pi-dbnet` | tráfico de datos | `backend`, `db`, `pgadmin`, `mantis` |

El frontend **no** está en `dbnet`: no tiene por qué hablar con la base. Es segmentación real, no
un dibujo.

> **Aprendizaje (D-15)**: la primera versión declaraba `dbnet` como `internal: true`. Docker
> entonces **descarta silenciosamente** la publicación de puertos: `docker compose up` sale en
> verde, los contenedores están sanos, y `docker port` no muestra nada. Se detectó probando con un
> `nginx` aislado sobre la misma red.

## 3. Volúmenes

| Volumen | Contenido | Consecuencia de perderlo |
|---|---|---|
| `pi-pgdata` | datos de PostgreSQL | se regenera con `scripts/db.ps1 seed` (~13 min) |
| `pi-pgadmin` | configuración de pgAdmin | se reconfigura |
| `pi-mantis-files` | adjuntos de las incidencias | **se pierde la evidencia de §11** |

## 4. Imágenes

### Backend (`app/backend/Dockerfile`)

- Etapa `build`: `node:20` + `npm ci` + `prisma generate` + `nx build`.
- Etapa `runtime`: `node:20-slim` + OpenSSL (lo necesita Prisma) + **solo dependencias de
  producción** (`npm ci --omit=dev` sobre el `package.json` que genera Nx).
- Corre como usuario `node` (no root).
- Healthcheck propio contra `/health`, que hace un `SELECT 1` a la base: un contenedor "up" con la
  base caída no es un servicio sano.

Detalle que costó: el schema de Prisma está en `src/prisma/schema.prisma`, fuera de la ubicación
por defecto, así que el `postinstall` de `@prisma/client` **no** lo detecta. Hay que ejecutar
`npx prisma generate --schema=...` explícito en el build, y copiar `node_modules/.prisma` y
`node_modules/@prisma` a la imagen final.

### Frontend (`app/frontend/Dockerfile`)

- Etapa `build`: `node:20` + `npm ci` + `vite build`.
- Etapa `runtime`: `nginx:1.27-alpine` sirviendo estático (**74 MB**, sin Node adentro).
- `nginx.conf`: SPA fallback, `/healthz`, proxy `/api` → `http://backend:3000` (mismo origen, sin
  CORS abierto) y caché de assets con hash.

## 5. Variables de entorno

Todo por `.env` (nunca versionado) y `.env.example` con placeholders.

| Variable | Uso |
|---|---|
| `POSTGRES_*` | base principal |
| `DB_PORT` | puerto publicado (5433 por colisión con otro stack local, D-16) |
| `JWT_SECRET` | firma de tokens; obligatorio (sin fallback, H1) |
| `MANTIS_*` | base, rol, contraseña del admin y `crypto_master_salt` |
| `SEED_*` | volumen del dataset |

Dentro de la red Docker la base se resuelve como `db:5432`; el 5433 es solo el puerto del host.

## 6. Verificación (evidencia)

| Comprobación | Resultado |
|---|---|
| `docker compose config --quiet` | válido |
| `docker compose ps` | 5 servicios, 3 con healthcheck en `healthy` |
| `GET :3000/health` desde el contenedor | `{"status":"ok","db":"up"}` |
| `GET :8090/` | 200 (SPA) |
| `GET :8090/api/articles?limit=3` | 200, `articlesCount = 6.000.000` |
| Escritura completa (registro → alta → comentario) | 201 / 201 / 200 |

Detalle en `evidence/07/e2e.log`.

## 7. Limitaciones

- El listado público tarda **10,4 s**: es el objetivo principal de §5 (hoy el `count(*)` con
  `JOIN` sobre 6M de filas domina el tiempo).
- No hay límites de CPU/memoria por servicio (`deploy.resources`) todavía: se agregan en §10 para
  que las métricas de cAdvisor sean comparables.
- `frontend` y `backend` se construyen localmente; la publicación en registry llega en §8.
