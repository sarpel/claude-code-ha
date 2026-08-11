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
    tmux \
    ripgrep \
    libgcc \
    libstdc++

# Cache-bust for the Codex CLI install layer below.
# The GitHub "latest release" API response changes whenever a new Codex release
# ships, which invalidates this and every following layer on rebuild, forcing the
# installer to fetch the newest version instead of reusing a stale cached layer.
ADD https://api.github.com/repos/openai/codex/releases/latest /tmp/codex-latest.json

# Install the complete OpenAI Codex package (latest release).
# The package includes companion executables such as codex-code-mode-host;
# installing only the standalone codex binary makes Code Mode fail closed.
ARG TARGETARCH
RUN npm install -g @openai/codex@latest \
    && CODEX_PACKAGE_ROOT="$(npm root -g)/@openai/codex" \
    && CODE_MODE_HOST="$(find "$CODEX_PACKAGE_ROOT" -type f -name codex-code-mode-host -print -quit)" \
    && test -x "$CODE_MODE_HOST" \
    && codex --version \
    && "$CODE_MODE_HOST" --help >/dev/null

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

# Bundle Ubuntu Mono for the terminal.
# The font is rendered by the browser, not the container, so it has to be
# self-hosted and served to the client - the image-service injects an
# @font-face rule into the ttyd page (see server.js).
# Licence: Ubuntu Font Licence 1.0 (redistribution permitted); UFL.txt ships
# alongside the fonts. A download failure is not fatal: the terminal then falls
# back to the local monospace stack configured in run.sh.
RUN mkdir -p /opt/image-service/public/fonts \
    && for f in UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf UFL.txt; do \
         curl -fsSL -o "/opt/image-service/public/fonts/$f" \
           "https://raw.githubusercontent.com/google/fonts/main/ufl/ubuntumono/$f" \
         || echo "WARNING: could not fetch $f - terminal will use fallback fonts"; \
       done \
    && ls -l /opt/image-service/public/fonts/

# Copy startup script, modular scripts, and Codex global instructions
COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
COPY codex-config/ /opt/codex-config/
RUN chmod +x /run.sh \
    && chmod +x /opt/scripts/*.sh

# Use exec form for better signal handling
CMD ["/run.sh"]
