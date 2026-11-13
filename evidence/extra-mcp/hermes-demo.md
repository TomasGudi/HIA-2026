# Agente Hermes sobre MCP — evidencia

Fecha: 2026-11-13T16:06:46.5544881-03:00

Cada bloque es la respuesta del agente a una pregunta. Las líneas `Practica · ...`
son las herramientas MCP que ejecutó (el nombre se ve en la salida cruda).

## ¿Está funcionando la plataforma? Decime versión y uptime.

```
☤ Hermes
Sí, la plataforma está operativa.

- Estado: ok- Base de datos: up
- Versión: sha-7f8ed58- Uptime: 355 s (~5 min 55 s)

Dato: el uptime es bajo, así que el backend arrancó hace menos de 6 minutos. Si no hubo un deploy programado, conviene revisar por qué se reinició.
```

- Herramientas usadas: estado plataforma
- Llamadas a herramientas: 8

## ¿Cuánto ocupa la base de datos y qué tabla tiene más filas?

```
☤ Hermes
Datos de estadisticas_bd:

Tamaño total: 8551 MB (~8.3 GB)

Tabla con más filas: Article — 6.000.003 filas estimadas, 6130 MB.

Top por filas:
  Article          6.000.003   6130 MB
  _ArticleToTag    6.000.002    375 MB
  _UserFavorites   6.000.000    473 MB
  Comment          5.999.908   1021 MB
  User               200.003    105 MB
  Tag                  5.004    568 kB
  mv_article_favorites      0    422 MB  (sin analyze)
  _UserFollows              0     16 MB  (sin analyze)
  mv_tag_counts             0    480 kB  (sin analyze)

Dos cosas llaman la atención: el cache hit está en 63,68% (bajo para OLTP) y mv_article_favorites ocupa 422 MB con 0 filas estimadas y nunca analizada — probablemente necesita REFRESH o ANALYZE.
```

- Herramientas usadas: estadisticas bd
- Llamadas a herramientas: 4

## Mostrame el título y el autor del artículo más reciente.

```
☤ Hermes
Artículo más reciente:  Título: Artículo número 365
  Autor:  user366Slug: article-9be40cee5b0eee1462c82c6964087ff9
Creado: 2026-11-13 03:56 UTC
Tag: tag-00366 — 1 favorito
```

- Herramientas usadas: listar articulos
- Llamadas a herramientas: 4
