#!/bin/bash
# Entrypoint de la réplica (§6).
#
# Si el volumen está vacío, clona la primaria con pg_basebackup -R (que además
# escribe primary_conninfo y standby.signal). Si ya tiene datos, arranca
# directamente: así el contenedor se puede reiniciar sin volver a clonar.
set -e

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "[replica] volumen vacío: clonando desde la primaria ($PRIMARY_HOST)..."
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  # esperar a que la primaria acepte conexiones de replicación
  for i in $(seq 1 60); do
    if PGPASSWORD="$REPL_PASSWORD" pg_isready -h "$PRIMARY_HOST" -p 5432 -U "$REPL_USER" >/dev/null 2>&1; then
      break
    fi
    echo "[replica] esperando a la primaria ($i/60)..."
    sleep 2
  done

  su-exec postgres env PGPASSWORD="$REPL_PASSWORD" \
    pg_basebackup -h "$PRIMARY_HOST" -p 5432 -U "$REPL_USER" \
                  -D "$PGDATA" -Fp -Xs -R -P -c fast

  echo "[replica] clon inicial completado"
else
  echo "[replica] datos existentes: arrancando sin clonar"
fi

exec docker-entrypoint.sh "$@"
