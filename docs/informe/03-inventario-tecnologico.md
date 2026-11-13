# 03 — Inventario tecnológico

Versiones efectivamente usadas (no "la última que había"). Las de runtime están fijadas en los
Dockerfile o en el compose; las de dependencias, en `package-lock.json`.

## Backend

| Componente | Versión | Rol | Nota |
|---|---|---|---|
| Node.js | 20 (imagen `node:20-alpine`) | runtime | LTS; el host tiene Node 26, que no se usa para el build |
| Express | ~4.18.1 | framework HTTP | |
| Prisma Client | ^4.16.1 | ORM | `provider = postgresql` |
| jsonwebtoken | ^9.0.2 | firma de JWT | `HS256`, expiración 60 días |
| express-jwt | ^8.4.1 | middleware de auth | |
| bcryptjs | ^2.4.3 | hash de contraseñas | |
| slugify | ^1.6.0 | slugs de artículos | |
| Nx | 17.2.6 | build del monorepo | build reproducible vía `package-lock.json` |

## Frontend (reescrito, D-18)

| Componente | Versión | Rol |
|---|---|---|
| React / React DOM | ^18.3.1 | UI |
| Vite | ^5.4.8 | build y dev server |
| react-router-dom | ^6.26.2 | ruteo SPA |
| nginx | 1.27-alpine | servidor estático + proxy `/api` |

## Base de datos

| Componente | Versión | Nota |
|---|---|---|
| PostgreSQL | 16.4-alpine | primaria; réplica en §6 |
| pg_stat_statements | extensión incluida | requiere `shared_preload_libraries` |
| pg_buffercache | extensión incluida | inspección de caché |
| pgAdmin | 8 (`dpage/pgadmin4:8`) | administración, solo loopback |
| pgBadger | a definir en §4 | análisis de logs |

## Infraestructura

| Componente | Versión | Nota |
|---|---|---|
| Docker Engine | 29.9.3 | Docker Desktop sobre WSL2 |
| Docker Compose | v5.7.0 | `compose.yaml` |
| Windows | 11 | host de desarrollo |
| WSL2 / Ubuntu | 2 | backend de Docker |

## Servicios previstos (§10, §11, §12, §13)

| Componente | Imagen prevista | Estado |
|---|---|---|
| Prometheus | `prom/prometheus` | pendiente |
| Grafana | `grafana/grafana` | pendiente |
| node-exporter | `prom/node-exporter` | pendiente |
| cAdvisor | `gcr.io/cadvisor/cadvisor` | pendiente |
| postgres-exporter | `prometheuscommunity/postgres-exporter` | pendiente |
| blackbox-exporter | `prom/blackbox-exporter` | pendiente |
| Alertmanager | `prom/alertmanager` | pendiente |
| n8n | `n8nio/n8n` | pendiente |
| Mantis | a definir (soporte PostgreSQL a verificar) | pendiente |
| Nextcloud | `nextcloud` | pendiente |

## Eventos de ciberseguridad considerados al elegir el stack

El enunciado pide explícitamente tener en cuenta los últimos eventos al inventariar el stack.

| Evento | Qué fue | Impacto en nuestras decisiones |
|---|---|---|
| **CVE-2024-4577** (PHP-CGI, Windows) | inyección de argumentos explotada masivamente para ransomware | descarta stacks PHP para los servicios propios; Mantis (PHP) queda aislado y sin exposición pública |
| **GhostAction** (sep. 2025) | robo de secretos desde workflows de GitHub Actions en ~327 repos | secretos solo en GitHub Secrets + `gitleaks` en pre-commit y CI (§3/§8) |
| **xz-utils / backdoor en cadena de suministro** (2024) | puerta trasera en una dependencia de compresión | imágenes con tag fijo, sin `latest`; escaneo con Trivy (§14) |
| **Compromisos de paquetes npm/PyPI** (recurrentes) | malware en dependencias publicadas | lockfile obligatorio y `npm audit` en el pipeline |
| **EOL de Node 8/16 y `react-scripts` antiguo** | runtimes sin parches | se fija Node 20 y se reescribe el frontend (D-18) |

> Verificar con la cátedra cuál evento espera ver citado en el inventario; el informe final debe
> nombrar el mismo en §1 y en §14 para no contradecirse.

## Evidencia

| Evidencia | Archivo |
|---|---|
| Versiones de runtime | `compose.yaml`, `app/*/Dockerfile` |
| Versiones de dependencias | `app/backend/package-lock.json`, `app/frontend/package.json` |
| Versión del motor | `docker compose exec db psql -c 'select version();'` → `evidence/04/version-motor.txt` |
