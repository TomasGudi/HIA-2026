# 04 — Manual de instalación

## 1. Objetivo

Levantar el stack completo desde cero en una máquina Windows con Docker Desktop, sin pasos
implícitos. Todo lo que sigue está probado en el equipo de la práctica; los tiempos son los
medidos, no estimaciones.

## 2. Requisitos

| Componente | Versión mínima | Verificación |
|---|---|---|
| Windows | 11 (probado) | `winver` |
| Docker Desktop | 4.30+ con WSL 2 | `docker version` |
| PowerShell | 5.1 (probado) o 7.x | `$PSVersionTable` |
| Git | cualquiera reciente | `git --version` |
| Espacio en disco | **40 GB libres** | 8,5 GB de base + imágenes + backups |
| RAM | 8 GB (16 GB recomendado) | Docker Desktop → Resources |
| Python | 3.11+ (solo scripts auxiliares) | `python --version` |

Recursos asignados a Docker Desktop usados en las pruebas: **6 CPU, 8 GB de RAM, 60 GB de disco**.
Con menos de 4 GB de RAM la carga del dataset puede quedar sin memoria.

## 3. Instalación paso a paso

### Paso 1 — Clonar y entrar al repositorio

```powershell
git clone https://github.com/TomasGudi/HIA-2026.git
cd HIA-2026
git checkout main
```

### Paso 2 — Crear el `.env`

```powershell
Copy-Item .env.example .env
```

Editar `.env` y **cambiar todas** las contraseñas. Las que no son opcionales:

| Variable | Para qué | Regla |
|---|---|---|
| `POSTGRES_PASSWORD` | usuario administrador de la base | ≥ 16 caracteres |
| `APP_DB_PASSWORD` | rol `app` de la aplicación (solo DML) | ≥ 16 caracteres |
| `REPL_PASSWORD` | replicación | ≥ 16 caracteres |
| `JWT_SECRET` | firma de sesiones | **≥ 32 caracteres** |
| `MANTIS_CRYPTO_SALT` | cifrado interno de Mantis | ≥ 32 caracteres |
| `MANTIS_API_TOKEN` | token de la API de Mantis | **exactamente 32 caracteres** |
| `N8N_WEBHOOK_TOKEN` | autenticación del webhook | ≥ 32 caracteres |
| `EDGE_ADMIN_PASSWORD` | Basic auth del borde administrativo | ≥ 16 caracteres |

Generar valores aleatorios:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(24))"
```

> `MANTIS_API_TOKEN` es la única con longitud fija: Mantis rechaza tokens que no tengan 32
> caracteres. Si se cambia, hay que regenerarlo también en la UI de Mantis.

### Paso 3 — Base de datos

```powershell
docker compose up -d db pgadmin
docker compose ps
```

Esperar a que `db` esté `healthy` (healthcheck con `pg_isready`). El primer arranque ejecuta
`db/init/` en orden: esquema, extensiones, usuario de monitoreo, usuario de replicación y rol
`app` con privilegios mínimos.

### Paso 4 — Cargar el dataset

```powershell
./scripts/db.ps1 seed       # ~13 min: 24,2 M de filas
./scripts/db.ps1 indexes    # DESPUÉS de la carga, no antes
./scripts/db.ps1 stats
```

Los índices se crean **después** de la carga a propósito: crearlos antes multiplica el tiempo de
inserción sin mejorar nada. `stats` debe mostrar las tablas de volumen con 6.000.001 filas.

### Paso 5 — Aplicación

```powershell
docker compose up -d backend frontend
curl.exe http://127.0.0.1:8090/health
```

Respuesta esperada: `{"status":"ok","db":"up","version":"dev"}`.

### Paso 6 — Réplica (opcional para desarrollo, obligatoria para §6)

```powershell
docker compose up -d db-replica
./scripts/replica.ps1 status    # debe mostrar state=streaming
./scripts/replica.ps1 test      # escritura en primaria + lectura en réplica
```

### Paso 7 — Servicios de operación

```powershell
docker compose --profile ops up -d
```

Levanta Mantis, Prometheus, Alertmanager, Grafana, exporters, n8n, el borde administrativo y el
registro local. Sin `--profile ops` el stack queda en modo mínimo (solo app + base).

### Paso 8 — Verificación integral

```powershell
./scripts/monitoreo.ps1 status
./scripts/publicar.ps1 up
```

`publicar.ps1` imprime las URLs de los túneles. Son **efímeras**: cambian en cada arranque.

## 4. Verificación

| Qué | Comando | Resultado esperado |
|---|---|---|
| Contenedores | `docker compose ps` | todos `healthy` o `running` |
| Salud de la app | `curl.exe http://127.0.0.1:8090/health` | `status=ok`, `db=up` |
| Datos | `./scripts/db.ps1 stats` | 6.000.001 filas en tablas de volumen |
| Réplica | `./scripts/replica.ps1 status` | `streaming`, lag < 1 s |
| Monitoreo | `http://127.0.0.1:9090/targets` | todos los targets `UP` |
| Grafana | `http://127.0.0.1:3001` | 8 paneles con datos |
| Mantis | `http://127.0.0.1:8081` | login y proyecto `HIA-2026` |
| n8n | `http://127.0.0.1:5678` | flujo `01-alerta-a-mantis` activo |

## 5. Puertos publicados

Todos en `127.0.0.1`: nada se expone a la LAN.

| Puerto | Servicio | Nota |
|---|---|---|
| 5433 | PostgreSQL primaria | 5432 queda libre para una instalación local |
| 8080 | pgAdmin | |
| 8081 | Mantis | |
| 8090 | Frontend | proxy a `/api/` del backend |
| 3001 | Grafana | |
| 5000 | Registro local de imágenes | plan B de GHCR |
| 5678 | n8n | |
| 8088 / 8089 / 8091 | Borde administrativo | pgAdmin / Mantis / n8n con Basic auth |
| 9090 / 9093 | Prometheus / Alertmanager | |

## 6. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `db` reinicia en bucle | contraseña con `$` o `#` sin escapar en `.env` | usar `secrets.token_urlsafe` (sin esos caracteres) |
| `frontend` unhealthy | el contenedor escucha en 8080, no en 80 | verificar `docker port pi-frontend` → `8080/tcp` |
| `seed` termina sin filas | volumen ya inicializado con otro esquema | `./scripts/db.ps1 reset` (borra datos) |
| Réplica no arranca | `pg_basebackup` falló por contraseña | `./scripts/replica.ps1 reinit` |
| Mantis da 500 | `MANTIS_CRYPTO_SALT` cambió después de inicializar | restaurar el valor original o recrear el volumen |
| n8n no importa el flujo | la base `n8n` ya tenía workflows | el entrypoint solo importa si la tabla está vacía |
| `deploy.ps1` falla al bajar la imagen | GHCR privado o sin login | usar `-Registry 127.0.0.1:5000` con el registro local |

## 7. Tiempos medidos

| Etapa | Tiempo |
|---|---|
| `docker compose up -d db pgadmin` (primer arranque) | ~40 s |
| `db.ps1 seed` (24,2 M de filas) | ~13 min |
| `db.ps1 indexes` | ~2 min |
| `docker compose --profile ops up -d` | ~90 s |
| Stack completo desde cero | **~18 min** |

## 8. Decisiones

- **Un solo `compose.yaml` con perfiles** en vez de varios archivos: `ops` separa lo que es
  operación de lo que es la aplicación. Ver `docs/05-decisiones.md` (D-03, D-16).
- **Sin `docker-compose.override.yml`**: lo que se prueba es lo que se despliega.
- **Secretos solo en `.env`**: el repo tiene `.env.example` con placeholders y gitleaks en CI.

## 9. Limitaciones

- El manual asume Windows + Docker Desktop. En Linux los comandos son los mismos salvo
  `curl.exe` → `curl` y las rutas de los scripts.
- No se cubre un clúster real: la réplica es un contenedor en el mismo host, no otra máquina.
- La publicación usa túneles rápidos de Cloudflare (URL efímera), no un dominio propio.

## 10. Preguntas frecuentes

**¿Por qué la base no publica el 5432?**
Porque el 5432 suele estar ocupado por un PostgreSQL local y porque publicar el puerto estándar
invita a escaneos. Se usa 5433 y solo en loopback.

**¿Qué pasa si corro `docker compose down -v`?**
Se borra el volumen `pi-pgdata`: hay que repetir el paso 4 (~15 min). Sin `-v`, los datos
sobreviven; está probado en `evidence/04/persistencia.txt`.

**¿Se puede levantar sin la réplica ni el monitoreo?**
Sí. `docker compose up -d` levanta solo app y base. La réplica y `--profile ops` son necesarios
para §6 y §10, no para que la aplicación funcione.
