#!/bin/sh
# Entrypoint de n8n (§13).
#
# Los workflows versionados tienen placeholders (__WEBHOOK_TOKEN__,
# __MANTIS_TOKEN__) en vez de secretos. Acá se renderiza una copia en /tmp con
# los valores de .env y se importa esa copia: el repositorio nunca contiene el
# token, y n8n solo ve el valor en su propia base.
#
# La condición para importar es que NO haya workflows en la base (no un
# marcador en el volumen): los workflows viven en PostgreSQL, no en el volumen,
# así que un marcador local no refleja la realidad y duplicaba el flujo.
set -e

echo "[n8n] esperando la base de datos..."
i=0
while ! n8n list:workflow >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "[n8n] timeout esperando la base; arranco igual"
    break
  fi
  sleep 2
done

# `n8n list:workflow` imprime un encabezado aunque no haya workflows: se
# cuentan solo las líneas con el separador `id|nombre`.
EXISTENTES=$(n8n list:workflow 2>/dev/null | grep -c '|' || true)
echo "[n8n] workflows existentes: ${EXISTENTES}"

if [ "${EXISTENTES}" = "0" ]; then
  echo "[n8n] renderizando workflows con los secretos del entorno"
  mkdir -p /tmp/wf
  sed -e "s|__WEBHOOK_TOKEN__|${N8N_WEBHOOK_TOKEN}|g" \
      -e "s|__MANTIS_TOKEN__|${MANTIS_TOKEN}|g" \
      /workflows/01-alerta-a-mantis.json > /tmp/wf/01-alerta-a-mantis.json

  echo "[n8n] importando workflows"
  n8n import:workflow --input=/tmp/wf/01-alerta-a-mantis.json || echo "[n8n] fallo el import"
  n8n update:workflow --all --active=true || echo "[n8n] fallo la activacion"
  rm -rf /tmp/wf
  echo "[n8n] workflows importados y activados"
else
  echo "[n8n] ya hay workflows en la base: no se importa de nuevo"
fi

exec n8n start
