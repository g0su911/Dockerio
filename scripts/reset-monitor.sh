#!/bin/bash
set -euo pipefail

RCON_PORT="${FACTORIO_RCON_PORT:-27015}"
RCON_PASSWORD="${FACTORIO_RCON_PASSWORD:-changeme}"
RESET_GAME_HOURS="${RESET_GAME_HOURS:-30}"
RESET_SCHEDULE="${RESET_SCHEDULE:-WED:06:00,FRI:19:00,MON:06:00}"

RCON_CMD="mcrcon -H 127.0.0.1 -P ${RCON_PORT} -p ${RCON_PASSWORD}"

# Wait for server to be ready
sleep 30

rcon() {
    ${RCON_CMD} "$1" 2>/dev/null || true
}

# /time returns "Map has been running for 123456 ticks (34 minutes)"
# 60 ticks/sec * 3600 sec/hr = 216000 ticks/hr
get_game_hours() {
    local output ticks
    output=$(rcon "/time")
    ticks=$(echo "${output}" | grep -oP '\d+ ticks' | grep -oP '\d+' || echo "0")
    echo $(( ticks / 216000 ))
}

# RESET_SCHEDULE format: "WED:06:00,FRI:19:00,MON:06:00"
is_scheduled_reset() {
    local current_day current_time
    current_day=$(date +%a | tr '[:lower:]' '[:upper:]')
    current_time=$(date +%H:%M)

    IFS=',' read -ra SCHEDULES <<< "${RESET_SCHEDULE}"
    for schedule in "${SCHEDULES[@]}"; do
        local day time
        day=$(echo "${schedule}" | cut -d: -f1)
        time=$(echo "${schedule}" | cut -d: -f2-3)
        if [ "${current_day}" = "${day}" ] && [ "${current_time}" = "${time}" ]; then
            return 0
        fi
    done
    return 1
}

trigger_reset() {
    echo "[reset-monitor] Triggering map reset..."
    rcon "/shout [SERVER] 60초 후 맵이 초기화됩니다"
    sleep 30
    rcon "/shout [SERVER] 30초 후 맵이 초기화됩니다"
    sleep 20
    for i in 10 9 8 7 6 5 4 3 2 1; do
        rcon "/shout [SERVER] ${i}초"
        sleep 1
    done
    rcon "/shout [SERVER] 맵을 초기화합니다"
    rcon "/quit"
}

echo "[reset-monitor] Started. Game hour limit: ${RESET_GAME_HOURS}h, Schedule: ${RESET_SCHEDULE}"

while true; do
    game_hours=$(get_game_hours)
    if [ "${game_hours}" -ge "${RESET_GAME_HOURS}" ]; then
        echo "[reset-monitor] Game time limit reached (${game_hours}h >= ${RESET_GAME_HOURS}h)"
        trigger_reset
        exit 0
    fi

    if is_scheduled_reset; then
        echo "[reset-monitor] Scheduled reset triggered"
        trigger_reset
        exit 0
    fi

    sleep 60
done
