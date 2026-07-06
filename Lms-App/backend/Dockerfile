# ============================================================
# Application Tier Dockerfile - Node.js business logic API
# Multi-stage build: builder installs deps, runtime stays lean
# ============================================================

# ---------- Stage 1: builder ----------
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
# Full install (would include devDependencies too, if/when you add
# TypeScript, a linter, or an in-image test run)
RUN npm install --omit=dev

COPY src ./src

# ---------- Stage 2: runtime ----------
FROM node:20-alpine AS runtime
WORKDIR /app

# Only copy what's needed to run the app - no build tools, no caches
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src

# Run as a non-root user for better container security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

ENV NODE_ENV=production \
    PORT=5000

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "src/server.js"]
