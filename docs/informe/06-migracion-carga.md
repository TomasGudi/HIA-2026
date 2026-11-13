# 06 — Migración y carga de datos

## 1. Objetivo

Poblar PostgreSQL con un dataset **sintético** que permita medir rendimiento real (§5), probar
replicación (§6) y ejercitar la aplicación con volumen representativo, sin usar datos personales
reales.

## 2. Método

| Aspecto | Decisión |
|---|---|
| Generación | `generate_series` + aritmética modular (sin `random()`) → **determinista y reproducible** (D-17) |
| Formato | SQL puro (`db/seed/10-seed.sql` para carga completa, `11-seed-bulk.sql` para recargar solo tablas de relación) |
| Integridad | FKs declaradas; durante la carga se desactivan los triggers (`session_replication_role=replica`) y se validan después (D-19) |
| Índices | **no** existen durante la carga; se crean al final (D-14) |
| Restricciones | PK, UNIQUE (`email`, `username`, `slug`, `name`), UNIQUE `(A,B)` en las N:M, CHECK de auto-seguimiento |
| Datos personales | ninguno: emails `userN@example.com`, contraseñas con hash ficticio, textos Lorem ipsum |

### Volumen por tabla

| Tabla | Filas | Rol en el dataset |
|---|---|---|
| `Article` | 6.000.000 | tabla de volumen |
| `Comment` | 6.000.000 | tabla de volumen |
| `_UserFavorites` | 6.000.000 | tabla de volumen (N:M) |
| `_ArticleToTag` | 6.000.000 | relación N:M derivada de los artículos |
| `User` | 200.000 | catálogo con cardinalidad realista |
| `Tag` | 5.000 | catálogo |
| **Total** | **24.205.000** | |

> El enunciado pide "al menos 6.000.000 de registros por tabla de datos que forme parte del
> conjunto de prueba". Se interpreta como **tablas de volumen del dominio** (ver D-05); los
> catálogos se dimensionan con cardinalidad realista porque inflarlos no aporta nada al análisis.

## 3. Tiempos medidos

| Etapa | Filas | Tiempo |
|---|---|---|
| `User` | 200.000 | 1,9 s |
| `Tag` | 5.000 | 0,02 s |
| `Article` | 6.000.000 | **10 min 43 s** |
| `Comment` (6 trozos de 1M) | 6.000.000 | **26,0 s** (3,8 + 4,3 + 4,4 + 4,9 + 5,0 + 5,1) |
| `_UserFavorites` | 6.000.000 | 24,6 s |
| `_ArticleToTag` | 6.000.000 | 29,9 s |
| `ANALYZE` | — | 36,1 s |
| **Total** | 24,2M | **~13 min** |

Evidencia: `evidence/04/seed-carga.log`, `evidence/04/seed-bulk.log`.

### Por qué `Article` tarda 20× más que `Comment` con la misma cantidad de filas

`Article` tiene dos índices UNIQUE (`slug`, y la PK), un cuerpo de ~500 bytes por fila
(`repeat(...)` ×12) y una FK a `User`; además se cargó **antes** de ajustar `max_wal_size`.
`Comment` se cargó sin triggers de FK y con el clúster ya ajustado. Es una comparación honesta
del costo de mantener índices y WAL durante la carga, y se retoma en §5.

## 4. Tamaño final

| Tabla | Datos | Índices | Total |
|---|---|---|---|
| `Article` | 5.210 MB | 722 MB | **5.931 MB** |
| `Comment` | 721 MB | 301 MB | 1.021 MB |
| `_UserFavorites` | 207 MB | 266 MB | 473 MB |
| `_ArticleToTag` | 207 MB | 168 MB | 375 MB |
| `User` | 36 MB | 28 MB | 64 MB |
| `Tag` | 264 kB | 304 kB | 568 kB |
| **Base de datos** | | | **7.874 MB (7,9 GB)** |

Los índices ocupan **~1,5 GB (19 % de la base)**. Ese número es el que hay que justificar cada
vez que se propone un índice nuevo (§5): no es gratis ni en disco ni en escritura.
Evidencia: `evidence/04/volumen.txt`.

## 5. Incidente de carga y su resolución (D-19)

| | |
|---|---|
| **Síntoma** | La inserción de `Comment` quedó 30 min con menos de 1.000 filas cargadas |
| **Causa** | Trigger de FK: `SELECT 1 FROM "User" WHERE id = $1 FOR KEY SHARE` por fila; 6M comentarios contra 200k usuarios → contención de locks de fila |
| **Solución** | `SET session_replication_role = replica` durante la carga + validación posterior de huérfanos |
| **Resultado** | 6M de comentarios en 26 s (mejora de más de dos órdenes de magnitud) |
| **Trade-off** | La integridad deja de estar garantizada por el motor durante la carga; se garantiza por verificación explícita y se documenta |

## 6. Verificación de integridad (evidencia)

Ejecutada al final de la carga, sobre 24M de filas:

| Control | Huérfanos |
|---|---|
| comentarios huérfanos (artículo) | **0** |
| comentarios huérfanos (autor) | **0** |
| favoritos huérfanos | **0** |
| artículo-etiqueta huérfanos | **0** |

Evidencia: `evidence/04/seed-bulk.log` (bloque "VERIFICACION DE INTEGRIDAD").

### Dato extra que sirve para §5

La misma consulta de control de huérfanos tardó **235.324 ms (3 min 55 s) sin índices** y
**3.570 ms con `Comment_articleId_idx`**: 65× menos. No es una consulta del producto, pero
demuestra el efecto de un índice sobre un `LEFT JOIN` de 6M × 6M.

## 7. Parámetros ajustados para la carga (D-20)

| Parámetro | Antes | Después | Motivo |
|---|---|---|---|
| `max_wal_size` | 1 GB (default) | 8 GB | la primera carga generó **38 GB de WAL** por checkpoints frecuentes |
| `checkpoint_timeout` | 5 min (default) | 15 min | menos full-page writes |
| `synchronous_commit` | on | off (solo durante la carga) | durabilidad no crítica en datos regenerables |
| `maintenance_work_mem` | 64 MB | 1 GB (sesión de carga) | `ANALYZE` y creación de índices más rápidos |

Los dos primeros se aplicaron con `ALTER SYSTEM` + `pg_reload_conf()` (sin reinicio) y quedan en
`postgresql.auto.conf`; se revierten o se justifican en el informe de §5.

## 8. Reproducción

```powershell
docker compose up -d db
./scripts/db.ps1 seed      # carga completa (10-seed.sql)
./scripts/db.ps1 indexes   # índices después de la carga
./scripts/db.ps1 stats     # tamaños y conteos
```

Para recargar solo comentarios/favoritos/relaciones:

```powershell
docker compose exec -T db psql -U practica_app -d practica `
  -v articles=6000000 -v comments=6000000 -v favorites=6000000 `
  -f /db/seed/11-seed-bulk.sql
```

## 9. Limitaciones

- `Article.body` es texto repetido: la distribución de longitudes no es realista, así que las
  mediciones de `LIKE`/full-text son optimistas en tamaño pero válidas en forma.
- No hay `_UserFollows` cargado (0 filas): el feed de seguidos se probará con datos insertados
  a mano en §5 si hace falta.
- El dataset **no** se versiona en el repo (7,9 GB): se regenera con los scripts.
