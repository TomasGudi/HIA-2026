# 21 — Scripts para la demo (runbook)

> Runbook operativo de la Práctica Integradora Final. Complementa
> [`20-guion-demo.md`](20-guion-demo.md): el guion dice **qué contar**, este documento dice
> **qué comando ejecutar** en cada bloque.
>
> Verificado el 20/11/2026 con el stack completo levantado (19 contenedores).
> Todos los comandos se ejecutan desde la raíz del repo, en **PowerShell**.

## 1. Requisitos

| Herramienta | Versión usada | Para qué |
|---|---|---|
| Docker Desktop | 29.9.3 / Compose v5.7.0 | todo el stack |
| PowerShell | 5.1 (Windows) | scripts `.ps1` |
| Python | 3.14 (3.11+ sirve) | `scripts/*.py` |
| `curl.exe` | 8.22 | pruebas HTTP de la demo |
| Git | 2.55 | ramas, PRs, evidencia |
| `nmap` (opcional) | contenedor `instrumentisto/nmap` | §9 superficie expuesta |

Antes de cualquier demo:

```powershell
# .env es obligatorio y NO se versiona
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# completar contraseñas; los valores de la defensa están en CREDENCIALES.local.md

docker version          # el daemon debe estar corriendo
docker compose version
```

> Si PowerShell bloquea los scripts:
> `powershell -ExecutionPolicy Bypass -File .\scripts\db.ps1 stats`

## 2. Arranque completo (T-60)

```powershell
# 1. token del webhook de Alertmanager (archivo montado; correr ANTES del up)
./scripts/preparar-tokens.ps1

# 2. stack completo: DB + réplica + app + monitoreo + ops
docker compose --profile ops up -d

# 3. estado
docker compose --profile ops ps --format "table {{.Name}}\t{{.Status}}"

# 4. URLs públicas (túneles efímeros)
./scripts/publicar.ps1 up
```

Orden importante: `preparar-tokens.ps1` primero. Alertmanager monta
`monitoring/alertmanager/n8n_token` y `monitoring/alertmanager/mcp_token` como archivos; si no
existen, Docker crea directorios y el contenedor falla.

### Verificación T-30

```powershell
curl.exe -s http://127.0.0.1:8090/health
curl.exe -s -o NUL -w "app        %{http_code}`n" http://127.0.0.1:8090/
curl.exe -s -o NUL -w "pgadmin    %{http_code}`n" http://127.0.0.1:8080/
curl.exe -s -o NUL -w "mantis     %{http_code}`n" http://127.0.0.1:8081/
curl.exe -s -o NUL -w "grafana    %{http_code}`n" http://127.0.0.1:3001/login
curl.exe -s -o NUL -w "prometheus %{http_code}`n" http://127.0.0.1:9090/-/healthy
curl.exe -s -o NUL -w "alertman   %{http_code}`n" http://127.0.0.1:9093/-/healthy
curl.exe -s -o NUL -w "n8n        %{http_code}`n" http://127.0.0.1:5678/
curl.exe -s -o NUL -w "nextcloud  %{http_code}`n" http://127.0.0.1:8082/status.php
curl.exe -s -o NUL -w "mailhog    %{http_code}`n" http://127.0.0.1:8025/

./scripts/replica.ps1 status
./scripts/monitoreo.ps1 status
```

Esperado: `/health` → `{"status":"ok","db":"up",...}`; todos los demás **200**;
réplica `streaming` con lag de 0 bytes; 7 targets de Prometheus en `up`.

### Accesos locales

| Servicio | URL |
|---|---|
| App (Conduit) | http://127.0.0.1:8090 |
| API (por proxy nginx) | http://127.0.0.1:8090/api |
| Health real (DB incluida) | http://127.0.0.1:8090/health |
| pgAdmin | http://127.0.0.1:8080 |
| Mantis | http://127.0.0.1:8081 |
| Nextcloud | http://127.0.0.1:8082 |
| Grafana | http://127.0.0.1:3001 |
| Prometheus | http://127.0.0.1:9090 |
| Alertmanager | http://127.0.0.1:9093 |
| n8n | http://127.0.0.1:5678 |
| MailHog (correos) | http://127.0.0.1:8025 |
| Borde con Basic auth | `:8088` pgAdmin · `:8089` Mantis · `:8091` Nextcloud |

## 3. Catálogo de scripts

| Script | Qué hace | Acciones / parámetros |
|---|---|---|
| `scripts/preparar-tokens.ps1` | escribe el token de n8n que lee Alertmanager | sin parámetros; idempotente |
| `scripts/db.ps1` | ciclo de vida de la base | `up` `down` `logs` `schema` `seed` `indexes` `stats` `psql` `reset` |
| `scripts/replica.ps1` | estado y failover de la réplica | `status` `lag` `test` `readonly` `promote` `reinit` |
| `scripts/backup.ps1` | backup lógico y prueba de restauración | `-RestoreTest` `-SkipBackup` `-RetentionDays N` |
| `scripts/monitoreo.ps1` | estado de Prometheus/alertas y prueba de carga | `status` `urls` `recargar` `test-alerta -Minutos N` |
| `scripts/publicar.ps1` | crea/destruye los 4 túneles Cloudflare | `up` `urls` `down` |
| `scripts/deploy.ps1` | deploy pull-based con rollback automático | `-Tag` `-Registry` `-Rollback` `-SkipPull` `-TimeoutSeconds` |
| `scripts/seguridad-scan.ps1` | Trivy, npm audit, Semgrep, Bandit, gitleaks | sin parámetros; escribe en `evidence/14/` |
| `scripts/nextcloud.ps1` | provisión de usuarios, grupos y documentos | `init` `structure` `status` |
| `scripts/mantis-seed.py` | carga las incidencias de ejemplo en Mantis | `python scripts/mantis-seed.py` |
| `scripts/mantis-campos.sql` | agrega campos `commit_sha`/`pr` a Mantis | se aplica con `psql` (ver §4.8) |
| `scripts/incidentes.ps1` | incidentes: init, demo, listar, aprobar, rechazar | `init` `demo` `listar` `aprobar <id>` `rechazar <id>` `estado <id>` |
| `scripts/incidente-watcher.ps1` | ejecuta el failover de un incidente aprobado | `-DryRun` `-UnaVez` `-Force` `-Intervalo N` |
| `scripts/restaurar-primaria.ps1` | reconstruye la primaria después de la demo | `-SwapBack` `-Force` |
| `scripts/informe.py` | regenera el informe HTML + PDF | `--solo-html` |
| `scripts/prueba-rate-limit.py` | dispara N requests y cuenta 200/429 | `python scripts/prueba-rate-limit.py 120` |

## 4. Secuencia por bloque de la demo

### 4.1 Bloque 1 — La app (0:00–2:00)

No hay script: se usa la URL pública del túnel en el celular.

1. Registrarse con un usuario nuevo.
2. Publicar un artículo con el tag `demo`.
3. Filtrar por `demo`.

Si el túnel falla:

```powershell
start http://127.0.0.1:8090
```

### 4.2 Bloque 2 — Datos y contenedores (2:00–4:00)

```powershell
docker compose ps --format "table {{.Name}}\t{{.Status}}"
docker volume ls | Select-String pgdata
./scripts/db.ps1 stats
```

Salida esperada (conteo exacto): `Article` **6.000.001**, `Comment` **6.000.001**,
`_UserFavorites` 6.000.000, `User` 200.003, `Tag` 5.004; base de datos **8,5 GB**.
`db.ps1 stats` usa `n_live_tup` (aproximado): puede mostrar 6.000.003 en `Article`.

### 4.3 Bloque 3 — SQL optimizado (4:00–7:00)

```powershell
./scripts/db.ps1 psql
```

Dentro de `psql`:

```sql
\timing on
\i /db/queries/20-optimizado.sql
```

Para comparar contra el baseline (más lento):

```sql
\i /db/queries/10-baseline.sql
```

Plan “antes” ya medido: `evidence/05/baseline-1.txt` (Seq Scan, 7,9 s).
Plan “después”: `evidence/05/optimizado.txt` (Index Scan, 0,19 s).

Consulta puntual correcta (el esquema usa `_ArticleToTag(A,B)`, no `articleId/tagId`):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.id, a.title, a."createdAt"
FROM "Article" a
JOIN "User" u ON u.id = a."authorId"
JOIN "_ArticleToTag" at ON at."A" = a.id
JOIN "Tag" t ON t.id = at."B"
WHERE u.demo = true AND t.name = 'tag-00042'
ORDER BY a."createdAt" DESC
LIMIT 10;
```

### 4.4 Bloque 4 — Réplica y caída (7:00–9:00)

```powershell
./scripts/replica.ps1 status     # streaming + lag
./scripts/replica.ps1 test       # INSERT en primaria → SELECT en réplica
./scripts/replica.ps1 lag        # atraso de replay medido en la réplica
./scripts/replica.ps1 readonly   # escritura en réplica: debe fallar

# la app sigue funcionando si se cae la réplica
docker stop pi-db-replica
curl.exe -s -o NUL -w "app sigue: %{http_code}`n" "http://127.0.0.1:8090/api/articles?limit=1"
docker start pi-db-replica
```

Failover **manual** (solo si se va a demostrar de verdad; deja la réplica como primaria):

```powershell
./scripts/replica.ps1 promote
# luego: DATABASE_HOST=db-replica en .env y recrear backend
docker compose up -d backend
```

Para volver al estado normal después de `promote`:

```powershell
./scripts/replica.ps1 reinit    # DESTRUCTIVO: borra y reclona el volumen de la réplica
```

### 4.5 Bloque 5 — CI/CD y rollback (9:00–11:00)

Plan A, sin depender de Internet (registro local `127.0.0.1:5000`, tags `v1` y `v2`):

```powershell
# desplegar v1 y luego v2 para que el "previous" sea v1
./scripts/deploy.ps1 -Tag v1 -Registry 127.0.0.1:5000
./scripts/deploy.ps1 -Tag v2 -Registry 127.0.0.1:5000

# volver a la versión anterior
./scripts/deploy.ps1 -Rollback -Registry 127.0.0.1:5000
```

Plan B, con las imágenes de GHCR ya presentes en el host y sin pull:

```powershell
./scripts/deploy.ps1 -Tag sha-82a8e98 -Registry ghcr.io/tomasgudi -SkipPull
```

El script verifica `http://127.0.0.1:8090/health` durante 90 s y hace rollback solo si falla.
El estado queda en `.deploy/state.json`.

En GitHub: mostrar el PR con los 4 checks (backend, frontend, compose, secrets) y `main` protegida.

### 4.6 Bloque 6 — Monitoreo y alerta (11:00–14:00)

```powershell
./scripts/monitoreo.ps1 status
./scripts/monitoreo.ps1 urls
```

Alerta en vivo rápida (≈2 min, regla `ServicioCaido`):

```powershell
docker stop pi-postgres-exporter
# esperar 2 min y mostrar Alertmanager + la incidencia creada por n8n en Mantis
docker start pi-postgres-exporter
```

Prueba de carga real (regla `CPUAlta`, umbral 85 %, tarda ~10 min; no hacerla en vivo):

```powershell
./scripts/monitoreo.ps1 test-alerta -Minutos 8
```

Fallback si no dispara: `evidence/10/alerta-stress.log`, `evidence/10/alertmanager-payloads.jsonl`.

Grafana: http://127.0.0.1:3001/d/pi-overview

### 4.7 Bloque 7 — n8n y Nextcloud (14:00–16:00)

Prueba negativa del webhook (debe dar **401**):

```powershell
curl.exe -s -o NUL -w "sin token -> %{http_code}`n" -X POST `
  http://127.0.0.1:5678/webhook/alertmanager `
  -H "Content-Type: application/json" -d "{}"
```

n8n: http://127.0.0.1:5678 — flujos `01`, `02`, `03` ya importados y activos.

Nextcloud:

```powershell
./scripts/nextcloud.ps1 status
# si hiciera falta reprovisionar (idempotente):
# ./scripts/nextcloud.ps1 init
# ./scripts/nextcloud.ps1 structure
```

Carpeta `HIA-2026` con 17 subcarpetas. Usuario `auditor` (solo lectura) e `invitado` (sin grupo)
sirven para la prueba de permisos: `403` al intentar subir y carpeta invisible.

### 4.7.1 Incidente + correo + Hermes (extra)

Flujo completo documentado en [`22-incidentes-hermes.md`](22-incidentes-hermes.md).

```powershell
# preparar una vez
docker compose up -d opsdb
./scripts/incidentes.ps1 init
docker compose --profile ops up -d mailhog
docker compose -f automation/hermes/compose.yaml --env-file .env up -d --force-recreate

# ensayo sin tocar la base: crea incidente sintético + correo + Telegram
./scripts/incidentes.ps1 demo
# MailHog: http://127.0.0.1:8025
# Hermes: docker exec -it pi-hermes hermes chat

# demo real (dos terminales)
./scripts/incidente-watcher.ps1          # terminal 1
docker stop pi-db                        # terminal 2; esperar ~60 s
# en Telegram: "SÍ, resolvé el incidente #1"
./scripts/incidentes.ps1 listar

# después de la demo
./scripts/restaurar-primaria.ps1 -SwapBack
```

### 4.8 Bloque 8 — Seguridad (16:00–18:00)

```powershell
# escaneos completos (Trivy baja ~50 MB la primera vez; puede tardar varios minutos)
./scripts/seguridad-scan.ps1

# rate limit de nginx: esperado 200 y 429
python scripts/prueba-rate-limit.py 120

# superficie desde la LAN (reemplazar la IP por la del host)
docker run --rm instrumentisto/nmap -Pn -T4 -p 5000,3001,5433,8080,8081,8088,8089,8090,9090,9093 192.168.1.8

# cabeceras de seguridad por el túnel
curl.exe -s -I https://<tu-url>.trycloudflare.com/ | Select-String "Content-Security|Strict-Transport|Server"
```

Evidencia ya generada: `evidence/14/trivy-backend-despues.txt`, `evidence/14/semgrep.txt`,
`evidence/14/gitleaks.log`, `evidence/14/rate-limit.log`, `evidence/14/zap-baseline.md`.

Campos de Mantis (solo si se recreó la base de Mantis):

```powershell
$u = (Get-Content .env | Where-Object { $_ -match '^POSTGRES_USER=' }) -replace '^POSTGRES_USER=', ''
Get-Content scripts/mantis-campos.sql -Raw |
  docker compose exec -T db psql -U $u -d mantis -f -
```

Carga de incidencias de ejemplo (idempotente):

```powershell
python scripts/mantis-seed.py
```

### 4.9 Cierre — Documentación (18:00–20:00)

```powershell
python scripts/informe.py            # docs/informe-consolidado.html + PDF
python scripts/informe.py --solo-html
```

Tarda un poco: usa Edge headless para el PDF. No es necesario en vivo; el PDF ya está en
`docs/HIA-2026-informe-final.pdf`.

## 5. Verificaciones de una línea

```powershell
# usuario y base salen de .env (el script los lee, acá se repiten para one-liners)
$u = (Get-Content .env | Where-Object { $_ -match '^POSTGRES_USER=' }) -replace '^POSTGRES_USER=', ''
$d = (Get-Content .env | Where-Object { $_ -match '^POSTGRES_DB=' })   -replace '^POSTGRES_DB=', ''

# salud real (proceso + DB)
curl.exe -s http://127.0.0.1:8090/health

# API
curl.exe -s "http://127.0.0.1:8090/api/articles?limit=2&offset=0"
curl.exe -s http://127.0.0.1:8090/api/tags

# réplica
docker compose exec -T db psql -U $u -d $d -c `
  "select client_addr,state,sync_state,pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),replay_lsn)) lag from pg_stat_replication;"

# targets y reglas de Prometheus
(Invoke-RestMethod http://127.0.0.1:9090/api/v1/targets).data.activeTargets |
  Select-Object @{n='job';e={$_.labels.job}},health | Format-Table -AutoSize
(Invoke-RestMethod http://127.0.0.1:9090/api/v1/rules).data.groups.rules |
  Select-Object name,state | Format-Table -AutoSize

# grafana (lectura anónima en loopback)
(Invoke-RestMethod "http://127.0.0.1:3001/api/search?type=dash-db").title
```

## 6. Parada y limpieza

```powershell
# 1. túneles primero: mientras estén arriba, la app es pública
./scripts/publicar.ps1 down

# 2. stack (conserva volúmenes y datos)
docker compose --profile ops down

# 3. apagar sin borrar contenedores
docker compose --profile ops stop
```

Destructivo — **no hacer en la demo**:

```powershell
docker compose --profile ops down -v   # borra volúmenes: se pierden los 8,5 GB
./scripts/db.ps1 reset                 # pide escribir BORRAR y vuelve a sembrar (≈13 min)
./scripts/replica.ps1 reinit           # borra el volumen de la réplica y la reclona
```

## 7. Advertencias

| Acción | Riesgo | Cómo se revierte |
|---|---|---|
| `publicar.ps1 up` | publica 4 URLs en Internet (admin solo con Basic auth) | `./scripts/publicar.ps1 down` |
| `db.ps1 reset` | borra la base completa | volver a `seed` + `indexes` (≈13 min) |
| `replica.ps1 promote` | la réplica deja de ser standby | `replica.ps1 reinit` |
| `deploy.ps1` con tag inexistente | intenta rollback; si no hay `previous`, queda para intervención manual | `-Tag <tag-válido>` |
| `backup.ps1` | borra backups con más de `RetentionDays` | no aplica |
| `seguridad-scan.ps1` | no modifica nada; solo escribe en `evidence/14/` | — |

## 8. Problemas conocidos y correcciones

| Síntoma | Causa | Solución |
|---|---|---|
| `exec /entrypoint-replica.sh: no such file or directory` | `.sh` con CRLF en Windows | convertir a LF (`git ls-files --eol` para verificar) |
| Túnel de la app da 502 | `publicar.ps1` apunta a `frontend:8080` (correcto); el doc 10 dice `frontend:80` (incorrecto) | usar `./scripts/publicar.ps1 up` |
| `GET /api/health` → 404 | el health cuelga de `/health`, no de `/api` | `http://127.0.0.1:8090/health` |
| `deploy.ps1` no encuentra la imagen | el registro local no tiene ese tag | usar `v1`/`v2` o `-SkipPull` |
| Alertmanager no arranca | falta `monitoring/alertmanager/n8n_token` o `mcp_token` | `./scripts/preparar-tokens.ps1` |
| La alerta `CPUAlta` no dispara en 2 min | `for: 5m` + `rate[5m]` | usar `ServicioCaido` o mostrar `evidence/10/` |
| Las URLs `.trycloudflare.com` cambian | quick tunnels efímeros | `./scripts/publicar.ps1 urls` |
| `Found orphan containers (pi-mcp)` | contenedor de otro proyecto en la misma red | ignorar o `docker rm -f pi-mcp` |

## 9. Orden mínimo para una demo de 20 minutos

```powershell
./scripts/preparar-tokens.ps1
docker compose --profile ops up -d
./scripts/publicar.ps1 up
./scripts/replica.ps1 status
./scripts/db.ps1 stats
./scripts/db.ps1 psql                 # \i /db/queries/20-optimizado.sql
./scripts/replica.ps1 test
./scripts/deploy.ps1 -Tag v1 -Registry 127.0.0.1:5000
./scripts/deploy.ps1 -Tag v2 -Registry 127.0.0.1:5000
./scripts/deploy.ps1 -Rollback -Registry 127.0.0.1:5000
./scripts/monitoreo.ps1 status
docker stop pi-postgres-exporter      # esperar 2 min → alerta + incidencia
docker start pi-postgres-exporter
python scripts/prueba-rate-limit.py 120
./scripts/nextcloud.ps1 status
./scripts/incidentes.ps1 demo           # incidente + correo + Telegram
./scripts/incidente-watcher.ps1 -DryRun -UnaVez
./scripts/publicar.ps1 down
```
