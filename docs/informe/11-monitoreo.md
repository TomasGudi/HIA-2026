# 11 — Monitoreo

## 1. Objetivo y alcance

Saber **qué está pasando** antes de que lo reporte un usuario, y tener evidencia de que la alerta
llega a una persona (o a un sistema) con el contexto suficiente para actuar.

Alcance de esta sección: métricas de infraestructura, del motor de base de datos, de la
replicación y de la disponibilidad HTTP real. Queda fuera el APM a nivel de código (traces) y la
observabilidad de logs centralizada: se documentan como limitación en §7.

## 2. Arquitectura

```
                          ┌──────────────┐
   node-exporter ────────▶│              │
   postgres-exporter ────▶│  Prometheus  │──▶ Alertmanager ──▶ webhook n8n (§13)
   postgres-exporter-r ──▶│  :9090       │                      └─▶ alert-sink (§10)
   blackbox-exporter ────▶│              │
                          └──────┬───────┘
                                 │ datasource
                          ┌──────▼───────┐
                          │   Grafana    │  dashboard `pi-overview` (8 paneles)
                          │   :3001      │
                          └──────────────┘
```

| Componente | Imagen | Puerto publicado | Para qué |
|---|---|---|---|
| Prometheus | `prom/prometheus:v2.54.1` | `127.0.0.1:9090` | recolección (15 s) y evaluación de reglas |
| Alertmanager | `prom/alertmanager:v0.27.0` | `127.0.0.1:9093` | agrupación, silencios y envío de notificaciones |
| Grafana | `grafana/grafana:11.2.0` | `127.0.0.1:3001` | dashboard provisionado por archivo |
| node-exporter | `prom/node-exporter:v1.8.2` | — | CPU, memoria, disco, red del anfitrión |
| postgres-exporter | `prometheuscommunity/postgres-exporter:v0.15.0` | — | métricas del motor: primaria |
| postgres-exporter-replica | ídem | — | métricas del motor: standby |
| blackbox-exporter | `prom/blackbox-exporter:v0.25.0` | — | sondeo HTTP real de los servicios |
| alert-sink | `python:3.12-alpine` | — | receptor de evidencia del webhook |

Todo el monitoreo corre bajo el perfil `ops`:

```powershell
docker compose --profile ops up -d
```

Ningún puerto sale de loopback. El acceso remoto va por el túnel de §9.

## 3. Targets y qué mide cada uno

| Job | Target | Métricas que aporta |
|---|---|---|
| `prometheus` | `localhost:9090` | salud del propio Prometheus (sirve para detectar evaluación atrasada) |
| `node` | `node-exporter:9100` | `node_cpu_seconds_total`, `node_memory_*`, `node_filesystem_*`, `node_load*`, `node_network_*` |
| `postgres` | `postgres-exporter:9187` | `pg_up`, conexiones, cache hit, `pg_stat_replication_pg_wal_lsn_diff` |
| `postgres-replica` | `postgres-exporter-replica:9187` | `pg_replication_lag_seconds`, `pg_replication_is_replica` |
| `blackbox` | `http://frontend/`, `http://backend:3000/health`, `http://mantis/` | `probe_success`, `probe_duration_seconds` |

**Por qué blackbox y no solo `up`**: `up` dice que el exporter respondió; no dice que el servicio
detrás responda. `probe_success` hace una petición HTTP real y verifica el código 2xx.

**Por qué un usuario `monitor` y no el de la aplicación**: `postgres_exporter` solo necesita leer
vistas de estadísticas. Se crea con `db/init/06-monitoreo.sh` y se le otorga el rol predefinido
`pg_monitor` (agrupa `pg_read_all_stats` y `pg_read_all_settings`), sin acceso a los datos.

## 4. Las 6 reglas y su umbral

| # | Alerta | Expresión | `for` | Severidad | Por qué ese umbral |
|---|---|---|---|---|---|
| R1 | `ServicioCaido` | `(up{job!="prometheus"} == 0) or (probe_success == 0)` | 2m | critical | 2m descarta reinicios normales de contenedor; cubre caída del exporter y del servicio |
| R2 | `CPUAlta` | CPU del anfitrión > 85% | 5m | warning | 85% deja 15% de margen antes de saturar; 5m descarta picos de build. Verificado: `stress-ng` con 16 workers sobre 8 vCPU lleva la CPU a 100% |
| R3 | `MemoriaAlta` | memoria usada > 90% | 5m | warning | deja margen antes de que el OOM killer mate un contenedor |
| R4 | `DiscoCasiLleno` | disco raíz usado > 85% | 5m | warning | un disco lleno rompe PostgreSQL (no puede escribir WAL); 15% libre da tiempo a purgar |
| R5 | `PostgresCaido` | `pg_up == 0` | 1m | critical | sin base la app no sirve nada: es la única con 1m |
| R6 | `ReplicacionAtrasada` | `max(pg_stat_replication_pg_wal_lsn_diff) > 100 MB` **o** `absent(...)` | 2m | critical | 100 MB es un RPO que conviene mirar; `absent()` cubre el caso peor: ninguna réplica conectada |

Criterio transversal: **una alerta que no es accionable es ruido**. Cada regla tiene en su
anotación `description` la acción concreta a ejecutar, no solo el síntoma.

Las alertas de recursos se agrupan (`group_by: [alertname, severity]`) para que una saturación no
genere una notificación por cada serie.

## 5. Dashboard (`monitoring/dashboards/pi-overview.json`)

Versionado como JSON y provisionado por archivo (`updateIntervalSeconds: 30`): no se edita a mano
en la UI. 8 paneles:

| # | Panel | Fuente | Para qué |
|---|---|---|---|
| 1 | CPU del anfitrión | node-exporter | detectar saturación |
| 2 | Memoria del anfitrión | node-exporter | riesgo de OOM |
| 3 | Disco raíz | node-exporter | riesgo de no poder escribir WAL |
| 4 | Carga del sistema y procesos | node-exporter | distinguir CPU alta por carga real de un pico puntual |
| 5 | Red del anfitrión | node-exporter | ver el corte de tráfico en un failover |
| 6 | Disponibilidad y latencia HTTP | blackbox-exporter | ¿el servicio responde y cuánto tarda? |
| 7 | PostgreSQL: conexiones y cache hit | postgres-exporter | saturación de conexiones y eficiencia de memoria |
| 8 | Replicación: lag de WAL | ambos exporters | estado de replicación (§6) |

El panel 8 usa **dos perspectivas**: `pg_stat_replication_pg_wal_lsn_diff` (bytes que le faltan al
standby, medido desde la primaria) y `pg_replication_lag_seconds` (segundos desde el último replay,
medido desde la réplica). Un panel que solo mirara uno de los dos lados no distinguiría "la réplica
no recibe WAL" de "la réplica recibe pero no aplica".

Acceso: `http://127.0.0.1:3001/d/pi-overview`. Lectura anónima habilitada **solo en loopback**
para la demo; el usuario `admin` conserva su contraseña.

### 5.1 Prueba de anomalía (cadena completa)

Objetivo: verificar que una anomalía real recorre **métrica → regla → Alertmanager → webhook**, no
solo que la regla existe.

```powershell
./scripts/monitoreo.ps1 test-alerta -Minutos 13
```

El script lanza `stress-ng` en un contenedor efímero (16 workers, **sin** límite de `--cpus`) y
sigue el estado de la regla leyéndolo de la API de reglas de Prometheus.

| Momento | CPU | Estado de `CPUAlta` |
|---|---|---|
| t = 1 s | 3,4% | `inactive` |
| t = 262 s | 99,9% | `pending` |
| t = 564 s | 99,9% | **`firing`** |
| t = 585 s | — | fin de la prueba; se retira el contenedor |

Alertmanager recibió la notificación 10 s después (`group_wait: 10s`):

```json
{"status": "firing",
 "alerts": [{"labels": {"alertname": "CPUAlta", "severity": "warning"},
             "annotations": {"summary": "CPU del anfitrión al 100.0%",
                             "description": "CPU sostenida por encima del 85% durante 5 minutos..."}}]}
```

Al retirar el estrés la expresión vuelve a `false`, la alerta se resuelve y Alertmanager envía el
`resolved` (`send_resolved: true`).

**Por qué 13 minutos y no 2**: la regla usa `rate(...[5m])` **y** `for: 5m`. La ventana de 5m tarda
unos 5 minutos en reflejar la carga real, y después hay que sostenerla 5 minutos más. Una prueba
más corta no verifica la regla: verifica que no dispara. La primera corrida (8 min) fue
exactamente ese error.

**Lección registrada**: la primera medición se hizo con `docker run --cpus 6`, que topa el
contenedor en 6 de 8 vCPU (75%). La CPU se estabilizó en 77,7% y la alerta nunca disparó. Al medir
capacidad con un generador de carga limitado se mide el límite del cgroup, no la del anfitrión.

## 6. Limitaciones encontradas (y qué se hizo)

### cAdvisor no funciona en Docker Desktop

Se intentó `gcr.io/cadvisor/cadvisor:v0.49.1` para métricas por contenedor. Falla al enumerar:

```
Failed to create existing container: /docker/<id>:
failed to identify the read-write layer ID ... 
open /rootfs/var/lib/docker/image/overlayfs/layerdb/mounts/<id>/mount-id: no such file or directory
```

Causa: Docker Desktop usa el **snapshotter de containerd**, así que `/var/lib/docker/image/overlayfs`
no existe. Se probó también con `--containerd=/run/containerd/containerd.sock
--containerd-namespace=moby`: el factory de containerd registra correctamente, pero no enumera los
contenedores de Docker Desktop y cAdvisor cae al handler `raw` (series sin label `name`).

**Decisión**: se retira cAdvisor y los paneles 4 y 5 pasan a carga del sistema y red del
anfitrión. El estado de cada servicio se cubre con `up` y con los sondeos HTTP del panel 6. Se
documenta en vez de dejar un panel vacío o un contenedor privilegiado que no aporta datos.

### Las métricas de "anfitrión" son las de la VM de Linux

`node-exporter` corre dentro de la VM de Docker Desktop, no en Windows. Mide los 8 vCPU y la
memoria asignados a esa VM. Es correcto para lo que corre en contenedores, pero **no** es el
consumo de Windows. En un servidor Linux real la distinción desaparece.

Nota de medición: la primera prueba con `docker run --cpus 6` se estabilizó en **77,7%** — el
límite de cgroup era exactamente 6 de 8 vCPU (75%) más la carga del stack. Con `--cpus 8` el
contenedor seguía limitado por la cuota y la lectura no subía. La prueba correcta es **sin
`--cpus`** y con sobre-suscripción (`stress-ng --cpu 16`): ahí la CPU llega a **100%** y la regla
de 85% dispara. Lección registrada: al medir con un límite de cgroup se está midiendo el límite,
no la capacidad del anfitrión.

### Un solo nodo de monitoreo

Prometheus, Alertmanager y Grafana corren en el mismo host que lo monitoreado. Si el host cae, no
hay alerta (no hay quien la emita). La solución real es un Prometheus externo con `remote_write`, o
un segundo nodo con Thanos/Mimir. Se declara como limitación, no se simula.

## 7. Fuera de alcance

| No implementado | Por qué | Mejora posible |
|---|---|---|
| Logs centralizados | el alcance es métricas; los logs se leen con `docker compose logs` | Loki + Promtail |
| Trazas (APM) | requiere instrumentar el backend | OpenTelemetry |
| Retención larga | 15 días en el volumen local | `remote_write` a Mimir/Thanos |
| Monitoreo del propio monitoreo | un nodo solo no puede alertar de su propia caída | segundo nodo + watchdog externo |

## 8. Operación

```powershell
./scripts/monitoreo.ps1 status        # targets, reglas y alertas activas
./scripts/monitoreo.ps1 urls          # URLs de los tres servicios
./scripts/monitoreo.ps1 test-alerta   # prueba de anomalía con stress-ng
./scripts/monitoreo.ps1 recargar      # recarga la configuración de Prometheus
```

## 9. Evidencia

| Evidencia | Archivo |
|---|---|
| Estado de targets, reglas y alertas | `evidence/10/monitoreo-estado.log` |
| Prueba de anomalía con `stress-ng` | `evidence/10/alerta-stress.log` |
| Payload recibido por el webhook | `evidence/10/alertmanager-payloads.jsonl` |
| Dashboard versionado | `monitoring/dashboards/pi-overview.json` |
| Reglas | `monitoring/prometheus/rules.yml` |
| Configuración de scrape | `monitoring/prometheus/prometheus.yml` |
| Ruteo de alertas | `monitoring/alertmanager/alertmanager.yml` |
