ARG BUILD_FROM
FROM ${BUILD_FROM}

# Install packages in a single layer to minimize image size
# Node.js and npm kept for image-service dependency (and the npm fallback install)
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    curl \
    nano \
    python3 \
    py3-pip \
    py3-requests \
    py3-aiohttp \
    py3-yaml \
    py3-beautifulsoup4 \
    jq \
    yq \
    git \
    vim \
    wget \
    tree \
    ripgrep \
    libgcc \
    libstdc++

# Cache-bust for the Codex CLI install layer below.
# The GitHub "latest release" API response changes whenever a new Codex release
# ships, which invalidates this and every following layer on rebuild, forcing the
# installer to fetch the newest version instead of reusing a stale cached layer.
ADD https://api.github.com/repos/openai/codex/releases/latest /tmp/codex-latest.json

# Install OpenAI Codex CLI (latest release)
# Download the static musl binary from GitHub releases (works on Alpine).
# Falls back to npm if the download fails; the npm package vendors the same binaries.
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
        amd64)  CODEX_TRIPLE="x86_64-unknown-linux-musl" ;; \
        arm64)  CODEX_TRIPLE="aarch64-unknown-linux-musl" ;; \
        *)      echo "Unsupported architecture for Codex: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    ( \
      echo "Installing Codex CLI ($(jq -r '.tag_name' /tmp/codex-latest.json 2>/dev/null || echo latest)) for ${CODEX_TRIPLE}..." && \
      mkdir -p /tmp/codex-extract && \
      curl -fsSL -o /tmp/codex.tar.gz \
        "https://github.com/openai/codex/releases/latest/download/codex-${CODEX_TRIPLE}.tar.gz" && \
      tar -xzf /tmp/codex.tar.gz -C /tmp/codex-extract && \
      mv /tmp/codex-extract/codex* /usr/local/bin/codex && \
      chmod +x /usr/local/bin/codex && \
      rm -rf /tmp/codex.tar.gz /tmp/codex-extract && \
      /usr/local/bin/codex --version \
    ) || npm install -g @openai/codex@latest

# Install Home Assistant CLI (ha command)
# Download appropriate binary based on build architecture
# Automatically fetches the latest version from GitHub
RUN case "${TARGETARCH}" in \
        amd64)   HA_ARCH="amd64" ;; \
        arm64)   HA_ARCH="aarch64" ;; \
        *)       echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "Fetching latest Home Assistant CLI version..." && \
    HA_VERSION=$(curl -fsSL https://api.github.com/repos/home-assistant/cli/releases/latest | jq -r '.tag_name') && \
    echo "Installing Home Assistant CLI ${HA_VERSION} for ${HA_ARCH}..." && \
    curl -fsSL -o /usr/bin/ha \
        "https://github.com/home-assistant/cli/releases/download/${HA_VERSION}/ha_${HA_ARCH}" && \
    chmod +x /usr/bin/ha && \
    echo "Home Assistant CLI ${HA_VERSION} installed successfully"

# Install GitHub CLI (gh command)
# Download appropriate binary based on build architecture
RUN case "${TARGETARCH}" in \
        amd64)   GH_ARCH="amd64" ;; \
        arm64)   GH_ARCH="arm64" ;; \
        *)       echo "Unsupported architecture for gh: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "Fetching latest GitHub CLI version..." && \
    GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    echo "Installing GitHub CLI v${GH_VERSION} for ${GH_ARCH}..." && \
    curl -fsSL -o /tmp/gh.tar.gz \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" && \
    tar -xzf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh /usr/bin/gh && \
    chmod +x /usr/bin/gh && \
    rm -rf /tmp/gh* && \
    echo "GitHub CLI v${GH_VERSION} installed successfully"

WORKDIR /config

# Copy and install image service
COPY image-service/ /opt/image-service/
RUN cd /opt/image-service \
    && npm install --production --no-optional \
    && npm cache clean --force \
    && chmod +x server.js

# Copy startup script, modular scripts, and Codex global instructions
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
COPY codex-config/ /opt/codex-config/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
