#!/bin/bash
# Crea la base y el rol de Mantis (§11) en el primer arranque del volumen.
# Se ejecuta como script (no como .sql) porque necesita interpolar variables
# de entorno: la contraseña no puede quedar escrita en el repositorio.
set -e

MANTIS_USER="${MANTIS_DB_USER:-mantis}"
MANTIS_DB="${MANTIS_DB_NAME:-mantis}"

if [ -z "$MANTIS_DB_PASSWORD" ]; then
  echo "[init] MANTIS_DB_PASSWORD no definida: se omite la creación de la base de Mantis"
  exit 0
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${MANTIS_USER}') THEN
    CREATE ROLE ${MANTIS_USER} LOGIN PASSWORD '${MANTIS_DB_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${MANTIS_DB} OWNER ${MANTIS_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${MANTIS_DB}')\gexec
EOSQL

echo "[init] base '${MANTIS_DB}' y rol '${MANTIS_USER}' listos"
