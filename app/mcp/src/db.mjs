// Acceso de solo lectura a PostgreSQL para las métricas que la API no expone.
//
// Usa el rol `monitor` (miembro de pg_monitor): puede leer vistas de
// estadísticas pero NO los datos de las tablas. Así el agente no puede
// exfiltrar contenido aunque el modelo alucine una consulta.

import pg from 'pg';
import { config } from './config.mjs';

let pool;

function getPool() {
  if (!pool) {
    pool = new pg.Pool({
      host: config.db.host,
      port: config.db.port,
      database: config.db.database,
      user: config.db.user,
      password: config.db.password,
      max: 2,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,
      statement_timeout: config.db.statement_timeout,
      application_name: 'pi-mcp',
    });
  }
  return pool;
}

async function consultar(sql) {
  const { rows } = await getPool().query(sql);
  return rows;
}

export const db = {
  async resumen() {
    const [tamano, tablas, conexiones, cache, lentas] = await Promise.all([
      consultar(`
        SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano,
               pg_database_size(current_database()) AS bytes`),
      consultar(`
        SELECT relname AS tabla,
               n_live_tup AS filas_estimadas,
               pg_size_pretty(pg_total_relation_size(relid)) AS tamano,
               seq_scan, idx_scan,
               COALESCE(ROUND(100.0 * idx_scan / NULLIF(seq_scan + idx_scan, 0), 1), 0) AS pct_indice,
               COALESCE(to_char(GREATEST(last_analyze, last_autoanalyze), 'YYYY-MM-DD HH24:MI'), 'nunca') AS ultimo_analyze
        FROM pg_stat_user_tables
        ORDER BY n_live_tup DESC
        LIMIT 10`),
      consultar(`
        SELECT state, count(*)::int AS conexiones
        FROM pg_stat_activity
        WHERE datname = current_database()
        GROUP BY state ORDER BY 2 DESC`),
      consultar(`
        SELECT ROUND(100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2) AS cache_hit
        FROM pg_stat_database WHERE datname = current_database()`),
      consultar(`
        SELECT pid, state,
               ROUND(EXTRACT(epoch FROM now() - query_start)::numeric, 1) AS segundos,
               left(regexp_replace(query, '\\s+', ' ', 'g'), 160) AS consulta
        FROM pg_stat_activity
        WHERE datname = current_database() AND state <> 'idle' AND query_start IS NOT NULL
        ORDER BY query_start ASC LIMIT 5`),
    ]);

    return {
      tamano: tamano[0]?.tamano,
      // si ninguna tabla tiene ANALYZE, las estimaciones no sirven: el agente
      // tiene que decirlo en vez de reportar "0 filas" como si fuera un dato
      estadisticas_actualizadas: tablas.some((t) => t.ultimo_analyze !== 'nunca'),
      tablas,
      conexiones,
      cache_hit_pct: cache[0]?.cache_hit,
      consultas_activas: lentas,
    };
  },

  async cerrar() {
    if (pool) await pool.end();
  },
};
