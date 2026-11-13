#!/bin/bash
# Rol de la aplicación con privilegios mínimos (§14).
#
# La app NO necesita ser dueña del esquema ni superusuario: solo leer y
# escribir datos. Las migraciones y la carga inicial las hace el usuario
# administrador (POSTGRES_USER) desde los scripts.
#
# `ALTER DEFAULT PRIVILEGES` cubre las tablas que se creen después (la carga
# inicial corre con el usuario administrador).
set -e

if [ -z "$APP_DB_PASSWORD" ]; then
  echo "[init] APP_DB_PASSWORD no definida: se omite el rol de la aplicación"
  exit 0
fi

APP_USER="${APP_DB_USER:-app}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${APP_USER}') THEN
    CREATE ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_DB_PASSWORD}';
  ELSE
    ALTER ROLE ${APP_USER} WITH LOGIN PASSWORD '${APP_DB_PASSWORD}';
  END IF;
END
\$\$;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_USER};
GRANT USAGE ON SCHEMA public TO ${APP_USER};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${APP_USER};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${APP_USER};
ALTER DEFAULT PRIVILEGES FOR ROLE ${POSTGRES_USER} IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_USER};
ALTER DEFAULT PRIVILEGES FOR ROLE ${POSTGRES_USER} IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO ${APP_USER};
EOSQL

echo "[init] rol '${APP_USER}' con permisos mínimos sobre '${POSTGRES_DB}'"
