FROM node:22-alpine AS base
# pnpm 11 requires Node 22+ (node:sqlite built-in)
RUN corepack enable && corepack prepare pnpm@11.5.0 --activate

FROM base AS deps
WORKDIR /app
COPY package.json .npmrc ./
RUN pnpm install --prod --no-strict-peer-dependencies

FROM base AS build
WORKDIR /app
COPY package.json .npmrc tsconfig.json ./
RUN pnpm install --no-strict-peer-dependencies
COPY src ./src
RUN pnpm build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/server.js"]
