# 14 — Seguridad informática

## 1. Objetivo y alcance

Identificar las amenazas reales del sistema, aplicar controles verificables y demostrar con
herramientas que las mitigaciones funcionan. No se declara "seguro": se declara **qué se probó y
qué no**.

Alcance: 7 componentes del stack. Fuera de alcance: seguridad del host Windows, del hipervisor y de
Cloudflare (se tratan como proveedores confiables).

## 2. Matriz STRIDE

| Componente | S — Suplantación | T — Manipulación | R — Repudio | I — Divulgación | D — Denegación | E — Elevación |
|---|---|---|---|---|---|---|
| **Frontend (nginx)** | sesión JWT robada → HSTS + CSP limitan el impacto | XSS modifica el DOM → React escapa por defecto + CSP sin `unsafe-eval` | sin log de auditoría por usuario → logs de nginx con IP | `Server` filtraba versión → `server_tokens off` | flooding → `limit_req` 10 r/s (98/120 → 429) | nginx como root → imagen unprivileged, uid 101 |
| **Backend (API)** | `JWT_SECRET` débil → 32 bytes aleatorios | SQLi → Prisma parametrizado (probado con 3 payloads) | sin auditoría de acciones → logs de aplicación | enumeración de usuarios → 401 genérico | consultas costosas → índices + cap + rate limit | RCE por dependencia → Trivy + `npm audit` |
| **PostgreSQL (primaria)** | credenciales en `.env` (no en el repo) | inyección → parámetros + rol sin DDL | `log_connections=off` → se acepta, se registra lo lento | puerto 5433 solo en loopback (nmap: filtered) | `max_connections=200` + pool de 10 | app como superusuario → **rol `app` solo DML** |
| **Réplica** | mismo rol de replicación con contraseña propia | WAL íntegro (checksums) | — | sin puerto publicado | si cae, la app sigue (escribe en la primaria) | solo lectura por diseño |
| **Monitoreo** | Grafana anónimo **solo lectura** y solo loopback | reglas en archivos versionados | historial de alertas en Alertmanager | paneles sin datos personales | un solo nodo (limitación declarada) | Prometheus sin auth pero en loopback |
| **Mantis** | login propio + Basic auth del borde | `/admin` bloqueado (403) | historial de estados (70 filas) | solo por túnel con auth | depende de PostgreSQL | Apache corre como root → **limitación declarada** |
| **n8n** | UI detrás del borde con Basic auth | webhook con token (falla cerrado) | ejecuciones registradas en su base | token fuera del repo (placeholders) | si cae, la app no se ve afectada | contenedor como `node` (no root) |

## 3. Informe de vulnerabilidades

### 3.1 Trivy — imágenes

Escaneo con `--severity HIGH,CRITICAL` sobre las 5 imágenes. Estado inicial y después de corregir:

| Imagen | Antes (total / críticas) | Después (total / críticas) | Qué se hizo |
|---|---|---|---|
| `pi-backend` | 100 / **9** | 62 / **2** | `apt-get upgrade` + `npm audit fix` |
| `pi-frontend` | 8 / 4 | — | imagen unprivileged de nginx |
| `pi-mantis` | 11 / 5 | — | limitación declarada (ver §7) |
| `postgres:16.4-alpine` | 12 / 6 | — | tag base de la imagen oficial |
| `n8n:1.68.0` | 36 / 18 | — | tag base de la imagen oficial |

Detalle de la corrección del backend:

- **Sistema operativo**: `apt-get upgrade` en la etapa de runtime. Debian pasa de 54 hallazgos
  (6 críticas) a 35 (1 crítica: `zlib` CVE-2023-45853, marcada `will_not_fix` por el proveedor).
- **Dependencias npm**: `npm audit fix` sobre el lockfile. De 46 hallazgos (3 críticas) a 27
  (1 crítica: `tar` 6.2.1, transitiva; requiere salto mayor).

**Lo que queda y por qué**: la crítica de `tar` y la de `zlib` no tienen corrección compatible sin
romper la aplicación. Se documentan en vez de ocultarlas. Las imágenes base de Mantis, n8n y
PostgreSQL arrastran CVEs de sus mantenedores: actualizarlas es una tarea de mantenimiento
periódico, no un cambio de configuración.

### 3.2 npm audit

| Servicio | Antes (solo producción) | Después |
|---|---|---|
| backend | 14 (2 críticas) | **9 (0 críticas)** |
| frontend | 2 moderadas (`react-router`) | 2 moderadas (requiere salto mayor) |

### 3.3 Semgrep

`--config=auto` sobre `app/`: **6 hallazgos**, todos `dockerfile.security.missing-user` en
`app/mantis/Dockerfile` (Apache corre como root). Es el mismo hallazgo que declara la matriz: no se
corrige porque Apache necesita el puerto 80 y escribir en el web root; se mitiga con el borde
autenticado y `/admin` bloqueado.

### 3.4 Bandit

Sobre `scripts/*.py`: **2 hallazgos medios** (B310, `urlopen` con esquema no validado). Triados con
`# nosec B310`: las URLs son constantes del código, no vienen del usuario.

### 3.5 gitleaks

Historial completo (35 commits): **sin filtraciones**. El mismo escaneo corre en CI como job
`secrets` y bloquea el merge si aparece un secreto.

## 4. Controles aplicados

| Control | Implementación | Verificación |
|---|---|---|
| Cabeceras de seguridad | `app/frontend/nginx.conf`: CSP, HSTS, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` | `curl -I` (evidence) |
| Ocultar versión | `server_tokens off` | `Server: nginx` (sin versión) |
| Rate limit | `limit_req_zone` 10 r/s, burst 20, sobre `/api/` | 120 peticiones → **98 × 429** |
| Non-root | backend `USER node`, frontend `uid 101`, n8n `node`, Prometheus `nobody`, Grafana `472` | `docker inspect` + `id` |
| Rol mínimo de base | rol `app` con solo `SELECT/INSERT/UPDATE/DELETE` | `CREATE TABLE` → `permission denied` |
| Puertos | todo en `127.0.0.1` | nmap desde la LAN: `filtered` |
| Secretos | `.env` fuera del repo, gitleaks en CI, tokens con placeholder | gitleaks: sin filtraciones |
| Auth administrativa | Basic auth en el borde (§9) | 401 sin credenciales |
| `/admin` de Mantis | bloqueado por Apache | 403 |

## 5. Pruebas controladas

### 5.1 SQLi

| Payload | Resultado |
|---|---|
| `tag=' OR 1=1--` | 200, lista vacía (33 bytes) |
| `tag=' UNION SELECT NULL,NULL,NULL--` | 200, lista vacía |
| `tag='; DROP TABLE "Article";--` | 200, lista vacía |
| login con `admin' OR '1'='1` | **403**, mensaje genérico |

La tabla `Article` sigue con **6.000.001 filas** después de las pruebas. Prisma usa consultas
parametrizadas: el payload se trata como valor, no como SQL.

### 5.2 Puerto de la base cerrado

`nmap` desde la LAN contra `192.168.1.8`: **5433, 8090, 9090, 9093, 3001, 5000, 8088, 8089, 8091 →
todos `filtered`**. Evidencia: `evidence/09/nmap.log`.

### 5.3 ZAP baseline

Escaneo pasivo sobre la URL pública (`https://<tunel>.trycloudflare.com`), con spider de 2 minutos.

| Corrida | FAIL | WARN | PASS |
|---|---|---|---|
| Antes (cabeceras heredadas mal) | 0 | 8 | 60 |
| Después (include de cabeceras en assets) | **0** | **5** | **63** |

Las 3 advertencias que se corrigieron eran `X-Content-Type-Options`, `HSTS` y `Permissions-Policy`
ausentes en `/assets/*`: nginx descarta las cabeceras del `server` cuando un `location` declara su
propio `add_header`, y el `location` de assets declaraba `Cache-Control`.

Las 5 restantes son informativas o de bajo impacto: `Cache-Control` reexaminado, contenido
cacheable, `img-src https:` (necesario para imágenes de artículos), "Modern Web Application" y
`Cross-Origin-Embedder-Policy` (la app no usa recursos cross-origin aislados).

Evidencia: `evidence/14/zap-baseline-antes.log`, `zap-baseline.log` y `zap-baseline.html`.

## 6. Runbook de respuesta a incidentes

| Fase | Qué se hace | Quién | Evidencia |
|---|---|---|---|
| **1. Detección** | alerta de Prometheus/Alertmanager, o incidencia en Mantis | monitoreo | `ALERTS` en estado `firing` |
| **2. Clasificación** | severidad y alcance: ¿afecta disponibilidad, datos o confidencialidad? | responsable de guardia | incidencia en Mantis con categoría |
| **3. Contención** | si hay compromiso: rotar `JWT_SECRET` y tokens, cortar el túnel, aislar el contenedor | operador | commit del cambio de secreto |
| **4. Erradicación y recuperación** | aplicar el fix, `deploy.ps1` con rollback si falla, verificar `/health` | desarrollo | PR + ejecución de deploy |
| **5. Cierre** | nota en la incidencia con causa raíz y verificación; actualizar el informe | ambos | incidencia `resolved` con `commit_sha` |

Tiempos objetivo: detección < 5 min (scrape 15 s + `for` de la regla), contención < 30 min,
recuperación medida por el RTO del despliegue (§8: ~50 s con rollback).

## 7. Limitaciones declaradas

| Limitación | Motivo | Riesgo aceptado |
|---|---|---|
| Mantis corre como root | Apache necesita el puerto 80 y escribir en el web root | mitigado con borde autenticado y `/admin` bloqueado |
| Prometheus/Grafana sin auth propia | solo escuchan en loopback | el acceso remoto pasa por el túnel |
| Basic auth sin MFA | Cloudflare Access requiere cuenta y dominio | contraseña fuerte + login propio de cada herramienta |
| `tar` y `zlib` con CVE crítica | sin versión compatible | documentado y monitoreado |
| Sin WAF ni rate limit en el borde | requiere plan pago | el rate limit de nginx cubre `/api/` |
| Sin escaneo de secretos en tiempo real | gitleaks corre en CI y manual | un secreto llega al repo pero no a `main` |

## 8. Flujo de incidentes con n8n

La alerta de Prometheus se convierte en incidencia automáticamente (§13, flujo 1):

```
Prometheus → Alertmanager → n8n (token) → POST /api/rest/issues → Mantis
```

Verificado con `amtool`: incidencia #18 creada desde una alerta real, y ejecución 21 en `error` con
Mantis caído. Ese es el eslabón que el enunciado pide para §14.

## 9. Evidencia

| Evidencia | Archivo |
|---|---|
| Trivy antes (5 imágenes) | `evidence/14/trivy-*.txt` |
| Trivy después (backend) | `evidence/14/trivy-backend-despues.txt` |
| npm audit | `evidence/14/npm-audit-backend.txt`, `npm-audit-frontend.txt` |
| Semgrep | `evidence/14/semgrep.txt` |
| Bandit | `evidence/14/bandit.txt` |
| gitleaks | `evidence/14/gitleaks.log` |
| Pruebas de SQLi y non-root | `evidence/14/pruebas-controladas.log` |
| Rate limit | `evidence/14/rate-limit.log` |
| ZAP baseline | `evidence/14/zap-baseline.log`, `zap-baseline.html` |
| nmap | `evidence/09/nmap.log` |
| Script reproducible | `scripts/seguridad-scan.ps1` |
