# Registro de decisiones (ADR)

Formato corto: contexto → decisión → consecuencia. Cada decisión debe poder defenderse sola.

---

## D-01 — Fechas del proyecto
**Contexto**: el enunciado fija "grupos hasta 30/11/2026" y "presentación semana del 16/11/2026",
lo que es contradictorio (el cierre de grupos sería posterior a la defensa).
**Decisión**: se trabaja con **cierre martes 17/11/2026** y congelamiento el **lunes 16 a las 23:59**.
El 30/11 se interpreta como fecha administrativa de definición de grupos, ya vencida.
**Consecuencia**: 5 días corridos. Toda decisión de alcance se toma con criterio de "¿esto se
demuestra en vivo?".

## D-02 — Aplicación base
**Contexto**: §1 pide seleccionar una aplicación existente; el equipo no quiere construir una.
**Decisión**: reutilizar **Conduit (RealWorld)** — Node/Express + React + PostgreSQL, licencia MIT.
**Consecuencia**: hay que verificar 6 puntos el día 1 (ver `06-app-seleccion.md` §4).
Plan B: Spring PetClinic.

## D-03 — Motor de base de datos
**Decisión**: **PostgreSQL 16**.
**Motivo**: replicación streaming nativa y simple (sin plugins), `EXPLAIN (ANALYZE, BUFFERS)` mejor
que MySQL para el informe, `pg_stat_statements` para hallar las 8 consultas, `pgBadger` como
herramienta de análisis, y `tsvector` para la búsqueda full-text.
**Consecuencia**: no se usa MySQLTuner; se cita pgBadger. Si la cátedra exige MySQL, cambia §6.

## D-04 — Replicación sin failover automático
**Contexto**: §6 advierte que "la replicación por sí sola no garantiza alta disponibilidad".
**Decisión**: **primaria + 1 réplica streaming asíncrona, con failover MANUAL documentado**.
No se instala Patroni/repmgr.
**Motivo**: montar Patroni + etcd en 5 días y demostrarlo en vivo es un riesgo alto para un
beneficio bajo: el enunciado no lo exige, solo prohíbe *afirmar* HA sin demostrarla.
**Consecuencia**: el informe declara explícitamente la limitación (RPO ≈ lag en bytes, RTO = tiempo
de promoción manual) y se prueba el procedimiento una vez.

## D-05 — Interpretación del dataset
**Contexto**: "al menos 6.000.000 de registros **por tabla**" es ambiguo y, tomado literalmente
sobre todo el esquema, excede el disco disponible.
**Decisión**: cargar **6M en las 3 tablas de volumen del dominio** (`articles`, `comments`,
`favorites`), y volúmenes realistas en catálogos (`users` 200k, `tags` 5k).
**Consecuencia**: se documenta el supuesto y se pregunta a la cátedra. Si exigen 6M en todas,
se sube el número de tablas de volumen y se documenta el recorte de las demás como limitación.

## D-06 — Dos herramientas de gestión: backlog ≠ incidencias
**Contexto**: §2 pide "Jira **o una herramienta equivalente**" para el backlog; §11 pide
"**instalar o desplegar Mantis o GLPI**" para incidencias, con entregables propios
("herramienta funcionando", "historial de resolución"). ¿Puede Jira cubrir las dos?

**Decisión**: **no**. Backlog en **Jira Free** (plan B: GitHub Projects) + **Mantis** para §11.
**Motivo (el argumento que cierra el tema)**: el propio enunciado, en §13 flujo 1, especifica
"registra una incidencia en **Mantis/GLPI**". Usar solo Jira implica (a) dejar §11 sin
"herramienta funcionando" propia, (b) desviar el flujo 1 de §13 hacia un destino no previsto.
No es interpretación: son dos secciones apuntando al mismo destino.
**Consecuencia**: dos herramientas, ~40 min de montaje. Mantis va en el compose con perfil `ops`.
Mantis necesita DB propia: verificar si el release soporta PostgreSQL (reutiliza el motor) o
levantar un MariaDB chico solo para él.
**Efecto colateral a resolver**: el vínculo incidencia↔commit (§11.5) no es nativo entre Jira y
Mantis → campo personalizado `commit_sha`/`pr_url` en Mantis + `refs #N` en el mensaje del commit.
**Descartado**: Jira para ambas (riesgo alto en §11 y §13); GLPI (más pesado, solo MySQL/MariaDB).

## D-07 — Publicación en Internet
**Decisión**: **Cloudflare Tunnel** como vía principal, **Tailscale Funnel** como plan B ya probado.
VPS descartado por costo (el enunciado no lo pide).
**Consecuencia**: no se abre ningún puerto en el router; HTTPS automático; hay que documentar la
dependencia de un tercero y el riesgo de caída.

## D-08 — Superficie expuesta
**Decisión**: público **solo** el frontend y `/api`. `pgadmin`, `prometheus`, `grafana`, `n8n`,
`mantis`, `nextcloud` **sin `ports:` hacia el host**; se accede por Tailscale o por ruta
protegida con auth básica.
**Consecuencia**: §9 se cumple por diseño, no por configuración manual de firewall.

## D-09 — Secretos
**Decisión**: un único `.env` local (git-ignored) + `.env.example` con placeholders.
En CI, GitHub Secrets. En n8n, credenciales nativas (nunca en nodos).
**Consecuencia**: `gitleaks` corre en pre-commit y en el pipeline; si aparece un secreto en el
historial, se rota la credencial y se reescribe el historial antes de la entrega.

## D-10 — n8n: 3 flujos, no 4
**Decisión**: implementar los flujos 1, 2 y 3 del enunciado; el cuarto (clasificación de eventos
de seguridad) queda como mejora futura documentada.
**Motivo**: el flujo 4 es explícitamente opcional ("se podrá implementar").

## D-11 — Alertas
**Decisión**: Prometheus + Alertmanager con 6 reglas y webhook a n8n.
**Motivo**: sin Alertmanager, "las alertas" son solo líneas rojas en Grafana y no disparan nada,
lo que rompe el flujo 1 de §13 y la prueba de §10.

## D-12 — Alcance de las pruebas de seguridad
**Decisión**: solo contra infraestructura propia: SQLi en formularios del propio frontend, intento
de acceso a `5432` desde Internet, ZAP baseline scan, `nmap` externo.
**Motivo**: legal y ético. Nada de DDoS ni de targets de terceros.
**Consecuencia**: la matriz de amenazas cubre DDoS/ransomware como **análisis y control**, no como
prueba ejecutada — y se dice así en el informe.

## D-13 — Documentación dentro del repo
**Decisión**: todo en Markdown dentro de `docs/`, versionado con el código; el PDF final se genera
desde ahí. Nextcloud recibe **copias** de los entregables (§12 exige centralizar).
**Consecuencia**: una sola fuente de verdad; Nextcloud se usa para la matriz de permisos y la
distribución, no como lugar donde vive el conocimiento.

## D-14 — Índices después de la carga, no antes
**Contexto**: cargar 18M de filas con 7 índices vivos obliga a mantener árboles B-tree durante
cada INSERT; el tiempo se multiplica.
**Decisión**: el esquema se crea **sin índices secundarios**; la carga corre sin ellos y
`db/03-indexes.sql` se aplica al final. Solo se mantienen las restricciones (PK/UNIQUE/FK).
**Consecuencia**: la carga es medible y reproducible, y el "antes/después" de §5 arranca con un
baseline honesto. Se documenta el costo de crear los índices a posteriori (tiempo + espacio).

## D-15 — `internal: true` rompe la publicación de puertos
**Contexto**: la primera versión de `compose.yaml` declaraba la red `dbnet` como `internal: true`.
Los contenedores levantaban, pero `docker port` no mostraba nada y la app no llegaba a la DB.
**Causa**: Docker no configura el proxy de puertos para contenedores conectados únicamente a una
red interna; el binding se descarta **sin devolver error** (el `docker compose up` sale en verde).
**Decisión**: `dbnet` es una bridge normal. El aislamiento se garantiza con (a) publicar solo en
`127.0.0.1` y (b) no publicar ningún puerto en producción.
**Consecuencia**: verificar siempre con `docker compose ps` que los puertos aparezcan como
`127.0.0.1:PUERTO->...`, no como `5432/tcp` a secas.

## D-16 — Puerto 5433 para evitar colisión con otro proyecto local
**Contexto**: en la máquina de desarrollo hay otro stack (`nexo-ic-postgres-1`) usando el 5432.
**Decisión**: la DB se publica en `127.0.0.1:5433` (variable `DB_PORT`).
**Consecuencia**: `DATABASE_URL` de desarrollo apunta a 5433. Dentro de la red Docker el puerto
sigue siendo 5432 (`db:5432`), así que la app no cambia.

## D-17 — Dataset sintético y determinista
**Decisión**: el seed no usa `random()`: usa aritmética modular sobre `generate_series`.
**Consecuencia**: dos cargas producen exactamente el mismo dataset (reproducible para comparar
mediciones de §5) y la generación es más rápida. Las relaciones N:M se generan de forma que no
puedan violar la restricción `UNIQUE (A,B)`.
