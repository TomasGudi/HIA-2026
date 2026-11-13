# Mapa documental — 16 documentos obligatorios (§15)

Convención: los documentos del informe final viven en **`docs/informe/`**, numerados en el orden
del enunciado. Los documentos de gestión (plan, backlog, arquitectura, decisiones) quedan en
`docs/` como soporte, y se referencian desde el informe.

| # | Documento obligatorio | Archivo | Sale de | Owner |
|---|---|---|---|---|
| 1 | Descripción de la aplicación | `docs/informe/01-descripcion-app.md` | §1 | R2 |
| 2 | Arquitectura general | `docs/informe/02-arquitectura.md` | §1/§6/§7 | R1 |
| 3 | Inventario tecnológico | `docs/informe/03-inventario-tecnologico.md` | §1 | R2 |
| 4 | Manual de instalación | `docs/informe/04-manual-instalacion.md` | §4/§7 | R2 |
| 5 | Configuración Docker | `docs/informe/05-configuracion-docker.md` | §4/§7 | R1 |
| 6 | Migración y carga de datos | `docs/informe/06-migracion-carga.md` | §4 | R1 |
| 7 | Informe de optimización SQL | `docs/informe/07-optimizacion-sql.md` | §5 | R1 |
| 8 | Configuración y pruebas de replicación | `docs/informe/08-replicacion.md` | §6 | R1 |
| 9 | Configuración CI/CD | `docs/informe/09-cicd.md` | §8 | R2 |
| 10 | Procedimiento de publicación | `docs/informe/10-publicacion.md` | §9 | R5 |
| 11 | Manual de monitoreo | `docs/informe/11-monitoreo.md` | §10 | R3 |
| 12 | Gestión de incidencias | `docs/informe/12-incidencias.md` | §11 | R3 |
| 13 | Flujos de n8n | `docs/informe/13-automatizacion.md` | §13 | R4 |
| 14 | Informe de seguridad | `docs/informe/14-seguridad.md` | §14 | R5 |
| 15 | Backup y restauración | `docs/informe/15-backup.md` | §4/§13 | R1 |
| 16 | Limitaciones y mejoras futuras | `docs/informe/16-limitaciones.md` | todas | R5 |

Extras: `docs/20-guion-demo.md` (guion de la defensa), `docs/12-nextcloud.md` (gestión documental
de §12) y `docs/dailies/YYYY-MM-DD.md` (seguimiento Scrum).

---

## Plantilla mínima por documento

Para no perder tiempo escribiendo prosa, cada doc sigue esta estructura de 6 bloques:

```markdown
# <Título>
## 1. Objetivo            (2 líneas: qué resuelve este documento)
## 2. Configuración       (comando/archivo exacto, con rutas del repo)
## 3. Evidencia           (tabla: evidencia | archivo | cómo se reproduce)
## 4. Decisiones          (link a la ADR de 05-decisiones.md)
## 5. Limitaciones        (qué NO hace)
## 6. Preguntas frecuentes (3 preguntas que haría el docente + respuesta corta)
```

El bloque 6 es el que salva la nota individual: si cada integrante escribe las 3 preguntas
de su sección antes de la defensa, llega con las respuestas preparadas.

## Contenido crítico por documento (lo que no puede faltar)

**01 Descripción** — dominio, usuarios, 8-12 funcionalidades con estado, qué se heredó y qué se modificó.

**02 Arquitectura** — los 5 diagramas Mermaid de `docs/02-arquitectura.md` + tabla de puertos y redes.

**03 Inventario** — tabla con versión exacta de cada componente (Postgres 16.x, Node xx, React xx,
nginx xx) y justificación de las elecciones. Mencionar los eventos de ciberseguridad recientes que
afectaron al stack elegido (ej. para PHP: CVE-2024-4577 / GhostAction).

**04 Instalación** — `git clone` → `.env` → `docker compose up -d` → verificación. Sin pasos mágicos.

**05 Docker** — explicación del compose: servicios, redes, volúmenes, dependencias, healthchecks,
perfiles `dev`/`prod`. Y por qué `5432` no se publica.

**06 Migración** — esquema, script de seed, tiempos medidos por tabla, integridad referencial,
tamaño final de la DB.

**07 Optimización** — los 8 pares antes/después con plan, tiempo y % de mejora + justificación de
cada índice + impacto en escritura + parámetros del motor.

**08 Réplica** — config de ambos nodos, `pg_stat_replication`, prueba de caída, procedimiento manual
de promoción, lag medido, declaración de que **no hay HA automática**.

**09 CI/CD** — YAML comentado, secretos usados (sin valores), prueba negativa, rollback con tiempos.

**10 Publicación** — Cloudflare Tunnel, diagrama de red, `nmap` externo, riesgos y plan B.

**11 Monitoreo** — targets, 6 reglas con umbral y justificación, paneles, prueba con `stress-ng`,
y la aclaración de que las métricas de DB son del motor, no de consultas individuales.

**12 Incidencias** — las 10 con pasos de reproducción, la de rendimiento y la de seguridad
destacadas, y el vínculo con commits.

**13 n8n** — 3 flujos con disparador/condiciones/acciones, manejo de error, validación de payload,
webhook autenticado, y qué pasa si el servicio destino está caído.

**14 Seguridad** — matriz STRIDE (7 componentes × 6 categorías), resultados de Trivy/npm audit/
Semgrep/ZAP, correcciones aplicadas, runbook de respuesta.

**15 Backup** — política, retención, automatización vía n8n, restauración probada con tiempos,
verificación de integridad.

**16 Limitaciones** — sin failover automático, dataset recortado (si aplica), dependencia de
Cloudflare, un solo nodo de monitoreo, flujo 4 no implementado. Honestidad = credibilidad.

---

## Guion de demo (20 min, 5 personas)

| Min | Quién | Qué se muestra |
|---|---|---|
| 0-2 | R2 | App funcionando desde 4G: login, listado, alta |
| 2-5 | R1 | `docker compose ps`, volúmenes, pgAdmin, `count(*)` = 6M |
| 5-8 | R1 | Una consulta: `EXPLAIN` antes (Seq Scan) → después (Index Scan) con tiempos |
| 8-11 | R1 | `pg_stat_replication` + INSERT visible en réplica + `docker stop replica` |
| 11-13 | R2 | PR con CI rojo → merge verde → deploy → rollback |
| 13-16 | R3 | Grafana + `stress-ng` → alerta → issue creado solo en Mantis |
| 16-18 | R4 | Los 3 flujos de n8n (incluido un fallo controlado) |
| 18-20 | R5 | `nmap` externo (solo 443), Trivy, matriz de amenazas, cierre |

Reglas: **nada de videos pregrabados**, un solo teclado, cada uno ejecuta su parte.
Tener en una terminal aparte los comandos listos (script `demo/run.sh`) para no tipear en vivo.
