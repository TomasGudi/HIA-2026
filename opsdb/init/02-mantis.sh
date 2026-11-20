#!/bin/bash
# ============================================================
# Base de Mantis dentro de opsdb (extra)
#
# Mantis deja de depender de la primaria: su base vive en el mismo
# PostgreSQL de operación que los incidentes. Así una incidencia se
# puede crear aunque `db` esté caída.
#
# El esquema se carga con 03-mantis-schema.sql en un volumen nuevo.
# En un volumen existente, la base se migra con pg_dump/restore.
# ============================================================
set -e

MANTIS_USER="${MANTIS_DB_USER:-mantis}"
MANTIS_DB="${MANTIS_DB_NAME:-mantis}"

if [ -z "$MANTIS_DB_PASSWORD" ]; then
  echo "[init] MANTIS_DB_PASSWORD no definida: se omite la base de Mantis"
  exit 0
fi

echo "[init] creando rol '$MANTIS_USER' y base '$MANTIS_DB' en opsdb"

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname postgres \
     -v m_user="$MANTIS_USER" \
     -v m_pass="$MANTIS_DB_PASSWORD" \
     -v m_db="$MANTIS_DB" <<'EOSQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'m_user', :'m_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'m_user') \gexec
SELECT 'CREATE DATABASE ' || quote_ident(:'m_db') || ' OWNER ' || quote_ident(:'m_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'m_db') \gexec
EOSQL

echo "[init] base de Mantis lista"
