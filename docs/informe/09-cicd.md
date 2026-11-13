# 09 — Integración y despliegue continuos

## 1. Objetivo

Que ninguna modificación defectuosa llegue a `main` ni al entorno publicado, que el despliegue sea
reproducible, y que si una versión nueva rompe el servicio el sistema vuelva solo a la anterior.

## 2. Herramienta

**GitHub Actions**, porque el repositorio ya vive en GitHub: no hace falta infraestructura extra ni
credenciales adicionales, y los *status checks* se integran nativamente con la protección de rama.

## 3. Integración continua (`.github/workflows/ci.yml`)

Se dispara en `push` y `pull_request` sobre `main` y `develop`.

| Job | Qué hace | Por qué |
|---|---|---|
| `backend` | `npm ci` + `npm run build` (Nx, Node 20) | el backend debe compilar antes de construir la imagen |
| `frontend` | `npm ci` + `eslint` + `vite build` + artefacto `frontend-dist` | lint y build son la barrera mínima de calidad |
| `secrets` | `gitleaks` sobre **todo el historial** con `--redact` | un secreto puede estar en un commit viejo, no solo en el HEAD |
| `compose` | `docker compose config` + control de que `.env` no está versionado | un compose inválido rompe el despliegue; un `.env` versionado filtra credenciales |

Decisiones de diseño:

- **`npm ci`, no `npm install`**: exige lockfile y garantiza que el build de CI sea el mismo que el local.
- **Node 20 fijo**: el host tiene Node 26, pero CI y Docker usan la misma versión LTS.
- **`permissions: contents: read`**: el workflow de CI no necesita escribir nada.
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

## 5. Publicación de imágenes (`.github/workflows/release.yml`)

Se dispara **solo con push a `main`** (y `workflow_dispatch`). No corre en PRs: publicar imágenes
de código que todavía no se mergeó llena el registro de versiones que nadie va a desplegar.

| Aspecto | Decisión |
|---|---|
| Registro | **GHCR** (`ghcr.io/tomasgudi/hia-2026-{backend,frontend}`) |
| Tags | `sha-<7>` (trazable al commit) + `latest` |
| Matriz | un job por servicio, en paralelo |
| Caché | `type=gha` por servicio: no recompila capas entre corridas |
| Permisos | `contents: read` + `packages: write` (el único permiso de escritura) |
| Labels | `org.opencontainers.image.{source,revision,version}` vía `metadata-action` |

El tag `sha-<7>` es el que se usa para desplegar: `latest` es una comodidad, no una referencia
estable. Desplegar `latest` en producción es un error clásico porque no se sabe qué código corre.

## 6. Registro local para el despliegue

CI publica en GHCR, pero **el host de despliegue es local** y el paquete de GHCR queda privado por
defecto. Un `docker pull` anónimo de un paquete privado falla, y cambiarlo a público requiere un
token con `write:packages` que este entorno no tiene.

Decisión: el host corre un **registro propio** (`registry:2` en `127.0.0.1:5000`) que recibe las
mismas imágenes con los mismos tags. Es una decisión de entorno, no de diseño: en un servidor con
salida a Internet y un PAT con `read:packages`, `deploy.ps1` apunta a GHCR cambiando `-Registry`.

```powershell
docker push 127.0.0.1:5000/hia-2026-backend:sha-1a2b3c4
```

El registro se levanta con el perfil `ops` y solo escucha en loopback.

## 7. Despliegue pull-based (`scripts/deploy.ps1`)

No hay *push* desde GitHub al host: el host **baja** la versión que se le indica. Es el patrón
correcto cuando el destino no tiene una IP pública ni un runner self-hosted.

```powershell
./scripts/deploy.ps1 -Tag sha-1a2b3c4     # despliegue normal
./scripts/deploy.ps1 -Rollback            # volver a la versión anterior
```

Secuencia:

1. **Baja las dos imágenes antes de tocar nada.** Si el pull falla, el servicio actual sigue
   corriendo: el despliegue aborta sin dejar el sistema a medias.
2. Escribe el tag en `BACKEND_IMAGE`, `FRONTEND_IMAGE` y `APP_VERSION`.
3. `docker compose up -d --no-build --no-deps backend frontend` (solo esos dos servicios).
4. Espera salud **real**: `GET /health` a través del frontend **y** `docker inspect` en `healthy`.
5. Si no queda sano en el timeout, **rollback automático** al tag anterior y vuelve a verificar.

El estado queda en `.deploy/state.json` (no versionado): `current`, `previous`, `history`,
`failed_tag` si hubo rollback.

`GET /health` devuelve la versión desplegada:

```json
{"status":"ok","db":"up","uptime":31.06,"version":"v1"}
```

Eso permite responder "¿qué está corriendo?" sin entrar al contenedor.

## 8. Rollback probado

| Paso | Acción | Resultado |
|---|---|---|
| 1 | `deploy.ps1 -Tag v1` | `version: v1`, app 200 |
| 2 | `deploy.ps1 -Tag v2` | `version: v2`, app 200 |
| 3 | `deploy.ps1 -Tag broken` | el contenedor no levanta: `dependency failed to start` |
| 4 | rollback **automático** | vuelve a `v2` sin intervención; `version: v2`, app 200 |
| 5 | `deploy.ps1 -Rollback` | vuelve a `v1`; `version: v1`, app 200 |

La imagen `broken` es un `alpine` que no escucha en `:3000`: no es un error simulado en el script,
es un contenedor que realmente no sirve. El rollback se dispara porque el healthcheck falla, no
porque el script "sepa" que esa imagen es mala.

Evidencia: `evidence/08/deploy.log`, `evidence/08/rollback-automatico.log`,
`evidence/08/rollback-manual.log`, `evidence/08/registro-y-despliegue.log`.

> Nota honesta: `v1` y `v2` son el **mismo commit con distinto tag**. Lo que se prueba es el
> mecanismo de despliegue y rollback, no un cambio de código. En un release real el tag `sha-<7>`
> cambia con el commit.

## 9. Flujo completo

```
feature/* ──PR──▶ develop ──PR──▶ main ──push──▶ release.yml ──▶ GHCR
                    │                │                              │
                    └── CI (4 jobs) ─┘                              │
                                                                    ▼
                                                     deploy.ps1 -Tag sha-xxxx
                                                                    │
                                                                    ▼
                                                     pull ─▶ up ─▶ /health
                                                              │
                                                              └─ falla ─▶ rollback
```

## 10. Estado

| Requisito de §8 | Estado |
|---|---|
| Configurar GitHub Actions | ✅ |
| Verificaciones automáticas | ✅ lint, build, secretos, compose |
| Construir imágenes Docker | ✅ `release.yml`, matriz backend/frontend |
| Publicar en un registro | ✅ GHCR + registro local para el host |
| Despliegue automático | ✅ pull-based con `deploy.ps1` |
| Secretos protegidos | ✅ `GITHUB_TOKEN` con permisos mínimos; gitleaks en todo el historial |
| Commit de prueba | ✅ PRs #1–#5 con CI verde |
| Rollback documentado y probado | ✅ automático y manual, con evidencia |

## 11. Evidencia

| Evidencia | Archivo |
|---|---|
| Workflow de CI | `.github/workflows/ci.yml` |
| Workflow de release | `.github/workflows/release.yml` |
| Corrida exitosa de CI (4/4 jobs) | `evidence/03/ci-evidencia.txt`, `evidence/03/ci-run-43424320086.json` |
| Configuración de protección | `evidence/03/branch-protection.json` |
| Prueba negativa de protección | `evidence/03/branch-protection-test.log` |
| Escaneo de secretos | `evidence/03/gitleaks.log` |
| Despliegue v1 → v2 | `evidence/08/deploy.log` |
| Rollback automático | `evidence/08/rollback-automatico.log` |
| Rollback manual | `evidence/08/rollback-manual.log` |
| Registro y digests | `evidence/08/registro-y-despliegue.log` |
| Script de despliegue | `scripts/deploy.ps1` |
