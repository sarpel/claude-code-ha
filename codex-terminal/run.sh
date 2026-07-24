#!/usr/bin/with-contenv bashio

# Enable strict error handling
set -e
set -o pipefail

# Initialize environment for OpenAI Codex CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local codex_home="/data/.config/codex"
    local gh_config_dir="/data/.config/gh"
    local persist_root="/data/packages"
    local persist_bin="$persist_root/bin"
    local persist_lib="$persist_root/lib"
    local persist_python="$persist_root/python"

    bashio::log.info "Initializing Codex CLI environment in /data..."

    # Create all required directories.
    # CODEX_HOME must exist before codex runs: when the env var is set,
    # Codex requires the directory to be present.
    if ! mkdir -p "$data_home" "$codex_home" "$config_dir/gh" "$cache_dir" "$state_dir" "/data/.local" \
                  "$persist_bin" "$persist_lib" "$persist_python"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set permissions (codex_home holds auth.json -> keep it private)
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$gh_config_dir" \
              "$persist_root" "$persist_bin" "$persist_lib" "$persist_python"
    chmod 700 "$codex_home"

    # Persistent override location: /data/home/.local/bin is first in PATH,
    # so a codex binary there supersedes the image-baked /usr/local/bin/codex.
    local native_bin_dir="$data_home/.local/bin"
    if [ ! -d "$native_bin_dir" ]; then
        mkdir -p "$native_bin_dir"
    fi

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # Codex-specific environment variables (auth.json, config.toml, sessions/)
    export CODEX_HOME="$codex_home"

    # GitHub CLI persistent configuration
    export GH_CONFIG_DIR="$gh_config_dir"

    # Get dangerous-bypass configuration
    local dangerously_bypass
    dangerously_bypass=$(bashio::config 'dangerously_bypass_approvals' 'false')
    export CODEX_DANGEROUS_MODE="$dangerously_bypass"

    # Setup persistent package paths (HIGHEST PRIORITY)
    export PATH="$persist_bin:$persist_python/venv/bin:$data_home/.local/bin:$PATH"
    export LD_LIBRARY_PATH="$persist_lib:${LD_LIBRARY_PATH:-}"
    export PKG_CONFIG_PATH="$persist_lib/pkgconfig:${PKG_CONFIG_PATH:-}"

    # Python virtual environment if it exists
    if [ -d "$persist_python/venv" ]; then
        export VIRTUAL_ENV="$persist_python/venv"
        bashio::log.info "  - Python venv: active"
    fi

    # Create profile script for persistent environment variables
    # This ensures ALL bash sessions (including ttyd shells) have correct PATH
    cat > /etc/profile.d/persistent-packages.sh << 'PROFILE_EOF'
# Persistent package environment - auto-loaded for all bash sessions
export HOME="/data/home"
export XDG_CONFIG_HOME="/data/.config"
export XDG_CACHE_HOME="/data/.cache"
export XDG_STATE_HOME="/data/.local/state"
export XDG_DATA_HOME="/data/.local/share"
export CODEX_HOME="/data/.config/codex"

# GitHub CLI persistent configuration
export GH_CONFIG_DIR="/data/.config/gh"

# Persistent package paths and Codex override binary (HIGHEST PRIORITY)
export PATH="/data/packages/bin:/data/packages/python/venv/bin:/data/home/.local/bin:$PATH"
export LD_LIBRARY_PATH="/data/packages/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/data/packages/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Python virtual environment if it exists
if [ -d "/data/packages/python/venv" ]; then
    export VIRTUAL_ENV="/data/packages/python/venv"
fi
PROFILE_EOF

    chmod 644 /etc/profile.d/persistent-packages.sh
    bashio::log.info "  - Profile script created: /etc/profile.d/persistent-packages.sh"

    # Install Codex global instructions (AGENTS.md) on first start
    if [ -f "/opt/codex-config/AGENTS.md" ] && [ ! -f "$codex_home/AGENTS.md" ]; then
        cp /opt/codex-config/AGENTS.md "$codex_home/AGENTS.md"
        bashio::log.info "  - Codex global AGENTS.md installed"
    fi

    bashio::log.info "Environment initialized:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Codex home: $CODEX_HOME"
    bashio::log.info "  - GitHub config: $GH_CONFIG_DIR"
    bashio::log.info "  - Cache: $XDG_CACHE_HOME"
    bashio::log.info "  - Persistent packages: $persist_root"
}

# Install required tools
install_tools() {
    bashio::log.info "Installing additional tools..."
    if ! apk add --no-cache ttyd jq curl; then
        bashio::log.error "Failed to install required tools"
        exit 1
    fi
    bashio::log.info "Tools installed successfully"
}

# Configure optional persistent Codex override.
#
# The override installs into $HOME/.local/bin (/data/home/.local/bin) — the
# highest-priority "codex" location in PATH (see init_environment). Installing
# there means the persistent binary cleanly supersedes the image-baked one, and
# because /data is persistent + writable, the install survives container restarts.
setup_persistent_codex() {
    local use_persistent_codex
    local auto_update_codex_on_start
    local target_bin="/data/home/.local/bin/codex"

    use_persistent_codex=$(bashio::config 'use_persistent_codex' 'false')
    auto_update_codex_on_start=$(bashio::config 'auto_update_codex_on_start' 'false')

    if [ "$use_persistent_codex" != "true" ]; then
        bashio::log.info "Persistent Codex override: disabled (using image-baked Codex CLI)"
        return 0
    fi

    if [ "$auto_update_codex_on_start" = "true" ]; then
        bashio::log.info "Persistent Codex override: downloading latest Codex CLI into /data/home/.local/bin..."
        if install_codex_release "$target_bin"; then
            bashio::log.info "Persistent Codex override: install/update completed"
        else
            bashio::log.warning "Persistent Codex override: install/update failed; falling back to existing version if present"
        fi
    fi

    if [ -x "$target_bin" ]; then
        bashio::log.info "Persistent Codex override active: $("$target_bin" --version 2>/dev/null || echo 'version unknown') ($target_bin)"
    else
        bashio::log.warning "Persistent Codex override enabled but no Codex binary at $target_bin"
        bashio::log.warning "Enable 'auto_update_codex_on_start', or install once from a shell:"
        bashio::log.warning "  codex-update"
    fi
}

# Download the latest Codex musl binary from GitHub releases into $1.
# Also exposed to terminal sessions as /usr/local/bin/codex-update.
install_codex_release() {
    local target_bin="$1"
    local triple
    local tmp_dir

    case "$(uname -m)" in
        x86_64)  triple="x86_64-unknown-linux-musl" ;;
        aarch64) triple="aarch64-unknown-linux-musl" ;;
        *)
            bashio::log.error "Unsupported architecture for Codex: $(uname -m)"
            return 1
            ;;
    esac

    tmp_dir=$(mktemp -d)
    if curl -fsSL -o "$tmp_dir/codex.tar.gz" \
        "https://github.com/openai/codex/releases/latest/download/codex-${triple}.tar.gz" \
        && tar -xzf "$tmp_dir/codex.tar.gz" -C "$tmp_dir"; then
        mkdir -p "$(dirname "$target_bin")"
        rm -f "$target_bin"
        mv "$tmp_dir"/codex-* "$target_bin" 2>/dev/null || mv "$tmp_dir"/codex "$target_bin"
        chmod +x "$target_bin"
        rm -rf "$tmp_dir"
        return 0
    fi

    rm -rf "$tmp_dir"
    return 1
}

# Log in to OpenAI with an API key from the add-on options (headless-friendly).
# Runs only when a key is configured and no valid login exists yet, so a
# ChatGPT-plan login done manually is never overwritten.
setup_openai_auth() {
    local api_key
    api_key=$(bashio::config 'openai_api_key' '')

    if [ -z "$api_key" ] || [ "$api_key" = "null" ]; then
        bashio::log.info "OpenAI auth: no API key configured (log in from the terminal with 'codex login')"
        return 0
    fi

    if codex login status >/dev/null 2>&1; then
        bashio::log.info "OpenAI auth: already logged in (keeping existing credentials)"
        return 0
    fi

    bashio::log.info "OpenAI auth: logging in with the configured API key..."
    if printf '%s' "$api_key" | codex login --with-api-key >/dev/null 2>&1; then
        bashio::log.info "OpenAI auth: API key login successful (persisted in $CODEX_HOME/auth.json)"
        find "$CODEX_HOME" -name 'auth.json' -exec chmod 600 {} \; 2>/dev/null || true
    else
        bashio::log.warning "OpenAI auth: API key login failed; use the auth helper in the session picker"
    fi
}

# Setup session picker and helper scripts
setup_session_picker() {
    # Copy session picker script from built-in location
    if [ -f "/opt/scripts/codex-session-picker.sh" ]; then
        if ! cp /opt/scripts/codex-session-picker.sh /usr/local/bin/codex-session-picker; then
            bashio::log.error "Failed to copy codex-session-picker script"
            exit 1
        fi
        chmod +x /usr/local/bin/codex-session-picker
        bashio::log.info "Session picker script installed successfully"
    else
        bashio::log.warning "Session picker script not found, using auto-launch mode only"
    fi

    # Setup authentication helper if it exists
    if [ -f "/opt/scripts/codex-auth-helper.sh" ]; then
        chmod +x /opt/scripts/codex-auth-helper.sh
        bashio::log.info "Authentication helper script ready"
    fi

    # Small helper so users can update the persistent override manually
    cat > /usr/local/bin/codex-update << 'UPDATE_EOF'
#!/bin/bash
# Download the latest Codex CLI musl binary into /data/home/.local/bin/codex
set -e
case "$(uname -m)" in
    x86_64)  TRIPLE="x86_64-unknown-linux-musl" ;;
    aarch64) TRIPLE="aarch64-unknown-linux-musl" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
echo "Downloading latest Codex CLI (${TRIPLE})..."
curl -fsSL -o "$TMP_DIR/codex.tar.gz" \
    "https://github.com/openai/codex/releases/latest/download/codex-${TRIPLE}.tar.gz"
tar -xzf "$TMP_DIR/codex.tar.gz" -C "$TMP_DIR"
mkdir -p /data/home/.local/bin
rm -f /data/home/.local/bin/codex
mv "$TMP_DIR"/codex-* /data/home/.local/bin/codex 2>/dev/null || mv "$TMP_DIR"/codex /data/home/.local/bin/codex
chmod +x /data/home/.local/bin/codex
echo "Installed: $(/data/home/.local/bin/codex --version)"
echo "Note: this persistent copy takes effect when 'use_persistent_codex' is enabled (it is first in PATH)."
UPDATE_EOF
    chmod +x /usr/local/bin/codex-update
}

# Setup persistent package manager
setup_persistent_packages() {
    # Install persist-install command globally
    if [ -f "/opt/scripts/persist-install" ]; then
        cp /opt/scripts/persist-install /usr/local/bin/persist-install
        chmod +x /usr/local/bin/persist-install
        bashio::log.info "Persistent package manager installed: 'persist-install'"
    fi

    # Auto-install packages from configuration.
    # Never let package installation abort startup (set -e): a bad package name
    # must not put the add-on into a restart loop.
    auto_install_packages || bashio::log.warning "Package auto-install step failed; continuing startup"
}

# Auto-install packages from add-on configuration
#
# NOTE: for a list option, bashio::config returns the array *elements*, one per
# line (see bashio's lib/config.sh: `.key[]`) - it does NOT return a JSON array.
# Feeding that back into `jq -r '.[]'` made jq fail with a parse error, and with
# `set -e` + `pipefail` that killed run.sh before the terminal ever started.
auto_install_packages() {
    local apk_packages
    local pip_packages
    local pkg
    local all_packages

    apk_packages=$(bashio::config 'persistent_apk_packages' '')
    pip_packages=$(bashio::config 'persistent_pip_packages' '')

    # Check if any packages are configured
    if [ -n "$apk_packages" ] && [ "$apk_packages" != "null" ]; then
        bashio::log.info "Auto-installing system packages from config..."

        while read -r pkg; do
            if [ -n "$pkg" ]; then
                bashio::log.info "  Installing: $pkg"
                /usr/local/bin/persist-install "$pkg" || bashio::log.warning "Failed to install: $pkg"
            fi
        done <<< "$apk_packages"
    fi

    # Check if any Python packages are configured
    if [ -n "$pip_packages" ] && [ "$pip_packages" != "null" ]; then
        bashio::log.info "Auto-installing Python packages from config..."

        # Collect all package names onto a single line
        all_packages=$(echo "$pip_packages" | tr '\n' ' ')

        if [ -n "${all_packages// /}" ]; then
            bashio::log.info "  Installing: $all_packages"
            /usr/local/bin/persist-install --python $all_packages || bashio::log.warning "Failed to install Python packages"
        fi
    fi
}

# Determine Codex launch command based on configuration
# Session picker handles its own loop, so Codex exiting returns to the menu
get_codex_launch_command() {
    local auto_launch_codex
    local dangerously_bypass
    local codex_flags=""

    # Get configuration values
    auto_launch_codex=$(bashio::config 'auto_launch_codex' 'true')
    dangerously_bypass=$(bashio::config 'dangerously_bypass_approvals' 'false')

    # Build Codex flags
    if [ "$dangerously_bypass" = "true" ]; then
        codex_flags="--dangerously-bypass-approvals-and-sandbox"
        bashio::log.warning "Codex will run with --dangerously-bypass-approvals-and-sandbox (no approvals, no sandbox)"
    fi

    if [ "$auto_launch_codex" = "true" ]; then
        # Auto-launch Codex first, then fall back to session picker on exit
        if [ -f /usr/local/bin/codex-session-picker ]; then
            echo "clear && echo 'Welcome to Codex Terminal!' && echo '' && echo 'Starting Codex...' && sleep 1 && codex ${codex_flags}; /usr/local/bin/codex-session-picker"
        else
            echo "clear && echo 'Welcome to Codex Terminal!' && echo '' && echo 'Starting Codex...' && sleep 1 && codex ${codex_flags}"
        fi
    else
        # Show interactive session picker (has its own while-true loop)
        if [ -f /usr/local/bin/codex-session-picker ]; then
            echo "clear && /usr/local/bin/codex-session-picker"
        else
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            echo "clear && echo 'Welcome to Codex Terminal!' && echo '' && echo 'Starting Codex...' && sleep 1 && codex"
        fi
    fi
}

# Write an unobtrusive tmux config, unless the user already has one.
#
# The goal is for tmux to be invisible: no status bar, native-feeling scroll,
# and a terminal type that keeps true colour working for the CLI's TUI.
write_tmux_config() {
    local config_file="${HOME}/.tmux.conf"

    if [ -f "$config_file" ]; then
        bashio::log.info "  - tmux: using existing ${config_file}"
        return 0
    fi

    cat > "$config_file" << 'TMUX_EOF'
# Minimal config so the persistent session stays out of the way.
set -g status off
set -g mouse on
set -g history-limit 50000
set -sg escape-time 0
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*:Tc"
setw -g aggressive-resize on
set -g destroy-unattached off
TMUX_EOF
    chmod 644 "$config_file"
    bashio::log.info "  - tmux: default config written to ${config_file}"
}

# Keep the CLI running when the browser disconnects.
#
# ttyd starts a *new* process for every websocket connection, so closing the
# dashboard (or a background tab being throttled until the socket drops) would
# otherwise kill the running Codex session - reconnecting then lands in a fresh
# one. Running inside tmux decouples the two: the connection carries a tmux
# client, while the session itself keeps running in the background, and a
# reconnect re-attaches to it with its scrollback and state intact.
wrap_launch_command() {
    local inner="$1"
    local session="codex"
    local persistent_session

    persistent_session=$(bashio::config 'persistent_terminal_session' 'true')

    if [ "$persistent_session" != "true" ]; then
        bashio::log.info "Persistent terminal session: disabled (a dropped connection restarts Codex)"
        echo "$inner"
        return 0
    fi

    if ! command -v tmux > /dev/null 2>&1; then
        bashio::log.warning "Persistent terminal session enabled but tmux is missing; falling back to a plain shell"
        echo "$inner"
        return 0
    fi

    # Write the command to a launcher script instead of nesting it in more
    # quotes: it travels through ttyd -> bash -c -> tmux -> bash, and the
    # command itself already contains single quotes.
    printf '#!/bin/bash\n%s\n' "$inner" > /usr/local/bin/codex-launch
    chmod +x /usr/local/bin/codex-launch

    write_tmux_config

    bashio::log.info "Persistent terminal session: enabled (tmux session '${session}')"
    # -A: attach to the session if it exists, create it otherwise
    # -D: detach any stale client, so a dead connection cannot shrink the window
    # -u: force UTF-8, keeps the CLI's box drawing intact
    echo "tmux -u new-session -A -D -s ${session} /usr/local/bin/codex-launch"
}


# Start image upload service
start_image_service() {
    local image_port=7680
    local ttyd_port=7681
    local upload_dir="/data/images"
    local service_dir="/opt/image-service"
    local server_file="${service_dir}/server.js"

    bashio::log.info "Starting image upload service on port ${image_port}..."

    # Create upload directory if it doesn't exist
    mkdir -p "${upload_dir}"
    chmod 755 "${upload_dir}"

    # Export environment variables for the image service
    export IMAGE_SERVICE_PORT="${image_port}"
    export TTYD_PORT="${ttyd_port}"
    export UPLOAD_DIR="${upload_dir}"

    # Check if server.js exists
    if [ ! -f "${server_file}" ]; then
        bashio::log.error "server.js not found at ${server_file}"
        ls -la "${service_dir}"
        return 1
    fi

    # Check if node_modules exists
    if [ ! -d "${service_dir}/node_modules" ]; then
        bashio::log.error "node_modules not found in ${service_dir}"
        bashio::log.info "Attempting to install dependencies..."
        cd "${service_dir}" && npm install || bashio::log.error "npm install failed"
        cd - > /dev/null
    fi

    # Start with better error logging (run from current directory with absolute path)
    bashio::log.info "Starting Node.js service from ${server_file}..."
    # Output is forwarded through a process substitution instead of a pipeline so
    # that $! is the node PID itself; with a pipeline it would be the log-reader
    # subshell, which stays alive even after node dies and would make the health
    # check below always succeed.
    node "${server_file}" > >(while IFS= read -r line; do
        bashio::log.info "[Image Service] $line"
    done) 2>&1 &

    # Store the PID for potential cleanup
    local image_service_pid=$!
    bashio::log.info "Image service started (PID: ${image_service_pid})"

    # Give it a moment to start
    sleep 3

    # Check if it's running
    if kill -0 "${image_service_pid}" 2>/dev/null; then
        bashio::log.info "Image service is running successfully"
    else
        bashio::log.error "Image service failed to start! Check logs above for errors"
        return 1
    fi
}

# Start main web terminal
start_web_terminal() {
    local port=7681
    bashio::log.info "Starting web terminal on port ${port}..."

    # Log environment information for debugging
    bashio::log.info "Environment variables:"
    bashio::log.info "CODEX_HOME=${CODEX_HOME}"
    bashio::log.info "HOME=${HOME}"

    # Get the appropriate launch command based on configuration, then keep it
    # alive across browser disconnects (tmux)
    local launch_command
    launch_command=$(get_codex_launch_command)
    launch_command=$(wrap_launch_command "$launch_command")

    # Log the configuration being used
    local auto_launch_codex
    auto_launch_codex=$(bashio::config 'auto_launch_codex' 'true')
    bashio::log.info "Auto-launch Codex: ${auto_launch_codex}"

    # Start the image upload service first
    start_image_service

    # Run ttyd with keepalive, reconnect and typography configuration
    # --ping-interval 30: WebSocket ping every 30s (default 300s) to prevent idle disconnects
    # --client-option reconnect=5: xterm.js auto-reconnect after 5 seconds on disconnect
    # --client-option fontSize=15: ttyd's own default is 13, which reads small in
    #   the dashboard iframe
    # --client-option fontFamily: Ubuntu Mono is served by the image-service
    #   (see server.js), the rest is a fallback chain of fonts commonly present
    #   on Windows/macOS/Linux clients
    exec ttyd \
        --port "${port}" \
        --interface 0.0.0.0 \
        --writable \
        --ping-interval 30 \
        --client-option reconnect=5 \
        --client-option fontSize=15 \
        --client-option "fontFamily=Ubuntu Mono, Cascadia Mono, DejaVu Sans Mono, Consolas, Liberation Mono, Menlo, monospace" \
        bash -c "$launch_command"
}

# Run health check
run_health_check() {
    if [ -f "/opt/scripts/health-check.sh" ]; then
        bashio::log.info "Running system health check..."
        chmod +x /opt/scripts/health-check.sh
        /opt/scripts/health-check.sh || bashio::log.warning "Some health checks failed but continuing..."
    fi
}

# Main execution
main() {
    bashio::log.info "Initializing Codex Terminal add-on..."

    # Run diagnostics first (especially helpful for VirtualBox issues)
    run_health_check

    init_environment
    install_tools
    setup_persistent_codex
    setup_openai_auth
    setup_session_picker
    setup_persistent_packages
    start_web_terminal
}

# Execute main function
main "$@"
