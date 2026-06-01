FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy workspace files
COPY pnpm-workspace.yaml package.json ./
COPY apps/backend/package.json apps/backend/

RUN pnpm install --filter backend --no-frozen-lockfile

COPY apps/backend ./apps/backend

RUN cd apps/backend && pnpm build

# ---- Runtime ----
FROM node:20-alpine

WORKDIR /app

RUN npm install -g pnpm

COPY pnpm-workspace.yaml package.json ./
COPY apps/backend/package.json apps/backend/

RUN pnpm install --filter backend --no-frozen-lockfile --prod

COPY --from=builder /app/apps/backend/dist ./apps/backend/dist

EXPOSE 3000

CMD ["node", "apps/backend/dist/server.js"]
