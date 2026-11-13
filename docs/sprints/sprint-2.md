# Sprint 2 — Datos, aplicación y rendimiento

| | |
|---|---|
| **Fechas** | 13/11/2026 → 13/11/2026 |
| **Objetivo** | Dataset cargado y medido, aplicación contenerizada, CI operativo y consultas optimizadas |
| **Comprometido** | 24 ítems |
| **Completado** | 20 ítems |
| **Arrastrados** | 4 ítems (con motivo) |

## Resultado por épica

| Épica | Ítems | Estado | Evidencia |
|---|---|---|---|
| E04 Base de datos | 8 | ✅ | `evidence/04/`, `docs/informe/06-migracion-carga.md`, `15-backup.md` |
| E05 Optimización | 9 | ✅ | `db/queries/`, `evidence/05/`, `docs/informe/07-optimizacion-sql.md` |
| E07 Aplicación contenerizada | 4/6 | ◐ | `compose.yaml`, `evidence/07/e2e.log`, `docs/informe/05-configuracion-docker.md` |
| E03 Control de versiones | 2/4 | ◐ | `.github/workflows/ci.yml`, `evidence/03/` |
| E02 Gestión ágil | 1 | ✅ | `docs/05-decisiones.md` D-18 (cambio de alcance) |

## Números del sprint

| Métrica | Valor |
|---|---|
| Filas cargadas | 24.205.000 |
| Tamaño de la base | 7.874 MB → 8.551 MB (tras §5) |
| Huérfanos en la verificación de integridad | 0 (4 controles) |
| Consultas optimizadas | 6 de 8 (2 ya estaban óptimas) |
| Mejora máxima | feed de seguidos: 8.331 ms → 1,2 ms (6.942×) |
| `GET /api/articles` | 7,9 s → **0,19 s** |
| Backup / restauración | 402,6 MB en 84,9 s / 746,1 s verificado |
| CI | 4 jobs, verde en 3 PRs |

## Arrastrados al Sprint 3 (con motivo)

| Ítem | Motivo |
|---|---|
| Separar configuración dev/prod | se resuelve junto con el túnel de §9: el overlay de producción y la publicación son la misma pieza |
| E2E en navegador con capturas | el flujo está validado por HTTP; falta la evidencia visual (se hace con la app publicada, §9) |
| 5 PRs con revisión de otro integrante | hay 3 PRs (#1, #2, #3); la revisión cruzada requiere que el resto del equipo tenga acceso al repo |
| Resolver un conflicto de merge | no apareció un conflicto real en el sprint; se documentará cuando ocurra (no se fabrica) |

> El cuarto es incómodo pero es lo correcto: inventar un conflicto para "cumplir" el ítem sería
> evidencia falsa. Se deja explícito en el informe.

## Revisión (sprint review)

**Demostrable:**

1. `docker compose --profile ops up -d` levanta los 5 servicios; `docker compose ps` con healthchecks.
2. `GET :8090/api/articles` → 200 en **0,19 s** con `articlesCount` de 10.000 (tope) sobre 6M.
3. Registro → alta de artículo → comentario, todo por la SPA.
4. `EXPLAIN ANALYZE` de las 8 consultas: antes y después, en `evidence/05/`.
5. `./scripts/backup.ps1 -RestoreTest` → conteos idénticos.
6. PR #1–#3 con CI verde; push directo a `main` rechazado por protección.

**No demostrable todavía:** réplica, publicación en Internet, monitoreo y n8n (Sprint 3+).

## Retrospectiva

**Funcionó**

- Medir antes de optimizar: la peor consulta del sistema no era la que suponíamos (la generaba el
  ORM con 17,8 s).
- Probar en negativo: el `enforce_admins=false` se detectó porque se intentó el push que *debía*
  fallar, no porque se leyera la configuración.
- Documentar el "por qué" en el momento: los ADR D-18 a D-21 salieron del trabajo, no de un repaso.

**No funcionó**

- El primer seed se lanzó sin revisar los triggers de FK: 30 minutos perdidos (D-19).
- Se asumió que el frontend de referencia compilaba (D-18).
- El script de backup pasó por tres iteraciones por detalles de PowerShell (`$ErrorActionPreference`
  con stderr de psql, quoting en `-c`): **acción**: pasar SQL por stdin siempre.

**Acciones para el Sprint 3**

1. Antes de cada carga o restauración, revisar triggers, índices y parámetros del motor.
2. Todo script con SQL va por `stdin` (`psql -f -`), nunca por `-c` con comillas.
3. Verificar el entorno al inicio de la jornada (Docker, puertos, credenciales) — ya evitó dos
   falsos positivos.
