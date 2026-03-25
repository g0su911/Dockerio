# Dockerio - Factorio Speedrun Server

팩토리오 헤드리스 서버 Docker 이미지. 자동 맵 리셋, 플레이어 모니터링, 업적 지원.

## Features

- **자동 맵 리셋** - 게임 시간 제한 + 스케줄 기반 초기화
- **플레이어 모니터링** - 신규 유저 환영 메시지, 복귀 유저 플레이타임 표시
- **업적 지원** - 콘솔 명령어/모드 없이 업적 달성 가능
- **AFK 자동 킥** - 기본 30분
- **RCON 통신** - mcrcon 기반 서버 제어
- **자동 버전 업데이트** - GitHub Actions로 6시간마다 최신 버전 체크
- **자동 배포** - Docker Hub push 후 GCP 자동 배포
- **리치 텍스트 태그** - 서버 목록에 색상/아이콘/폰트 적용

## Quick Start

### 1. 설정 파일 준비

```bash
git clone https://github.com/Dongsoon-Shin/Dockerio.git
cd Dockerio
```

`config/server-settings.json`에서 Factorio 계정 정보 수정:
```json
{
  "username": "your_factorio_username",
  "token": "your_factorio_token"
}
```

### 2. 환경 변수 설정

`.env` 파일 생성:
```env
FACTORIO_RCON_PASSWORD=your_rcon_password
```

### 3. 서버 실행

```bash
docker compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FACTORIO_RCON_PASSWORD` | `changeme` | RCON 비밀번호 |
| `FACTORIO_RCON_PORT` | `27015` | RCON 포트 |
| `RESET_SCHEDULE` | `WED:06:00,FRI:19:00,MON:06:00` | 자동 리셋 스케줄 (요일:HH:MM) |
| `RESET_GAME_HOURS` | `30` | 게임 내 시간 제한 (시간) |
| `SERVER_MODE` | `achievement` | 서버 모드 |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 34197 | UDP | Factorio 게임 |
| 27015 | TCP | RCON |

## Config Files

| File | Description |
|------|-------------|
| `config/server-settings.json` | 서버 이름, 비밀번호, 태그 등 |
| `config/map-gen-settings.json` | 맵 생성 설정 (자원량, 절벽, 행성별 설정) |
| `config/map-settings.json` | 게임 규칙 (오염, 바이터 진화 등) |
| `config/server-adminlist.json` | 관리자 목록 |

## Scripts

### entrypoint.sh
서버 메인 루프. 맵 생성 → 서버 실행 → 종료 시 새 맵 생성 후 재시작.
리셋 시 `마지막 초기화` 날짜를 server-settings.json 태그에 자동 업데이트.

### reset-monitor.sh
백그라운드에서 실행되며 두 가지 조건으로 자동 리셋:
- **게임 시간 제한**: `RESET_GAME_HOURS` 초과 시
- **스케줄 리셋**: `RESET_SCHEDULE`에 설정된 시간

리셋 전 `/server-save` 실행 후 60초 → 30초 → 10~1초 카운트다운.

### player-monitor.sh
`console.log`를 실시간 감시하며:
- **신규 유저**: 환영 메시지 + 서버 가동시간 + 업적 50% 플레이타임 안내
- **복귀 유저**: 누적 플레이타임 표시
- **퇴장 시**: 세션 플레이타임 자동 누적 저장 (`players.json`)

### manual-reset.sh
관리자 수동 리셋. 컨테이너 내부에서 실행:
```bash
docker exec dockerio-factorio-1 bash /opt/factorio/scripts/manual-reset.sh
```

## Server Commands (RCON)

호스트에서 `shout` 명령어 사용:

```bash
# 서버 공지
shout "메시지 내용"

# RCON 명령어 실행
shout '/players o'          # 접속 중인 플레이어 확인
shout '/time'               # 서버 가동 시간 확인
shout '/server-save'        # 수동 저장
shout '/quit'               # 서버 종료 (entrypoint가 자동 재시작)
```

또는 docker exec로 직접 실행:
```bash
docker exec dockerio-factorio-1 mcrcon -H 127.0.0.1 -P 27015 -p $RCON_PASSWORD "/players o"
```

## Map Settings

현재 맵 설정:
- **자원**: 전부 500% (frequency=6, size=6, richness=6)
- **절벽**: 전체 행성 OFF
- **바이터**: ON (기본값)
- **행성별 자원**: vulcanus_coal, gleba_stone 등 Space Age 자원 포함

값 매핑: `5` = 400%, `6` = 500% (슬라이더 최대)

자세한 설정값은 `docs/map-gen-reference.md` 참고.

## Auto Version Update

GitHub Actions가 6시간마다 Factorio 최신 안정 버전을 체크.
새 버전 감지 시:
1. `VERSION` 파일 업데이트 + 커밋
2. Docker 이미지 빌드 + Docker Hub push
3. GCP 서버에 자동 배포

## CI/CD Pipeline

```
push to main → GitHub Actions → Docker Build → Docker Hub → GCP Deploy
```

수동 배포:
```bash
# GCP 서버에서
cd /home/hackerman/Dockerio
git pull origin main
sudo docker compose pull
sudo docker compose down
sudo docker compose up -d
```

## GCP Server Access

```bash
gcloud compute ssh instance-20260309-130902 --project=dedi-489710 --zone=asia-northeast3-a
```

## Docs

- `docs/plans/2026-03-25-multi-server-platform.md` - 멀티 서버 플랫폼 계획
- `docs/map-gen-reference.md` - 맵 생성 설정 레퍼런스 + Lua 확인 명령어
