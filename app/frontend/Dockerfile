# Build multi-stage: compila con Node y sirve estático con nginx
# (la imagen final no lleva Node ni npm: menos superficie de ataque, §14)
FROM node:20-alpine AS build
WORKDIR /app

# dependencias primero: aprovecha la caché de capas.
# `npm ci` (no `npm install`) exige el lockfile y garantiza build reproducible (§8).
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN npm run build

# §14: imagen "unprivileged" de nginx. Corre como uid 101 (no root) y
# escucha en 8080, que es un puerto no privilegiado.
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY security-headers.conf /etc/nginx/snippets/security-headers.conf

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
