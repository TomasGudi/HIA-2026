# 09 — Integración y despliegue continuos

## 1. Objetivo

Que ninguna modificación defectuosa llegue a `main` ni al entorno publicado, y que el proceso sea
reproducible desde un `git push`.

## 2. Herramienta

**GitHub Actions**, porque el repositorio ya vive en GitHub: no hace falta infraestructura extra ni
credenciales adicionales, y los *status checks* se integran nativamente con la protección de rama.

## 3. Pipeline (`.github/workflows/ci.yml`)

Se dispara en `push` y `pull_request` sobre `main` y `develop`.

| Job | Qué hace | Por qué |
|---|---|---|
| `backend` | `npm ci` + `npm run build` (Nx, Node 20) | el backend debe compilar antes de construir la imagen |
| `frontend` | `npm ci` + `eslint` + `vite build` + artefacto `frontend-dist` | lint y build son la barrera mínima de calidad |
| `secrets` | `gitleaks` sobre **todo el historial** con `--redact` | un secreto puede estar en un commit viejo, no solo en el HEAD |
| `compose` | `docker compose config` + control de que `.env` no esté versionado | un compose inválido rompe el despliegue; un `.env` versionado filtra credenciales |

Decisiones de diseño:

- **`npm ci`, no `npm install`**: exige lockfile y garantiza que el build de CI sea el mismo que el local.
- **Node 20 fijo**: el host tiene Node 26, pero CI y Docker usan la misma versión LTS. Evita el
  clásico "en mi máquina anda".
- **`permissions: contents: read`**: el workflow no necesita escribir nada.
- **`concurrency` con `cancel-in-progress`**: dos pushes seguidos no encolan dos pipelines completos.
- **`gitleaks` por imagen Docker**: no requiere token ni licencia de la action.

## 4. Protección de `main`

Configurada por API (`evidence/03/branch-protection.json`):

| Regla | Valor | Efecto |
|---|---|---|
| Pull request obligatorio | sí | no se puede pushear directo |
| Status checks requeridos | `backend`, `frontend`, `secrets`, `compose` | el merge se bloquea si algún job falla |
| `strict` | sí | la rama debe estar actualizada con `main` antes de mergear |
| `enforce_admins` | **sí** | la regla también aplica al dueño del repositorio |
| Force push | no | no se puede reescribir el historial |
| Borrado de la rama | no | — |

**Prueba negativa ejecutada** (`evidence/03/branch-protection-test.log`):

```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 4 of 4 required status checks are expected.
 ! [remote rejected] main -> main (protected branch hook declined)
```

Ese intento se hizo **con la cuenta dueña del repositorio** y aun así fue rechazado: es la prueba
de que `enforce_admins=true` está funcionando y no es una regla decorativa.

> Anécdota que vale para la defensa: la primera configuración tenía `enforce_admins=false` y el push
> directo **pasó**. GitHub lo informó como *"Bypassed rule violations"*. Se detectó justamente porque
> se probó el caso negativo en lugar de asumir que la configuración estaba bien.

## 5. Flujo de trabajo

```
feature/* ──PR──> develop ──PR──> main
                     │            │
                     └─ CI ───────┴─ CI + protección
```

- El trabajo diario va a `develop` (o a ramas `feature/*` que se mergean ahí).
- `main` solo recibe merges por PR con CI verde.
- Cada commit referencia su incidencia: `feat(api): ... (HS2-42)`.

## 6. Estado

| Requisito de §8 | Estado |
|---|---|
| Configurar GitHub Actions | ✅ |
| Verificaciones automáticas | ✅ lint, build, secretos, compose |
| Construir imágenes Docker | ⬜ (Sprint 3: backend/frontend) |
| Publicar en un registro | ⬜ (GHCR, Sprint 3) |
| Despliegue automático | ⬜ (Sprint 3) |
| Secretos protegidos | ✅ GitHub Secrets no usados todavía; gitleaks activo |
| Commit de prueba | ◐ este pipeline (run #43424320086) |
| Rollback documentado | ⬜ |

## 7. Evidencia

| Evidencia | Archivo |
|---|---|
| Workflow | `.github/workflows/ci.yml` |
| Corrida exitosa (4/4 jobs) | `evidence/03/ci-evidencia.txt`, `evidence/03/ci-run-43424320086.json` |
| Configuración de protección | `evidence/03/branch-protection.json` |
| Prueba negativa de protección | `evidence/03/branch-protection-test.log` |
| Escaneo de secretos | `evidence/03/gitleaks.log` |
