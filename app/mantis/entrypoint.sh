#!/bin/sh
# Genera config/config_inc.php a partir de variables de entorno.
# Así la imagen no contiene credenciales y el compose es la única fuente.
set -e

CONF=/var/www/html/config/config_inc.php

if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<EOF
<?php
/**
 * Generado automáticamente por entrypoint.sh — no editar a mano.
 * Credenciales tomadas del entorno (compose/.env).
 */
\$g_hostname              = '${MANTIS_DB_HOST:-db}';
\$g_db_type               = 'pgsql';
\$g_database_name         = '${MANTIS_DB_NAME:-mantis}';
\$g_db_username           = '${MANTIS_DB_USER:-mantis}';
\$g_db_password           = '${MANTIS_DB_PASSWORD}';
\$g_dbport                = 5432;
\$g_use_persistent_connections = OFF;

/* Sal criptográfica obligatoria desde 2.26 (error 2900 si falta o es corta) */
\$g_crypto_master_salt    = '${MANTIS_CRYPTO_SALT}';

/* Sin SMTP: las notificaciones las maneja n8n (§13), no Mantis */
\$g_enable_email_notification = OFF;
\$g_allow_signup          = OFF;
\$g_allow_anonymous_login = OFF;
\$g_default_language      = 'english';

/* Logs: se dejan en el error log de Apache (visible con `docker compose logs`).
   No se fija $g_log_level acá porque las constantes LOG_* todavía no están
   definidas cuando se carga este archivo (provoca "Undefined constant"). */

/* Endurecimiento básico (§14) */
\$g_allow_file_upload     = ON;
\$g_max_file_size         = 5000000;
\$g_session_expiry        = 14400;
EOF
  chown www-data:www-data "$CONF"
  chmod 640 "$CONF"
  echo "[mantis] config_inc.php generado"
fi

exec "$@"
