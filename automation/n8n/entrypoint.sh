#!/bin/sh
# Entrypoint de n8n (§13).
#
# Los workflows versionados tienen placeholders (__WEBHOOK_TOKEN__,
# __MANTIS_TOKEN__, __NC_USER__, __NC_BASIC__) en vez de secretos. Acá se
# renderiza una copia en /tmp con los valores de .env y se importa esa copia:
# el repositorio nunca contiene el token, y n8n solo ve el valor en su base.
#
# Se importa workflow por workflow si su nombre no está en la base. Así se
# pueden agregar flujos nuevos sin borrar los existentes ni duplicarlos.
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

# header Basic para WebDAV de Nextcloud: base64(usuario:contraseña)
NC_BASIC="Basic $(printf '%s:%s' "${NEXTCLOUD_ADMIN_USER:-admin}" "${NEXTCLOUD_ADMIN_PASSWORD:-}" | base64 | tr -d '\n')"

echo "[n8n] renderizando workflows con los secretos del entorno"
mkdir -p /tmp/wf
for origen in /workflows/*.json; do
  destino="/tmp/wf/$(basename "$origen")"
  sed -e "s|__WEBHOOK_TOKEN__|${N8N_WEBHOOK_TOKEN}|g" \
      -e "s|__MANTIS_TOKEN__|${MANTIS_TOKEN}|g" \
      -e "s|__NC_USER__|${NEXTCLOUD_ADMIN_USER:-admin}|g" \
      -e "s|__NC_BASIC__|${NC_BASIC}|g" \
      "$origen" > "$destino"
done

# `n8n list:workflow` imprime un encabezado aunque no haya workflows: se
# cuentan solo las líneas con el separador `id|nombre`.
EXISTENTES=$(n8n list:workflow 2>/dev/null | grep -c '|' || true)
echo "[n8n] workflows existentes: ${EXISTENTES}"

IMPORTADOS=0
for archivo in /tmp/wf/*.json; do
  # el primer "name" del JSON es el nombre del workflow
  nombre=$(sed -n 's/.*"name": "\([^"]*\)".*/\1/p' "$archivo" | head -1)
  if [ -z "$nombre" ]; then
    echo "[n8n] no se pudo leer el nombre de $(basename "$archivo"); se omite"
    continue
  fi
  if n8n list:workflow 2>/dev/null | grep -F "|${nombre}" >/dev/null; then
    echo "[n8n] ya existe: ${nombre}"
  else
    echo "[n8n] importando: ${nombre}"
    n8n import:workflow --input="$archivo" || echo "[n8n] fallo el import de ${nombre}"
    IMPORTADOS=$((IMPORTADOS + 1))
  fi
done

if [ "$IMPORTADOS" -gt 0 ]; then
  n8n update:workflow --all --active=true || echo "[n8n] fallo la activacion"
fi
rm -rf /tmp/wf
echo "[n8n] listo (${IMPORTADOS} workflows nuevos)"

exec n8n start
