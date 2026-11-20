# 22 — Incidentes, correo y remediación con Hermes (extra)

> Anexo operativo. No forma parte de las 16 secciones obligatorias: documenta el flujo
> **alerta → incidente en base → correo → confirmación en Telegram → failover**.
>
> Requiere la rama `feat/incidentes-hermes` (parte de `feat/telegram`, que ya trae MCP y Hermes).

## 1. Qué se agregó

| Pieza | Dónde | Qué hace |
|---|---|---|
| MailHog | `compose.yaml` (`mailhog`, perfil `ops`) | captura los correos en `http://127.0.0.1:8025`; SMTP en `1025` |
| Tabla de incidentes | `opsdb/init/01-incidentes.sql` (base `ops`, esquema `ops`) | incidentes, eventos y runbooks |
| Base `opsdb` | `compose.yaml` (servicio `opsdb`) | PostgreSQL pequeño e independiente de la primaria: el incidente se registra aunque `db` esté caída |
| Usuario `mcp_ops` | creado por el contenedor `opsdb` | dueño de la base `ops`; no ve las tablas de Conduit |
| Mantis | `app/mantis` + base `mantis` en `opsdb` | la incidencia se crea aunque `db` esté caída; el esquema se carga con `opsdb/init/02-mantis.sh` y `03-mantis-schema.sql` |
| Flujo n8n 04 | `automation/n8n/workflows/04-incidente-db.json` | variante vía n8n (no se usa para PostgresCaido: ese va directo de Alertmanager al MCP) |
| API de incidentes | `app/mcp/src/server.mjs` | `POST /incidentes`, estados, aprobación |
| Herramientas MCP | `app/mcp/src/tools.mjs` | `listar_incidentes`, `buscar_solucion`, `aprobar_remediacion`, `rechazar_remediacion` |
| Correo + Telegram | `app/mcp/src/ops.mjs` | aviso con diagnóstico, solución y pedido de aprobación |
| Watcher | `scripts/incidente-watcher.ps1` | ejecuta el failover cuando el incidente está `approved` |
| Restauración | `scripts/restaurar-primaria.ps1` | reconstruye la primaria después de la demo |

## 2. Aclaración: no es un clúster

El proyecto **no** usa un clúster con quórum (Patroni, repmgr, etc.). Es:

```
primaria (db) ──streaming asíncrono──▶ réplica (db-replica)
        ▲                                      │
        └──────── failover MANUAL ─────────────┘
```

La promoción es explícita (`pg_promote`) y la app se repunta con `DATABASE_HOST`.
La demo automatiza el procedimiento manual, pero **no** afirma alta disponibilidad:
si la primaria cae, hay una ventana de indisponibilidad y se puede perder la última
transacción no replicada.

## 3. Flujo de la demo

```
1. docker stop pi-db
        │
        ▼
2. Prometheus: PostgresCaido (pg_up == 0) a los 60 s
        │
        ▼
3. Alertmanager enruta:
   ├── PostgresCaido → MCP /incidentes (directo, sin n8n)
   └── otras alertas → n8n /webhook/alertmanager → Mantis
                     → MCP /incidentes (solo guarda el incidente)
                                      │
                                      ▼
                              MCP /incidentes
                                      │
                                      ├── INSERT ops.incident (estado open)
                                      ├── busca runbook PG_PRIMARY_DOWN
                                      ├── crea incidencia en Mantis (solo PostgresCaido)
                                      ├── correo a MailHog
                                      └── mensaje de Telegram
        │
        ▼
4. Hermes (Telegram) explica el incidente y pregunta:
   "¿Querés que lo resuelva? Respondé SÍ o NO."
        │
        ├── NO  → rechazar_remediacion → estado rejected
        └── SÍ  → aprobar_remediacion  → estado approved
                                      │
                                      ▼
5. scripts/incidente-watcher.ps1 (host) ve approved:
   ├── verifica que pi-db esté detenida (evita split-brain)
   ├── promueve db-replica (pg_promote)
   ├── recrea backend con DATABASE_HOST=db-replica
   ├── espera /health con db=up
   └── marca resolved (o failed) y manda correo/Telegram
        │
        ▼
6. Hermes consulta listar_incidentes y confirma el estado real.
```

## 4. Preparación (una vez)

```powershell
# 1. variables nuevas en .env (ver .env.example)
#    OPS_DB_NAME=ops, OPS_DB_USER=mcp_ops, MCP_OPS_DB_PASSWORD
#    SMTP_HOST=mailhog, SMTP_PORT=1025, MAIL_FROM, MAIL_TO
#    TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
#    MCP_INCIDENTS_ENABLED=true, MCP_ALLOW_WRITE=true

# 2. base de incidentes + esquema (el contenedor la crea en el primer arranque)
./scripts/preparar-tokens.ps1
docker compose up -d opsdb
./scripts/incidentes.ps1 init

# 3. servicios
docker compose --profile ops up -d mailhog n8n alertmanager mcp
docker compose build mcp; docker compose up -d mcp

# 4. Hermes (relee SOUL y las herramientas MCP)
docker compose -f automation/hermes/compose.yaml --env-file .env up -d --force-recreate
```

Verificación:

```powershell
curl.exe -s http://127.0.0.1:8098/health          # escritura=true
./scripts/incidentes.ps1 listar                   # tabla vacía al inicio
docker exec pi-hermes sh -c "grep 'MCP: registered' /opt/data/logs/agent.log | tail -1"
# debe listar 10 tools de practica (incluye listar_incidentes y aprobar_remediacion)
```

## 5. Ensayo sin romper nada

Crea un incidente sintético (no detiene la base) y manda correo/Telegram:

```powershell
./scripts/incidentes.ps1 demo
```

Después:

- MailHog: <http://127.0.0.1:8025> → asunto `[INCIDENTE #1] PostgresCaido...`.
- Telegram: mensaje del bot con la solución y la pregunta.
- Hermes: `docker exec -it pi-hermes hermes chat` y preguntar
  `"Revisá los incidentes y decime si hay alguno pendiente"`.
- Aprobar sin ejecutar: `./scripts/incidentes.ps1 aprobar 1`.
- Ensayar el watcher: `./scripts/incidente-watcher.ps1 -DryRun -UnaVez`.

## 6. Demo real (failover)

> Antes: backup reciente (`./scripts/backup.ps1`) y confirmar que la réplica está
> `streaming` con lag 0 (`./scripts/replica.ps1 status`).

```powershell
# terminal 1: watcher (dejarlo escuchando)
./scripts/incidente-watcher.ps1

# terminal 2: simular la caída del maestro
docker stop pi-db

# esperar ~60 s: Prometheus dispara PostgresCaido
# revisar correo en http://127.0.0.1:8025 y el mensaje de Telegram

# en Telegram, responder al bot:
#   "SÍ, resolvé el incidente #1"
```

El watcher hace la promoción y el repunte. Verificación:

```powershell
./scripts/incidentes.ps1 listar
curl.exe -s http://127.0.0.1:8090/health
./scripts/replica.ps1 status          # la réplica ya no está en recovery
```

Resultado esperado: incidente `resolved`, `resultado` con el RTO, correo de cierre
y backend respondiendo contra `db-replica`.

## 7. Restauración después de la demo

La demo deja `db-replica` como primaria y `pi-db` detenida. Dos opciones:

```powershell
# A) dejar la topología invertida: pi-db queda como standby de db-replica
./scripts/restaurar-primaria.ps1

# B) volver a la topología original: db primaria, db-replica standby
./scripts/restaurar-primaria.ps1 -SwapBack
```

Ambas borran `pi-pgdata` y clonan ~8,5 GB; `-SwapBack` además reconstruye la réplica.
El script pide escribir `RESTAURAR` (o usar `-Force` en un entorno descartable).

Si preferís no clonar, la alternativa es restaurar el backup previo y reinicializar
la réplica con `./scripts/replica.ps1 reinit` (más lento y pierde las escrituras de la demo).

## 8. Operación

```powershell
./scripts/incidentes.ps1 init            # idempotente
./scripts/incidentes.ps1 listar
./scripts/incidentes.ps1 estado 3
./scripts/incidentes.ps1 aprobar 3
./scripts/incidentes.ps1 rechazar 3
./scripts/incidente-watcher.ps1 -DryRun -UnaVez
./scripts/incidente-watcher.ps1 -Intervalo 3
```

API interna del MCP (token `MCP_TOKEN`):

| Método | Ruta | Uso |
|---|---|---|
| `POST` | `/incidentes` | n8n registra la alerta |
| `GET` | `/incidentes?estado=open` | listar |
| `GET` | `/incidentes/:id` | detalle |
| `POST` | `/incidentes/:id/aprobar` | Hermes/operador aprueba |
| `POST` | `/incidentes/:id/rechazar` | rechaza |
| `POST` | `/incidentes/:id/estado` | watcher: `resolving`, `resolved`, `failed` |

## 9. Seguridad y límites

| Punto | Decisión |
|---|---|
| Rol de escritura | `mcp_ops` es dueño de la base `ops`; no puede leer artículos |
| Independencia | `opsdb` sobrevive a la caída de la primaria: el incidente queda registrado |
| Aprobación | solo después de un "sí" explícito; el MCP no ejecuta nada por sí solo |
| Ejecución | watcher en el host, sin Docker socket dentro de contenedores |
| Anti split-brain | el watcher se niega a promover si `pi-db` sigue corriendo (`-Force` solo para ensayo) |
| Correo | MailHog captura, no entrega a Internet; solo loopback |
| Telegram | bot con allowlist (`TELEGRAM_ALLOWED_USERS`); el token no está en el repo |
| Datos perdidos | la réplica es asíncrona: el failover puede perder la última transacción; se declara |
| Mantis | para `PostgresCaido` la crea el MCP; para el resto, el flujo 01 de n8n |

## 10. Evidencia sugerida

| Evidencia | Archivo |
|---|---|
| Correos capturados | `evidence/extra-incidentes/mailhog.json` (exportar de la API) |
| Incidente y eventos | `evidence/extra-incidentes/incidentes.txt` |
| Promoción y RTO | `evidence/extra-incidentes/failover.log` |
| Respuesta de Hermes | `evidence/extra-incidentes/hermes.txt` |
| Estado final | `./scripts/incidentes.ps1 listar` |

Para guardar la evidencia:

```powershell
New-Item -ItemType Directory -Force evidence/extra-incidentes | Out-Null
Invoke-RestMethod http://127.0.0.1:8025/api/v2/messages |
  ConvertTo-Json -Depth 8 | Set-Content evidence/extra-incidentes/mailhog.json
@'
SELECT id, codigo, estado, aprobado_por, resultado, created_at, resuelto_at
FROM ops.incident ORDER BY id;
'@ | docker compose exec -T opsdb psql -U mcp_ops -d ops -f - |
  Set-Content evidence/extra-incidentes/incidentes.txt
```

## 11. Resultado medido (20/11/2026)

| Paso | Resultado |
|---|---|
| Detección `PostgresCaido` | ~60 s (`for: 1m`) |
| Registro del incidente con la primaria caída | correcto: `opsdb` es independiente |
| Correo en MailHog + mensaje de Telegram | correcto |
| Incidencia en Mantis | creada por el MCP |
| Promoción + repunte | **5,4 s** |
| `/health` después del failover | `status=ok`, `db=up` contra `db-replica` |
| Restauración `-SwapBack` | topología original, réplica en streaming |

La prueba completa está en `evidence/extra-incidentes/`.

