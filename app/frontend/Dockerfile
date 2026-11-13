# Build multi-stage: compila con Node y sirve estático con nginx
# (la imagen final no lleva Node ni npm: menos superficie de ataque, §14)
FROM node:20-alpine AS build
WORKDIR /app

# dependencias primero: aprovecha la caché de capas
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

COPY . .
RUN npm run build

FROM nginx:1.27-alpine
RUN addgroup -S app && adduser -S app -G app \
 && rm -rf /usr/share/nginx/html/*
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# nginx oficial corre como root para abrir :80; lo dejamos documentado como
# decisión pendiente: en §14 se evalúa mover a :8080 sin privilegios.
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
