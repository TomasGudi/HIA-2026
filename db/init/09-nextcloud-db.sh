#!/bin/bash
# Base de datos propia para Nextcloud (§12).
#
# Nextcloud guarda archivos, metadatos y comparticiones: no comparte base con
# la aplicación, Mantis ni n8n. Se crea un rol y una base dedicados.
set -e

if [ -z "$NEXTCLOUD_DB_PASSWORD" ]; then
  echo "[init] NEXTCLOUD_DB_PASSWORD no definida: se omite la base de Nextcloud"
  exit 0
fi

NEXTCLOUD_DB_NAME="${NEXTCLOUD_DB_NAME:-nextcloud}"
NEXTCLOUD_DB_USER="${NEXTCLOUD_DB_USER:-nextcloud}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${NEXTCLOUD_DB_USER}') THEN
    CREATE ROLE ${NEXTCLOUD_DB_USER} WITH LOGIN PASSWORD '${NEXTCLOUD_DB_PASSWORD}';
  ELSE
    ALTER ROLE ${NEXTCLOUD_DB_USER} WITH LOGIN PASSWORD '${NEXTCLOUD_DB_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${NEXTCLOUD_DB_NAME} OWNER ${NEXTCLOUD_DB_USER}'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${NEXTCLOUD_DB_NAME}')\gexec
EOSQL

echo "[init] base '${NEXTCLOUD_DB_NAME}' y rol '${NEXTCLOUD_DB_USER}' listos para Nextcloud"
