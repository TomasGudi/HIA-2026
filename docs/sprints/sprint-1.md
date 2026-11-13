# Sprint 1 — Fundaciones

| | |
|---|---|
| **Fechas** | 12/11/2026 → 13/11/2026 |
| **Objetivo** | Dejar el repositorio, el tablero, la base de datos contenerizada y el dataset listo para trabajar |
| **Comprometido** | 18 ítems · 35 puntos |
| **Completado** | 16 ítems · 30 puntos |
| **Arrastrados** | 2 ítems · 5 puntos (con motivo) |

## Resultado por épica

| Épica | Ítems | Estado | Evidencia |
|---|---|---|---|
| E01 Selección y diagnóstico | 4 | ✅ | `docs/informe/01-descripcion-app.md`, `03-inventario-tecnologico.md`, `docs/02-arquitectura.md` |
| E02 Gestión ágil | 5 | ✅ | `docs/00-plan-proyecto.md`, `docs/dailies/`, tablero HS2 con 5 sprints |
| E03 Control de versiones | 5 | ◐ 3 ✅ / 2 → | repo público + ramas + `.gitattributes` + gitleaks + claves en commits |
| E04 Base de datos contenerizada | 4 | ✅ | `compose.yaml`, `db/init/*.sql`, `evidence/04/` |

## Evidencia dura

| Métrica | Valor | Archivo |
|---|---|---|
| Filas cargadas | 24.205.000 | `evidence/04/seed-bulk.log` |
| Tamaño de la base | 7.874 MB | `evidence/04/volumen.txt` |
| Índices | 1,5 GB (19 %) | `evidence/04/volumen.txt` |
| Huérfanos | 0 en los 4 controles | `evidence/04/seed-bulk.log` |
| Tiempo total de carga | ~13 min | `evidence/04/seed-carga.log` |
| Secretos detectados | 0 en 5 commits | `evidence/03/gitleaks.log` |

## Arrastrados al Sprint 2 (con motivo)

| Ítem | Puntos | Motivo |
|---|---|---|
| Configurar linter y formateador compartidos | 2 | Se definió al reescribir el frontend; falta fijar ESLint/Prettier para ambos proyectos y conectarlo al CI, que es del Sprint 2 |
| Proteger `main` (PR + CI verde obligatorio) | 3 | Requiere configuración de *branch protection* en GitHub, que se hace junto con el primer workflow de CI (Sprint 2); sin CI no hay estado que exigir |

> No se cierra un sprint "marcando todo como hecho". Estos dos ítems dependen de piezas que
> todavía no existen (CI), así que se arrastran con motivo escrito y se reflejan en Jira.

## Revisión (sprint review)

**Demostrable al cierre:**

1. `docker compose up -d db pgadmin` → base healthy en `127.0.0.1:5433`, pgAdmin en `:8080`.
2. `select count(*)` en las 6 tablas → 6M / 6M / 6M / 6M / 200k / 5k.
3. `pg_size_pretty(pg_database_size())` → 7,9 GB.
4. `gitleaks detect` sobre el historial → sin hallazgos.
5. `git ls-remote` → `main` y `develop` públicos en GitHub.

**No demostrable todavía:** la aplicación corriendo (backend + frontend) y la prueba E2E.

## Retrospectiva

**Funcionó**
- Verificar con `docker compose ps` en vez de confiar en el exit code: detectó el problema de
  puertos que el "up" en verde ocultaba.
- Medir en lugar de estimar: el incidente de FK se diagnosticó con `pg_stat_activity` y
  `pg_stat_database`, no por intuición.
- Documentar el "por qué" en el mismo momento en que se decide (los ADR salieron del trabajo real,
  no de un ejercicio posterior).

**No funcionó**
- El primer seed se lanzó sin pensar en los triggers de FK: 30 minutos perdidos.
  **Acción**: antes de cualquier carga masiva, revisar triggers, índices y `max_wal_size`.
- Se asumió que el frontend de referencia compilaba. **Acción**: la verificación de 6 puntos
  (`docs/06-app-seleccion.md` §4) se hace *antes* de comprometerse con un repositorio.
- El push falló por tener dos cuentas de GitHub. **Acción**: definir la cuenta de trabajo antes
  de crear el remoto.

**Acciones para el Sprint 2**
1. Verificar el entorno (Docker, puertos, credenciales) al inicio de cada jornada.
2. Toda medición se archiva en `evidence/` en el momento, no al final.
3. Antes de dar por buena una herramienta, ejecutarla una vez (gitleaks, compose, build).
