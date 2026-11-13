#!/bin/bash
# Crea el rol de solo lectura que usa postgres_exporter (§10).
#
# No se usa el usuario de la aplicación: el exporter solo necesita leer
# vistas de estadísticas. `pg_monitor` es el rol predefinido de PostgreSQL
# que agrupa pg_read_all_stats + pg_read_all_settings, sin acceso a datos.
set -e

if [ -z "$MONITOR_DB_PASSWORD" ]; then
  echo "[init] MONITOR_DB_PASSWORD no definida: se omite el rol de monitoreo"
  exit 0
fi

MONITOR_USER="${MONITOR_DB_USER:-monitor}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${MONITOR_USER}') THEN
    CREATE ROLE ${MONITOR_USER} WITH LOGIN PASSWORD '${MONITOR_DB_PASSWORD}';
  ELSE
    ALTER ROLE ${MONITOR_USER} WITH LOGIN PASSWORD '${MONITOR_DB_PASSWORD}';
  END IF;
END
\$\$;
GRANT pg_monitor TO ${MONITOR_USER};
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${MONITOR_USER};
EOSQL

echo "[init] rol '${MONITOR_USER}' con pg_monitor listo para postgres_exporter"
