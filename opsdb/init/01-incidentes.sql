-- ============================================================
-- Incidentes operativos (extra: Hermes + remediación)
--
-- Base `ops` independiente de la primaria. Así el incidente se puede
-- registrar aunque `db` esté caída. El usuario `mcp_ops` es dueño de
-- esta base y solo ve estas tablas.
--
-- Se aplica solo en el primer arranque del volumen `pi-opsdb-data`.
-- Para un volumen existente: ./scripts/incidentes.ps1 init
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS ops.runbook (
  id          serial PRIMARY KEY,
  codigo      text UNIQUE NOT NULL,
  sintoma     text NOT NULL,
  causa       text NOT NULL,
  solucion    text NOT NULL,
  comando     text,
  riesgo      text NOT NULL DEFAULT 'medio',
  actualizado timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ops.incident (
  id                 bigserial PRIMARY KEY,
  codigo             text NOT NULL,
  titulo             text NOT NULL,
  severidad          text NOT NULL DEFAULT 'critical',
  estado             text NOT NULL DEFAULT 'open',
  servicio           text,
  sintoma            text,
  diagnostico        text,
  solucion_propuesta text,
  runbook_id         integer REFERENCES ops.runbook(id),
  mantis_id          integer,
  alerta             jsonb,
  aprobado_por       text,
  aprobado_at        timestamptz,
  resuelto_at        timestamptz,
  resultado          text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ops.incident_event (
  id          bigserial PRIMARY KEY,
  incident_id bigint NOT NULL REFERENCES ops.incident(id) ON DELETE CASCADE,
  tipo        text NOT NULL,
  detalle     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS incident_estado_idx
  ON ops.incident (estado, created_at DESC);
CREATE INDEX IF NOT EXISTS incident_event_incidente_idx
  ON ops.incident_event (incident_id, created_at);

INSERT INTO ops.runbook (codigo, sintoma, causa, solucion, comando, riesgo) VALUES
(
  'PG_PRIMARY_DOWN',
  'pg_up == 0 o la aplicación no puede abrir conexiones a la primaria',
  'El contenedor de la primaria está detenido, no responde o perdió la conexión.',
  E'1. Confirmar que la primaria no responde: docker compose ps db y pg_isready.\n2. Verificar que la réplica sigue en streaming y sin lag: ./scripts/replica.ps1 status.\n3. Promover la réplica: SELECT pg_promote(wait => true, wait_seconds => 30).\n4. Repuntar el backend a db-replica: DATABASE_HOST=db-replica y recrear el servicio backend.\n5. Esperar /health con status=ok y db=up.\n6. Registrar el RTO y dejar la primaria vieja detenida hasta reconstruirla.',
  './scripts/replica.ps1 promote',
  'alto'
),
(
  'PG_REPLICA_LAG',
  'pg_wal_lsn_diff entre la primaria y la réplica supera el umbral',
  'La réplica no alcanza a aplicar el WAL: I/O lento, red saturada o consultas largas.',
  E'1. Medir el lag: ./scripts/replica.ps1 lag.\n2. Revisar I/O y red del host.\n3. Si el lag no baja, evaluar reiniciar la réplica con ./scripts/replica.ps1 reinit.\n4. No promover una réplica atrasada sin declarar la pérdida de datos.',
  './scripts/replica.ps1 lag',
  'medio'
),
(
  'ALERTA_GENERICA',
  'Cualquier alerta de Prometheus sin runbook específico',
  'No hay un procedimiento específico cargado para esta alerta.',
  E'1. Leer el resumen y la descripción de la alerta.\n2. Revisar Grafana y los logs del servicio afectado.\n3. Si no hay impacto, silenciar con justificación.\n4. Si hay impacto, abrir una incidencia en Mantis y documentar la acción.',
  NULL,
  'bajo'
)
ON CONFLICT (codigo) DO UPDATE SET
  sintoma = EXCLUDED.sintoma,
  causa = EXCLUDED.causa,
  solucion = EXCLUDED.solucion,
  comando = EXCLUDED.comando,
  riesgo = EXCLUDED.riesgo,
  actualizado = now();

COMMIT;
