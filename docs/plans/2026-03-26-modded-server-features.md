# Modded Server Features Plan

## 개요

speedrun-sandbox (비업적) 서버에서 자체 제작 Lua 모드 + 서버 스크립트로 구현하는 기능들.
업적 모드에서 불가능한 기능들을 Lua API로 자유롭게 구현.

## 지금 구현: 타임랩스 모드

### Lua 모드 (`timelapse-mod`)
- 1시간마다 `game.take_screenshot()` 호출
- 촬영 위치: 스폰(0,0) 고정
- 줌: **로그 스케일 줌아웃** — 초반에 빠르게 줌아웃, 후반에 천천히 (공장 확장 속도에 맞춤)
- 이미지 저장 경로: `script-output/timelapse/`

### 서버 스크립트 (`timelapse-render`)
- 리셋 시 모인 스크린샷을 ffmpeg로 렌더링
- 스크린샷 사이 fade in/out 효과
- 출력: mp4 + gif
- 렌더링 완료 후 스크린샷 원본 정리

---

## 나중에 구현

### 1. 통계 모드 (`stats-mod`)
- 플레이어별 생산량 추적 (Lua `item_production_statistics`)
- 플레이어별 건설량, 기여도
- 플레이어 활동 로그 (Lua event listeners)
- GUI: 추후 설계

### 2. 스피드런 스플릿 타이머 모드 (`speedrun-timer-mod`)
- 리얼타임 스플릿 타이머 (LiveSplit 스타일, 게임 내 표시)
- 마일스톤 자동 감지:
  - 연구 기반: 주요 연구 완료 시점
  - 행성 기반: 각 행성 도달/클리어 (Vulcanus, Fulgora, Gleba, Aquilo)
  - 이벤트 기반: 로켓 발사, 첫 우주 플랫폼, Solar System Edge 도달
- 클리어 감지: Lua `game.finished` (Space Age)
- 로켓 발사 감지: 콘솔 로그 파싱
- 웹 대시보드 연동 (리더보드)

### 3. 고퀄리티 타임랩스 (클라우드 렌더링)
- 클라우드 윈도우 VM (GCP/Azure) 온디맨드 방식
- 리셋 감지 → API로 VM 시작 → OpenClaw로 Factorio GUI 자동 조작
- 리플레이 로드 → 실제 게임 렌더링으로 스크린샷 촬영 → 타임랩스 생성
- 렌더링 완료 → VM 자동 종료 (비용 최소화, 월 $5 이하 목표)
- 현재 서버 스크린샷 방식보다 훨씬 높은 퀄리티

---

## 서버 구조

```
servers/
└── speedrun-sandbox/
    ├── config/
    ├── mods/
    │   ├── timelapse-mod/       # 지금 구현
    │   ├── stats-mod/           # 나중에
    │   └── speedrun-timer-mod/  # 나중에
    ├── .env
    └── docker-compose.yml
```

## 의존성

- `SERVER_MODE=sandbox` 분기가 entrypoint.sh에 구현되어야 함
- ffmpeg 설치 (Docker 이미지에 추가)
- 웹 대시보드는 별도 프로젝트
