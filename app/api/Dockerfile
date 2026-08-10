# =============================================================================
# ShortLink API - multi-stage build
# Stage 1: install dependencies (including dev deps for future use)
# Stage 2: runtime image, minimal and non-root
# =============================================================================

FROM node:26-alpine AS build

WORKDIR /app

# Leverage Docker layer caching: install deps first, copy source after
COPY package.json package-lock.json ./
RUN npm ci

# Copy the rest of the source
COPY src ./src

# Remove dev dependencies so the runtime image stays small and secure
RUN npm prune --omit=dev

# =============================================================================
FROM node:26-alpine AS runtime

ENV NODE_ENV=production \
    APP_VERSION=1.0.0

WORKDIR /app

# Never run as root in production
USER node

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/src ./src
COPY --from=build --chown=node:node /app/package.json ./

EXPOSE 3000 9100

# Container-level healthcheck (used by Docker, orchestrators use probes)
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health/live || exit 1

CMD ["node", "src/server.js"]
