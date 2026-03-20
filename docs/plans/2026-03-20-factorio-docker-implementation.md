# Factorio Docker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Factorio headless 서버 Docker 이미지 빌드 — 자동 맵 리셋, AFK 킥, RCON 모니터링 포함

**Architecture:** Debian slim 기반 Docker 이미지에 Factorio headless 바이너리를 다운로드하고, entrypoint 스크립트로 서버 라이프사이클(시작/리셋/모니터링)을 관리한다. GitHub Actions로 버전 자동 업데이트 + Docker Hub 푸시.

**Tech Stack:** Docker, Bash, GitHub Actions, RCON (mcrcon)

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Dockerfile`
- Create: `docker-compose.yml`
- Create: `.dockerignore`
- Create: `config/server-settings.json`
- Create: `config/map-gen-settings.json`
- Create: `config/map-settings.json`

**Step 1: Create .dockerignore**

```
.git
.github
docs
README.md
LICENSE
*.md
```

**Step 2: Create default server-settings.json**

```json
{
  "name": "Factorio Speedrun Server",
  "description": "Auto-reset speedrun server",
  "tags": ["speedrun"],
  "max_players": 0,
  "visibility": {
    "public": true,
    "lan": true
  },
  "username": "",
  "token": "",
  "game_password": "",
  "require_user_verification": true,
  "max_upload_in_kilobytes_per_second": 0,
  "max_upload_slots": 5,
  "minimum_latency_in_ticks": 0,
  "max_heartbeats_per_second": 60,
  "ignore_player_limit_for_returning_players": false,
  "allow_commands": "admins-only",
  "autosave_interval": 10,
  "autosave_slots": 3,
  "afk_autokick_interval": 30,
  "auto_pause": true,
  "auto_pause_when_players_connect": false,
  "only_admins_can_pause_the_game": true,
  "autosave_only_on_server": true,
  "non_blocking_saving": false,
  "minimum_segment_size": 25,
  "minimum_segment_size_peer_count": 20,
  "maximum_segment_size": 100,
  "maximum_segment_size_peer_count": 10
}
```

**Step 3: Create minimal map-gen-settings.json**

```json
{}
```

**Step 4: Create minimal map-settings.json**

```json
{}
```

**Step 5: Create docker-compose.yml**

```yaml
services:
  factorio:
    build: .
    ports:
      - "34197:34197/udp"
      - "27015:27015/tcp"
    volumes:
      - ./config:/factorio/config
    environment:
      - FACTORIO_SERVER_NAME=Factorio Speedrun Server
      - FACTORIO_RCON_PASSWORD=changeme
      - RESET_SCHEDULE=WED:06:00,FRI:19:00,MON:06:00
      - RESET_GAME_HOURS=30
      - SERVER_MODE=achievement
    restart: unless-stopped
```

**Step 6: Commit**

```bash
git init
git add .dockerignore config/ docker-compose.yml
git commit -m "chore: project scaffolding with config files"
```

---

### Task 2: Dockerfile

**Files:**
- Create: `Dockerfile`
- Create: `VERSION`

**Step 1: Create VERSION file**

```
2.0.76
```

**Step 2: Create Dockerfile**

```dockerfile
FROM debian:bookworm-slim

ARG FACTORIO_VERSION
ENV FACTORIO_VERSION=${FACTORIO_VERSION:-2.0.76}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install mcrcon for RCON communication
RUN curl -fsSL https://github.com/Tiiffi/mcrcon/releases/download/v0.7.2/mcrcon-0.7.2-linux-x86-64.tar.gz \
    | tar -xz -C /usr/local/bin/ mcrcon \
    && chmod +x /usr/local/bin/mcrcon

# Download and install Factorio headless server
RUN curl -fsSL -o /tmp/factorio.tar.xz \
        "https://factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64" \
    && tar -xJf /tmp/factorio.tar.xz -C /opt \
    && rm /tmp/factorio.tar.xz

# Create factorio user and directories
RUN useradd -r -m -d /factorio factorio \
    && mkdir -p /factorio/saves /factorio/config /factorio/mods \
    && chown -R factorio:factorio /factorio

COPY scripts/ /opt/factorio/scripts/
RUN chmod +x /opt/factorio/scripts/*.sh

EXPOSE 34197/udp 27015/tcp

VOLUME ["/factorio/saves", "/factorio/config"]

ENTRYPOINT ["/opt/factorio/scripts/entrypoint.sh"]
```

**Step 3: Commit**

```bash
git add Dockerfile VERSION
git commit -m "feat: add Dockerfile with Factorio headless server"
```

---

### Task 3: Entrypoint Script

**Files:**
- Create: `scripts/entrypoint.sh`

**Step 1: Create entrypoint.sh**

```bash
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
for f in server-settings.json map-gen-settings.json map-settings.json; do
    if [ ! -f "${CONFIG_DIR}/${f}" ]; then
        if [ -f "${FACTORIO_DIR}/data/${f}" ]; then
            cp "${FACTORIO_DIR}/data/${f}" "${CONFIG_DIR}/${f}"
        fi
    fi
done

# Create new map if no save exists
create_new_map() {
    echo "[entrypoint] Creating new map..."
    rm -f "${SAVES_DIR}"/*.zip
    ${FACTORIO_DIR}/bin/x64/factorio \
        --create "${SAVES_DIR}/world.zip" \
        --map-gen-settings "${MAP_GEN_SETTINGS}" \
        --map-settings "${MAP_SETTINGS}"
    echo "[entrypoint] New map created."
}

if [ ! -f "${SAVES_DIR}/world.zip" ]; then
    create_new_map
fi

# Start the reset monitor in background
/opt/factorio/scripts/reset-monitor.sh &

# Start Factorio server
exec ${FACTORIO_DIR}/bin/x64/factorio \
    --start-server "${SAVES_DIR}/world.zip" \
    --server-settings "${SERVER_SETTINGS}" \
    --rcon-port "${RCON_PORT}" \
    --rcon-password "${RCON_PASSWORD}" \
    --server-adminlist "${CONFIG_DIR}/server-adminlist.json"
```

**Step 2: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: add entrypoint script for server lifecycle"
```

---

### Task 4: Reset Monitor Script

**Files:**
- Create: `scripts/reset-monitor.sh`

**Step 1: Create reset-monitor.sh**

이 스크립트는 두 가지 리셋 조건을 모니터링한다:
1. 게임 내 시간 30시간 도달
2. 고정 스케줄 (수/금/월)

```bash
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

# Get game time in ticks, convert to hours
# /time returns something like "Map has been running for 123456 ticks (34 minutes)"
get_game_hours() {
    local output
    output=$(rcon "/time")
    local ticks
    ticks=$(echo "${output}" | grep -oP '\d+ ticks' | grep -oP '\d+' || echo "0")
    # 60 ticks per second * 3600 seconds per hour = 216000 ticks per hour
    echo $(( ticks / 216000 ))
}

# Check if current time matches a scheduled reset
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
    rcon "/say [SERVER] Map will reset in 60 seconds!"
    sleep 30
    rcon "/say [SERVER] Map will reset in 30 seconds!"
    sleep 20
    rcon "/say [SERVER] Map will reset in 10 seconds!"
    sleep 10
    rcon "/say [SERVER] Resetting map now!"

    # Save and quit — the entrypoint detects exit and recreates
    rcon "/quit"
}

echo "[reset-monitor] Started. Game hour limit: ${RESET_GAME_HOURS}h, Schedule: ${RESET_SCHEDULE}"

while true; do
    # Check game time
    game_hours=$(get_game_hours)
    if [ "${game_hours}" -ge "${RESET_GAME_HOURS}" ]; then
        echo "[reset-monitor] Game time limit reached (${game_hours}h >= ${RESET_GAME_HOURS}h)"
        trigger_reset
        exit 0
    fi

    # Check scheduled reset
    if is_scheduled_reset; then
        echo "[reset-monitor] Scheduled reset triggered"
        trigger_reset
        exit 0
    fi

    sleep 60
done
```

**Step 2: Commit**

```bash
git add scripts/reset-monitor.sh
git commit -m "feat: add reset monitor for game-time and schedule-based resets"
```

---

### Task 5: Restart Wrapper

`/quit` 으로 서버가 종료되면 새 맵을 만들고 다시 시작해야 한다.
entrypoint.sh에서 `exec`를 제거하고 루프로 감싼다.

**Files:**
- Modify: `scripts/entrypoint.sh`

**Step 1: Modify entrypoint.sh — replace exec with restart loop**

entrypoint.sh의 마지막 부분을 다음으로 교체:

```bash
# Main server loop — restarts with new map on exit
while true; do
    # Start the reset monitor in background
    /opt/factorio/scripts/reset-monitor.sh &
    MONITOR_PID=$!

    # Run Factorio server (blocks until server exits)
    ${FACTORIO_DIR}/bin/x64/factorio \
        --start-server "${SAVES_DIR}/world.zip" \
        --server-settings "${SERVER_SETTINGS}" \
        --rcon-port "${RCON_PORT}" \
        --rcon-password "${RCON_PASSWORD}" \
        --server-adminlist "${CONFIG_DIR}/server-adminlist.json" \
    || true

    # Kill reset monitor if still running
    kill ${MONITOR_PID} 2>/dev/null || true

    echo "[entrypoint] Server exited. Creating new map and restarting..."
    create_new_map

    sleep 5
done
```

**Step 2: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: add restart loop for auto map reset"
```

---

### Task 6: GitHub Actions — Auto Version Update

**Files:**
- Create: `.github/workflows/build-and-push.yml`

**Step 1: Create the workflow**

```yaml
name: Build and Push Factorio Docker Image

on:
  schedule:
    - cron: '0 */6 * * *'
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  check-and-build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Get latest Factorio stable version
        id: version
        run: |
          LATEST=$(curl -s https://factorio.com/api/latest-releases | jq -r '.stable.headless')
          CURRENT=$(cat VERSION)
          echo "latest=${LATEST}" >> $GITHUB_OUTPUT
          echo "current=${CURRENT}" >> $GITHUB_OUTPUT
          if [ "${LATEST}" != "${CURRENT}" ]; then
            echo "updated=true" >> $GITHUB_OUTPUT
          else
            echo "updated=false" >> $GITHUB_OUTPUT
          fi

      - name: Update VERSION file
        if: steps.version.outputs.updated == 'true'
        run: echo "${{ steps.version.outputs.latest }}" > VERSION

      - name: Commit version update
        if: steps.version.outputs.updated == 'true'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add VERSION
          git commit -m "chore: bump factorio to ${{ steps.version.outputs.latest }}"
          git push

      - name: Set up Docker Buildx
        if: steps.version.outputs.updated == 'true' || github.event_name == 'push'
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        if: steps.version.outputs.updated == 'true' || github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        if: steps.version.outputs.updated == 'true' || github.event_name == 'push'
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          build-args: FACTORIO_VERSION=${{ steps.version.outputs.latest || steps.version.outputs.current }}
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/factorio:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/factorio:${{ steps.version.outputs.latest || steps.version.outputs.current }}
```

**Step 2: Commit**

```bash
git add .github/workflows/build-and-push.yml
git commit -m "ci: add GitHub Actions for auto version update and Docker Hub push"
```

---

### Task 7: Local Build & Test

**Step 1: Build Docker image locally**

```bash
docker build --build-arg FACTORIO_VERSION=2.0.76 -t factorio-test .
```

Expected: 이미지 빌드 성공

**Step 2: Test run with docker-compose**

```bash
docker compose up -d
```

**Step 3: Verify server starts**

```bash
docker compose logs -f factorio
```

Expected: `Factorio initializing` → `Creating new map` → `Loading map` 로그

**Step 4: Test RCON connection**

```bash
mcrcon -H 127.0.0.1 -P 27015 -p changeme "/players"
```

Expected: 플레이어 목록 응답

**Step 5: Test game connection**

Factorio 클라이언트에서 `localhost:34197`로 접속 확인

**Step 6: Commit all final adjustments**

```bash
git add -A
git commit -m "test: verify local build and server startup"
```

---

### Task 8: README

**Files:**
- Create: `README.md`

**Step 1: Create README**

```markdown
# Factorio Docker

Factorio headless server Docker image with auto map reset for speedrun servers.

## Features

- Auto map reset (game time limit + scheduled resets)
- AFK auto-kick (configurable, default 30 min)
- RCON enabled for monitoring
- Auto version update via GitHub Actions
- Achievement-safe (no mods, no console commands)

## Quick Start

```bash
cp config/server-settings.json config/server-settings.json
# Edit config/server-settings.json with your credentials
docker compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FACTORIO_RCON_PASSWORD` | `changeme` | RCON password |
| `FACTORIO_RCON_PORT` | `27015` | RCON port |
| `RESET_SCHEDULE` | `WED:06:00,FRI:19:00,MON:06:00` | Scheduled reset times |
| `RESET_GAME_HOURS` | `30` | Game hours before auto reset |
| `SERVER_MODE` | `achievement` | `achievement` or `full` |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 34197 | UDP | Factorio game |
| 27015 | TCP | RCON |
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with usage instructions"
```

---

## Task Dependency Graph

```
Task 1 (scaffolding)
  → Task 2 (Dockerfile)
    → Task 3 (entrypoint)
      → Task 4 (reset monitor)
        → Task 5 (restart wrapper)
          → Task 7 (local test)
            → Task 8 (README)
    → Task 6 (GitHub Actions) — independent of Tasks 3-5
```
