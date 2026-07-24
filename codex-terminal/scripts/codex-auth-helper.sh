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
    echo "  1) 🔑 Log in with an OpenAI API key (recommended for containers)"
    echo "  2) 📁 Read API key from file (/config/openai-api-key.txt)"
    echo "  3) 🌐 ChatGPT browser login (advanced — needs port forwarding)"
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

browser_login_info() {
    echo ""
    echo "🌐 ChatGPT browser login inside a container"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "'codex login' starts a local OAuth server on port 1455 and the browser"
    echo "redirect goes to localhost:1455 — which is inside this container, so a"
    echo "normal browser login cannot complete through the Home Assistant UI."
    echo ""
    echo "Workaround (from a machine with a browser):"
    echo "  1. SSH to your Home Assistant host with a port forward for 1455"
    echo "     (e.g. ssh -L 1455:<HA-IP>:1455 user@host, with port 1455 exposed)"
    echo "  2. Run 'codex login' here and open the printed URL in that browser"
    echo ""
    echo "For most users, the API key login (option 1) is much simpler."
    echo ""
    read -rp "Run 'codex login' now anyway? [y/N]: " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        codex login
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
                browser_login_info
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
