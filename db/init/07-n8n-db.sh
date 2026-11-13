#!/bin/bash
# Base de datos propia para n8n (§13).
#
# n8n guarda workflows, ejecuciones y credenciales: no comparte base con la
# aplicación ni con Mantis. Se crea un rol y una base dedicados.
set -e

if [ -z "$N8N_DB_PASSWORD" ]; then
  echo "[init] N8N_DB_PASSWORD no definida: se omite la base de n8n"
  exit 0
fi

N8N_DB_NAME="${N8N_DB_NAME:-n8n}"
N8N_DB_USER="${N8N_DB_USER:-n8n}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${N8N_DB_USER}') THEN
    CREATE ROLE ${N8N_DB_USER} WITH LOGIN PASSWORD '${N8N_DB_PASSWORD}';
  ELSE
    ALTER ROLE ${N8N_DB_USER} WITH LOGIN PASSWORD '${N8N_DB_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${N8N_DB_NAME} OWNER ${N8N_DB_USER}'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${N8N_DB_NAME}')\gexec
EOSQL

echo "[init] base '${N8N_DB_NAME}' y rol '${N8N_DB_USER}' listos para n8n"
