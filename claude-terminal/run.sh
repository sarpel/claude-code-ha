#!/usr/bin/with-contenv bashio

# Enable strict error handling
set -e
set -o pipefail

# Initialize environment for Claude Code CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local claude_config_dir="/data/.config/claude"
    local gh_config_dir="/data/.config/gh"
    local persist_root="/data/packages"
    local persist_bin="$persist_root/bin"
    local persist_lib="$persist_root/lib"
    local persist_python="$persist_root/python"

    bashio::log.info "Initializing Claude Code environment in /data..."

    # Create all required directories
    if ! mkdir -p "$data_home" "$config_dir/claude" "$config_dir/gh" "$cache_dir" "$state_dir" "/data/.local" \
                  "$persist_bin" "$persist_lib" "$persist_python"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set permissions
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$claude_config_dir" "$gh_config_dir" \
              "$persist_root" "$persist_bin" "$persist_lib" "$persist_python"

    # Ensure Claude native binary is available at $HOME/.local/bin/claude
    # The native installer places it at /root/.local/bin/claude during Docker build,
    # but at runtime HOME=/data/home, so Claude's self-check looks in /data/home/.local/bin/
    local native_bin_dir="$data_home/.local/bin"
    if [ ! -d "$native_bin_dir" ]; then
        mkdir -p "$native_bin_dir"
    fi
    if [ -f /root/.local/bin/claude ] && [ ! -f "$native_bin_dir/claude" ]; then
        ln -sf /root/.local/bin/claude "$native_bin_dir/claude"
        bashio::log.info "  - Claude native binary linked: $native_bin_dir/claude"
    fi

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # Claude-specific environment variables
    export ANTHROPIC_CONFIG_DIR="$claude_config_dir"
    export ANTHROPIC_HOME="/data"

    # Disable auto-updates: binary is baked into the container image,
    # updates are delivered via add-on releases, not CLI self-update
    export DISABLE_AUTOUPDATER=1

    # GitHub CLI persistent configuration
    export GH_CONFIG_DIR="$gh_config_dir"

    # Get dangerously-skip-permissions configuration
    local dangerously_skip_permissions
    dangerously_skip_permissions=$(bashio::config 'dangerously_skip_permissions' 'false')
    export CLAUDE_DANGEROUS_MODE="$dangerously_skip_permissions"

    # Set IS_SANDBOX=1 to allow --dangerously-skip-permissions when running as root
    if [ "$dangerously_skip_permissions" = "true" ]; then
        export IS_SANDBOX=1
    fi

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
export ANTHROPIC_CONFIG_DIR="/data/.config/claude"
export ANTHROPIC_HOME="/data"

# Disable auto-updates inside container (updates via add-on releases)
export DISABLE_AUTOUPDATER=1

# GitHub CLI persistent configuration
export GH_CONFIG_DIR="/data/.config/gh"

# Persistent package paths and native Claude binary (HIGHEST PRIORITY)
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

    # Migrate any existing authentication files from legacy locations
    migrate_legacy_auth_files "$claude_config_dir"

    # Setup Claude Code skills and commands
    if [ -d "/opt/.claude" ]; then
        if [ ! -d "$data_home/.claude" ]; then
            cp -r /opt/.claude "$data_home/.claude"
            bashio::log.info "  - Claude Code skills & commands installed"
        else
            bashio::log.info "  - Claude Code skills & commands: already configured"
        fi
    fi

    bashio::log.info "Environment initialized:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Claude config: $ANTHROPIC_CONFIG_DIR"
    bashio::log.info "  - GitHub config: $GH_CONFIG_DIR"
    bashio::log.info "  - Cache: $XDG_CACHE_HOME"
    bashio::log.info "  - Persistent packages: $persist_root"
}

# One-time migration of existing authentication files
migrate_legacy_auth_files() {
    local target_dir="$1"
    local migrated=false

    bashio::log.info "Checking for existing authentication files to migrate..."

    # Check common legacy locations
    local legacy_locations=(
        "/root/.config/anthropic"
        "/root/.anthropic" 
        "/config/claude-config"
        "/tmp/claude-config"
    )

    for legacy_path in "${legacy_locations[@]}"; do
        if [ -d "$legacy_path" ] && [ "$(ls -A "$legacy_path" 2>/dev/null)" ]; then
            bashio::log.info "Migrating auth files from: $legacy_path"
            
            # Copy files to new location
            if cp -r "$legacy_path"/* "$target_dir/" 2>/dev/null; then
                # Set proper permissions
                find "$target_dir" -type f -exec chmod 600 {} \;
                
                # Create compatibility symlink if this is a standard location
                if [[ "$legacy_path" == "/root/.config/anthropic" ]] || [[ "$legacy_path" == "/root/.anthropic" ]]; then
                    rm -rf "$legacy_path"
                    ln -sf "$target_dir" "$legacy_path"
                    bashio::log.info "Created compatibility symlink: $legacy_path -> $target_dir"
                fi
                
                migrated=true
                bashio::log.info "Migration completed from: $legacy_path"
            else
                bashio::log.warning "Failed to migrate from: $legacy_path"
            fi
        fi
    done

    if [ "$migrated" = false ]; then
        bashio::log.info "No existing authentication files found to migrate"
    fi
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

# Configure optional persistent Claude Code override using the native installer.
#
# The override installs into $HOME/.local/bin (/data/home/.local/bin) — which is the
# highest-priority "claude" location in PATH (see init_environment). Installing there
# means the persistent binary cleanly supersedes the image-baked one, and because
# /data is persistent + writable, the install survives container restarts.
#
# This replaces the old npm-into-/data/npm approach: Anthropic now ships Claude Code as
# a native binary, and the npm symlink target was shadowed by /data/home/.local/bin in
# PATH (so the override never actually took effect).
setup_persistent_claude() {
    local use_persistent_claude
    local auto_update_claude_on_start
    local claude_channel
    local target_bin="/data/home/.local/bin/claude"

    use_persistent_claude=$(bashio::config 'use_persistent_claude' 'false')
    auto_update_claude_on_start=$(bashio::config 'auto_update_claude_on_start' 'false')
    claude_channel=$(bashio::config 'claude_channel' 'latest')

    if [ "$use_persistent_claude" != "true" ]; then
        bashio::log.info "Persistent Claude override: disabled (using image-baked Claude Code)"
        return 0
    fi

    if [ "$auto_update_claude_on_start" = "true" ]; then
        bashio::log.info "Persistent Claude override: installing Claude Code '${claude_channel}' via native installer into /data/home/.local/bin..."
        # Remove the symlink created by init_environment so the installer writes a fresh real binary
        rm -f "$target_bin"
        # HOME is already /data/home, so the native installer targets /data/home/.local/bin
        if curl -fsSL https://claude.ai/install.sh | bash -s "$claude_channel"; then
            bashio::log.info "Persistent Claude override: native install/update completed"
        elif [ -x "$target_bin" ] && "$target_bin" update; then
            bashio::log.info "Persistent Claude override: updated via 'claude update'"
        else
            bashio::log.warning "Persistent Claude override: install/update failed; falling back to image-baked version if present"
        fi
    fi

    if [ -x "$target_bin" ]; then
        bashio::log.info "Persistent Claude override active: $("$target_bin" --version 2>/dev/null || echo 'version unknown') ($target_bin)"
    else
        bashio::log.warning "Persistent Claude override enabled but no Claude binary at $target_bin"
        bashio::log.warning "Enable 'auto_update_claude_on_start', or install once from a shell:"
        bashio::log.warning "  curl -fsSL https://claude.ai/install.sh | bash -s ${claude_channel}"
    fi
}

# Setup session picker script
setup_session_picker() {
    # Copy session picker script from built-in location
    if [ -f "/opt/scripts/claude-session-picker.sh" ]; then
        if ! cp /opt/scripts/claude-session-picker.sh /usr/local/bin/claude-session-picker; then
            bashio::log.error "Failed to copy claude-session-picker script"
            exit 1
        fi
        chmod +x /usr/local/bin/claude-session-picker
        bashio::log.info "Session picker script installed successfully"
    else
        bashio::log.warning "Session picker script not found, using auto-launch mode only"
    fi

    # Setup authentication helper if it exists
    if [ -f "/opt/scripts/claude-auth-helper.sh" ]; then
        chmod +x /opt/scripts/claude-auth-helper.sh
        bashio::log.info "Authentication helper script ready"
    fi
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

# Legacy monitoring functions removed - using simplified /data approach

# Determine Claude launch command based on configuration
# Session picker handles its own loop, so Claude exiting returns to the menu (#6)
get_claude_launch_command() {
    local auto_launch_claude
    local dangerously_skip_permissions
    local claude_flags=""

    # Get configuration values
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    dangerously_skip_permissions=$(bashio::config 'dangerously_skip_permissions' 'false')

    # Build Claude flags
    if [ "$dangerously_skip_permissions" = "true" ]; then
        claude_flags="--dangerously-skip-permissions"
        bashio::log.warning "Claude will run with --dangerously-skip-permissions (unrestricted file access)"
    fi

    if [ "$auto_launch_claude" = "true" ]; then
        # Auto-launch Claude first, then fall back to session picker on exit
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude ${claude_flags}; /usr/local/bin/claude-session-picker"
        else
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude ${claude_flags}"
        fi
    else
        # Show interactive session picker (has its own while-true loop)
        if [ -f /usr/local/bin/claude-session-picker ]; then
            echo "clear && /usr/local/bin/claude-session-picker"
        else
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            echo "clear && echo 'Welcome to Claude Terminal!' && echo '' && echo 'Starting Claude...' && sleep 1 && claude"
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
# otherwise kill the running Claude session - reconnecting then lands in a fresh
# one. Running inside tmux decouples the two: the connection carries a tmux
# client, while the session itself keeps running in the background, and a
# reconnect re-attaches to it with its scrollback and state intact.
wrap_launch_command() {
    local inner="$1"
    local session="claude"
    local persistent_session

    persistent_session=$(bashio::config 'persistent_terminal_session' 'true')

    if [ "$persistent_session" != "true" ]; then
        bashio::log.info "Persistent terminal session: disabled (a dropped connection restarts Claude)"
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
    printf '#!/bin/bash\n%s\n' "$inner" > /usr/local/bin/claude-launch
    chmod +x /usr/local/bin/claude-launch

    write_tmux_config

    bashio::log.info "Persistent terminal session: enabled (tmux session '${session}')"
    # -A: attach to the session if it exists, create it otherwise
    # -D: detach any stale client, so a dead connection cannot shrink the window
    # -u: force UTF-8, keeps the CLI's box drawing intact
    echo "tmux -u new-session -A -D -s ${session} /usr/local/bin/claude-launch"
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
    bashio::log.info "ANTHROPIC_CONFIG_DIR=${ANTHROPIC_CONFIG_DIR}"
    bashio::log.info "HOME=${HOME}"

    # Get the appropriate launch command based on configuration, then keep it
    # alive across browser disconnects (tmux)
    local launch_command
    launch_command=$(get_claude_launch_command)
    launch_command=$(wrap_launch_command "$launch_command")

    # Log the configuration being used
    local auto_launch_claude
    auto_launch_claude=$(bashio::config 'auto_launch_claude' 'true')
    bashio::log.info "Auto-launch Claude: ${auto_launch_claude}"

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
    bashio::log.info "Initializing Claude Terminal add-on..."

    # Run diagnostics first (especially helpful for VirtualBox issues)
    run_health_check

    init_environment
    install_tools
    setup_persistent_claude
    setup_session_picker
    setup_persistent_packages
    start_web_terminal
}

# Execute main function
main "$@"