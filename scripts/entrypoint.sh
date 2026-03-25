#!/bin/bash
set -euo pipefail

FACTORIO_DIR="/opt/factorio"
DATA_DIR="/factorio"
SAVES_DIR="${DATA_DIR}/saves"
CONFIG_DIR="${DATA_DIR}/config"
SERVER_SETTINGS="${CONFIG_DIR}/server-settings.json"
MAP_GEN_SETTINGS="${CONFIG_DIR}/map-gen-settings.json"
MAP_SETTINGS="${CONFIG_DIR}/map-settings.json"

RCON_PORT="${FACTORIO_RCON_PORT:-27015}"
RCON_PASSWORD="${FACTORIO_RCON_PASSWORD:-changeme}"

# Copy default configs if not present
for f in map-gen-settings.json map-settings.json; do
    if [ ! -f "${CONFIG_DIR}/${f}" ]; then
        if [ -f "${FACTORIO_DIR}/data/${f}" ]; then
            cp "${FACTORIO_DIR}/data/${f}" "${CONFIG_DIR}/${f}"
        fi
    fi
done

# Generate server-settings.json from env vars if not present
if [ ! -f "${SERVER_SETTINGS}" ]; then
    echo "[entrypoint] Generating server-settings.json from environment variables..."
    cat > "${SERVER_SETTINGS}" <<SETTINGS
{
  "name": "${FACTORIO_SERVER_NAME:-Dockerio Server}",
  "description": "${FACTORIO_SERVER_DESCRIPTION:-Powered by Dockerio}",
  "tags": ["${FACTORIO_SERVER_TAGS:-Dockerio}"],
  "max_players": 0,
  "visibility": {"public": true, "lan": true},
  "username": "${FACTORIO_USERNAME:-}",
  "token": "${FACTORIO_TOKEN:-}",
  "game_password": "${FACTORIO_GAME_PASSWORD:-}",
  "require_user_verification": true,
  "max_upload_in_kilobytes_per_second": 0,
  "max_upload_slots": 5,
  "minimum_latency_in_ticks": 0,
  "max_heartbeats_per_second": 60,
  "ignore_player_limit_for_returning_players": false,
  "allow_commands": "admins-only",
  "autosave_interval": 10,
  "autosave_slots": 3,
  "afk_autokick_interval": ${FACTORIO_AFK_KICK:-30},
  "auto_pause": true,
  "auto_pause_when_players_connect": false,
  "only_admins_can_pause_the_game": true,
  "autosave_only_on_server": true,
  "non_blocking_saving": true,
  "minimum_segment_size": 25,
  "minimum_segment_size_peer_count": 20,
  "maximum_segment_size": 100,
  "maximum_segment_size_peer_count": 10
}
SETTINGS
    echo "[entrypoint] server-settings.json generated."
fi

# Generate server-adminlist.json from env vars if not present
if [ ! -f "${CONFIG_DIR}/server-adminlist.json" ]; then
    if [ -n "${FACTORIO_ADMINS:-}" ]; then
        echo "[${FACTORIO_ADMINS}]" | sed 's/,/","/g; s/\[/["/; s/\]/"]/' > "${CONFIG_DIR}/server-adminlist.json"
    else
        echo "[]" > "${CONFIG_DIR}/server-adminlist.json"
    fi
    echo "[entrypoint] server-adminlist.json generated."
fi

# Create new map if no save exists
create_new_map() {
    echo "[entrypoint] Creating new map..."
    rm -f "${SAVES_DIR}"/*.zip
    local cmd=("${FACTORIO_DIR}/bin/x64/factorio" "--create" "${SAVES_DIR}/world.zip")
    if [ -s "${MAP_GEN_SETTINGS}" ] && [ "$(cat "${MAP_GEN_SETTINGS}")" != "{}" ]; then
        cmd+=("--map-gen-settings" "${MAP_GEN_SETTINGS}")
    fi
    if [ -s "${MAP_SETTINGS}" ] && [ "$(cat "${MAP_SETTINGS}")" != "{}" ]; then
        cmd+=("--map-settings" "${MAP_SETTINGS}")
    fi
    "${cmd[@]}"
    echo "[entrypoint] New map created."
}

if [ ! -f "${SAVES_DIR}/world.zip" ]; then
    create_new_map
fi

# Main server loop — restarts with new map on exit
while true; do
    # Start the reset monitor in background
    /opt/factorio/scripts/reset-monitor.sh &
    MONITOR_PID=$!

    # Start the player monitor in background
    /opt/factorio/scripts/player-monitor.sh &
    PLAYER_MONITOR_PID=$!

    # Run Factorio server (blocks until server exits)
    ${FACTORIO_DIR}/bin/x64/factorio \
        --start-server "${SAVES_DIR}/world.zip" \
        --server-settings "${SERVER_SETTINGS}" \
        --rcon-port "${RCON_PORT}" \
        --rcon-password "${RCON_PASSWORD}" \
        --server-adminlist "${CONFIG_DIR}/server-adminlist.json" \
        --console-log "${DATA_DIR}/console.log" \
    || true

    # Kill monitors if still running
    kill ${MONITOR_PID} 2>/dev/null || true
    kill ${PLAYER_MONITOR_PID} 2>/dev/null || true

    echo "[entrypoint] Server exited. Creating new map and restarting..."
    create_new_map

    # Update last reset date in server tags
    RESET_DATE=$(TZ=Asia/Seoul date '+%Y-%m-%d %H:%M')
    sed -i "s/마지막 초기화: [^[]*/마지막 초기화: ${RESET_DATE}/" "${SERVER_SETTINGS}"
    echo "[entrypoint] Updated last reset date: ${RESET_DATE}"

    sleep 5
done
