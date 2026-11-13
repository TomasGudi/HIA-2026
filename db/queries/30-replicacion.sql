-- ============================================================
-- 30-replicacion.sql — Verificación de replicación (§6)
--
-- Se ejecuta en DOS pasos porque primaria y réplica son contenedores
-- distintos:
--   1) en la primaria: estado, lag y una escritura de prueba
--   2) en la réplica: la misma fila, en modo solo lectura
-- ============================================================

-- ---------- PASO 1: en la PRIMARIA ----------
\echo '== estado de replicación (primaria) =='
SELECT client_addr,
       state,
       sync_state,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_replay,
       write_lag,
       flush_lag,
       replay_lag
FROM pg_stat_replication;

\echo '== ¿está en modo primaria? =='
SELECT pg_is_in_recovery() AS en_recuperacion;  -- false = primaria

\echo '== escritura de prueba =='
INSERT INTO "Tag" (name)
VALUES ('replica-test-' || to_char(now(), 'YYYYMMDDHH24MISS'))
ON CONFLICT (name) DO NOTHING
RETURNING id, name;

\echo '== LSN actual =='
SELECT pg_current_wal_lsn() AS lsn_primaria;

-- ---------- PASO 2: en la RÉPLICA ----------
-- \echo '== ¿está en modo standby? =='
-- SELECT pg_is_in_recovery() AS en_recuperacion;  -- true = réplica
--
-- \echo '== lag de replay =='
-- SELECT pg_last_wal_replay_lsn() AS lsn_replica,
--        now() - pg_last_xact_replay_timestamp() AS atraso;
--
-- \echo '== la fila escrita en la primaria =='
-- SELECT id, name FROM "Tag" WHERE name LIKE 'replica-test-%' ORDER BY id DESC LIMIT 3;
--
-- \echo '== la réplica rechaza escrituras (correcto) =='
-- INSERT INTO "Tag" (name) VALUES ('no-debe-poder-' || to_char(now(),'HH24MISS'));
