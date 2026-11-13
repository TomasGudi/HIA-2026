# Mantis Bug Tracker sobre PostgreSQL (§11)
#
# Por qué una imagen propia y no una comunitaria:
#  - no existe imagen oficial de MantisBT en Docker Hub
#  - las comunitarias no fijan versión ni tienen mantenimiento verificable
#    (riesgo de cadena de suministro, §14)
#  - acá la versión queda clavada por ARG y el build es reproducible
FROM php:8.3-apache

ARG MANTIS_VERSION=2.28.4

# Extensiones que MantisBT necesita: pgsql, mbstring, gd, xml, curl, zip, intl
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
      libzip-dev libcurl4-openssl-dev libonig-dev libxml2-dev \
      libicu-dev unzip curl ca-certificates \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" pgsql pdo_pgsql mbstring gd xml curl zip intl \
 && rm -rf /var/lib/apt/lists/*

# Código fuente de la release exacta.
# Se usa el paquete oficial de SourceForge y no el tarball de GitHub porque
# este último NO incluye vendor/ (MantisBT 2.28 usa Composer) y el instalador
# falla con "Failed opening required vendor/autoload.php".
RUN curl -fsSL "https://downloads.sourceforge.net/project/mantisbt/mantis-stable/${MANTIS_VERSION}/mantisbt-${MANTIS_VERSION}.tar.gz" -o /tmp/mantis.tgz \
 && tar -xzf /tmp/mantis.tgz -C /tmp \
 && cp -a "/tmp/mantisbt-${MANTIS_VERSION}/." /var/www/html/ \
 && rm -rf /tmp/mantis* \
 && a2enmod rewrite headers \
 && chown -R www-data:www-data /var/www/html

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# El instalador (/admin) queda bloqueado: es la puerta que §14 marca como hallazgo.
# Para una actualización de esquema se habilita temporalmente con:
#   docker compose exec mantis a2disconf mantis-admin && docker compose restart mantis
RUN printf '<Directory /var/www/html/admin>\n    Require all denied\n</Directory>\n' \
      > /etc/apache2/conf-available/mantis-admin.conf \
 && a2enconf mantis-admin

# La configuración se genera en el arranque desde variables de entorno:
# nunca queda una contraseña dentro de la imagen.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD curl -fsS http://127.0.0.1/login_page.php || exit 1
