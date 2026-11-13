# Backend (API RealWorld) — build multi-stage
#
# Etapa 1 compila con Nx y genera el cliente Prisma.
# Etapa 2 solo lleva el resultado + dependencias de producción: la imagen final
# no tiene toolchain de build ni devDependencies (menos superficie, §14).

FROM node:20 AS build
WORKDIR /app

# dependencias primero (caché de capas)
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .

# El schema de Prisma está en src/prisma/schema.prisma (ubicación no estándar),
# así que el postinstall de @prisma/client no lo detecta: se genera explícito.
RUN npx prisma generate --schema=src/prisma/schema.prisma

RUN npm run build

# ---------------------------------------------------------------------------

FROM node:20-slim AS runtime
WORKDIR /app

# Prisma necesita OpenSSL en runtime
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

# Nx genera package.json + lockfile en dist/api: se instalan SOLO deps de prod
COPY --from=build /app/dist/api/package.json /app/dist/api/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# Código compilado (main.js + src/ con los módulos)
COPY --from=build /app/dist/api ./

# Cliente Prisma generado en la etapa de build
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/node_modules/@prisma ./node_modules/@prisma

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "main.js"]
