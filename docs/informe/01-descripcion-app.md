# 01 — Descripción de la aplicación

## 1. Qué es

**Conduit** es una aplicación web de publicación de artículos (blog social tipo Medium) que
implementa el contrato de API **RealWorld**: usuarios, artículos, etiquetas, comentarios,
favoritos y seguimiento entre usuarios. Es el caso de estudio que la comunidad RealWorld usa
para comparar implementaciones de stacks completos.

El proyecto del integrador **reutiliza el backend** de referencia
(`node-express-realworld-example-app`, MIT) y **reescribe la capa de presentación** con Vite +
React 18 (ver `docs/05-decisiones.md` D-18). El dominio, el esquema relacional y el contrato de
API son los de la aplicación existente.

## 2. Usuarios y permisos

| Rol | Puede | No puede |
|---|---|---|
| **Visitante** (sin sesión) | Ver listado de artículos, filtrar por etiqueta, leer un artículo y sus comentarios | Publicar, comentar, favoritear |
| **Usuario registrado** | Todo lo anterior + publicar artículos, comentar, marcar favoritos, editar su perfil | Editar o borrar artículos de otros |
| **Administrador de infraestructura** | Acceder a pgAdmin, Grafana, n8n y Mantis **por túnel** | Acceder desde Internet sin autenticación |

## 3. Funcionalidades

| # | Funcionalidad | Origen | Estado |
|---|---|---|---|
| F1 | Registro e inicio de sesión con JWT | heredada (backend) | operativa |
| F2 | Listado paginado de artículos | heredada | operativa |
| F3 | Filtro por etiqueta | heredada | operativa |
| F4 | Detalle de artículo con comentarios | heredada | operativa |
| F5 | Publicación de artículos con etiquetas | heredada | operativa |
| F6 | Comentarios sobre artículos | heredada | operativa |
| F7 | Favoritos por usuario | heredada (API) | API operativa; botón en UI: pendiente |
| F8 | Perfil de usuario y seguimiento | heredada (API) | API operativa; pantalla: pendiente |
| F9 | Feed de autores seguidos | heredada (API) | API operativa; pantalla: pendiente |
| F10 | Interfaz SPA con rutas y proxy `/api` | **reescrita** | operativa |
| F11 | Endpoint `/healthz` para monitoreo | **agregada** | operativa |
| F12 | Dataset sintético de 6M por tabla de volumen | **agregada** | operativa |

Las funcionalidades F7–F9 existen en la API y son parte del contrato, pero la interfaz de
demostración prioriza los flujos que se muestran en la defensa. Se declaran como alcance parcial
en `docs/informe/16-limitaciones.md` en lugar de figurar como terminadas.

## 4. Alcance del integrador

| Se modifica | Se agrega |
|---|---|
| Conexión a PostgreSQL por variables de entorno | Contenerización completa (DB, backend, frontend) |
| Validación obligatoria de `JWT_SECRET` | Réplica streaming + failover manual |
| Capa de presentación (reescrita) | Dataset masivo + 8 consultas optimizadas |
| — | CI/CD, monitoreo, backups, incidencias, n8n, seguridad |

## 5. Diagnóstico técnico inicial y plan de mejoras

Hallazgos sobre el estado recibido (antes de intervenir), con su tratamiento.

| # | Hallazgo | Categoría | Impacto | Mejora aplicada | Sección |
|---|---|---|---|---|---|
| H1 | `JWT_SECRET` con fallback `'superSecret'`: si la variable falta, la API firma tokens con una clave pública conocida | Seguridad | **Crítico** | `getJwtSecret()` con fail-fast; sin fallback | §14 |
| H2 | El frontend hardcodea `https://conduit.productionready.io/api` | Configuración | Alto | URL por variable de entorno + proxy de nginx | §7 |
| H3 | Frontend con `react-scripts 1.1.1` (2018), sin lockfile: build no reproducible | Mantenibilidad | Alto | Reescritura con Vite 5 + lockfile | §7/§8 |
| H4 | El upstream no trae Dockerfile ni compose utilizable | Despliegue | Alto | Imágenes multi-stage + compose | §4/§7 |
| H5 | Sin réplica, sin backups, sin procedimiento de recuperación | Disponibilidad | Alto | Réplica streaming + backup verificado | §6/§15 |
| H6 | Sin observabilidad: no hay `/metrics` ni logs estructurados | Operación | Alto | Prometheus + exporters + dashboards | §10 |
| H7 | Índices solo los implícitos del ORM; ninguna estrategia de consultas | Rendimiento | Medio | 8 consultas medidas antes/después | §5 |
| H8 | Esquema sin migraciones versionadas (depende de `db push`) | Mantenibilidad | Medio | `db/init/*.sql` versionado en el repo | §4 |
| H9 | Sin tests de integración contra una base real | Calidad | Medio | Suite de humo + CI con DB de servicio | §8 |
| H10 | Credenciales en variables de entorno sin rotación documentada | Seguridad | Medio | `.env` fuera del repo + rotación + gitleaks | §3/§14 |
| H11 | Sin límites de recursos ni healthchecks en contenedores | Operación | Bajo | `healthcheck` y límites por servicio | §4/§10 |
| H12 | `log_connections=off`: sin rastro de accesos a la base | Auditoría | Bajo | Se documenta como decisión consciente de rendimiento | §14 |

## 6. Evidencia

| Evidencia | Archivo |
|---|---|
| Procedencia y commit del código heredado | `app/UPSTREAM.txt` |
| Inventario de versiones | `docs/informe/03-inventario-tecnologico.md` |
| Diagrama de arquitectura | `docs/02-arquitectura.md` |
| Decisiones sobre el frontend | `docs/05-decisiones.md` D-18 |
