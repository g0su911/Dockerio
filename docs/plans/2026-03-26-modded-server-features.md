# Modded Server Features Plan

## 개요

modded (비업적) 서버에서 자체 제작 Lua 모드 + 서버 스크립트로 구현하는 기능들.
업적 모드에서 불가능한 기능들을 Lua API로 자유롭게 구현.

## 완료

### 타임랩스 모드 (`dockerio-timelapse` v0.2.0)
- TLBE 기반 베이스 트래커 (on_built_entity → 바운딩 박스 자동 확장)
- 공장 크기 기반 줌 계산 + 부드러운 카메라 전환
- 2.4초 주기 (25fps, speedGain=60), 1920x1080
- 모든 surface 자동 촬영 (행성 + 우주 플랫폼)
- 리셋 시 ffmpeg 렌더링 → GCS 업로드 (mp4만, 스크린샷 삭제)

### 스피드런 타이머 모드 (`dockerio-speedrun-timer` v0.2.0)
- LiveSplit 스타일 GUI (프로그레스바 + 스플릿 목록 + 타이머)
- 마일스톤: Green Science → Oil → Blue Science → Silo → Launch → Space Science → 행성들 → SSE
- 아이콘 표시, 현재 스플릿 하이라이트, PB 비교 (+/- 초록/빨강)
- 접기/펼치기, 드래그 가능, 위치 저장
- PB RCON 인터페이스 (load_pb/get_pb)
- 첫 접속 시 Tips 화면
- 모드 포털 자동 배포 (GitHub Actions)

---

## 지금 구현: 통계 모드 (`dockerio-stats`)

데이터 수집만 Lua 모드에서, 표시는 웹에서.

### 1. 생산/소비 통계
- 아이템별 생산량/소비량 (철판, 구리판, 회로, 과학팩 등)
- 과학팩 분당 생산 속도
- 로켓 부품 생산량
- 전력 생산/소비

### 2. 플레이어별 기여도
- 플레이어별 건설한 건물 수/종류
- 플레이어별 채굴량
- 플레이어별 킬/데스 (바이터)
- 플레이어별 건설 위치 추적 → 웹에서 히트맵 시각화 (플레이어 색상별)

### 3. 서버 전체 통계
- 바이터 총 킬 수
- 오염도
- 연구 진행 속도

### 4. 잡통계 (재미)
- 컨베이어 벨트 총 길이 (XXkm)
- 설치한 전봇대 수
- 깔은 레일 길이
- 생산한 철판 환산 (에펠탑 XX개)
- 플레이어 사망 횟수
- 걸은 거리

### 데이터 저장
- `game.write_file()` → `script-output/stats/` (JSON)
- RCON으로 실시간 조회 가능 (remote interface)
- 리셋 시 웹/GCS로 전송 후 정리

---

## 나중에 구현

### PB RCON 플로우
- 리셋 전 RCON으로 PB 추출 → 파일 저장
- 서버 시작 시 RCON으로 PB 주입
- entrypoint.sh에서 자동화

### 고퀄리티 타임랩스 (클라우드 렌더링)
- 클라우드 윈도우 VM (GCP/Azure) 온디맨드 방식
- OpenClaw로 Factorio GUI 자동 조작 → 리플레이 렌더링
- 월 $5 이하 목표

---

## 서버 구조

```
mods/
├── timelapse-mod/          # 완료 (v0.2.0)
│   ├── control.lua
│   ├── settings.lua
│   └── scripts/
│       ├── tracker.lua
│       └── camera.lua
├── speedrun-timer-mod/     # 완료 (v0.2.0)
│   └── control.lua
└── stats-mod/              # 지금 구현
    └── control.lua
```
