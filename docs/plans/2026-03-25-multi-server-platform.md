# Multi-Server Factorio Platform

## 개요

하나의 베이스 Docker 이미지로 여러 타입의 Factorio 서버를 운영하는 구조.
서버 타입은 환경변수 + config로 구분하고, Docker Hub에서 태그로 관리.

## 서버 타입

| 타입 | Docker Hub 태그 | 설명 |
|------|----------------|------|
| speedrun | `dockerio:speedrun` | 업적 가능, 자동 리셋, 현재 운영 중인 서버 |
| speedrun-sandbox | `dockerio:speedrun-sandbox` | 업적 없음, 타임랩스 등 콘솔 기능 활성화 |
| megabase | `dockerio:megabase` | 리셋 없음, 장기 운영, 대규모 공장 |

## 아키텍처

```
dockerio/
├── Dockerfile                  # 공통 베이스 이미지
├── scripts/
│   ├── entrypoint.sh           # 공통 (SERVER_MODE로 분기)
│   ├── reset-monitor.sh        # speedrun 전용
│   └── player-monitor.sh       # 공통
├── servers/
│   ├── speedrun/
│   │   ├── config/             # server-settings, map-gen 등
│   │   ├── .env
│   │   └── docker-compose.yml
│   ├── speedrun-sandbox/
│   │   ├── config/
│   │   ├── .env
│   │   └── docker-compose.yml
│   └── megabase/
│       ├── config/
│       ├── .env
│       └── docker-compose.yml
└── docker-compose.yml          # 전체 서버 한번에 관리용 (optional)
```

## 서버별 차이점

### speedrun (현재)
- `SERVER_MODE=achievement`
- 자동 리셋: 30시간 / 스케줄
- 콘솔 명령어 제한 (업적 보호)

### speedrun-sandbox
- `SERVER_MODE=sandbox`
- 자동 리셋: 동일
- 콘솔 명령어 허용
- 타임랩스 스크린샷 자동 촬영

### megabase
- `SERVER_MODE=megabase`
- 리셋 없음
- 자동 세이브 강화
- 맵 설정: 자원 극대화, 바이터 OFF 또는 ON (설정 가능)

## Docker Hub 빌드

하나의 Dockerfile에서 빌드 후 태그만 다르게 push:
```
hideroot/dockerio:speedrun
hideroot/dockerio:speedrun-sandbox
hideroot/dockerio:megabase
hideroot/dockerio:latest  (= speedrun)
```

이미지는 동일하고, 서버 타입은 `SERVER_MODE` 환경변수로 결정.

## GCP 배포

하나의 인스턴스에서 서버별로 포트만 다르게 운영:

| 서버 | UDP 포트 | RCON 포트 |
|------|---------|-----------|
| speedrun | 34197 | 27015 |
| speedrun-sandbox | 34198 | 27016 |
| megabase | 34199 | 27017 |

## 마일스톤

1. repo 구조 정리 (servers/ 디렉토리, config 분리)
2. entrypoint.sh에 SERVER_MODE 분기 추가
3. 서버별 docker-compose.yml + config 세팅
4. CI/CD 멀티 태그 빌드
5. GCP에 멀티 서버 배포
6. (추후) 웹 관리 페이지
