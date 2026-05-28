# ──────────────────────────────────────────────────────────────────────────────
# Exocore Web — production Docker image (dist/-based)
#
# The dist/ folder is pre-built (TypeScript compiled + obfuscated via
# build-dist.mjs) and committed to the repo, so this image only needs to:
#   1. Install production npm deps (including building node-pty natively)
#   2. Copy dist/ and the static assets that live inside it
#   3. Run: node dist/index.js
#
# Build:  docker build -t exocore:latest .
# Run:    docker run --rm -p 5000:5000 \
#           -v exocore-projects:/app/projects \
#           -v exocore-uploads:/app/uploads  \
#           exocore:latest
# ──────────────────────────────────────────────────────────────────────────────

# ───── Stage 1: install production deps (needs build tools for node-pty) ──────
FROM node:20 AS builder

WORKDIR /app

ENV PUPPETEER_SKIP_DOWNLOAD=1 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false

RUN apt-get update \
 && apt-get install -y \
        python3 make g++ ca-certificates \
        build-essential cmake \
        curl wget git \
        gcc gdb \
        libc6-dev libssl-dev \
 && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm install --omit=dev --legacy-peer-deps --no-audit --no-fund

# ───── Stage 2: runtime - fully root, no restrictions ─────────────────────────
FROM node:20 AS runner

LABEL org.opencontainers.image.title="Exocore IDE"
LABEL org.opencontainers.image.description="Browser-based IDE — full stack, any language"
LABEL org.opencontainers.image.version="5.0.0"

ENV NODE_ENV=production \
    PORT=5000 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 \
    NODE_OPTIONS="--max-old-space-size=384"

RUN apt-get update \
 && apt-get install -y \
        ca-certificates curl tini procps \
        bash coreutils \
        git unzip zip \
        python3 python3-pip python3-venv \
        sudo vim nano htop \
        build-essential gcc g++ make \
        openssh-client \
        wget net-tools \
        strace ltrace \
        gdb valgrind \
        tree jq \
        rsync \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /var/cache/apt/archives/*

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY dist/ ./dist/
COPY package.json ./

RUN mkdir -p \
        /app/projects \
        /app/projects_archive \
        /app/uploads/temp \
        /app/uploads/avatars \
        /tmp/exo-cache

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=25s --retries=3 \
    CMD curl -f http://localhost:${PORT}/exocore/api/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "dist/index.js"]
