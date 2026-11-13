# Checklist de entregables (§1 a §15)

Convención de evidencia: `evidence/<NN-seccion>/<archivo>`. Toda evidencia = **comando + salida**,
no solo screenshot. Estado: ☐ pendiente · ◐ en curso · ☑ listo · ✗ recortado (documentar como limitación).

## §1 Selección y diagnóstico — R2

| ☐ | Entregable | Evidencia esperada | Pregunta probable en la oral |
|---|---|---|---|
| ☐ | Descripción de la aplicación | `docs/informe/01-descripcion-app.md` | ¿Qué problema resuelve y qué hace hoy? |
| ☐ | Inventario del stack | tabla back/front/DB/deps con **versiones exactas** | ¿Qué versión de Postgres y por qué? |
| ☐ | Diagrama inicial de arquitectura | `docs/02-arquitectura.md` §1 | ¿Qué contenerizaste y qué no? |
| ☐ | Lista de funcionalidades | 8-12 funcionalidades con estado | ¿Cuáles son propias y cuáles heredadas? |
| ☐ | Diagnóstico técnico y plan de mejoras | ≥10 hallazgos con impacto y prioridad | ¿Cuál fue el peor problema encontrado? |

## §2 Scrum — R2

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Tablero (GitHub Projects / Jira) | link público + screenshot del board |
| ☐ | Product Backlog | `docs/01-product-backlog.csv` cargado como issues |
| ☐ | Plan de sprints | `docs/00-plan-proyecto.md` §3 |
| ☐ | Responsables y criterios de aceptación | columnas Owner + Criterio del backlog |
| ☐ | Evidencias de seguimiento | 3+ dailies en `docs/dailies/` + changelog de alcance |

> El backlog debe incluir infra, pruebas, seguridad y documentación — ya está en el CSV (E4..E15).

## §3 Control de versiones — R2

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Repo remoto público sin secretos | `gitleaks detect` sin hallazgos |
| ☐ | Historial de commits | `git log --oneline --graph` en el informe |
| ☐ | Ramas de trabajo | `git branch -a` con main/develop/feature-*/fix-* |
| ☐ | PRs y revisiones | ≥5 PRs cerrados con review de otro integrante |
| ☐ | README inicial | raíz del repo, con quickstart de 5 comandos |

Controles obligatorios: `main` protegida, PR + CI verde requerido, `.env` en `.gitignore`.

## §4 Contenerización de la DB — R1

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Dockerfile y compose | `compose.yaml` (+ `compose.override.yaml`) |
| ☐ | Esquema de la base | `db/init/01-schema.sql` + diagrama ER |
| ☐ | Script de carga | `scripts/seed.sh` / `scripts/seed.py` |
| ☐ | Evidencia de volumen | `evidence/04/volumen.txt`: count(*), `pg_size_pretty`, tiempos |
| ☐ | Cliente admin funcionando | screenshot pgAdmin vía túnel |
| ☐ | Backup + restauración | `evidence/04/backup-*.log` y restauración con count igual |
| ☐ | Persistencia al recrear | `docker compose down` (sin -v) → datos intactos |
| ☐ | Datos del dataset documentados | registros/tabla, tamaño DB, método, tiempo de carga, restricciones, tiempo de backup |
| ☐ | Herramienta de análisis | salida de pgBadger o Percona Toolkit |

## §5 Optimización — R1

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | 8 consultas originales + optimizadas | `db/queries/qN-*.sql` (antes y después) |
| ☐ | Planes iniciales y posteriores | 16 bloques `EXPLAIN (ANALYZE, BUFFERS)` |
| ☐ | Índices + justificación | tabla: índice / consulta / selectividad / costo escritura / tamaño |
| ☐ | Mediciones | tiempo antes/después ×10 ejecuciones, % de mejora |
| ☐ | Informe | `docs/informe/07-optimizacion-sql.md` |
| ☐ | Parámetros del motor | análisis de `shared_buffers`, `work_mem`, `effective_cache_size` |

**Consultas candidatas en Conduit** (todas del producto real):
1. Feed de artículos por autores seguidos (JOIN + ORDER BY + LIMIT/OFFSET)
2. Listado por tag (JOIN con `article_tags`)
3. Búsqueda por título/cuerpo (ILIKE vs `tsvector`)
4. Conteo de favoritos por artículo (agregado sobre 6M)
5. Tags populares (`GROUP BY` sobre `article_tags`)
6. Perfil de autor + número de seguidores
7. Artículos con conteo de comentarios (N+1 → agregado)
8. Paginación profunda con OFFSET alto (demostrar el problema + keyset pagination)

## §6 Replicación — R1

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Diagrama de replicación | `docs/02-arquitectura.md` §2 |
| ☐ | Configuración de nodos | `db/postgresql.primary.conf`, `replica.conf`, init scripts |
| ☐ | Evidencias de replicación | `pg_stat_replication` en streaming + INSERT visible en réplica |
| ☐ | Prueba de fallo y recuperación | `docker stop replica` / `docker stop primary` + comportamiento |
| ☐ | Informe consistencia y limitaciones | lag medido, sin failover automático, procedimiento manual |

> No inventar failover automático. Si no hay Patroni, se dice "failover manual con estos 5 pasos".

## §7 App contenerizada — R2

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Backend + frontend en contenedores | `Dockerfile` multistage de cada uno |
| ☐ | Compose de la app | en el compose principal, redes `appnet`/`dbnet` |
| ☐ | Evidencia de comunicación FE→BE→DB | logs + request con `curl` + panel de red |
| ☐ | Capturas funcionando | `evidence/07/e2e/` (login, listado, alta) |
| ☐ | Configs dev/prod separadas | `compose.override.yaml` o perfiles |

## §8 CI/CD — R2

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Pipeline | `.github/workflows/ci.yml` + `deploy.yml` |
| ☐ | Ejecución exitosa | link al run verde |
| ☐ | Commit de prueba | SHA del commit + run que lo desplegó |
| ☐ | Evidencia de despliegue | healthcheck externo mostrando la versión nueva |
| ☐ | Rollback | run de redeploy del tag anterior < 3 min |
| ☐ | Prueba negativa | PR con test roto → pipeline rojo (esto suele preguntarse) |

## §9 Publicación — R5

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | URL de acceso | https://… (probar desde datos móviles, no wifi de casa) |
| ☐ | Diagrama de red | `docs/02-arquitectura.md` §6 |
| ☐ | Configuración de publicación | `cloudflared/config.yml` (sin el JSON de credenciales) |
| ☐ | Evidencia de acceso externo | screenshot con IP externa / 4G |
| ☐ | Firewall y HTTPS | `nmap` externo: solo 443 abierto; candado TLS |
| ☐ | Análisis de riesgos | tabla de riesgos del túnel + plan B |

## §10 Monitoreo - R3

| ☑ | Entregable | Evidencia esperada |
|---|---|---|
| ☑ | Config Prometheus | `monitoring/prometheus/prometheus.yml` + `rules.yml` |
| ☑ | Dashboard Grafana | `monitoring/dashboards/pi-overview.json` (8 paneles) |
| ☑ | Métricas reales | `evidence/10/prometheus-targets.json`, `evidence/10/grafana-dashboard.json` |
| ☑ | Alertas | 6 reglas con umbral justificado (`rules.yml`) |
| ☑ | Prueba de anomalía | `stress-ng` → `CPUAlta` firing a los 564 s → payload recibido (`evidence/10/alerta-stress.log`) |
| ☐ | Alerta → incidencia | n8n crea el issue en Mantis (§13) |

> cAdvisor no enumera contenedores en Docker Desktop (snapshotter de containerd):
> se retiró y se documentó en `docs/informe/11-monitoreo.md` §6.

## §11 Incidencias — R3

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Mantis funcionando | URL + usuario de prueba |
| ☐ | ≥10 incidencias | export CSV o screenshot del listado |
| ☐ | Asignación y seguimiento | historial de estados |
| ☐ | Resolución | ≥5 con commit/PR asociado y verificación |

Requisito: **1 de rendimiento** (ej. listado por tag sin índice) y **1 de seguridad**
(ej. header de n8n sin validar, o `/api` filtrando emails).

> §11 no lo cubre Jira: el enunciado exige Mantis/GLPI como herramienta propia y §13 flujo 1
> escribe ahí. El vínculo con código se resuelve con campo `commit_sha`/`pr_url` en Mantis
> + `refs #N` en el commit (ver D-06).
> No olvidar: borrar/bloquear `mantis/admin/` después de instalar, y desactivar el mail de Mantis
> (las notificaciones las maneja n8n).

## §12 Nextcloud — R4

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Estructura documental | árbol de carpetas 01..15 |
| ☐ | Matriz de permisos | tabla usuario/grupo/carpeta/permiso |
| ☐ | Informes centralizados | ≥6 archivos versionados + prueba con segundo usuario |

## §13 n8n — R4

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Configuración | servicio en compose + volumen + Postgres propio |
| ☐ | Diagramas | `docs/02-arquitectura.md` §5 + JSON exportado de cada flujo |
| ☐ | Evidencias de ejecución | execuciones exitosas con timestamp |
| ☐ | Registro de errores | 1 ejecución fallida forzada + su manejo |
| ☐ | Pruebas de integración | payload inválido rechazado, webhook sin token rechazado |
| ☐ | Análisis de riesgos | qué pasa si el flujo se dispara en loop, si Mantis está caído, etc. |

## §14 Seguridad — R5

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | Matriz de amenazas | STRIDE × 7 componentes, con control y evidencia |
| ☐ | Informe de vulnerabilidades | Trivy + npm audit + Semgrep/Bandit |
| ☐ | Escaneo y corrección | antes/después de CVEs críticas |
| ☐ | Pruebas controladas | SQLi mitigada, puerto DB cerrado, ZAP baseline |
| ☐ | Controles | headers, rate limit, auth, secretos, non-root en contenedores |
| ☐ | Respuesta a incidentes | runbook 5 fases |
| ☐ | Flujo de incidentes con n8n | issue creado automáticamente + evidencia |

## §15 Documentación y defensa — R5

| ☐ | Entregable | Evidencia esperada |
|---|---|---|
| ☐ | 16 documentos obligatorios | `docs/` completo, ver `04-informe-final-outline.md` |
| ☐ | Informe consolidado | PDF único con índice |
| ☐ | Demo de 20 min | `docs/20-guion-demo.md` con tiempos |

---

## Preguntas abiertas para la cátedra

Llevarlas por escrito (mail o al inicio de la clase), no en la defensa:

1. **Fechas**: el enunciado dice grupos hasta 30/11 y presentación 16/11. ¿Cuál rige?
2. **6M de registros**: ¿por cada tabla del esquema o por las tablas principales del dataset?
3. **Mantis**: ¿Jira puede cubrir §11 o Mantis/GLPI es obligatorio?
4. **§14**: ¿qué cuenta como "prueba controlada" válida (escaneo automatizado vs pentest manual)?
5. **§9**: ¿el túnel local es obligatorio o vale cualquier publicación con HTTPS?
