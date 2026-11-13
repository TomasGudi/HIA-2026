# 12 — Gestión de incidencias (Mantis)

## 1. Objetivo

Registrar, priorizar y resolver los defectos detectados durante el desarrollo y las pruebas, con
trazabilidad hacia el código (§11).

## 2. Herramienta y despliegue

| Aspecto | Decisión | Motivo |
|---|---|---|
| Herramienta | **MantisBT 2.28.4** | el enunciado la nombra explícitamente en §11 y en §13 (flujo 1) |
| Imagen | **propia** (`app/mantis/Dockerfile`) | no existe imagen oficial en Docker Hub; las comunitarias no fijan versión ni tienen mantenimiento verificable (riesgo de cadena de suministro, §14) |
| Fuente | paquete oficial de SourceForge | el tarball de GitHub **no incluye `vendor/`** y el instalador falla con `Failed opening required vendor/autoload.php` |
| Base de datos | PostgreSQL 16, base `mantis` (misma instancia, base separada) | la guía de administración de MantisBT soporta PostgreSQL; evita levantar un MariaDB extra |
| Configuración | generada en el arranque desde variables de entorno | la imagen no contiene credenciales |
| Exposición | `127.0.0.1:8081` | en producción se llega por túnel con auth (§9) |
| `/admin` | **bloqueado** (`403`) por configuración de Apache | es el instalador: dejarlo abierto es un hallazgo de §14 |
| Correo | desactivado (`$g_enable_email_notification = OFF`) | las notificaciones las maneja n8n (§13), no Mantis |
| Adjuntos | volumen `pi-mantis-files` | sin volumen, un `docker compose down` borra la evidencia de §11 |

### Arranque

```powershell
docker compose --profile ops up -d mantis
# http://127.0.0.1:8081  (usuario: administrator)
```

El perfil `ops` evita que Mantis compita por recursos con la aplicación durante la demo.

### Credenciales

Usuario `administrator`; la contraseña está en `.env` como `MANTIS_ADMIN_PASSWORD` (generada,
no versionada). La contraseña por defecto (`root`) se reemplazó en la instalación.

## 3. Incidentes del despliegue (reales, encontrados durante la puesta en marcha)

Estos son incidentes del entorno que quedan documentados como parte del aprendizaje del §11.

| # | Síntoma | Causa | Solución |
|---|---|---|---|
| M1 | `Fatal error: Failed opening required vendor/autoload.php` | el tarball de GitHub es el árbol de fuentes, sin dependencias de Composer | usar el paquete oficial de SourceForge (incluye `vendor/`) |
| M2 | `Undefined constant "LOG_ERROR"` en `config_inc.php` | el archivo de configuración se carga **antes** de que existan las constantes `LOG_*` | no fijar `$g_log_level` en la configuración |
| M3 | `APPLICATION ERROR #2900` | falta `$g_crypto_master_salt` (obligatorio desde 2.26, mínimo 16 caracteres) | se genera desde `.env` (`MANTIS_CRYPTO_SALT`) |
| M4 | Instalador: "Attempting to connect to database as admin → BAD" | en este release, `admin_username`/`admin_password` del formulario son las **credenciales de la base**, no una cuenta de Mantis | enviar el usuario/clave de la base en esos campos |
| M5 | `APPLICATION ERROR #401 — relation "mantis_user_table" does not exist` | esquema no instalado todavía | completar el paso 2 del instalador |

## 4. Configuración de categorías y prioridades

| Categoría | Uso |
|---|---|
| `base de datos` | consultas lentas, índices, réplicas |
| `infraestructura` | Docker, redes, volúmenes, despliegue |
| `aplicación` | defectos funcionales del backend/frontend |
| `seguridad` | hallazgos de §14 |
| `automatización` | flujos de n8n |

Prioridades: `inmediata` (servicio caído), `urgente` (bloquea la demo), `normal`, `baja`.
Severidades: `bloqueante`, `mayor`, `menor`, `trivial`, `ajuste`.

## 5. Vinculación con el código

Mantis no se integra nativamente con GitHub, así que el vínculo se hace explícito en los dos
sentidos:

| Dirección | Mecanismo |
|---|---|
| Incidencia → código | campo personalizado `commit_sha` / `pr_url` en el formulario de la incidencia |
| Código → incidencia | el mensaje de commit referencia la incidencia: `fix(api): valida JWT_SECRET (refs MANTIS-0000012)` |

Esto se declara como **procedimiento manual** en el informe: no se afirma integración automática.

## 6. Estado

| Requisito de §11 | Estado |
|---|---|
| Herramienta funcionando | ✅ 32 tablas, login operativo, `/admin` bloqueado |
| Categorías, prioridades y responsables | ✅ 5 categorías, 3 usuarios con roles distintos |
| ≥10 incidencias (1 de rendimiento, 1 de seguridad) | ✅ 14 incidencias |
| Pasos de reproducción | ✅ en la descripción de cada una |
| ≥5 resueltas con commit/PR | ✅ 13 resueltas + 1 cerrada, con nota de verificación |

## 7. Configuración

| Elemento | Valor |
|---|---|
| Proyecto | `HIA-2026` (id 1) |
| Categorías | Infraestructura, Base de Datos, Seguridad, Rendimiento, Aplicacion |
| Usuarios | `administrator` (90), `dev.tomas` (55, developer), `qa.analista` (25, reporter) |
| Token de API | 32 caracteres, guardado como `sha256` en `mantis_api_token_table` |
| Correo | desactivado: las notificaciones las maneja n8n (§13) |

> Detalle que costó tiempo: Mantis exige que el token mida exactamente `API_TOKEN_LENGTH` = **32**
> caracteres. Un token de 48 devolvía 401 sin explicación; la validación es
> `mb_strlen($token) != 32` antes de tocar la base.

## 8. Las incidencias registradas

14 incidencias del proyecto, todas con categoría, severidad, prioridad, responsable e historial.
Además hay 8 incidencias generadas por las pruebas del flujo 1, cerradas como "no es un defecto".

| # | Categoría | Tipo | Estado | Resumen |
|---|---|---|---|---|
| 1 | Rendimiento | major / urgent | resuelto | `GET /api/articles` tarda 7,9 s con 6M de filas |
| 2 | Rendimiento | major / high | resuelto | Filtro por tag sin índice GIN: 3,5 s |
| 3 | Seguridad | major / high | resuelto | Login permite enumerar usuarios por mensaje de error |
| 4 | Seguridad | crash / urgent | resuelto | Webhook de n8n acepta cualquier POST sin token |
| 5 | Infraestructura | major / high | resuelto | La réplica no acepta lecturas (`hot_standby` apagado) |
| 6 | Infraestructura | minor / normal | resuelto | El contenedor de réplica vuelve a clonar en cada reinicio |
| 7 | Base de Datos | major / high | resuelto | La carga inicial generó 38 GB de WAL |
| 8 | Base de Datos | crash / urgent | resuelto | Backups sin verificación de restauración |
| 9 | Aplicacion | crash / urgent | resuelto | Frontend no compila en Node 20 (CRA 1.1.1 de 2018) |
| 10 | Aplicacion | major / high | resuelto | Contador de artículos hace `COUNT(*)` sobre 6M de filas |
| 11 | Seguridad | major / high | resuelto | Panel `/admin` de Mantis accesible sin restricción |
| 12 | Infraestructura | crash / urgent | cerrado | Puertos del stack publicados en `0.0.0.0` |
| 13 | Rendimiento | minor / normal | resuelto | Alerta de CPU no dispara con `stress-ng` al 79% |
| 14 | Seguridad | crash / urgent | resuelto | Falta de auth en las rutas administrativas publicadas |

Requisito del enunciado: hay **1 de rendimiento** (#1, #2, #10, #13) y **1 de seguridad** (#3, #4,
#11, #14).

## 9. Proceso de gestión

```
nuevo ──▶ asignado ──▶ resuelto ──▶ cerrado
  │                        │
  └── feedback ◀───────────┘
```

1. **Alta**: categoría, severidad, prioridad y descripción reproducible (qué, cómo, resultado
   esperado y obtenido).
2. **Asignación**: `handler_id` a `dev.tomas`. Mantis registra la transición en
   `mantis_bug_history_table` (70 entradas para 14 incidencias).
3. **Resolución**: estado `resolved` + resolución `fixed`, con una nota que incluye el commit o PR
   y la medición que verifica el arreglo.
4. **Cierre**: `closed` cuando la verificación está en la evidencia del informe.

## 10. Campos personalizados

Dos campos a nivel proyecto, para no depender de que el commit esté escrito en la nota:

| Campo | Tipo | Uso |
|---|---|---|
| `commit_sha` | string (40) | SHA del merge que corrigió la incidencia |
| `pr_url` | string (200) | URL del PR con la discusión y el diff |

Se guardan en `mantis_custom_field_string_table` y se ven en el detalle de cada incidencia.

## 11. Evidencia

| Evidencia | Dónde |
|---|---|
| Definición de la imagen | `app/mantis/Dockerfile`, `app/mantis/entrypoint.sh` |
| Servicio y volumen | `compose.yaml` (perfil `ops`) |
| Creación de base y rol | `db/init/04-mantis-db.sh` |
| Instalación del esquema | 32 tablas en `mantis` + usuario `administrator` |
| `/admin` bloqueado | `403` verificado con `curl` |

| Incidencias cargadas | 14 en `HIA-2026` (script `scripts/mantis-seed.py`) |
| Historial de estados | 70 filas en `mantis_bug_history_table` |
| Campos `commit_sha` / `pr_url` | `scripts/mantis-campos.sql` |
| Prueba de la cadena alerta → incidencia | `evidence/13/flujo-1.log` |
