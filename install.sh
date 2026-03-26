#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  Dockerio - Factorio Server Installer"
echo "============================================"
echo ""

ENV_FILE=".env"

if [ -f "${ENV_FILE}" ]; then
    echo "[!] .env already exists. Skipping."
    echo "    To reconfigure, delete .env and run again."
    echo ""
    exit 0
fi

echo "[1/5] Server Mode"
echo ""
echo "  1) achieve - Achievement speedrun (auto-reset, blueprint ban)"
echo "  2) modded  - Mod/test server (timelapse, stats, no restrictions)"
echo ""
read -rp "  Select mode (1/2, default: 1): " MODE_SELECT
case "${MODE_SELECT}" in
    2|modded)
        SERVER_MODE="modded"
        FACTORIO_DISABLE_BLUEPRINTS="false"
        FACTORIO_AUTO_RESET="false"
        FACTORIO_PLAYER_MONITOR="true"
        ;;
    *)
        SERVER_MODE="achieve"
        FACTORIO_DISABLE_BLUEPRINTS="true"
        FACTORIO_AUTO_RESET="true"
        FACTORIO_PLAYER_MONITOR="true"
        ;;
esac
echo "  -> ${SERVER_MODE} mode selected"
echo ""

echo "[2/5] Factorio Account"
echo ""
echo "  You need a Factorio token."
echo "  Get it from https://factorio.com/profile"
echo ""
read -rp "  Factorio username: " FACTORIO_USERNAME
read -rp "  Factorio token: " FACTORIO_TOKEN
echo ""

echo "[3/5] Server Settings"
read -rp "  Server name (default: Dockerio Server): " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-Dockerio Server}"
read -rp "  Game password (blank=none): " GAME_PASSWORD
echo ""

echo "[4/5] Admin Setup"
read -rp "  Admin username (blank=skip): " ADMIN_NAME
echo ""

echo "[5/5] Generating config..."
RCON_PASS=$(openssl rand -hex 16)

cat > "${ENV_FILE}" <<EOF
# Server mode (achieve / modded)
SERVER_MODE=${SERVER_MODE}

# Factorio account
FACTORIO_USERNAME=${FACTORIO_USERNAME}
FACTORIO_TOKEN=${FACTORIO_TOKEN}

# RCON
FACTORIO_RCON_PASSWORD=${RCON_PASS}

# Server settings (used to auto-generate server-settings.json)
FACTORIO_SERVER_NAME=${SERVER_NAME}
FACTORIO_GAME_PASSWORD=${GAME_PASSWORD}
FACTORIO_AFK_KICK=30
FACTORIO_ADMINS=${ADMIN_NAME}

# Feature flags
FACTORIO_DISABLE_BLUEPRINTS=${FACTORIO_DISABLE_BLUEPRINTS}
FACTORIO_AUTO_RESET=${FACTORIO_AUTO_RESET}
FACTORIO_PLAYER_MONITOR=${FACTORIO_PLAYER_MONITOR}
EOF

echo "  [OK] .env created (${SERVER_MODE} mode)"
echo ""
echo "============================================"
echo "  Install complete!"
echo "============================================"
echo ""
echo "  Start server:"
echo "    docker compose up -d"
echo ""
echo "  server-settings.json will be auto-generated"
echo "  on first startup from .env values."
echo ""
echo "  To customize features, edit .env:"
echo "    FACTORIO_DISABLE_BLUEPRINTS=${FACTORIO_DISABLE_BLUEPRINTS}"
echo "    FACTORIO_AUTO_RESET=${FACTORIO_AUTO_RESET}"
echo "    FACTORIO_PLAYER_MONITOR=${FACTORIO_PLAYER_MONITOR}"
echo ""
