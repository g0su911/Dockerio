-- Dockerio Statistics
-- Collects game stats for web dashboard display
-- No in-game GUI, data collection only
-- Writes JSON lines to script-output/stats/

local POLL_INTERVAL = 3600 -- 1 minute in ticks (60 * 60)

-- Entity category lookup for event-based counting (replaces periodic scan)
local ENTITY_CATEGORY = {}
for _, name in ipairs({
    "transport-belt", "fast-transport-belt", "express-transport-belt", "turbo-transport-belt",
}) do ENTITY_CATEGORY[name] = "belt_count" end
for _, name in ipairs({
    "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail", "legacy-straight-rail", "legacy-curved-rail",
}) do ENTITY_CATEGORY[name] = "rail_count" end
for _, name in ipairs({
    "small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation",
}) do ENTITY_CATEGORY[name] = "pole_count" end
for _, name in ipairs({
    "pipe", "pipe-to-ground",
}) do ENTITY_CATEGORY[name] = "pipe_count" end

---------------------------------------------------------------------------
-- JSON helpers
---------------------------------------------------------------------------

local function to_json_value(v)
    if type(v) == "string" then
        return '"' .. v:gsub('"', '\\"') .. '"'
    elseif type(v) == "number" then
        return tostring(v)
    elseif type(v) == "boolean" then
        return v and "true" or "false"
    elseif type(v) == "nil" then
        return "null"
    end
    return tostring(v)
end

local function dict_to_json(dict)
    local parts = {}
    for k, v in pairs(dict) do
        table.insert(parts, '"' .. k .. '":' .. to_json_value(v))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function nested_to_json(data)
    local parts = {}
    for k, v in pairs(data) do
        if type(v) == "table" then
            table.insert(parts, '"' .. k .. '":' .. dict_to_json(v))
        else
            table.insert(parts, '"' .. k .. '":' .. to_json_value(v))
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

---------------------------------------------------------------------------
-- Production/consumption stats (polled)
---------------------------------------------------------------------------

local function collect_production_stats(force)
    local item_stats = force.get_item_production_statistics("nauvis")
    local fluid_stats = force.get_fluid_production_statistics("nauvis")

    return {
        item_input = item_stats.input_counts,
        item_output = item_stats.output_counts,
        fluid_input = fluid_stats.input_counts,
        fluid_output = fluid_stats.output_counts,
    }
end

local function collect_kill_stats(force)
    local kill_stats = force.get_kill_count_statistics("nauvis")
    return {
        kills = kill_stats.input_counts,
        deaths = kill_stats.output_counts,
    }
end

---------------------------------------------------------------------------
-- Fun stats: event-driven counts (no per-minute scan)
---------------------------------------------------------------------------

local function collect_fun_stats()
    local c = storage.entity_counts
    local belt_count = c.belt_count
    local rail_count = c.rail_count
    return {
        belt_count = belt_count,
        rail_count = rail_count,
        pole_count = c.pole_count,
        pipe_count = c.pipe_count,
        belt_km = math.floor(belt_count * 2 / 1000 * 100) / 100,
        rail_km  = math.floor(rail_count * 2 / 1000 * 100) / 100,
    }
end

local function on_entity_built(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end
    local cat = ENTITY_CATEGORY[entity.name]
    if cat then
        storage.entity_counts[cat] = storage.entity_counts[cat] + 1
    end
end

local function on_entity_removed(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    local cat = ENTITY_CATEGORY[entity.name]
    if cat then
        local v = storage.entity_counts[cat] - 1
        storage.entity_counts[cat] = v > 0 and v or 0
    end
end

---------------------------------------------------------------------------
-- Player stats
---------------------------------------------------------------------------

local function get_player_summary()
    local summary = {}
    for _, player in pairs(game.players) do
        summary[player.name] = {
            online = player.connected,
            color = string.format("#%02x%02x%02x",
                math.floor(player.color.r * 255),
                math.floor(player.color.g * 255),
                math.floor(player.color.b * 255)),
            built = storage.player_stats[player.name] and storage.player_stats[player.name].built or 0,
            mined = storage.player_stats[player.name] and storage.player_stats[player.name].mined or 0,
            kills = storage.player_stats[player.name] and storage.player_stats[player.name].kills or 0,
            deaths = storage.player_stats[player.name] and storage.player_stats[player.name].deaths or 0,
            distance = storage.player_stats[player.name] and storage.player_stats[player.name].distance or 0,
        }
    end
    return summary
end

---------------------------------------------------------------------------
-- Write stats to file (JSON lines)
---------------------------------------------------------------------------

local function write_stats()
    local force = game.forces["player"]
    if not force then return end

    local production = collect_production_stats(force)
    local kills = collect_kill_stats(force)
    local fun = collect_fun_stats()
    local players = get_player_summary()

    local record = {
        tick = game.tick,
        timestamp = game.tick / 60,
        production = production,
        kills = kills,
        fun = fun,
        players = players,
    }

    -- Build nested JSON manually for deep structures
    local parts = {}
    table.insert(parts, '"tick":' .. record.tick)
    table.insert(parts, '"timestamp":' .. string.format("%.1f", record.timestamp))

    -- Production (nested dicts)
    local prod_parts = {}
    for category, counts in pairs(production) do
        table.insert(prod_parts, '"' .. category .. '":' .. dict_to_json(counts))
    end
    table.insert(parts, '"production":{' .. table.concat(prod_parts, ",") .. '}')

    -- Kills
    local kill_parts = {}
    for category, counts in pairs(kills) do
        table.insert(kill_parts, '"' .. category .. '":' .. dict_to_json(counts))
    end
    table.insert(parts, '"kills":{' .. table.concat(kill_parts, ",") .. '}')

    -- Fun stats
    table.insert(parts, '"fun":' .. dict_to_json(fun))

    -- Players (nested)
    local player_parts = {}
    for name, data in pairs(players) do
        table.insert(player_parts, '"' .. name .. '":' .. dict_to_json(data))
    end
    table.insert(parts, '"players":{' .. table.concat(player_parts, ",") .. '}')

    local json_line = "{" .. table.concat(parts, ",") .. "}\n"
    helpers.write_file("stats/timeline.jsonl", json_line, true) -- append
end

---------------------------------------------------------------------------
-- Event handlers (real-time tracking)
---------------------------------------------------------------------------

local function init_player_stats(player_name)
    if not storage.player_stats[player_name] then
        storage.player_stats[player_name] = {
            built = 0,
            mined = 0,
            kills = 0,
            deaths = 0,
            distance = 0,
            last_pos = nil,
            build_positions = {},
        }
    end
end

-- Player built entity
script.on_event(defines.events.on_built_entity, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    init_player_stats(player.name)
    local ps = storage.player_stats[player.name]
    ps.built = ps.built + 1

    -- Track build position for heatmap
    if event.entity and event.entity.valid then
        local pos = event.entity.position
        table.insert(ps.build_positions, {
            x = math.floor(pos.x),
            y = math.floor(pos.y),
            tick = game.tick,
        })

        -- Keep only last 10000 positions to limit memory
        if #ps.build_positions > 10000 then
            table.remove(ps.build_positions, 1)
        end
    end
end)

-- Player mined entity
script.on_event(defines.events.on_player_mined_entity, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    init_player_stats(player.name)
    storage.player_stats[player.name].mined = storage.player_stats[player.name].mined + 1
end)

-- Player killed enemy
script.on_event(defines.events.on_entity_died, function(event)
    if event.cause and event.cause.valid and event.cause.type == "character" then
        local player = event.cause.player
        if player then
            init_player_stats(player.name)
            storage.player_stats[player.name].kills = storage.player_stats[player.name].kills + 1
        end
    end
end)

-- Player died
script.on_event(defines.events.on_player_died, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    init_player_stats(player.name)
    storage.player_stats[player.name].deaths = storage.player_stats[player.name].deaths + 1
end)

-- Track player walking distance (every 5 seconds)
script.on_nth_tick(300, function()
    for _, player in pairs(game.connected_players) do
        init_player_stats(player.name)
        local ps = storage.player_stats[player.name]

        if ps.last_pos and player.position then
            local dx = player.position.x - ps.last_pos.x
            local dy = player.position.y - ps.last_pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            -- 1 tile = 2m in Factorio
            ps.distance = ps.distance + (dist * 2)
        end
        ps.last_pos = { x = player.position.x, y = player.position.y }
    end
end)

---------------------------------------------------------------------------
-- Entity count events
---------------------------------------------------------------------------

script.on_event(defines.events.on_built_entity,        on_entity_built)
script.on_event(defines.events.on_robot_built_entity,  on_entity_built)
script.on_event(defines.events.script_raised_built,    on_entity_built)
script.on_event(defines.events.script_raised_revive,   on_entity_built)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity,  on_entity_removed)
script.on_event(defines.events.on_entity_died,         on_entity_removed)
script.on_event(defines.events.script_raised_destroy,  on_entity_removed)

---------------------------------------------------------------------------
-- Periodic polling
---------------------------------------------------------------------------

script.on_nth_tick(POLL_INTERVAL, function()
    write_stats()
end)

---------------------------------------------------------------------------
-- RCON interface for web
---------------------------------------------------------------------------

remote.add_interface("statistics", {
    -- Get current stats snapshot
    get_current = function()
        local force = game.forces["player"]
        if not force then return "{}" end

        local production = collect_production_stats(force)
        local kills = collect_kill_stats(force)
        local fun = collect_fun_stats()
        local players = get_player_summary()

        return nested_to_json({
            tick = game.tick,
            fun = fun,
        })
    end,

    -- Get player heatmap data
    get_heatmap = function(player_name)
        if not storage.player_stats[player_name] then return "[]" end
        local positions = storage.player_stats[player_name].build_positions
        local parts = {}
        for _, pos in ipairs(positions) do
            table.insert(parts, "{" ..
                '"x":' .. pos.x .. ',' ..
                '"y":' .. pos.y .. ',' ..
                '"t":' .. pos.tick .. "}")
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end,

    -- Force write current stats
    flush = function()
        write_stats()
        return "flushed"
    end,
})

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

local function init_entity_counts()
    if not storage.entity_counts then
        -- One-time scan to seed counts from existing save
        local counts = { belt_count = 0, rail_count = 0, pole_count = 0, pipe_count = 0 }
        for _, surface in pairs(game.surfaces) do
            for name, cat in pairs(ENTITY_CATEGORY) do
                counts[cat] = counts[cat] + surface.count_entities_filtered{ name = name }
            end
        end
        storage.entity_counts = counts
    end
end

script.on_init(function()
    storage.player_stats = {}
    storage.entity_counts = { belt_count = 0, rail_count = 0, pole_count = 0, pipe_count = 0 }
end)

script.on_configuration_changed(function()
    if not storage.player_stats then
        storage.player_stats = {}
    end
    init_entity_counts()
end)
