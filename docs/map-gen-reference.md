# Map Generation Settings Reference

## autoplace_controls 값 매핑

값 `5`는 게임 내에서 약 400~500%에 해당 (정확한 매핑은 팩토리오 내부 로직에 따라 다름).

## 현재 설정 (map-gen-settings.json)

### Nauvis 자원 (전부 freq=5, size=5, richness=5)
- `coal` - 석탄
- `stone` - 돌
- `copper-ore` - 구리
- `iron-ore` - 철
- `uranium-ore` - 우라늄
- `crude-oil` - 원유

### Space Age 행성 자원 (전부 freq=5, size=5, richness=5)
- `calcite` - 방해석 (불카누스)
- `vulcanus_coal` - 불카누스 석탄
- `lithium_brine` - 리튬 (풀고라)
- `scrap` - 고철 (풀고라)
- `sulfuric_acid_geyser` - 황산 간헐천 (불카누스)
- `fluorine_vent` - 불소 분출구 (아퀼로)
- `tungsten_ore` - 텅스텐 (불카누스)
- `aquilo_crude_oil` - 아퀼로 원유
- `gleba_stone` - 글레바 돌

### 기본값 유지 (freq=1, size=1, richness=1)
- `water` - 물
- `trees` - 나무
- `enemy-base` - 바이터 기지
- `rocks` - 바위
- `vulcanus_volcanism` - 불카누스 화산 활동
- `gleba_plants` - 글레바 식물
- `gleba_water` - 글레바 물
- `gleba_enemy_base` - 글레바 바이터
- `fulgora_islands` - 풀고라 섬

### 절벽 (전부 OFF)
- `nauvis_cliff` - freq=0, size=0, richness=0
- `gleba_cliff` - freq=0, size=0, richness=0
- `fulgora_cliff` - freq=0, size=0, richness=0
- `cliff_settings` - cliff_elevation_0=0, cliff_elevation_interval=0, richness=0

## Lua로 현재 맵 설정 확인하는 방법

게임 내 콘솔(~ 키)에서 실행:

### 현재 surface의 autoplace 값 확인
```
/c local controls = game.surfaces[1].map_gen_settings.autoplace_controls; local result = ""; for name, settings in pairs(controls) do result = result .. name .. ": freq=" .. settings.frequency .. " size=" .. settings.size .. " rich=" .. settings.richness .. "\n"; end; rcon.print(result)
```

### map exchange string에서 설정 추출
```
/c helpers.write_file("map_settings_export.json", helpers.table_to_json(helpers.parse_map_exchange_string(">>>EXCHANGE_STRING<<<")))
```
결과 파일: `script-output/map_settings_export.json`

### 특정 행성 surface 확인
```
/c local s = game.surfaces["vulcanus"]; if s then local controls = s.map_gen_settings.autoplace_controls; local result = ""; for name, settings in pairs(controls) do result = result .. name .. ": freq=" .. settings.frequency .. " size=" .. settings.size .. " rich=" .. settings.richness .. "\n"; end; rcon.print(result) end
```
