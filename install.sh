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

echo "[1/4] Factorio Account"
echo ""
echo "  You need a Factorio token."
echo "  Get it from https://factorio.com/profile"
echo ""
read -rp "  Factorio username: " FACTORIO_USERNAME
read -rp "  Factorio token: " FACTORIO_TOKEN
echo ""

echo "[2/4] Server Settings"
read -rp "  Server name (default: Dockerio Server): " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-Dockerio Server}"
read -rp "  Game password (blank=none): " GAME_PASSWORD
echo ""

echo "[3/4] Admin Setup"
read -rp "  Admin username (blank=skip): " ADMIN_NAME
echo ""

echo "[4/4] Generating config..."
RCON_PASS=$(openssl rand -hex 16)

cat > "${ENV_FILE}" <<EOF
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
EOF

echo "  [OK] .env created"
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
echo "  To customize further, edit .env or"
echo "  config/server-settings.json directly."
echo ""
