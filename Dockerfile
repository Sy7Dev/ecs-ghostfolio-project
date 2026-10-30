
# ==========================================
# Build stage
# ==========================================
FROM node:22 AS builder

WORKDIR /ghostfolio

# Copy dependency manifests and configuration
COPY app/package.json package.json
COPY app/package-lock.json package-lock.json
COPY app/.config/ .config/
COPY app/CHANGELOG.md CHANGELOG.md
COPY app/prisma/schema.prisma prisma/schema.prisma

# Install dependencies
RUN npm ci

# Copy application source
COPY app/apps/ apps/
COPY app/libs/ libs/
COPY app/jest.config.ts jest.config.ts
COPY app/jest.preset.js jest.preset.js
COPY app/nx.json nx.json
COPY app/tools/replace.build.mjs replace.build.mjs
COPY app/tsconfig.base.json tsconfig.base.json

ENV NX_DAEMON=false

# Build production application without Storybook
RUN npx nx run api:copy-assets && \
    npx nx run api:build:production && \
    npx nx run client:copy-assets && \
    npx nx run client:build:production && \
    npm run replace-placeholders-in-build

# ==========================================
# Production dependencies
# ==========================================
WORKDIR /ghostfolio/dist/apps/api

COPY app/package-lock.json package-lock.json

RUN npm ci

COPY app/.config/ .config/
COPY app/prisma/ prisma/

# Generate database typings
COPY app/package.json package.json

RUN npm run database:generate-typings

# ==========================================
# Production runtime
# ==========================================
FROM node:22 AS production

LABEL org.opencontainers.image.source="https://github.com/Sy7Dev/ecs-ghostfolio-project"

ENV NODE_ENV=production

COPY --chown=node:node --from=builder /ghostfolio/dist/apps/ /ghostfolio/apps/

COPY --chown=node:node app/docker/entrypoint.sh /ghostfolio/entrypoint.sh

WORKDIR /ghostfolio/apps/api

EXPOSE 3333

USER node

CMD ["/ghostfolio/entrypoint.sh"]
