# Selección de la aplicación base

> Decisión: **reutilizar una aplicación de ejemplo open source** (elegido por el equipo).
> Este documento compara candidatas, define los criterios y deja el plan de datos.
> Decisión final registrada en `05-decisiones.md` (D-02).

## 1. Criterios de selección

| # | Criterio | Por qué pesa |
|---|---|---|
| C1 | Backend + frontend + DB **separados** | §7 exige un contenedor para cada uno |
| C2 | Motor **PostgreSQL o MySQL/MariaDB** | §4/§5/§6 (replicación y EXPLAIN) |
| C3 | Esquema con **al menos 3 tablas aptas para volumen** | §4 pide 6M por tabla; no se puede inflar un catálogo de 20 filas |
| C4 | Migraciones / esquema versionado en SQL | §4 entregable "esquema de la base de datos" |
| C5 | `docker-compose` o Dockerfile ya existentes, o triviales de escribir | §7 y §4 en 5 días |
| C6 | Licencia permisiva (MIT/Apache) | §3 repositorio público |
| C7 | Suite de tests mínima | §8 CI necesita algo que correr |
| C8 | Dominio entendible en la defensa | §15 nota individual |

## 2. Candidatas

| Candidata | Stack | A favor | En contra |
|---|---|---|---|
| **A. RealWorld "Conduit"** (implementación Node/Express + React) | Express, React, Postgres, Sequelize/Prisma | Esquema natural para volumen (`comments`, `favorites`, `article_tags`); API REST clara; mucha documentación; MIT; frontend SPA separado | Hay muchas implementaciones distintas: elegir una con soporte Postgres real y migraciones |
| **B. Spring PetClinic** | Spring Boot, Thymeleaf, Postgres/MySQL | Proyecto "institucional", muy conocido; perfiles de DB ya provistos; tests incluidos; Apache-2.0 | Frontend server-side (no es servicio aparte → §7 queda flojo); build Java más lento en CI; esquema muy chico |
| **C. CMS headless (Strapi/Directus)** | Node + Postgres | Compose oficial, rápido de levantar | Es un producto, no una app: §1 y §2 (funcionalidades propias) quedan vacíos; poco que optimizar a mano |
| **D. Gestión de turnos / expedientes propia** | Node + React | Control total | Descartada: el equipo eligió no construir |

## 3. Recomendación

**A. Conduit (RealWorld)**, porque:
- Cumple C1–C3 sin forzar nada: `articles` ↔ `comments` ↔ `favorites` ↔ `tags` ↔ `users`.
- El frontend React consume `/api` → separar contenedores es natural y demuestra comunicación real (§7).
- El dominio se explica en 2 minutos en la defensa (un blog tipo Medium), y **todas** las 8 consultas
  de §5 salen del producto real (feed, listado por tag, conteo de favoritos, tags populares, búsqueda).

**Plan B**: PetClinic si al clonar Conduit aparece fricción con Postgres o con migraciones.
El cambio debe decidirse **el jueves**, no el domingo.

## 4. Verificación obligatoria antes de comprometerse (30 min)

Antes de escribir una línea de docs, sobre el repo elegido:

1. `docker compose up` levanta DB + backend + frontend sin editar código.
2. El backend **usa Postgres**, no SQLite embebido (buscar `dialect`/`DATABASE_URL`).
3. Tiene migraciones o al menos un `.sql` de esquema.
4. Tiene al menos un test que corre local (`npm test`).
5. Licencia presente en el repo original.
6. El frontend toma la URL del backend por variable de entorno (no `localhost` hardcodeado → rompe en Docker).

Si falla el punto 2 o el 6, cambiar de implementación **el mismo día**.

## 5. Estrategia de datos (el punto más riesgoso)

El enunciado dice "al menos 6.000.000 registros **por tabla**". Interpretación adoptada
(**a confirmar con la cátedra**): las **tablas de volumen del dominio**, no los catálogos.

| Tabla | Registros objetivo | Justificación |
|---|---|---|
| `comments` | 6.000.000 | Entidad transaccional del dominio |
| `favorites` | 6.000.000 | Relación N:M con volumen |
| `articles` | 6.000.000 | Entidad principal |
| `users` | 200.000 | Catálogo con cardinalidad realista |
| `tags` | 5.000 | Catálogo |

### Cómo cargar 18M de filas sin morir

```sql
-- 1) Cargar SIN índices secundarios ni FKs diferibles
ALTER TABLE comments DROP CONSTRAINT ...;  -- o crear tablas sin índices
-- 2) INSERT ... SELECT con generate_series (más rápido que un script en Python)
INSERT INTO articles (id, author_id, title, body, created_at)
SELECT g,
       (random()*199999+1)::int,
       'Article ' || g,
       repeat('lorem ipsum ', 20),
       now() - (random()*365)::int * interval '1 day'
FROM generate_series(1, 6000000) g;
-- 3) Recrear índices al final (mucho más rápido que mantenerlos durante la carga)
-- 4) ANALYZE y medir tamaño
```

- `maintenance_work_mem` alto durante la carga; tablas `UNLOGGED` si el tiempo aprieta
  (y documentar que se reloguean después).
- Medir y archivar: tiempo por tabla, `pg_size_pretty(pg_database_size())`, `count(*)`.
- **Esto también es material de §5**: el antes/después de "índice presente durante la carga vs creado al final" es una medición real y citable.

### Presupuesto de disco estimado

| Concepto | Estimado |
|---|---|
| `articles` (6M, body ~200 B) | ~2,5 GB |
| `comments` (6M) | ~1,5 GB |
| `favorites` (6M, tabla angosta) | ~400 MB |
| Índices (≈ 60% de las tablas) | ~2,5 GB |
| WAL de la carga | ~3 GB (transitorio) |
| **Total con réplica** | **~20 GB** |

Necesitás **~25 GB libres**. Si no los hay, bajar a 6M en una sola tabla y 2M en las otras,
y documentar el recorte como limitación conocida (§15.16).
