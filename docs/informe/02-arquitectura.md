# 02 — Arquitectura general

Los diagramas completos (red Docker, replicación, CI/CD, monitoreo y n8n) están en
[`docs/02-arquitectura.md`](../02-arquitectura.md). Este documento describe **lo que está
desplegado hoy** y las decisiones que lo sostienen.

## 1. Vista de despliegue

```
Internet
   │  (pendiente §9: Cloudflare Tunnel)
   ▼
┌─────────────────────── host (Windows + Docker Desktop) ───────────────────────┐
│                                                                               │
│  127.0.0.1:8090           127.0.0.1:8080      127.0.0.1:8081   127.0.0.1:5433 │
│      │                        │                   │                  │        │
│  ┌───▼────────┐   appnet  ┌────▼─────┐        ┌────▼────┐        ┌────▼────┐   │
│  │ frontend   │──────────▶│ backend  │───────▶│ mantis  │        │  db     │   │
│  │ nginx      │           │ Node 20  │  dbnet │ PHP 8.3 │───────▶│ PG 16   │   │
│  └────────────┘           └────┬─────┘        └─────────┘        └─────────┘   │
│                                │                      ▲                       │
│                                └──────────────────────┘                       │
│                          ┌──────────┐                                        │
│                          │ pgadmin  │  (dbnet)                               │
│                          └──────────┘                                        │
└───────────────────────────────────────────────────────────────────────────────┘
```

## 2. Componentes y responsabilidades

| Componente | Responsabilidad | Tecnología |
|---|---|---|
| `frontend` | SPA; sirve estático y proxea `/api` al backend | Vite 5 + React 18 → nginx 1.27 |
| `backend` | API REST del dominio; autenticación JWT; healthcheck con ping a la base | Node 20 + Express 4 + Prisma 4 |
| `db` | Persistencia; extensiones de diagnóstico | PostgreSQL 16.4 |
| `pgadmin` | Administración de la base (solo loopback) | pgAdmin 8 |
| `mantis` | Gestión de incidencias (§11) | MantisBT 2.28.4 sobre PostgreSQL |

## 3. Redes y exposición

| Servicio | Redes | Puerto publicado | Justificación |
|---|---|---|---|
| `frontend` | `appnet` | `127.0.0.1:8090` | único punto de entrada de la app |
| `backend` | `appnet`, `dbnet` | **ninguno** (`expose 3000`) | solo alcanzable desde el frontend |
| `db` | `dbnet` | `127.0.0.1:5433` | acceso local para desarrollo; en prod no se publica |
| `pgadmin` | `dbnet` | `127.0.0.1:8080` | administración, jamás expuesta a Internet |
| `mantis` | `dbnet` | `127.0.0.1:8081` | perfil `ops`; acceso por túnel |

Todas las publicaciones son en **loopback**: no hay un solo puerto escuchando en `0.0.0.0`.

## 4. Flujo de una petición

```
navegador → nginx (:8090)
             ├── assets estáticos (SPA)
             └── /api/* → proxy → backend:3000 → Prisma → PostgreSQL:5432 (dbnet)
```

Un solo origen ⇒ **no hace falta CORS** (el `cors()` del backend queda como red de seguridad para
clientes externos, no como solución de arquitectura).

## 5. Decisiones estructurales

| Decisión | Motivo | Registro |
|---|---|---|
| Backend sin puerto publicado | reduce superficie; el frontend es el único borde | D-08 |
| Redes separadas `appnet` / `dbnet` | el frontend no debe hablar con la base | §7 |
| Healthcheck con `SELECT 1` | un contenedor "up" con la base caída no es un servicio sano | §7 |
| Imágenes multi-stage | la imagen final no lleva toolchain ni devDependencies | §14 |
| Mantis en perfil `ops` | no compite por recursos con la demo principal | D-21 |
| Un solo motor (PostgreSQL) | menos superficie y menos servicios que mantener | D-03/D-21 |

## 6. Pendiente (Sprint 3+)

- **Réplica streaming** (§6) y su documentación de límites.
- **Túnel** de publicación (§9) y diagrama de red definitivo.
- **Prometheus/Grafana** (§10) con exporters sobre `appnet`/`dbnet`.
- **n8n** (§13) consumiendo webhooks de Alertmanager y ejecutando los backups.
