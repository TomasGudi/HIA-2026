# Guion de demo — 20 minutos, 5 integrantes

> Regla de oro: **nada pregrabado**. Cada bloque se ejecuta en vivo y, si algo falla, se muestra el
> error y se explica. Un fallo explicado vale más que un video perfecto.

## 1. Reparto

| Rol | Persona | Bloques | Secciones que defiende |
|---|---|---|---|
| R1 | | 2, 3, 4 | §4 datos, §5 SQL, §6 réplica |
| R2 | | 1, 5 | §1 app, §8 CI/CD |
| R3 | | 6 | §10 monitoreo, §11 incidencias |
| R4 | | 7 | §13 n8n, §12 Nextcloud |
| R5 | | 8, cierre | §9 publicación, §14 seguridad, §15 documentación |

Cada uno defiende **una sección ajena** en las preguntas (preparada de antemano): eso demuestra
comprensión del conjunto y no solo de la propia parte.

## 2. Antes de empezar (checklist T-60 / T-30 / T-5)

### T-60 min

```powershell
# 1. stack completo arriba
docker compose --profile ops up -d
docker compose ps

# 2. versión desplegada = la de main
git fetch origin; git rev-parse --short origin/main
./scripts/deploy.ps1 -Tag sha-82a8e98 -Registry ghcr.io/tomasgudi

# 3. URLs nuevas (los quick tunnels cambian)
./scripts/publicar.ps1 up
```

### T-30 min

```powershell
# 4. verificar los 4 accesos
curl.exe -s http://127.0.0.1:8090/health
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:8081/
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:3001/login
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:5678/
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:8082/login

# 5. targets de Prometheus en UP
Start-Process http://127.0.0.1:9090/targets

# 6. réplica en streaming
./scripts/replica.ps1 status
```

### T-5 min

- Cerrar Slack/Discord/actualizaciones. Modo avión en el celular **excepto** el hotspot del bloque 1.
- Abrir 6 pestañas en orden: app pública, Grafana, Prometheus/alertas, Mantis, n8n, GitHub PR #10.
- Terminal 1: repo en `main`. Terminal 2: `psql` abierto con `./scripts/db.ps1 psql`.
- Tener `docs/20-guion-demo.md` impreso: el que habla no mira la pantalla para saber qué sigue.

## 3. Bloques

### 0:00–2:00 · R2 — La app existe y se usa (2 min)

**Desde el celular con datos móviles**, no desde la notebook:

1. Abrir la URL pública del túnel.
2. Registrarse: `defensa@example.com` / `Defensa2026!`.
3. Publicar un artículo: título `Demo 17/11`, cuerpo, tag `demo`.
4. Filtrar por tag `demo` y mostrar que aparece.

**Qué decir**: "Esto no es localhost: es la app por HTTPS desde otra red. El túnel termina TLS y el
borde solo publica 80/443 (§9)."

**Si falla el túnel**: mostrar la misma app en `http://127.0.0.1:8090` y declarar la URL efímera como
limitación P1.

### 2:00–4:00 · R1 — Datos y contenedores (2 min)

```powershell
docker compose ps --format "table {{.Name}}\t{{.Status}}"
docker volume ls | Select-String pgdata
./scripts/db.ps1 stats
```

Mostrar: **24,2 M de filas**, `Article` 6.000.001, tamaño de base 8,5 GB.

**Qué decir**: "Los índices se crean después de la carga; al revés, la carga tarda el triple."

### 4:00–7:00 · R1 — La consulta que bajó de 7,9 s a 0,19 s (3 min)

En `psql`:

```sql
-- antes: Seq Scan sobre 6 M de filas
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.id, a.title FROM "Article" a
JOIN "_ArticleToTag" at ON at."articleId" = a.id
JOIN "Tag" t ON t.id = at."tagId"
WHERE t.name = 'demo' ORDER BY a."createdAt" DESC LIMIT 20;
```

Mostrar el plan actual (Index Scan) y el tiempo. Después abrir
`evidence/05/` y mostrar el plan **antes** con Seq Scan y 7,9 s.

**Qué decir**: "No alcancé con un índice: fueron 8 pares medidos. El detalle está en el doc 07."

### 7:00–9:00 · R1 — Réplica y caída (2 min)

```powershell
./scripts/replica.ps1 status      # state=streaming, lag < 1 s
./scripts/replica.ps1 test        # INSERT en primaria, SELECT en réplica
docker stop pi-db-replica
curl.exe -s -o NUL -w "app sigue: %{http_code}`n" http://127.0.0.1:8090/api/articles?limit=1
docker start pi-db-replica
```

**Qué decir**: "La app sigue escribiendo en la primaria porque la réplica es asíncrona. El failover
es **manual** y está medido: 8,6 s. No digo alta disponibilidad: digo replicación."

### 9:00–11:00 · R2 — CI/CD y rollback (2 min)

En GitHub, PR #10:

1. Mostrar los **4 checks** obligatorios (backend, frontend, compose, secrets) en verde.
2. Mostrar `main` protegida: sin checks no hay merge.
3. En terminal:

```powershell
./scripts/deploy.ps1 -Tag sha-82a8e98 -Registry ghcr.io/tomasgudi
./scripts/deploy.ps1 -Rollback
```

Mostrar que `/health` reporta la versión y que el rollback vuelve a la anterior.

**Qué decir**: "El deploy es pull-based: la imagen viene de GHCR. Si la versión nueva no responde en
90 s, vuelve sola."

### 11:00–14:00 · R3 — Monitoreo y alerta real (3 min)

1. Grafana: 8 paneles con datos (CPU, memoria, disco, red, HTTP, Postgres, réplica).
2. Prometheus → Alerts: mostrar `CPUAlta` en `firing` con el registro de la corrida real (564 s).
3. **Alerta en vivo (2 min de espera)**:

```powershell
docker stop pi-postgres-exporter
# esperar 2 min: ServicioCaido pasa a firing
```

4. Mostrar en Alertmanager la alerta y en Mantis la incidencia creada por n8n con el título de la alerta.

```powershell
docker start pi-postgres-exporter
```

**Qué decir**: "El umbral de CPU es 85% y tarda 10 minutos en disparar: `rate[5m]` más `for: 5m`.
Por eso la prueba de carga dura 13 minutos. La alerta en vivo usa `ServicioCaido`, que dispara en 2."

**Si no dispara**: abrir `evidence/10/` y mostrar el `firing` de la corrida real y la incidencia #18.

### 14:00–16:00 · R4 — Automatización y gestión documental (2 min)

1. n8n: abrir el flujo `01-alerta-a-mantis`, mostrar los 3 nodos y el token como **credencial**, no
   en el JSON.
2. Ejecuciones: la #18 (éxito) y la #21 (error con Mantis caído).
3. Mostrar los flujos **02** (verificación de backup) y **03** (informe a Nextcloud) en el editor, y
   el archivo `informe-semanal-2026-11-13.md` dentro de Nextcloud.
4. Nextcloud: abrir `HIA-2026`, mostrar las 17 carpetas y el PDF. Entrar como `auditor` e intentar
   subir: **403**. Entrar como `invitado`: no ve la carpeta.
5. Prueba negativa del webhook:

```powershell
curl.exe -s -o NUL -w "sin token -> %{http_code}`n" -X POST http://127.0.0.1:5678/webhook/alerta -H "Content-Type: application/json" -d "{}"
```

Debe dar **401**.

**Qué decir**: "Si Mantis está caído, la ejecución queda en error y no se pierde: Alertmanager
reintenta. El flujo 2 verifica el backup y crea incidencia si está viejo; el 3 sube el informe
semanal a Nextcloud por WebDAV."

### 16:00–18:00 · R5 — Publicación y seguridad (2 min)

```powershell
# desde otra máquina de la LAN
nmap -Pn -p 80,443,5433,8090,9090 192.168.1.8
```

Mostrar: solo 80/443 abiertos al público; los demás `filtered` en la LAN.

Después, en la notebook:

```powershell
curl.exe -s -I https://<tunel>.trycloudflare.com/ | Select-String "Content-Security|Strict-Transport|Server"
Get-Content evidence/14/trivy-backend-despues.txt | Select-String "Total:"
```

**Qué decir**: "Trivy bajó las críticas de 9 a 2; las 2 que quedan no tienen fix compatible y están
declaradas. ZAP: 0 fallos. La app usa un rol de base solo DML: un SQLi no puede borrar tablas."

### 18:00–20:00 · R5 — Cierre (2 min)

Tres frases, sin leer:

1. **Qué está**: app, 24,2 M de filas, 8 consultas optimizadas, réplica con failover manual,
   CI/CD con rollback, monitoreo con alerta → incidencia, seguridad medida, backups restaurados.
2. **Qué no está**: failover automático, Nextcloud (§12), flujos 2 y 3 de n8n. Está en el doc 16.
3. **Qué aprendimos**: lo que más costó no fue levantar servicios, fue **medir**: el antes/después de
   cada consulta, el RTO real y el tiempo que tarda una alerta en disparar.

Cerrar con la URL pública en pantalla y el repo:
`https://github.com/TomasGudi/HIA-2026`.

## 4. Contingencias

| Falla | Qué se hace | Qué se dice |
|---|---|---|
| El túnel no responde | mostrar `127.0.0.1:8090` | "URL efímera, limitación P1" |
| El celular no navega | usar la notebook | "el punto es el HTTPS, no el dispositivo" |
| La alerta no dispara en 2 min | abrir `evidence/10/` | "el `for` es 2 min; mostramos la corrida real" |
| n8n no crea la incidencia | mostrar ejecución #18 | "el flujo funciona; ahora Mantis no responde" |
| Nextcloud no abre | mostrar la carpeta local `docs/informe/` | "el repo es la fuente de verdad" |
| El deploy falla | `./scripts/deploy.ps1 -Rollback` | "esto es exactamente el rollback" |
| Se cae la base | `docker compose up -d db` | "el volumen persiste; probado en §4" |
| Pregunta que no sabemos | "no lo medimos, lo anotamos" | nunca inventar un número |

## 5. Preguntas que van a hacer

| Pregunta | Respuesta corta | Doc |
|---|---|---|
| ¿Por qué Postgres y no MySQL? | replicación streaming nativa, `EXPLAIN` más rico, extensiones | 03 |
| ¿Por qué no Kubernetes? | el alcance es un host; Compose es reproducible y demostrable | 05 |
| ¿Cómo saben que el índice se usa? | `EXPLAIN (ANALYZE, BUFFERS)` antes/después, 8 pares medidos | 07 |
| ¿Qué pasa si cae la primaria? | promoción manual, RTO 8,6 s, divergencia documentada | 08 |
| ¿El rollback es automático? | sí, si `/health` no responde en 90 s | 09 |
| ¿Por qué el umbral de CPU es 85%? | por debajo, el stack normal ya roza el 60-70% | 11 |
| ¿Mantis o Jira? | Jira para Scrum, Mantis para incidencias: son propósitos distintos | 12 |
| ¿Qué pasa si n8n está caído? | Alertmanager reintenta; la ejecución queda en error | 13 |
| ¿La app es segura? | no se afirma: se midió. ZAP 0 fallos, 2 CVE declaradas | 14 |
| ¿Dónde está la documentación? | Nextcloud con 17 carpetas y permisos por grupo; el repo es la fuente | 12 |
| ¿Restauraron un backup? | sí, 12,5 min, conteos idénticos | 15 |

## 6. Lo que no se hace en la demo

- No se carga el dataset en vivo (13 min).
- No se corre `stress-ng` 13 min: se muestra el registro y se ofrece repetir después.
- No se hace `docker compose down -v`.
- No se tipean comandos largos: están en este archivo y se copian.
