#!/bin/bash
# Prepara la primaria para replicación streaming (§6).
#
# 1) crea el rol de replicación con contraseña desde el entorno
# 2) agrega la regla de pg_hba para conexiones de replicación
# 3) recarga la configuración
#
# Se ejecuta como script (no .sql) porque necesita interpolar la contraseña.
set -e

REPL_USER="${REPL_USER:-replicador}"
SUBNET="${REPL_SUBNET:-172.16.0.0/12}"

if [ -z "$REPL_PASSWORD" ]; then
  echo "[init] REPL_PASSWORD no definida: se omite la configuración de replicación"
  exit 0
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${REPL_USER}') THEN
    CREATE ROLE ${REPL_USER} WITH REPLICATION LOGIN PASSWORD '${REPL_PASSWORD}';
  ELSE
    ALTER ROLE ${REPL_USER} WITH REPLICATION LOGIN PASSWORD '${REPL_PASSWORD}';
  END IF;
END
\$\$;
EOSQL

# La regla de replicación va al final: las reglas previas no la cubren.
HBA="$PGDATA/pg_hba.conf"
if ! grep -q "^host replication ${REPL_USER}" "$HBA"; then
  echo "host replication ${REPL_USER} ${SUBNET} scram-sha-256" >> "$HBA"
  echo "[init] regla de replicación agregada a pg_hba.conf"
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -c "SELECT pg_reload_conf();" >/dev/null
echo "[init] rol '${REPL_USER}' y pg_hba listos para replicación"
