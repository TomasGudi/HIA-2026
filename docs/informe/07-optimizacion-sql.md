# 07 — Informe de optimización SQL

## 1. Método

1. Se identificaron las consultas con `pg_stat_statements` (top por tiempo total) y se
   contrastaron con las operaciones reales del backend (Prisma): cada consulta de este informe
   corresponde a una pantalla del producto, no a un ejemplo inventado.
2. Para cada una se capturó `EXPLAIN (ANALYZE, BUFFERS)` y el tiempo de ejecución con la caché
   caliente (segunda corrida).
3. Se aplicó **un cambio por vez**, midiendo el efecto.
4. Se probó también una optimización que **no** funcionó y se descartó con el número en la mano.

Scripts: `db/queries/10-baseline.sql` (antes) y `db/queries/20-optimizado.sql` (después).
Evidencia cruda: `evidence/05/baseline-1.txt`, `evidence/05/optimizado.txt`, `evidence/05/control.txt`.

## 2. Resultado general

| # | Consulta | Antes | Después | Mejora | Cambio aplicado |
|---|---|---|---|---|---|
| Q1 | count del listado público | 656 ms | **5,9 ms** | 111× | conteo acotado (`LIMIT` interno) |
| Q2 | listado paginado (offset 0) | 5,3 ms | 5,3 ms | — | ya óptimo (índice de `createdAt`) |
| Q2b | paginación profunda (offset 500.000) | 1.933 ms | **62,6 ms** | 31× | keyset pagination |
| Q3 | listado filtrado por etiqueta | 134 ms | 134 ms | — | ya óptimo (nested loop con índices) |
| Q4 | etiquetas populares (top 10) | 1.033 ms | **0,69 ms** | 1.497× | vista materializada |
| Q5 | feed de autores seguidos | 8.331 ms | **1,2 ms** | 6.942× | reescritura `IN (subconsulta)` |
| Q6 | detalle + comentarios | 7,5 ms | 7,5 ms | — | ya óptimo (índices únicos) |
| Q7 | top de artículos por favoritos | 3.565 ms | **1,4 ms** | 2.546× | vista materializada |
| Q8 | búsqueda por título (`ILIKE '%…%'`) | 5.292 ms | **3,5 ms** | 1.512× | `pg_trgm` + índice GIN |

**Efecto medido en el producto**: `GET /api/articles` pasó de **7,9 s a 0,19 s** (41×).

## 3. Análisis consulta por consulta

### Q1 — count del listado (656 ms → 5,9 ms)

Plan inicial: `Parallel Hash Join` + `Parallel Index Only Scan` sobre `Article_authorId_idx`
(2.000.000 filas × 3 workers). El join no es el problema: **contar 6M de filas es O(n)** y ningún
índice lo evita.

Decisión: acotar el conteo a 10.000 (la interfaz solo necesita la cantidad de páginas). El plan
corta al alcanzar el tope y baja a 5,9 ms.

> Hallazgo mayor: la consulta que **genera Prisma** para este mismo caso tarda **17,8 s** de
> promedio (5 llamadas en `pg_stat_statements`), contra 656 ms del SQL equivalente escrito a mano.
> El ORM arma una subconsulta con `IN (SELECT … FROM "User" WHERE demo)` que el planificador
> resuelve mal. Se reemplazó por SQL directo en `article.service.ts` (ver §5 del informe de
> configuración Docker).

### Q2 — listado paginado (5,3 ms, sin cambios)

Usa `Article_createdAt_idx` y corta en 10 filas. **No se tocó**: no hay nada que optimizar y
agregar un índice acá solo costaría escrituras.

### Q2b — paginación profunda (1.933 ms → 62,6 ms)

Con `OFFSET 500000` PostgreSQL lee y descarta medio millón de filas. Se reemplazó por
**keyset pagination**: `WHERE (createdAt, id) < (último de la página anterior)`.

Trade-off honesto: keyset no permite "saltar a la página 50" directamente; sirve para scroll
infinito o "siguiente/anterior", que es el patrón real de un listado.

### Q3 — filtro por etiqueta (134 ms, sin cambios)

El plan ya es bueno: `Bitmap Index Scan` sobre `_ArticleToTag_B_idx` → `Index Scan` sobre
`Article_pkey` → `Index Scan` sobre `User_pkey`, 1.200 filas y 9,5 ms de ejecución. Los 134 ms
incluyen planificación y JIT de la primera ejecución. **Se deja como está** y se documenta: es el
caso que demuestra que no todo se optimiza agregando índices.

### Q4 — etiquetas populares (1.033 ms → 0,69 ms)

`GROUP BY` sobre 6M de filas de `_ArticleToTag` en cada request. Se materializó el agregado:

```sql
CREATE MATERIALIZED VIEW mv_tag_counts AS
SELECT t.id, t.name, count(*) AS n
FROM "_ArticleToTag" at JOIN "Tag" t ON t.id = at."B"
GROUP BY t.id, t.name;
```

Trade-off: el dato puede tener atraso. El refresco se delega a n8n (§13), que es exactamente el
tipo de tarea operativa que pide el enunciado.

### Q5 — feed de autores seguidos (8.331 ms → 1,2 ms)

El `JOIN "_UserFollows"` hacía que el planificador estimara mal y terminara escaneando artículos.
Reescritura:

```sql
SELECT … FROM "Article" a
WHERE a."authorId" IN (SELECT "B" FROM "_UserFollows" WHERE "A" = 42)
ORDER BY a."createdAt" DESC LIMIT 10;
```

Plan nuevo: `Nested Loop` con `Index Only Scan` sobre `_UserFollows_AB_unique` y `Index Scan`
sobre `Article_authorId_idx`. **0,109 ms de ejecución.**

### Q6 — detalle + comentarios (7,5 ms, sin cambios)

`slug` es UNIQUE (índice), `Comment.articleId` está indexado y el subquery de conteo usa ese
índice. Óptimo de entrada.

### Q7 — top de artículos por favoritos (3.565 ms → 1,4 ms)

Mismo patrón que Q4: agregado sobre 6M. Vista materializada `mv_article_favorites` con índice
único y otro por `favs DESC`.

### Q8 — búsqueda por título (5.292 ms → 3,5 ms)

`ILIKE '%texto%'` **no es SARGable**: ningún B-tree puede resolver una subcadena con comodín
inicial. Control ejecutado con `enable_indexscan=off`: 5.074 ms (seq scan de 6M).

Solución: `pg_trgm` + índice GIN. Plan nuevo: `Bitmap Index Scan on Article_title_trgm_idx`,
**0,55 ms de ejecución**.

## 4. Índices y objetos creados: justificación y costo

| Objeto | Consulta que sirve | Tamaño | Costo de creación medido |
|---|---|---|---|
| `mv_tag_counts` (+2 índices) | Q4 | 480 kB + 184 kB | 0,64 s |
| `mv_article_favorites` (+2 índices) | Q7 | 422 MB + 169 MB | 5,8 s + 8,2 s |
| `Article_title_trgm_idx` (GIN) | Q8 | 198 MB | **28,8 s** |

**Impacto total**: la base pasó de 7.874 MB a **8.551 MB (+677 MB, +8,6 %)**.

Ese número es el argumento central contra "crear índices por las dudas": cada índice se paga en
disco y en tiempo de escritura. La vista de favoritos es la más cara (591 MB con índices) y se
justifica solo porque el top de favoritos se muestra en la home.

### Optimización descartada (control negativo)

Se probó un índice parcial en `User(demo)`:

| Escenario | count sin tope |
|---|---|
| con `User_demo_partial_idx` | 478 ms |
| sin el índice | 568 ms |

Diferencia dentro del ruido, y el filtro **no es selectivo** (200.000 de 200.000 usuarios tienen
`demo = true`). Se **eliminó el índice** y se documenta el intento: un índice que no mejora nada
es deuda.

## 5. Parámetros del motor

| Parámetro | Valor | Motivo |
|---|---|---|
| `shared_buffers` | 1 GB | base de 8,5 GB: ~12 %, dentro de lo recomendado |
| `effective_cache_size` | 3 GB | estimación para el planificador |
| `work_mem` | 16 MB | los `GROUP BY` grandes se materializaron, ya no necesitan más |
| `max_wal_size` | 8 GB | la carga masiva generaba 38 GB de WAL con el default (D-20) |
| `checkpoint_timeout` | 15 min | ídem |
| `log_min_duration_statement` | 200 ms | alimenta pgBadger (§4) |

## 6. Limitaciones

- **El conteo acotado cambia semántica**: `articlesCount` tope 10.000 (1.000 páginas de 10). Es una
  decisión de producto, no un techo técnico; se documenta para que no sorprenda.
- Las vistas materializadas tienen **atraso** hasta el próximo refresco. Se refrescan por cron
  (n8n) y se documenta el intervalo.
- Las optimizaciones de Q2b, Q4 y Q7 están implementadas en SQL; la API todavía usa `OFFSET` y
  consultas directas. La integración de keyset pagination y de las vistas en el backend queda como
  mejora pendiente (no afecta la demo: el listado ya bajó a 0,19 s por el cambio de Q1).
- Las mediciones son con caché caliente; en frío los números son peores para todas las variantes.

## 7. Evidencia

| Evidencia | Archivo |
|---|---|
| Baseline (8 consultas + planes) | `evidence/05/baseline-1.txt` |
| Después (optimizaciones + planes) | `evidence/05/optimizado.txt` |
| Control negativo (índice descartado, Q8 sin índice) | `evidence/05/control.txt` |
| Consultas usadas | `db/queries/10-baseline.sql`, `db/queries/20-optimizado.sql` |
| Consultas más costosas del motor | `pg_stat_statements` (top 8 por tiempo total) |
