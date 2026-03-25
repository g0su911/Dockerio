#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  Dockerio - Factorio Server Installer"
echo "============================================"
echo ""

CONFIG_DIR="config"
ENV_FILE=".env"

# --- server-settings.json ---
if [ -f "${CONFIG_DIR}/server-settings.json" ]; then
    echo "[!] server-settings.json already exists. Skipping."
else
    echo "[1/4] Factorio 계정 설정"
    echo ""
    echo "  Factorio 토큰이 필요합니다."
    echo "  https://factorio.com/profile 에서 로그인 후 토큰을 복사하세요."
    echo ""
    read -rp "  Factorio username: " FACTORIO_USERNAME
    read -rp "  Factorio token: " FACTORIO_TOKEN
    echo ""

    echo "[2/4] 서버 설정"
    read -rp "  서버 이름 (기본: My Factorio Server): " SERVER_NAME
    SERVER_NAME="${SERVER_NAME:-My Factorio Server}"
    read -rp "  서버 비밀번호 (빈칸=없음): " GAME_PASSWORD
    echo ""

    cp "${CONFIG_DIR}/server-settings.example.json" "${CONFIG_DIR}/server-settings.json"

    # Use python3 for reliable JSON editing
    python3 -c "
import json
with open('${CONFIG_DIR}/server-settings.json', 'r') as f:
    s = json.load(f)
s['username'] = '${FACTORIO_USERNAME}'
s['token'] = '${FACTORIO_TOKEN}'
s['name'] = '''${SERVER_NAME}'''
s['game_password'] = '${GAME_PASSWORD}'
with open('${CONFIG_DIR}/server-settings.json', 'w') as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
" 2>/dev/null || {
    # Fallback: sed
    sed -i "s/\"username\": \"\"/\"username\": \"${FACTORIO_USERNAME}\"/" "${CONFIG_DIR}/server-settings.json"
    sed -i "s/\"token\": \"\"/\"token\": \"${FACTORIO_TOKEN}\"/" "${CONFIG_DIR}/server-settings.json"
    sed -i "s/\"name\": \"My Factorio Server\"/\"name\": \"${SERVER_NAME}\"/" "${CONFIG_DIR}/server-settings.json"
    sed -i "s/\"game_password\": \"\"/\"game_password\": \"${GAME_PASSWORD}\"/" "${CONFIG_DIR}/server-settings.json"
}

    echo "  [OK] server-settings.json 생성 완료"
fi

# --- server-adminlist.json ---
if [ -f "${CONFIG_DIR}/server-adminlist.json" ]; then
    echo "[!] server-adminlist.json already exists. Skipping."
else
    echo ""
    echo "[3/4] 관리자 설정"
    read -rp "  관리자 Factorio username (빈칸=건너뛰기): " ADMIN_NAME
    if [ -n "${ADMIN_NAME}" ]; then
        echo "[\"${ADMIN_NAME}\"]" > "${CONFIG_DIR}/server-adminlist.json"
        echo "  [OK] server-adminlist.json 생성 완료"
    else
        echo "[]" > "${CONFIG_DIR}/server-adminlist.json"
        echo "  [OK] 관리자 없이 생성"
    fi
fi

# --- .env ---
if [ -f "${ENV_FILE}" ]; then
    echo "[!] .env already exists. Skipping."
else
    echo ""
    echo "[4/4] RCON 설정"
    RCON_PASS=$(openssl rand -hex 16)
    echo "FACTORIO_RCON_PASSWORD=${RCON_PASS}" > "${ENV_FILE}"
    echo "  [OK] .env 생성 완료 (RCON 비밀번호 자동 생성)"
fi

echo ""
echo "============================================"
echo "  설치 완료!"
echo "============================================"
echo ""
echo "  서버 시작:"
echo "    docker compose up -d"
echo "  또는"
echo "    docker-compose up -d"
echo ""
echo "  서버 접속: Factorio 멀티플레이어에서 서버 이름으로 검색"
echo ""
