-- ============================================================
-- 02-extensions.sql — Extensiones necesarias para §5 y §10
-- shared_preload_libraries ya está configurado en compose.yaml
-- ============================================================

-- Estadísticas de consultas: base del informe de optimización (§5)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Inspección de caché de buffers (útil para justificar índices)
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
