# Plan de proyecto — Práctica Integradora Final

> Documento vivo. Última actualización: 12/11/2026.
> Cierre asumido: **martes 17/11/2026** (el enunciado dice "semana del 16/11"; el "30/11" del
> enunciado se interpreta como fecha de definición de grupos, ya vencida → ver `05-decisiones.md` D-01).

## 1. Restricción principal

Hay **5 días corridos** (jue 12 → mar 17) y la defensa cae dentro de esa ventana.
Regla de oro: **todo entregable debe ser demostrable en vivo**. Un documento sin evidencia
ejecutable no suma; una demo sin documento sí resta menos.

## 2. Estrategia

1. **Un solo `docker compose`** que levante todo el stack (DB + réplica + admin + app + monitoreo + ops).
   Si un servicio no está en el compose, no existe para la defensa.
2. **Evidencia automatizada**: cada sección deja salida de comandos en `evidence/<seccion>/`.
   Nada de capturas sueltas en un Word.
3. **Orden por dependencias reales**, no por el orden del enunciado (ver §4).
4. **Congelar el martes a las 00:00**. El martes solo se ensaya.

## 3. Cronograma (5 días)

| Fecha | Bloque | Entregable verificable |
|---|---|---|
| **Jue 12** (hoy) | Plan, backlog, elección de app, repo GitHub (ramas `main`/`develop`, protección, README, `.gitignore`, `.env.example`) | Repo público + `docs/` + tablero con backlog cargado |
| **Vie 13** | Compose de DB: primaria + réplica + pgAdmin, volúmenes, red interna, backup base. Script de seed masivo. Medición de carga | `compose.yaml`, `db/init/*.sql`, `scripts/seed.*`, evidencia de volumen y tiempos |
| **Sáb 14** | 8 consultas optimizadas (EXPLAIN antes/después), índices justificados. Compose de app (back+front). Pipeline CI/CD + deploy. Túnel | `db/queries/optimizacion.md`, `.github/workflows/ci.yml`, URL pública funcionando |
| **Dom 15** | Prometheus + Grafana + exporters + dashboard + alertas + prueba de alerta. Mantis + 10 incidencias. n8n con 3 flujos | Dashboard con métricas reales, Mantis poblado, 3 workflows exportados |
| **Lun 16** | Seguridad: escaneos, matriz STRIDE, ZAP, webhook sin token. Nextcloud. Informe final (16 docs) | `security/`, carpeta Nextcloud, PDF final |
| **Mar 17** | Ensayo cronometrado (20 min), congelar, entregar | Guion de demo + tag `v1.0.0` |

**Buffer**: sábado y domingo son los días con más carga. Si el sábado se atrasa,
el recorte es **replicación con failover manual** (permitido) y **n8n flujo 4** (opcional).

## 4. Dependencias (por qué el orden del enunciado no sirve)

```
§4 DB+compose ──┬─> §5 optimización ──┐
                ├─> §6 replicación ───┼─> §10 monitoreo ──┐
                └─> §7 app compose ───┘                   ├─> §13 n8n
§3 repo ──> §8 CI/CD ──> §9 túnel ───────────────────────┘
§11 Mantis ──────────────────────────────────────────────┘
§12 Nextcloud ───────────────────────────────────────────┘
§14 seguridad  (necesita §5 para el bug de rendimiento y §14 para el de seguridad)
```

- §13 flujo 1 **no puede existir** sin Prometheus (§10) + Mantis (§11).
- §13 flujo 3 **no puede existir** sin Nextcloud (§12).
- §11 exige ≥10 incidencias reales, **una de rendimiento y una de seguridad** → dependen de §5 y §14.
- §8 CI/CD antes de §9: el túnel publica lo que el pipeline construye.

## 5. Riesgos

| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Seed de 60-80M filas no entra en disco/RAM | Media | Alto | Generar solo en tablas de volumen (6M c/u en 3 tablas), `COPY`, tuning de `maintenance_work_mem` y `unlogged` temporal. Ver `06-app-seleccion.md` |
| Réplica no arranca por config WAL | Media | Alto | `pg_basebackup` con `-R`; verificar `wal_level=replica`, `max_wal_senders`, `hot_standby` |
| Docker Desktop con 8 contenedores ahoga la máquina | Alta | Medio | Límites `mem_limit` por servicio; monitoreo y ops en el mismo compose pero con perfiles (`--profile ops`) |
| Túnel caído en plena demo | Media | **Crítico** | Plan B: Tailscale Funnel ya configurado + `docker compose up` local como respaldo |
| Alertas que no disparan (sin `alertmanager`) | Media | Medio | Reglas de Prometheus + `alertmanager` con webhook a n8n; probar con `stress-ng` |
| Permisos de la API de Mantis para n8n | Media | Bajo | Usar API REST con token de usuario dedicado, no la cuenta admin |
| Se pierde tiempo en documentación y no queda demo | Alta | **Crítico** | Documentar al final de cada bloque con lo ya funcionando, nunca antes |

## 6. Roles (5 integrantes)

| Rol | Dueño de secciones | Defiende en la oral |
|---|---|---|
| R1 — Infra/DB | §4, §5, §6 | Docker, volumen de datos, EXPLAIN, replicación y sus límites |
| R2 — App/CI | §1, §3, §7, §8 | Stack, ramas, pipeline, rollback |
| R3 — Obs/Incidentes | §10, §11 | Dashboard, umbrales, ciclo de vida de un bug |
| R4 — Automatización | §13, §12 | Los 3 flujos, idempotencia, manejo de error |
| R5 — Seguridad/Docs | §9, §14, §15 | Túnel, matriz STRIDE, escaneos, informe |

Cada integrante debe poder **levantar y romper** su parte. La nota es individual:
el que no puede explicar su sección, no aprueba aunque el sistema funcione.

## 7. Definición de "terminado" (DoD)

Un entregable está terminado cuando:
1. Se ejecuta desde cero con `git clone && cp .env.example .env && docker compose up -d`.
2. La evidencia está en `evidence/` y es reproducible (comando + salida, no screenshot solo).
3. Está referenciado en el informe final con su ruta exacta.
4. Otro integrante distinto al autor pudo ejecutarlo sin ayuda.
