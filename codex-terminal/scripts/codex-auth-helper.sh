#!/bin/bash

# OpenAI Codex Authentication Helper
# Container-friendly alternatives to the browser-based ChatGPT login

show_auth_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               🔐 Codex Authentication Helper                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Codex home: ${CODEX_HOME:-~/.codex} (credentials persist here)"
    echo ""
    echo "Options:"
    echo "  1) 🔑 Log in with an OpenAI API key"
    echo "  2) 📁 Read API key from file (/config/openai-api-key.txt)"
    echo "  3) 🌐 ChatGPT OAuth with device code (recommended for HA / SSH)"
    echo "  4) ℹ️  Show login status"
    echo "  5) 🚪 Log out (remove stored credentials)"
    echo "  6) ❌ Exit"
    echo ""
}

login_with_api_key() {
    echo ""
    echo "Create an API key at: https://platform.openai.com/api-keys"
    echo "(You can try pasting with Ctrl+Shift+V, right-click, or type manually)"
    echo ""
    read -rsp "API key: " api_key
    echo ""

    if [ -z "$api_key" ]; then
        echo "❌ No API key provided"
        return 1
    fi

    echo ""
    echo "Logging in..."
    if printf '%s' "$api_key" | codex login --with-api-key; then
        echo ""
        echo "✅ Logged in! Credentials persist across restarts."
        return 0
    fi

    echo "❌ Login failed"
    return 1
}

login_from_file() {
    local key_file="/config/openai-api-key.txt"

    echo ""
    echo "Looking for an API key in: $key_file"

    if [ ! -f "$key_file" ]; then
        echo "❌ File not found: $key_file"
        echo ""
        echo "To use this method:"
        echo "1. Create the file in Home Assistant's config directory"
        echo "2. Paste your OpenAI API key in the file (single line)"
        echo "3. Save the file and try again"
        return 1
    fi

    local api_key
    api_key=$(tr -d '[:space:]' < "$key_file")
    if [ -z "$api_key" ]; then
        echo "❌ File exists but is empty"
        return 1
    fi

    echo "✅ Key found. Logging in..."
    if printf '%s' "$api_key" | codex login --with-api-key; then
        rm -f "$key_file"
        echo "🧹 Cleaned up API key file"
        echo "✅ Logged in! Credentials persist across restarts."
        return 0
    fi

    echo "❌ Login failed (key file kept for retry)"
    return 1
}

device_login() {
    echo ""
    echo "ChatGPT OAuth - headless device-code login"
    echo ""
    echo "1. In ChatGPT Settings > Security, enable device-code login for Codex."
    echo "   For a managed workspace, its administrator must allow this method."
    echo "2. Keep this terminal open. Codex will display a browser link and a code."
    echo "3. Open that link on your computer or phone and enter the displayed code."
    echo "4. Return here; Codex will finish signing in automatically."
    echo ""
    echo "No callback port or SSH tunnel is needed. Do not share the code."
    echo "Credentials remain in the add-on's persistent Codex home."
    echo ""

    if ! codex login --help 2>&1 | grep -q -- '--device-auth'; then
        echo "This Codex CLI does not support device-code login."
        echo "Update the CLI, then try this option again."
        return 1
    fi

    if codex login --device-auth; then
        if [ -f "${CODEX_HOME:-/data/.config/codex}/auth.json" ]; then
            chmod 600 "${CODEX_HOME:-/data/.config/codex}/auth.json"
        fi
        echo ""
        echo "ChatGPT login completed. You can now start or resume a Codex session."
        codex login status || true
        return 0
    else
        local result=$?
        echo ""
        echo "Device-code login did not complete."
        echo "Check the error above and ensure device-code login is enabled in ChatGPT."
        echo "If the code expired, select this option again to request a fresh one."
        return "$result"
    fi
}

show_login_status() {
    echo ""
    codex login status || true
}

do_logout() {
    echo ""
    read -rp "Remove stored OpenAI credentials? [y/N]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        codex logout || true
    else
        echo "Cancelled."
    fi
}

main() {
    while true; do
        show_auth_menu

        echo -n "Enter your choice [1-6]: "
        read -r choice

        case "$choice" in
            1)
                login_with_api_key
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            2)
                login_from_file
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            3)
                device_login
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            4)
                show_login_status
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            5)
                do_logout
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            6)
                echo "👋 Exiting..."
                exit 0
                ;;
            *)
                echo "❌ Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"
