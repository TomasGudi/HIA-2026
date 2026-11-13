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
| Categorías, prioridades y responsables | ◐ categorías definidas; falta cargarlas en la instancia |
| ≥10 incidencias registradas (1 de rendimiento, 1 de seguridad) | ⬜ (hay 5 candidatas ya identificadas: M1–M5, H1 de JWT y el incidente de FK) |
| Pasos de reproducción | ⬜ |
| Vínculo con tareas y commits | ◐ procedimiento definido (campo + `refs`) |
| Solución registrada y cierre con evidencia | ⬜ |

## 7. Evidencia

| Evidencia | Dónde |
|---|---|
| Definición de la imagen | `app/mantis/Dockerfile`, `app/mantis/entrypoint.sh` |
| Servicio y volumen | `compose.yaml` (perfil `ops`) |
| Creación de base y rol | `db/init/04-mantis-db.sh` |
| Instalación del esquema | 32 tablas en `mantis` + usuario `administrator` |
| `/admin` bloqueado | `403` verificado con `curl` |
