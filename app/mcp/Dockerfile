# Servidor MCP de la aplicación (§ extra: agente Hermes)
#
# Imagen mínima: solo dependencias de producción y usuario sin privilegios.
FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY src ./src

# §14: no corre como root
USER node

ENV NODE_ENV=production \
    MCP_PORT=8080

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

CMD ["node", "src/server.mjs"]
