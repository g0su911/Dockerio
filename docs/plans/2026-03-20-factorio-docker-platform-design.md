# Factorio Docker Platform Design

## Overview

웹에서 Factorio 전용 서버를 생성/관리할 수 있는 플랫폼.
스피드런 업적용 자동 맵 리셋 서버가 핵심 컨셉.

## Architecture

```
[Next.js (Frontend + API)]
  |
  +-- GCP Cloud Run / GKE
  |     +-- Factorio Docker Container (per server)
  |     +-- Auto-scaling
  |
  +-- RCON 통신 (서버 모니터링/제어)
  +-- Docker Hub (이미지 자동 빌드/배포)
```

## Docker Image

- **Base:** `debian:bookworm-slim`
- **Factorio:** headless 서버 바이너리 (공식 사이트 다운로드)
- **Steam 불필요:** headless 빌드 별도 제공
- **RCON:** 활성화 (모니터링 + 제어용)

## Server Modes

### Achievement Mode (업적 모드)
- `/c`, `/silent-command` 사용 금지
- 모드 사용 금지
- 블루프린트 차단 불가 (룰 기반 운영, 위반 시 수동 밴)
- 제한된 모니터링 (RCON 기본 명령어만)

### Non-Achievement Mode (비업적 모드)
- `/silent-command`로 블루프린트 자동 차단
- Lua API를 통한 상세 생산 통계
- 상세 플레이어 활동 로그
- 자유로운 서버 자동화

## Auto Map Reset

### Trigger Conditions
1. **Game time:** 게임 내 시간 30시간 도달
2. **Fixed schedule:** 수요일 06:00 / 금요일 19:00 / 월요일 06:00
3. 둘 중 먼저 도달하는 조건으로 리셋

### Reset Flow
1. 서버 중지
2. 기존 세이브 삭제 (백업 없음)
3. 새 맵 생성 (랜덤 시드, `map-gen-settings.json` 기반)
4. 서버 재시작

## Server Rules (Entrypoint Script)

### AFK Kick (30min)
- `server-settings.json`의 `afk_autokick_interval: 30`으로 처리 (별도 스크립트 불필요)
- 양쪽 모드 동일하게 동작

### Blueprint Ban
- 업적 모드: 자동화 불가, 룰 공지 + 제보 기반 밴
- 비업적 모드: `/silent-command`로 permission group 설정
- **공식 포럼에 RCON `/permissions` 지원 요청 제출 완료** (2026-03-20)

## Web Dashboard (Next.js)

### Common Features (Both Modes)
| Feature | Method | Interval |
|---------|--------|----------|
| Online players | RCON `/players` | 30s~1min |
| Game time | RCON `/time` | 1min |
| Next reset countdown | Schedule calculation | Realtime |
| Biter evolution | RCON `/evolution` | 1min |
| Server status | Health check | 30s |
| Map overview snapshot | `--generate-map-preview` | 5~10min |
| Map timelapse | Accumulated snapshots | Per reset |

### Non-Achievement Mode Only
| Feature | Method |
|---------|--------|
| Production statistics | Lua `item_production_statistics` |
| Player activity log | Lua event listeners |
| Speedrun leaderboard (Rocket) | 서버 콘솔 로그에서 로켓 발사 감지 (`--console-log`) |
| Speedrun leaderboard (Space Age) | Lua `game.finished` 상태 감지 |
| Blueprint auto-ban | `/silent-command`로 permission group 설정 |

### Clear Detection (클리어 감지)

| 조건 | 업적 모드 | 비업적 모드 |
|------|----------|-----------|
| 로켓 발사 (바닐라) | 서버 콘솔 로그로 감지 가능 | 서버 콘솔 로그 + Lua |
| Space Age 클리어 (Solar System Edge) | **불가** | Lua `game.finished` 감지 가능 |

**Space Age 클리어 감지 제한 사유:**
- 승리 조건은 `control.lua`에서 `game.set_game_state{game_finished=true}`로 런타임에 처리됨
- 서버 로그에 출력되지 않음
- 세이브 파일에 클리어 플래그 저장되지 않음 (.zip 문자열 추출로 확인 완료)
- Lua로 읽으면 업적 비활성화됨

## CI/CD: Auto Version Update

```yaml
# GitHub Actions
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours

# Flow:
# 1. Fetch latest stable version from https://factorio.com/api/latest-releases
# 2. Compare with current deployed version
# 3. If different → build new Docker image → push to Docker Hub (latest + version tag)
```

- **Track:** stable only
- **API:** `https://factorio.com/api/latest-releases` → `stable.headless`

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Frontend + API | Next.js |
| Container | Docker (debian:bookworm-slim) |
| Hosting | GCP (Cloud Run / GKE, auto-scaling) |
| Image Registry | Docker Hub |
| CI/CD | GitHub Actions |
| Server Communication | RCON |

## Known Limitations

1. **Blueprint ban + achievements:** `/permissions`가 GUI 전용이라 RCON/headless에서 자동화 불가. 공식 포럼에 feature request 제출함 (2026-03-20).
2. **Production stats in achievement mode:** Lua API 접근 시 업적 비활성화되므로 불가.
3. **Save file permission editing:** `level.dat` 바이너리 포맷이 비공개이고 버전마다 변경되어 현실적으로 불가.
4. **Space Age 클리어 감지 + achievements:** 승리 이벤트가 로그에 남지 않고, Lua로만 감지 가능하나 업적 비활성화됨. 업적 모드에서는 스피드런 리더보드(Space Age) 미지원.
5. **Speedrun leaderboard in achievement mode:** 로켓 발사는 콘솔 로그로 감지 가능하나, Space Age 클리어는 감지 불가하여 비업적 모드에서만 지원.

## Open Items

- [ ] `/toggle-action-logging`이 RCON + headless에서 동작하는지 테스트
- [ ] GCP 인프라 상세 설계 (Cloud Run vs GKE)
- [ ] 인증/유저 관리 방식 결정
- [ ] 서버당 리소스 제한 (CPU/RAM) 설정
- [ ] 과금 모델 (무료/유료)
