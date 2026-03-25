```
╔═══════════════════════════════════════════╗
║  ██████╗  ██████╗  ██████╗██╗  ██╗       ║
║  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝       ║
║  ██║  ██║██║   ██║██║     █████╔╝        ║
║  ██║  ██║██║   ██║██║     ██╔═██╗        ║
║  ██████╔╝╚██████╔╝╚██████╗██║  ██╗       ║
║  ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝       ║
║            ███████╗██████╗ ██╗ ██████╗    ║
║            ██╔════╝██╔══██╗██║██╔═══██╗   ║
║            █████╗  ██████╔╝██║██║   ██║   ║
║            ██╔══╝  ██╔══██╗██║██║   ██║   ║
║            ███████╗██║  ██║██║╚██████╔╝   ║
║            ╚══════╝╚═╝  ╚═╝╚═╝ ╚═════╝   ║
╚═══════════════════════════════════════════╝
```

# Dockerio

Factorio 헤드리스 서버를 Docker로 간편하게 운영. 자동 맵 리셋, 플레이어 모니터링, 업적 지원.

## Features

- **자동 맵 리셋** — 게임 시간 제한 + 스케줄 기반 초기화
- **플레이어 모니터링** — 신규 유저 환영, 복귀 유저 플레이타임 표시
- **업적 지원** — 콘솔 명령어/모드 없이 업적 달성 가능
- **AFK 자동 킥** — 기본 30분
- **리치 텍스트** — 서버 목록에 색상/아이콘/폰트 적용
- **자동 버전 업데이트** — GitHub Actions로 최신 Factorio 버전 자동 빌드
- **10~1초 카운트다운** — 리셋 전 서버 공지

## Quick Start

### 1. Clone

```bash
git clone https://github.com/Dongsoon-Shin/Dockerio.git
cd Dockerio
```

### 2. Install

```bash
./install.sh
```

설치 스크립트가 다음을 안내합니다:
- Factorio 계정 (username + token)
- 서버 이름 / 비밀번호
- 관리자 설정
- RCON 비밀번호 자동 생성

### 3. Factorio Token 발급

1. [https://factorio.com/profile](https://factorio.com/profile) 접속
2. Factorio 계정으로 로그인
3. 페이지 하단 **API authentication token** 섹션에서 토큰 복사
4. `install.sh` 실행 시 입력

> 토큰은 서버가 공개 서버 목록에 등록될 때 필요합니다.

### 4. Run

```bash
docker compose up -d
# 또는
docker-compose up -d
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
| `config/server-settings.json` | 서버 이름, 토큰, 태그 등 (`install.sh`로 생성) |
| `config/server-settings.example.json` | 서버 설정 템플릿 |
| `config/map-gen-settings.json` | 맵 생성 설정 (자원량, 절벽, 행성별 설정) |
| `config/map-settings.json` | 게임 규칙 (오염, 바이터 진화 등) |
| `config/server-adminlist.json` | 관리자 목록 (`install.sh`로 생성) |

> `server-settings.json`, `server-adminlist.json`, `.env`는 `.gitignore`에 포함되어 git에 올라가지 않습니다.

## Scripts

### entrypoint.sh
서버 메인 루프. 맵 생성 → 서버 실행 → 종료 시 새 맵 생성 후 재시작.
리셋 시 `마지막 초기화` 날짜를 server-settings.json 태그에 자동 업데이트.

### reset-monitor.sh
백그라운드에서 실행되며 두 가지 조건으로 자동 리셋:
- **게임 시간 제한**: `RESET_GAME_HOURS` 초과 시
- **스케줄 리셋**: `RESET_SCHEDULE`에 설정된 시간

리셋 전 `/server-save` → 60초 → 30초 → 10~1초 카운트다운.

### player-monitor.sh
`console.log`를 실시간 감시:
- **신규 유저**: 환영 메시지 + 서버 가동시간 + 업적 50% 플레이타임 안내
- **복귀 유저**: 누적 플레이타임 표시
- **퇴장 시**: 세션 플레이타임 자동 누적 저장

### manual-reset.sh
관리자 수동 리셋:
```bash
docker exec dockerio-factorio-1 bash /opt/factorio/scripts/manual-reset.sh
```

## Server Commands (RCON)

```bash
# 서버 공지 (shout 명령어 설치 시)
shout "메시지"

# RCON 명령어
shout '/players o'          # 접속자 확인
shout '/time'               # 서버 가동 시간
shout '/evolution'          # 바이터 진화도
shout '/server-save'        # 수동 저장
```

## Map Settings

현재 기본 맵 설정:
- **자원**: 500% (frequency=6, size=6, richness=6)
- **절벽**: 전체 행성 OFF
- **바이터**: ON
- **Space Age**: vulcanus_coal, gleba_stone 등 행성별 자원 포함

값 매핑: `5` = 400%, `6` = 500%

자세한 설정은 `docs/map-gen-reference.md` 참고.

## Auto Version Update

GitHub Actions가 6시간마다 최신 Factorio 안정 버전 체크.
새 버전 → Docker 빌드 → Docker Hub push → 서버 자동 배포.

## License

MIT
