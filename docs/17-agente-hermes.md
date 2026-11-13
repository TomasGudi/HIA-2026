# 17 — Agente Hermes sobre MCP (extra)

> Este anexo **no** es uno de los 16 documentos obligatorios: documenta el extra
> que se agregó después del cierre del informe. El servidor MCP es parte de la
> aplicación; el agente Hermes es una herramienta de operación y se levanta aparte.

## 1. Qué se agregó

Dos piezas:

| Pieza | Dónde vive | Qué hace |
|---|---|---|
| **Servidor MCP** | `app/mcp/` (servicio `mcp` del compose) | Expone la plataforma como 5 herramientas MCP sobre HTTP |
| **Agente Hermes** | `automation/hermes/` (compose propio) | Contenedor con Hermes Agent que consume esas herramientas y responde en lenguaje natural |

La separación es deliberada: el MCP es código de la aplicación (se construye, se
testea y se despliega con ella); el agente es un cliente que se puede apagar sin
afectar al sistema.

## 2. Arquitectura

```
                 ┌──────────────────────────────┐
   pregunta  ──▶ │  Hermes Agent (pi-hermes)    │
                 │  gateway + dashboard :9119   │
                 └──────────────┬───────────────┘
                                │ MCP sobre HTTP
                                │ Authorization: Bearer <MCP_TOKEN>
                 ┌──────────────▼───────────────┐
                 │  Servidor MCP (pi-mcp)       │
                 │  /mcp   /health   :8080      │
                 └───────┬──────────────┬───────┘
                         │ HTTP         │ SQL (rol `monitor`)
                 ┌───────▼──────┐  ┌────▼─────────┐
                 │  backend     │  │  PostgreSQL  │
                 │  /api/*      │  │  (solo lectura)
                 └──────────────┘  └──────────────┘
```

El MCP no habla con la base para leer contenido: usa la misma API que el
frontend, así respeta validaciones y permisos. La base se consulta solo para
métricas, con el rol `monitor` (miembro de `pg_monitor`), que **no puede leer
datos de las tablas**.

## 3. Herramientas

| Herramienta | Devuelve | Fuente |
|---|---|---|
| `estado_plataforma` | estado, base, versión y uptime | `GET /health` |
| `listar_articulos` | página de artículos con filtro por tag/autor | `GET /api/articles` |
| `obtener_articulo` | artículo completo por slug | `GET /api/articles/:slug` |
| `listar_tags` | tags que expone la API | `GET /api/tags` |
| `estadisticas_bd` | tamaño, filas estimadas, índices, conexiones, cache hit | `pg_stat_*` |
| `crear_articulo` | publica un artículo | `POST /api/articles` |

`crear_articulo` **no existe** salvo que se levante con `MCP_ALLOW_WRITE=true` y
credenciales dedicadas: si la herramienta no está registrada, el modelo no puede
intentarla. El valor por defecto es solo lectura.

## 4. Seguridad

| Control | Implementación |
|---|---|
| Autenticación | `Authorization: Bearer` con comparación en tiempo constante; sin token el proceso **no arranca** |
| Fallo cerrado | `MCP_TOKEN` ausente o corto ⇒ error al iniciar, nunca modo abierto |
| Privilegio mínimo | rol `monitor` para métricas; la app usa el rol `app` (§14) |
| Sin escritura por defecto | `MCP_ALLOW_WRITE=false` |
| Sin root | `USER node` en la imagen (`docker inspect` ⇒ `User=node`) |
| Exposición | `127.0.0.1:8098` en el host; dentro de Docker solo `appnet` y `dbnet` |
| Superficie del agente | dashboard y API en `127.0.0.1`, con Basic auth |

El token viaja por variable de entorno y **no** está en el repo: `config.yaml`
usa `${MCP_TOKEN}` y gitleaks corre en CI (§14).

## 5. Cómo levantarlo

```powershell
# 1) servidor MCP (parte de la aplicación)
docker compose up -d mcp

# 2) agente
docker compose -f automation/hermes/compose.yaml --env-file .env up -d

# 3) preguntar
docker exec pi-hermes hermes chat -q "¿Está funcionando la plataforma?"
```

Dashboard: <http://127.0.0.1:9119> (usuario y contraseña de `HERMES_DASHBOARD_*`).

## 6. Pruebas

| Prueba | Qué verifica | Evidencia |
|---|---|---|
| `app/mcp/test/unit.mjs` | contrato: auth, 5 herramientas, forma de las respuestas | corre en CI (job `mcp`) |
| `app/mcp/test/smoke.mjs` | contra el stack real, incluida la base | `evidence/extra-mcp/smoke-mcp.log` |
| `scripts/hermes-demo.ps1` | el agente resuelve 3 preguntas usando herramientas | `evidence/extra-mcp/hermes-demo.md` |

Resultado de la prueba de humo: 9/9 (`OK: 0 fallo(s)`), incluidos los dos
rechazos por token.

## 7. Hallazgos que produjo el agente

El valor del ejercicio no fue "el agente responde": fue lo que encontró al
consultar datos reales.

1. **Estadísticas de PostgreSQL nunca analizadas.** `pg_stat_user_tables` daba
   `n_live_tup = 0` en `Article` (6 M de filas) y `last_analyze` vacío: el
   planificador venía estimando con valores por defecto. Se corrió `ANALYZE`
   sobre las 6 tablas principales (7 s) y las estimaciones pasaron a ser reales.
   Efecto medible: `GET /api/tags` bajó de 6,2 s a 4,4 s.
2. **La API topea los conteos en 10.000** (`COUNT_CAP` en
   `article.service.ts`). El agente lo detectó al comparar el total con el de
   la base y lo reportó como límite, no como dato.
3. **`listar_tags` devuelve solo los tags del usuario demo** (10), aunque los
   artículos referencien cientos. Es el comportamiento de la API, no del MCP.
4. **Paginación profunda inviable**: `offset=1190` supera los 30 s y el borde
   devuelve 504. El MCP lo advierte en la descripción de la herramienta para que
   el agente filtre por tag o autor en lugar de paginar.
5. **Vistas materializadas sin refrescar**: `mv_article_favorites` ocupa 422 MB
   con 0 filas estimadas y sin `ANALYZE`.

## 8. Limitaciones

| Limitación | Motivo |
|---|---|
| El agente depende de una API externa para el modelo | se reusó el proveedor de `automatizacion/agente-hermes`; el agente corre local, la inferencia no |
| Sin streaming SSE en `/mcp` | modo sin sesión con respuesta JSON; alcanza para herramientas de request/response |
| Sin caché de tags | `GET /api/tags` tarda ~4 s; se prefirió no esconder latencia real |
| El agente no ejecuta comandos ni toca archivos | su alcance es la plataforma, por diseño (SOUL.md) |
| Sin cuota por usuario en el MCP | un solo cliente interno autenticado; el rate limit de nginx cubre la API pública |
