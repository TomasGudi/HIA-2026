# 12 — Gestión documental con Nextcloud

## 1. Objetivo

Centralizar la documentación del proyecto en una herramienta de gestión documental, con estructura
por sección, permisos por grupo y una prueba de que un usuario no autorizado no accede.

Nextcloud 30 corre contenerizado, con base propia en PostgreSQL y volumen propio. Es el único
servicio del stack con login propio expuesto a Internet sin Basic auth del borde: el túnel va
directo al contenedor para no romper WebDAV.

## 2. Despliegue

| Elemento | Decisión |
|---|---|
| Imagen | `nextcloud:30-apache` |
| Base | PostgreSQL, base `nextcloud` y rol `nextcloud` (separados de la app, Mantis y n8n) |
| Volumen | `pi-nextcloud-data` montado en `/var/www/html` |
| Red | `dbnet` (habla con `db`, no con el frontend) |
| Puerto local | `127.0.0.1:8082` |
| Acceso público | túnel `pi-tunnel-nextcloud` → `http://nextcloud:80` (HTTPS en Cloudflare) |
| Dominios confiables | `localhost 127.0.0.1 nextcloud *.trycloudflare.com` |
| Proxy | `TRUSTED_PROXIES=172.16.0.0/12` para que respete `X-Forwarded-Proto` |

```powershell
docker compose --profile ops up -d nextcloud
./scripts/nextcloud.ps1 init        # grupos, usuarios y carpeta de grupo
./scripts/nextcloud.ps1 structure   # 17 carpetas + 18 archivos
./scripts/nextcloud.ps1 status
```

La base se crea con `db/init/09-nextcloud-db.sh` en un volumen nuevo, o a mano en uno existente:

```powershell
docker compose exec -T -e NEXTCLOUD_DB_PASSWORD=... db bash /docker-entrypoint-initdb.d/09-nextcloud-db.sh
```

## 3. Estructura documental

Una **carpeta de grupo** (`groupfolders`) llamada `HIA-2026`, con 17 carpetas:

```
HIA-2026/
├── 00-informe-consolidado/     ← PDF de 59 páginas + markdown consolidado
├── 01-descripcion-app/         ├── 09-cicd/
├── 02-arquitectura/            ├── 10-publicacion/
├── 03-inventario-tecnologico/  ├── 11-monitoreo/
├── 04-manual-instalacion/      ├── 12-incidencias/
├── 05-configuracion-docker/    ├── 13-automatizacion/
├── 06-migracion-carga/         ├── 14-seguridad/
├── 07-optimizacion-sql/        ├── 15-backup/
└── 08-replicacion/             └── 16-limitaciones/
```

La numeración coincide con el enunciado y con `docs/informe/`, así que la defensa puede ir
documento por documento sin buscar.

## 4. Matriz de permisos

| Usuario | Grupo | Carpeta | Leer | Escribir | Borrar | Compartir |
|---|---|---|---|---|---|---|
| `admin` | `admin`, `equipo` | `HIA-2026` | ✅ | ✅ | ✅ | ✅ |
| `r1` … `r5` | `equipo` | `HIA-2026` | ✅ | ✅ | ✅ | ✅ |
| `auditor` | `lectores` | `HIA-2026` | ✅ | ❌ | ❌ | ❌ |
| `invitado` | — (sin grupo) | `HIA-2026` | ❌ (no la ve) | ❌ | ❌ | ❌ |

Los permisos se aplican con la app `groupfolders`, no compartiendo carpeta por carpeta:

```powershell
occ groupfolders:group 1 equipo read write delete share
occ groupfolders:group 1 lectores read
```

`write` incluye crear (`PERMISSION_UPDATE | PERMISSION_CREATE`), por eso no hace falta un permiso
`create` aparte.

### Verificación (evidencia `evidence/12/permisos.log`)

| Prueba | Resultado |
|---|---|
| `r1` lista la carpeta | **207** Multi-Status |
| `r1` sube un archivo | **201** Created |
| `r1` borra su archivo | **204** No Content |
| `auditor` lista la carpeta | **207** Multi-Status |
| `auditor` intenta subir | **403** Forbidden |
| `invitado` intenta listar | **404** Not Found (la carpeta no existe para él) |

La prueba se hizo con WebDAV y las credenciales de cada usuario, no con la UI: es el mismo camino
que usa el cliente de escritorio, así que verifica el permiso real.

## 5. Centralización y versionado

| Qué | Dónde | Cómo se actualiza |
|---|---|---|
| 16 documentos | `HIA-2026/01..16/<documento>.md` | `./scripts/nextcloud.ps1 structure` (idempotente: `PUT` sobrescribe) |
| Informe consolidado | `HIA-2026/00-informe-consolidado/HIA-2026-informe-final.pdf` | `python scripts/informe.py` y volver a subir |
| Versión congelada | tag `v1.0.0` en GitHub | el PDF y los `.md` de ese tag son los de la defensa |

La fuente de verdad sigue siendo el repositorio (historial Git); Nextcloud es la vista compartida
para quien no usa Git. Los 18 archivos subidos son exactamente los de `docs/informe/` más el PDF:
no hay copias divergentes.

## 6. Integración con n8n (flujo 3)

El flujo 3 del enunciado sube un informe periódico a Nextcloud. La pieza que lo habilita es que
Nextcloud hable WebDAV con Basic auth, y el contenedor `n8n` esté en `dbnet`:

```
Cron (semanal) → Prometheus (consulta) → Code (resumen markdown)
      → PUT https://<tunel>/remote.php/dav/files/admin/HIA-2026/00-informe-consolidado/informe-semanal.md
```

Estado: ver `docs/informe/13-automatizacion.md` (flujo 3). Si el flujo no está activo, la carga se
hace con `scripts/nextcloud.ps1 structure`.

## 7. Operación

| Tarea | Comando |
|---|---|
| Ver estado | `./scripts/nextcloud.ps1 status` |
| Consola de Nextcloud | `docker compose exec -u www-data nextcloud php occ <comando>` |
| Actualizar apps | `occ app:update --all` |
| Modo mantenimiento | `occ maintenance:mode --on` / `--off` |
| Escanear archivos | `occ files:scan --all` |
| Logs | `docker compose logs nextcloud` |

## 8. Limitaciones

| Limitación | Motivo | Riesgo aceptado |
|---|---|---|
| Almacenamiento en el mismo host | un solo equipo | se pierde con el host; el repo tiene la copia versionada |
| Sin cifrado de servidor | Nextcloud cifra en tránsito por TLS, no en reposo | disco del host sin cifrar |
| Sin LDAP/SSO | alcance académico | usuarios locales con contraseña propia |
| URL efímera | *quick tunnel* | cambia al reiniciar; se republica antes de la demo |
| Sin cuotas por usuario | volumen único | la carpeta de grupo es de 2,6 MB |
| Sin backup propio de Nextcloud | el backup actual cubre PostgreSQL, no el volumen | los documentos están en Git |

## 9. Evidencia

| Evidencia | Archivo |
|---|---|
| Estado, usuarios, grupos y permisos | `evidence/12/nextcloud-status.log` |
| Matriz de permisos probada por WebDAV | `evidence/12/permisos.log` |
| Provisión reproducible | `scripts/nextcloud.ps1` |
| Creación de la base | `db/init/09-nextcloud-db.sh` |
| Servicio en el stack | `compose.yaml` (`nextcloud`, perfil `ops`) |

## 10. Preguntas frecuentes

**¿Por qué Nextcloud y no una carpeta compartida?**
Porque el enunciado pide gestión documental con permisos y trazabilidad. Una carpeta de red no
tiene control de acceso por grupo ni historial de versiones.

**¿Por qué el túnel no pasa por el borde con Basic auth?**
Porque WebDAV y los clientes de escritorio no negocian Basic auth del proxy además del login. El
borde se usa para herramientas administrativas sin login propio fuerte; Nextcloud ya tiene login,
2FA opcional y bloqueo por intentos.

**¿Qué pasa si se cae Nextcloud?**
La aplicación y el monitoreo siguen. Solo se pierde el acceso a la documentación compartida; el
repo y el PDF local siguen disponibles.
