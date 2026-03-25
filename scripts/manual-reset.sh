#!/bin/bash
set -euo pipefail

RCON_PORT="${FACTORIO_RCON_PORT:-27015}"
RCON_PASSWORD="${FACTORIO_RCON_PASSWORD:-changeme}"
RCON_CMD="mcrcon -H 127.0.0.1 -P ${RCON_PORT} -p ${RCON_PASSWORD}"

rcon() {
    ${RCON_CMD} "$1" 2>/dev/null || true
}

echo "[manual-reset] Manual reset triggered"
rcon "/shout [SERVER] 관리자에 의해 60초 후 맵이 초기화됩니다"
sleep 30
rcon "/shout [SERVER] 30초 후 맵이 초기화됩니다"
sleep 20
for i in 10 9 8 7 6 5 4 3 2 1; do
    rcon "/shout [SERVER] ${i}초"
    sleep 1
done
rcon "/shout [SERVER] 맵을 초기화합니다"
rcon "/quit"
