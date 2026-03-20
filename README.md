# Factorio Docker

Factorio headless server Docker image with auto map reset for speedrun servers.

## Features

- Auto map reset (game time limit + scheduled resets)
- AFK auto-kick (configurable, default 30 min)
- RCON enabled for monitoring
- Auto version update via GitHub Actions
- Achievement-safe (no mods, no console commands)

## Quick Start

1. Edit `config/server-settings.json` with your Factorio credentials
2. Run:
   ```bash
   docker compose up -d
   ```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FACTORIO_RCON_PASSWORD` | `changeme` | RCON password |
| `FACTORIO_RCON_PORT` | `27015` | RCON port |
| `RESET_SCHEDULE` | `WED:06:00,FRI:19:00,MON:06:00` | Scheduled reset times (day:HH:MM) |
| `RESET_GAME_HOURS` | `30` | Game hours before auto reset |
| `SERVER_MODE` | `achievement` | `achievement` or `full` |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 34197 | UDP | Factorio game |
| 27015 | TCP | RCON |

## Auto Version Update

GitHub Actions checks for new Factorio stable releases every 6 hours.
New version detected → Docker image auto-built → pushed to Docker Hub.

## Known Limitations (Achievement Mode)

- Blueprint ban cannot be automated (requires manual `/permissions` via GUI)
- Space Age clear detection not available
- Production stats / player activity logs not available
- See `docs/plans/2026-03-20-factorio-docker-platform-design.md` for details
