# Práctica Integradora Final

Aplicación web (Conduit/RealWorld) contenerizada con PostgreSQL, réplica, CI/CD,
monitoreo, seguridad y automatización con n8n.

- **Sección del trabajo:** Práctica Integradora Final 2026
- **Backlog:** [Jira HIA-Scrum-2026](https://tomassgudi-1794538432846.atlassian.net/jira/software/projects/HS2/boards/3)
- **Documentación del proyecto:** [`docs/`](docs/) — empezar por [`docs/00-plan-proyecto.md`](docs/00-plan-proyecto.md)
- **Backlog versionado:** [`backlog/jira-import.csv`](backlog/jira-import.csv)

## Stack

| Capa | Tecnología |
|---|---|
| Base de datos | PostgreSQL 16 (primaria + réplica streaming) |
| Backend | Node.js / Express (API RealWorld) |
| Frontend | React (SPA servida por nginx) |
| Administración DB | pgAdmin 8 |
| Monitoreo | Prometheus + Grafana + exporters |
| CI/CD | GitHub Actions |
| Automatización | n8n |
| Incidencias | Mantis |

## Quickstart

```powershell
# 1. variables de entorno
Copy-Item .env.example .env
# editar .env y cambiar TODAS las contraseñas

# 2. base de datos + pgAdmin
docker compose up -d db pgadmin

# 3. verificar
docker compose ps
# pgAdmin: http://127.0.0.1:8080

# 4. cargar el dataset de prueba (18M de filas; tarda varios minutos)
./scripts/db.ps1 seed

# 5. crear índices DESPUÉS de la carga
./scripts/db.ps1 indexes

# 6. ver tamaño y conteos
./scripts/db.ps1 stats
```

## Estructura

```
.
├── compose.yaml           # servicios, redes y volúmenes
├── db/
│   ├── init/              # esquema y extensiones (primer arranque)
│   ├── seed/              # dataset sintético masivo
│   └── 03-indexes.sql     # índices, aplicados después de la carga
├── scripts/db.ps1         # atajos: up | seed | indexes | stats | reset
├── docs/                  # plan, backlog, arquitectura y decisiones
└── backlog/               # backlog exportable a Jira
```

## Reglas del repositorio

- `.env` **nunca** se versiona. Solo `.env.example` con placeholders.
- La base de datos no se publica fuera de loopback (`127.0.0.1`); en producción se llega por túnel.
- Ramas: `main` (estable), `develop` (integración), `feature/*`, `fix/*`.
- Cada commit referencia su incidencia: `feat(api): listado por tag (HS2-42)`.
- Los datos del dataset son **sintéticos**: no hay información personal real.

## Estado

| Sección | Estado |
|---|---|
| §1 Diagnóstico | pendiente |
| §2 Scrum | tablero y sprints cargados |
| §3 Repositorio | en curso |
| §4 DB contenerizada + dataset | en curso |
| §5–§15 | planificados (ver `docs/00-plan-proyecto.md`) |
