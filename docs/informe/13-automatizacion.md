# 13 — Automatización con n8n

## 1. Objetivo

Que los eventos del sistema no dependan de que alguien mire: una alerta de Prometheus tiene que
convertirse en una incidencia en Mantis, con contexto suficiente para actuar.

## 2. Despliegue

| Aspecto | Decisión | Motivo |
|---|---|---|
| Imagen | `docker.n8n.io/n8nio/n8n:1.68.0` | versión fija, no `latest` |
| Base de datos | PostgreSQL, base `n8n` y rol `n8n` propios | workflows y ejecuciones no comparten base con la app ni con Mantis |
| Volumen | `pi-n8n-data` | configuración y clave de cifrado de n8n |
| Red | `appnet`, `dbnet`, `monnet` | tiene que ver Mantis, la base y recibir de Alertmanager |
| Puerto | `127.0.0.1:5678` | en producción va por el borde con auth (§9) |
| Secretos | placeholders en el JSON versionado | el entrypoint los reemplaza desde `.env` antes de importar |

### Importación de workflows

`n8n import:workflow` **no es idempotente**: crea un workflow nuevo cada vez. El entrypoint
renderiza los secretos y después importa **workflow por workflow**, solo si su nombre no está en la
base:

```sh
nombre=$(sed -n 's/.*"name": "\([^"]*\)".*/\1/p' "$archivo" | head -1)
n8n list:workflow | grep -F "|${nombre}" || n8n import:workflow --input="$archivo"
```

Así se pueden agregar flujos nuevos sin duplicar los existentes ni borrar ejecuciones.

> Primer intento fallido que vale documentar: se usaba un marcador en el volumen
> (`/home/node/.n8n/.workflows-imported`). Los workflows viven en **PostgreSQL**, no en el volumen,
> así que el marcador no reflejaba la realidad y terminamos con **5 copias activas del mismo flujo**
> peleando por el mismo webhook. La condición correcta es consultar la base.

Segundo error: `n8n list:workflow` imprime un encabezado aunque no haya workflows, así que
`wc -l` daba 1 y el import nunca corría. Se cuentan solo las líneas con `|`.

## 3. Flujo 1 — Alerta de Prometheus a incidencia en Mantis

```
Alertmanager ──POST /webhook/alertmanager──▶ Webhook
                                              │
                                     Validar token y payload (Code)
                                              │
                                        ¿autorizado y válido?
                                        ├── sí ──▶ POST /api/rest/issues ──▶ 200 {ok, issue}
                                        └── no ──▶ 400 (payload) / 401 (token)
```

| Nodo | Qué hace |
|---|---|
| `Webhook Alertmanager` | recibe el POST en `/webhook/alertmanager`, responde con `respondToWebhook` |
| `Validar token y payload` | compara el token (case-insensitive), exige `status` y `alerts[]`, arma el cuerpo de Mantis |
| `Peticion valida?` | rama única booleana: autorizado **y** válido |
| `Crear issue en Mantis` | `POST http://mantis/api/rest/issues` con `Authorization: <token>` |
| `Responder 200 / Responder error` | devuelve el id de la incidencia o el motivo del rechazo |

### Autenticación del webhook

El token viaja en `Authorization: Bearer <token>` porque es lo que soporta `http_config` de
Alertmanager (no manda headers arbitrarios). El flujo también acepta `x-webhook-token` para pruebas
manuales.

El token **no está en el repositorio**: el JSON versionado tiene `__WEBHOOK_TOKEN__` y
`__MANTIS_TOKEN__`, y el entrypoint genera una copia en `/tmp` con los valores de `.env` antes de
importar. Si el reemplazo no ocurriera, el flujo falla cerrado (`autorizado` exige que el
placeholder ya no esté presente).

### Validación y rama de error

| Caso | Respuesta | Efecto |
|---|---|---|
| Sin token | **401** `{"ok":false,"error":"token invalido o ausente"}` | no toca Mantis |
| Token válido, payload sin `alerts` | **400** `{"ok":false,"error":"payload invalido..."}` | no toca Mantis |
| Token válido, payload correcto | **200** `{"ok":true,"issue":21,...}` | crea la incidencia |
| Mantis caído | **500** `{"message":"Error in workflow"}` | ejecución en `error`; Alertmanager reintenta |

## 4. Pruebas de integración

| Prueba | Resultado | Evidencia |
|---|---|---|
| Cadena real Alertmanager → n8n → Mantis | incidencia #18 creada por `amtool` | `evidence/13/flujo-1.log` |
| Sin token | 401, sin incidencia | idem |
| Payload inválido | 400, sin incidencia | idem |
| Mantis caído (fallo controlado) | ejecución **21** en `error`, HTTP 500 | idem |
| Recuperación | ejecución **22** en `success`, incidencia #21 | idem |

Ejecuciones (tabla `execution_entity`):

```
 id | status  |         startedAt
 22 | success | 2026-11-13 16:56:04
 21 | error   | 2026-11-13 16:55:30   <- Mantis detenido
 20 | success | 2026-11-13 16:55:24
```

## 5. Riesgos de las automatizaciones

| Riesgo | Qué pasaría | Mitigación |
|---|---|---|
| **Loop de disparo** | Alertmanager repite la notificación cada `repeat_interval` (4h) y crea una incidencia por vez | `group_by` por `alertname`+`severity` y `repeat_interval` alto; el flujo no se auto-dispara |
| **Mantis caído** | la ejecución falla y Alertmanager reintenta 11 veces | probado: ejecución en `error`, HTTP 500; no se pierde la alerta, se reintenta |
| **Token filtrado** | cualquiera podría crear incidencias | token en `.env`, no en el JSON; rotación cambiando la variable y reimportando |
| **Payload enorme** | el flujo arma una descripción gigante | se toman solo `summary`, `description` y `generatorURL` de la primera alerta |
| **Duplicados** | dos alertas iguales crean dos incidencias | `group_by` + `repeat_interval`; falta deduplicación por fingerprint (mejora pendiente) |
| **n8n caído** | no hay automatización, pero el sistema sigue funcionando | es un componente auxiliar: la app y la base no dependen de n8n |

## 6. Flujo 2 — Verificación de backup

No ejecuta `pg_dump` (la imagen oficial de n8n no trae cliente de PostgreSQL): **verifica** el
backup que genera `scripts/backup.ps1`. Es la parte que el enunciado pide cuando habla de
"verificar el resultado del backup".

```
Cron diario 03:00 ──▶ stat /backups/*.sql.gz ──▶ Evaluar (Code) ──▶ ¿vigente?
                                                                   ├── sí ──▶ sin acción
                                                                   └── no ──▶ issue en Mantis
```

| Regla | Valor por defecto | Variable |
|---|---|---|
| Edad máxima del backup | 26 h | `BACKUP_MAX_HORAS` |
| Tamaño mínimo | 1 MB (detecta un dump vacío) | `BACKUP_MIN_MB` |

```powershell
# caso vigente: no hace nada
docker compose exec n8n n8n execute --id <id>

# caso vencido: umbral 0 h fuerza la alerta
docker compose exec -e BACKUP_MAX_HORAS=0 n8n n8n execute --id <id>
```

Resultado medido (`evidence/13/flujo-2.log`): con el backup real de 402,6 MB y 5,5 h de antigüedad
→ `ok: true`, `Sin accion`. Con el umbral en 0 → `Crear issue en Mantis`, incidencia **#28**
("Backup vencido o invalido: tiene 5.5 h (maximo 0)"), cerrada después como prueba.

El volumen `./backups` se monta **solo lectura** en n8n: el flujo no puede borrar ni modificar un
backup.

## 7. Flujo 3 — Informe semanal a Nextcloud

```
Cron semanal (lunes 07:00)
   ──▶ GET prometheus /api/v1/query (CPU)
   ──▶ GET prometheus /api/v1/query (memoria)
   ──▶ Code: arma el markdown
   ──▶ PUT http://nextcloud/remote.php/dav/files/admin/HIA-2026/00-informe-consolidado/informe-semanal-YYYY-MM-DD.md
```

- La autenticación es **WebDAV con Basic**: el JSON versionado tiene `__NC_USER__` y `__NC_BASIC__`,
  y el entrypoint los reemplaza por el usuario y el header en base64. La contraseña no está en el
  repo.
- El archivo se escribe en la carpeta de grupo de §12, así que los 5 integrantes lo ven sin
  compartir nada a mano.
- Verificado (`evidence/13/flujo-3.log`): ejecución `success`, último nodo `Subir a Nextcloud`,
  archivo `informe-semanal-2026-11-13.md` de 263 bytes con los valores de Prometheus.

## 8. Flujo 4 — no implementado

El flujo 4 (eventos de seguridad) está marcado como opcional en el backlog y no se implementó. Se
declara en `16-limitaciones.md` (N3).

## 9. Evidencia

| Evidencia | Archivo |
|---|---|
| Workflows versionados (con placeholders) | `automation/n8n/workflows/01..03-*.json` |
| Entrypoint (renderizado e importación por nombre) | `automation/n8n/entrypoint.sh` |
| Pruebas del flujo 1 | `evidence/13/flujo-1.log` |
| Pruebas del flujo 2 (vigente y vencido) | `evidence/13/flujo-2.log` |
| Pruebas del flujo 3 (subida a Nextcloud) | `evidence/13/flujo-3.log` |
| Base y rol de n8n | `db/init/07-n8n-db.sh` |
| Servicio en compose | `compose.yaml` (perfil `ops`) |
| Diagrama | `docs/02-arquitectura.md` §5 |
