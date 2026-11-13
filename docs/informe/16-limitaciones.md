# 16 — Limitaciones y mejoras futuras

## 1. Objetivo

Declarar lo que el sistema **no** hace. Un informe que solo enumera logros no es verificable; este
documento existe para que quien evalúe pueda distinguir entre "no se hizo", "no se pudo" y "no
correspondía".

Criterio: cada limitación tiene **causa**, **riesgo aceptado** y **qué haría falta** para cerrarla.

## 2. Limitaciones de arquitectura

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| A1 | **Sin failover automático** | se eligió replicación streaming manual (D-04); Patroni exige un clúster de 3 nodos y consenso | si cae la primaria, la app queda en escritura hasta que un operador promueva la réplica (**RTO medido: 8,6 s** manual) | Patroni + etcd, o un servicio gestionado |
| A2 | **Primaria y réplica en el mismo host** | un solo equipo disponible | la caída del host se lleva ambas: la réplica protege de un fallo de proceso, no de hardware | segundo host o nube |
| A3 | **Un solo nodo de monitoreo** | Prometheus local sin HA | si cae Prometheus, se pierde la observabilidad, no el servicio | Prometheus en pares + Thanos |
| A4 | **Sin balanceo ni réplicas de la app** | un backend y un frontend | el techo es un contenedor; no hay tolerancia a fallo de la app | varias réplicas + balanceador |
| A5 | **Sin cola de trabajos** | el envío de alertas es síncrono (n8n) | una alerta puede perderse si n8n está caído; Alertmanager reintenta | cola persistente (Redis/RabbitMQ) |

## 3. Limitaciones de datos

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| D1 | **Dataset sintético** | no se dispone de datos reales de producción | los patrones de consulta son realistas, los valores no | anonimizar un dump real |
| D2 | **24,2 M de filas, no 6 M por tabla** | el enunciado pide 6 M en tablas de volumen; se cargaron 6 M en `Article`, `Comment` y `_UserFavorites` | cumple el mínimo en las tres tablas de volumen, no en todas | subir `SEED_*` (multiplica el tiempo de carga) |
| D3 | **Backup lógico** | `pg_dump` es independiente de la versión y simple de verificar | **12,5 min** de restauración para 8,5 GB | `pg_basebackup` + WAL archiving (PITR) |
| D4 | **Backups en el mismo host y sin cifrar** | no hay almacenamiento externo ni claves gestionadas | si se pierde el host, se pierden base y backups | destino S3 + `age`/`gpg` |
| D5 | **Sin PITR** | requeriría archivado continuo de WAL | la granularidad de recuperación es el último dump (24 h) | `archive_command` + retención de WAL |

## 4. Limitaciones de seguridad

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| S1 | **Mantis corre como root** | Apache necesita el puerto 80 y escribir en el web root | mitigado con borde autenticado y `/admin` bloqueado (403) | imagen con `su-exec` y puerto alto |
| S2 | **Basic auth sin MFA** | Cloudflare Access requiere dominio propio y cuenta | contraseña fuerte + login propio de cada herramienta | Cloudflare Access o TOTP |
| S3 | **Token JWT en `localStorage`** | simplicidad del cliente Conduit | un XSS podría leerlo; la CSP sin `unsafe-inline` en scripts reduce la superficie | cookie `HttpOnly` + `SameSite` |
| S4 | **Sin WAF en el borde** | plan pago de Cloudflare | el rate limit de nginx cubre `/api/`, no el resto | WAF o ModSecurity |
| S5 | **2 CVE críticas sin fix** | `zlib` (`will_not_fix` de Debian) y `tar` 6.2.1 (transitiva, requiere salto mayor) | documentadas y monitoreadas; no explotables desde la API | esperar el fix upstream o reemplazar la dependencia |
| S6 | **Prometheus y Grafana sin auth propia** | solo escuchan en loopback | el acceso remoto pasa por el borde con Basic auth | OAuth proxy |
| S7 | **Sin pentest manual** | alcance académico y tiempo | ZAP baseline + pruebas controladas de SQLi cubren lo automatizable | pentest con especialista |

## 5. Limitaciones de automatización

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| N1 | **Flujo 2 (backup programado) no implementado** | la imagen oficial de n8n no trae `postgresql-client`, y el flujo necesita `pg_dump` | el backup se ejecuta con `scripts/backup.ps1` (manual o por Programador de tareas) | imagen propia de n8n con `postgresql-client` |
| N2 | **Flujo 3 (informe semanal a Nextcloud) no implementado** | depende de §12, que no se desplegó | el informe se genera a mano desde `docs/informe/` | desplegar Nextcloud + nodo HTTP de subida |
| N3 | **Flujo 4 no implementado** | no estaba en el alcance mínimo | — | definir disparador y destino |
| N4 | **n8n sin alta disponibilidad** | un contenedor con SQLite/Postgres propio | si cae, se pierden alertas automatizadas; el resto sigue | cola + workers de n8n |

## 6. Limitaciones de gestión

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| G1 | **§12 Nextcloud no desplegado** | prioridad a §1–§11, §13 y §14; el tiempo restante se usó en seguridad y documentación | la documentación vive en el repo (versionada, con historial) y las incidencias en Mantis; no hay una herramienta única de "intranet documental" | desplegar Nextcloud y migrar `docs/` con la matriz de permisos |
| G2 | **HS2-32 sin revisión cruzada real** | una sola cuenta de GitHub; GitHub no permite autoaprobar un PR | los 10 PRs tienen CI obligatorio y revisión del propio autor documentada | incorporar un segundo integrante con cuenta |
| G3 | **HS2-67 sin E2E manual con capturas** | el flujo se validó por API y con el navegador, pero sin set de capturas sistemático | el E2E por API cubre los mismos pasos y queda versionado | agregar Playwright con capturas en CI |

## 7. Limitaciones de publicación

| # | Limitación | Causa | Riesgo aceptado | Para cerrarla |
|---|---|---|---|---|
| P1 | **URL efímera de Cloudflare** | *quick tunnels* no requieren dominio ni cuenta | la URL cambia en cada arranque y hay que republicar antes de la demo | túnel nombrado + dominio propio |
| P2 | **Dependencia de Cloudflare** | es el único camino a Internet | si Cloudflare falla, la app solo es accesible en la LAN | segundo proveedor o IP pública |
| P3 | **Sin TLS propio** | el TLS lo termina Cloudflare | el tramo host→Cloudflare viaja cifrado por el túnel, pero no se controla el certificado | certificado propio con `cloudflared` + origen HTTPS |
| P4 | **Sin dominio ni DNS propio** | costo y tiempo | — | registrar dominio y usar túnel nombrado |

## 8. Lo que sí está resuelto

Para que la lista anterior no oculte lo importante:

- 24,2 M de filas cargadas y **8 consultas optimizadas** con medición antes/después (7,9 s → 0,19 s).
- Replicación streaming verificada y **failover manual probado** (RTO 8,6 s, divergencia documentada).
- CI/CD con 4 checks obligatorios, imágenes en GHCR y **rollback automático**.
- Monitoreo con 8 paneles, 6 reglas y **alerta real convertida en incidencia** por n8n.
- Seguridad con matriz STRIDE de 7 componentes, escaneos antes/después y **ZAP sin fallos**.
- Backup **restaurado y verificado** con comparación de conteos.

## 9. Mejoras priorizadas

Ordenadas por relación impacto/esfuerzo, para un supuesto sprint 5:

| Prioridad | Mejora | Impacto | Esfuerzo |
|---|---|---|---|
| 1 | Nextcloud (§12) + flujo 3 | cierra el único entregable ausente | 1 día |
| 2 | Imagen de n8n con `postgresql-client` + flujo 2 | automatiza el backup | 3 h |
| 3 | Playwright E2E con capturas en CI | cierra HS2-67 y previene regresiones | 4 h |
| 4 | `pg_basebackup` + PITR | reduce RTO/RPO de datos | 1 día |
| 5 | Cookie `HttpOnly` para el JWT | elimina el riesgo de S3 | 3 h |
| 6 | Patroni + etcd | failover automático | 2 días |
| 7 | Túnel nombrado + dominio | URL estable y TLS propio | 4 h |

## 10. Preguntas frecuentes

**¿Por qué no hay failover automático si el enunciado lo sugiere?**
Porque el enunciado pide **replicación**, y el failover automático con Patroni requiere consenso de
3 nodos. Se implementó lo que se puede demostrar en un host: promoción manual medida en 8,6 s y
procedimiento escrito. Se declara como limitación en vez de simularlo.

**¿El sistema aguanta un usuario real?**
Aguanta el tráfico de la práctica (prueba de carga con 100 usuarios concurrentes). No está
dimensionado para producción: un backend, un frontend y un solo host.

**¿Qué pasa si se cae Cloudflare?**
La aplicación sigue funcionando en la LAN (`http://192.168.1.8:8090` no está publicado; el acceso
es por `127.0.0.1` en el host). Se pierde el acceso remoto, no el servicio.
