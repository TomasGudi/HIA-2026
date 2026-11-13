# 08 — Configuración y pruebas de replicación

## 1. Arquitectura implementada

**Primaria + 1 réplica en streaming asíncrona**, sin failover automático.

```
┌─────────────────────────┐        WAL (streaming, async)        ┌──────────────────────────┐
│  pi-db (primaria)       │ ───────────────────────────────────▶ │  pi-db-replica (standby) │
│  lectura + escritura    │                                      │  solo lectura            │
│  wal_level = replica    │ ◀── pg_basebackup -R (clon inicial)  │  hot_standby = on        │
└─────────────────────────┘                                      └──────────────────────────┘
        ▲                                                                   ▲
        └────────────── backend (DATABASE_HOST) ────────────────────────────┘
```

| Nodo | Rol | Puerto publicado | Persistencia |
|---|---|---|---|
| `pi-db` | primaria: recibe todas las escrituras | `127.0.0.1:5433` | volumen `pi-pgdata` |
| `pi-db-replica` | standby: replay continuo, solo lectura | **ninguno** | volumen `pi-pgdata-replica` |

## 2. Configuración

### Primaria (`compose.yaml`, servicio `db`)

| Parámetro | Valor | Motivo |
|---|---|---|
| `wal_level` | `replica` | necesario para enviar WAL con información suficiente para consultas en standby |
| `max_wal_senders` | `10` | conexiones de envío concurrentes |
| rol `replicador` | `REPLICATION LOGIN` con contraseña desde `.env` | credencial específica, no la de la aplicación |
| `pg_hba.conf` | `host replication replicador 172.16.0.0/12 scram-sha-256` | solo la red interna de Docker puede replicar |

El rol y la regla de `pg_hba` se crean con `db/init/05-replicacion.sh` (idempotente: se puede
volver a ejecutar sin duplicar nada).

### Réplica (`db/replica/entrypoint.sh`)

1. Si el volumen está vacío: `pg_basebackup -h db -U replicador -D $PGDATA -Fp -Xs -R -P`.
   El `-R` escribe `primary_conninfo` y crea `standby.signal`: eso es todo lo que convierte al
   nodo en standby.
2. Si ya hay datos: arranca directamente (un reinicio no vuelve a clonar).

## 3. Verificación de replicación

| Comprobación | Resultado |
|---|---|
| `pg_stat_replication` en la primaria | `state = streaming`, `sync_state = async`, **lag = 0 bytes** |
| `pg_is_in_recovery()` en la primaria | `false` (es primaria) |
| Réplicas conectadas | 1 |
| `pg_is_in_recovery()` en la réplica | `true` (es standby) |
| Escritura en primaria visible en réplica | **447 ms** (incluye el sondeo cada 200 ms) |
| Escritura directa en la réplica | rechazada: `cannot execute INSERT in a read-only transaction` |

Evidencia: `evidence/06/replicacion.log`.

## 4. Pruebas de fallo

| Escenario | Resultado medido |
|---|---|
| **A) Se detiene la réplica** | la app sigue respondiendo **200 en 0,198 s**; sin impacto porque escribe en la primaria |
| **B) Se detiene la primaria** | primera respuesta no-200 a los **1,4 s**; 20/20 fallos en 10 s (HTTP 500) |
| **C) Failover manual** (`pg_promote`) | promoción en **1,2 s**; nodo fuera de recovery |
| **C2) Repunte de la app** | `DATABASE_HOST=db-replica` + recrear el backend |
| **C3) RTO total** | **8,6 s** desde el inicio de la promoción hasta que la app vuelve a responder 200 |
| **C4) Escritura en el nodo promovido** | `POST /api/users` → **201**; 200.002 usuarios |

Evidencia: `evidence/06/failover.log`.

## 5. Failover: procedimiento manual (no automático)

```powershell
# 1. detectar que la primaria no responde (monitoreo o healthcheck)
docker compose stop db

# 2. promover la réplica
./scripts/replica.ps1 promote        # pg_promote()

# 3. repuntar la aplicación
#    .env -> DATABASE_HOST=db-replica
docker compose up -d --force-recreate backend

# 4. verificar
curl http://127.0.0.1:8090/api/articles?limit=3
```

**No hay detección automática de falla ni promoción automática.** No se usa Patroni/repmgr: el
enunciado advierte que la replicación por sí sola no garantiza alta disponibilidad, y afirma que
si se declara failover automático hay que demostrarlo. Acá se declara **failover manual**, con el
procedimiento ejecutado y el RTO medido.

## 6. Divergencia detectada (lo más importante de la prueba)

Al promover la réplica y seguir escribiendo, el nodo promovido quedó con **un usuario que la
primaria vieja no tiene** (`failover_demo`). Al restaurar la topología original hubo que
**descartar el volumen de la réplica promovida y volver a clonar**, perdiendo esa escritura.

Eso no es un defecto del procedimiento: es la naturaleza de un failover manual sin cuórum. Si la
primaria "caída" en realidad solo estaba aislada (split-brain), ambas aceptarían escrituras y
habría que reconciliar. Un sistema con promoción automática necesita un mecanismo de cuórum
(Patroni + etcd) para evitar exactamente esto.

**Consecuencia documentada**: RPO ≠ 0. En replicación asíncrona se puede perder el WAL que no
llegó a la réplica. En la prueba el lag era 0 bytes, así que la pérdida fue de la escritura hecha
*después* de la promoción, no antes.

## 7. Limitaciones

| Limitación | Impacto | Mejora posible |
|---|---|---|
| Sin failover automático | RTO depende de una persona (~9 s medidos, más el tiempo de detección) | Patroni + etcd o repmgr |
| Replicación asíncrona | RPO > 0 ante caída abrupta | `synchronous_commit=remote_apply` (más latencia) |
| La app necesita repunte manual | un `DATABASE_HOST` y un reinicio | proxy (HAProxy/pgBouncer) o driver con failover |
| Sin balanceo de lecturas | la réplica no se usa para consultas | `read replica` de Prisma no existe en 4.x; requiere segundo cliente o proxy |
| Un solo standby | sin cuórum ni segunda copia | añadir una segunda réplica |

## 8. Evidencia

| Evidencia | Archivo |
|---|---|
| Estado, lag, escritura→lectura, solo-lectura | `evidence/06/replicacion.log` |
| Pruebas de fallo, promoción y RTO | `evidence/06/failover.log` |
| Configuración | `compose.yaml`, `db/replica/entrypoint.sh`, `db/init/05-replicacion.sh` |
| Script de operación | `scripts/replica.ps1` |
| Consultas de verificación | `db/queries/30-replicacion.sql` |
