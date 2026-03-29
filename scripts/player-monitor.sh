#!/bin/bash
set -euo pipefail

RCON_PORT="${FACTORIO_RCON_PORT:-27015}"
RCON_PASSWORD="${FACTORIO_RCON_PASSWORD:-changeme}"
DATA_DIR="/factorio"
CONSOLE_LOG="${DATA_DIR}/console.log"
PLAYERS_FILE="${DATA_DIR}/config/players.json"

RCON_CMD="mcrcon -H 127.0.0.1 -P ${RCON_PORT} -p ${RCON_PASSWORD}"

# Wait for server and console log to be ready
sleep 35

rcon() {
    ${RCON_CMD} "$1" 2>/dev/null || true
}

get_game_hours_text() {
    local output hours minutes
    output=$(rcon "/time")
    hours=$(echo "${output}" | grep -oP '\d+ hour' | grep -oP '\d+' || echo "0")
    minutes=$(echo "${output}" | grep -oP '\d+ minute' | grep -oP '\d+' || echo "0")
    echo "${hours}h ${minutes}m"
}

# Initialize players file if not exists
if [ ! -f "${PLAYERS_FILE}" ]; then
    echo '{}' > "${PLAYERS_FILE}"
fi

# Track join times for session duration
declare -A join_times

echo "[player-monitor] Started. Watching ${CONSOLE_LOG}"

tail -n 0 -f "${CONSOLE_LOG}" 2>/dev/null | while read -r line; do
    # Detect player join: [JOIN] player_name joined the game
    if echo "${line}" | grep -qP '\[JOIN\] .+ joined the game'; then
        player=$(echo "${line}" | grep -oP '\[JOIN\] \K.+(?= joined the game)')
        join_times["${player}"]=$(date +%s)

        # Check if new or returning player
        if jq -e --arg p "${player}" '.[$p]' "${PLAYERS_FILE}" > /dev/null 2>&1; then
            # Returning player - show accumulated playtime
            total_mins=$(jq -r --arg p "${player}" '.[$p].minutes // 0' "${PLAYERS_FILE}")
            hours=$(( total_mins / 60 ))
            mins=$(( total_mins % 60 ))
            game_time=$(get_game_hours_text)
            rcon "/whisper ${player} [SERVER] ${player}님, 다시 오셨군요! 누적 플레이타임: ${hours}h ${mins}m"
            rcon "/whisper ${player} [SERVER] 다른 플레이어의 건물/오브젝트를 업그레이드하거나 철거 시 밴 될 수 있습니다."
        else
            # New player - welcome message
            game_time=$(get_game_hours_text)
            jq --arg p "${player}" '.[$p] = {"minutes": 0}' "${PLAYERS_FILE}" > "${PLAYERS_FILE}.tmp" \
                && mv "${PLAYERS_FILE}.tmp" "${PLAYERS_FILE}"
            rcon "/whisper ${player} [SERVER] ${player}님, 환영합니다! 현재 서버 가동시간: ${game_time}"
            rcon "/whisper ${player} [SERVER] /time 으로 서버 진행시간을 확인하세요. 내 플레이타임이 서버 진행시간의 50% 이상이어야 업적 달성이 가능합니다."
            rcon "/whisper ${player} [SERVER] 다른 플레이어의 건물/오브젝트를 업그레이드하거나 철거 시 밴 될 수 있습니다."
        fi
    fi

    # Detect player leave: [LEAVE] player_name left the game
    if echo "${line}" | grep -qP '\[LEAVE\] .+ left the game'; then
        player=$(echo "${line}" | grep -oP '\[LEAVE\] \K.+(?= left the game)')

        # Calculate session duration and update total
        if [ -n "${join_times[${player}]+x}" ]; then
            now=$(date +%s)
            session_secs=$(( now - join_times["${player}"] ))
            session_mins=$(( session_secs / 60 ))
            unset 'join_times[${player}]'

            if jq -e --arg p "${player}" '.[$p]' "${PLAYERS_FILE}" > /dev/null 2>&1; then
                jq --arg p "${player}" --argjson m "${session_mins}" \
                    '.[$p].minutes = ((.[$p].minutes // 0) + $m)' \
                    "${PLAYERS_FILE}" > "${PLAYERS_FILE}.tmp" \
                    && mv "${PLAYERS_FILE}.tmp" "${PLAYERS_FILE}"
            fi
        fi
    fi
done
