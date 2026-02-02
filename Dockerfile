FROM node:20-slim

# Labels for metadata
LABEL org.opencontainers.image.title="opencode-sandbox" \
      org.opencontainers.image.description="Sandbox environment for opencode AI agents" \
      org.opencontainers.image.source="https://github.com/fabianlema/opencode-sandbox" \
      org.opencontainers.image.licenses="MIT"

# Arguments and Environment
ARG SANDBOX_NAME="opencode-cli-sandbox"
ENV SANDBOX="$SANDBOX_NAME"
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# 1. Install system packages and configure permissions in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    man-db \
    curl \
    dnsutils \
    less \
    jq \
    bc \
    gh \
    git \
    unzip \
    rsync \
    ripgrep \
    procps \
    psmisc \
    lsof \
    socat \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/local/share/npm-global \
    && chown -R node:node /usr/local/share/npm-global \
    && mkdir -p /repo && chown node:node /repo

# 2. Switch to node user and install opencode
USER node
WORKDIR /repo

RUN npm install -g opencode-ai && npm cache clean --force

# Default command
CMD ["opencode"]
