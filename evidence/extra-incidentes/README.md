# Evidencia — incidentes + Hermes

Prueba real ejecutada el 20/11/2026:

1. `docker stop pi-db` a las 18:24.
2. Prometheus `PostgresCaido` en `firing`; Alertmanager envió el webhook directo al MCP.
3. El MCP registró el incidente #3 en `opsdb`, creó la incidencia en Mantis y envió
   correo a MailHog y mensaje a Telegram.
4. Se aprobó el incidente #3.
5. `incidente-watcher.ps1` promovió `db-replica` y repuntó el backend.
6. Resultado registrado: **failover completado en 5,4 s**; `/health` = ok, db = up.
7. `restaurar-primaria.ps1 -SwapBack` devolvió la topología original
   (`db` primaria, `db-replica` standby en streaming).

Archivos:

- `mailhog.json`: mensajes capturados por MailHog.
- `incidentes.txt`: filas de `ops.incident` con estado y resultado.

Nota: la primera prueba generó dos incidencias en Mantis (#70/#71) porque
Alertmanager enviaba el mismo `PostgresCaido` a n8n y al MCP. Se corrigió el
ruteo: `PostgresCaido` va **solo** al MCP, y el MCP crea la incidencia en Mantis.
Las demás alertas siguen usando n8n para Mantis y el MCP solo guarda el incidente
en `opsdb`.

Además, Mantis pasó a usar la base `mantis` dentro de `opsdb` (migrada con
`pg_dump`/restore). Antes usaba la primaria y devolvía HTML/500 cuando `db`
estaba caída; ahora crea la incidencia durante el incidente.
