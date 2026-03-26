-- Dockerio Speedrun Timer
-- LiveSplit-style timer with milestone tracking
-- PB comparison via RCON, draggable, collapsible

local TIMER_UPDATE_INTERVAL = 3

-- Milestones in speedrun route order
local MILESTONES = {
    -- Nauvis
    { id = "green_science",     name = "Green Science",      type = "research", tech = "logistic-science-pack",   icon = "item/logistic-science-pack" },
    { id = "oil",               name = "Oil Processing",     type = "research", tech = "oil-processing",          icon = "item/oil-refinery" },
    { id = "blue_science",      name = "Blue Science",       type = "research", tech = "chemical-science-pack",   icon = "item/chemical-science-pack" },
    { id = "rocket_silo",       name = "Rocket Silo",        type = "research", tech = "rocket-silo",             icon = "item/rocket-silo" },
    { id = "rocket_launch",     name = "Rocket Launch",      type = "event",    icon = "item/rocket-part" },
    { id = "white_science",     name = "Space Science",      type = "research", tech = "space-science-pack",      icon = "item/space-science-pack" },

    -- Planets (any order)
    { id = "planet_vulcanus",   name = "Vulcanus",           type = "planet",   surface = "vulcanus",  icon = "space-location/vulcanus" },
    { id = "planet_gleba",      name = "Gleba",              type = "planet",   surface = "gleba",     icon = "space-location/gleba" },
    { id = "planet_fulgora",    name = "Fulgora",            type = "planet",   surface = "fulgora",   icon = "space-location/fulgora" },
    { id = "planet_aquilo",     name = "Aquilo",             type = "planet",   surface = "aquilo",    icon = "space-location/aquilo" },

    -- Finish
    { id = "space_age_clear",   name = "Solar System Edge",  type = "event",    icon = "space-location/solar-system-edge" },
}

---------------------------------------------------------------------------
-- Time formatting
---------------------------------------------------------------------------

local function format_time(ticks)
    if not ticks then return "--:--.--" end
    local total_seconds = ticks / 60
    local hours = math.floor(total_seconds / 3600)
    local minutes = math.floor((total_seconds % 3600) / 60)
    local seconds = total_seconds % 60

    if hours > 0 then
        return string.format("%d:%02d:%05.2f", hours, minutes, seconds)
    else
        return string.format("%02d:%05.2f", minutes, seconds)
    end
end

local function format_delta(current_ticks, pb_ticks)
    if not current_ticks or not pb_ticks then return "" end
    local delta = current_ticks - pb_ticks
    local sign = delta >= 0 and "+" or "-"
    local abs_delta = math.abs(delta)
    local total_seconds = abs_delta / 60
    local minutes = math.floor(total_seconds / 60)
    local seconds = total_seconds % 60

    if minutes > 0 then
        return string.format("%s%d:%04.1f", sign, minutes, seconds)
    else
        return string.format("%s%04.1f", sign, seconds)
    end
end

---------------------------------------------------------------------------
-- PB management
---------------------------------------------------------------------------

local function save_pb()
    -- Write PB to file for RCON extraction
    if not storage.pb then return end
    local data = "{"
    local first = true
    for id, ticks in pairs(storage.pb) do
        if not first then data = data .. "," end
        data = data .. '"' .. id .. '":' .. ticks
        first = false
    end
    data = data .. "}"
    helpers.write_file("speedrun-pb.json", data, false)
end

local function update_pb()
    -- Update PB if current run is faster (or first run)
    if not storage.milestones then return end
    if not storage.pb then storage.pb = {} end

    local updated = false
    for _, ms in ipairs(MILESTONES) do
        local current = storage.milestones[ms.id]
        if current then
            if not storage.pb[ms.id] or current < storage.pb[ms.id] then
                storage.pb[ms.id] = current
                updated = true
            end
        end
    end

    if updated then
        save_pb()
    end
end

---------------------------------------------------------------------------
-- Milestone checking
---------------------------------------------------------------------------

local function check_milestones(force)
    if not storage.milestones then return end

    for _, ms in ipairs(MILESTONES) do
        if not storage.milestones[ms.id] then
            local completed = false

            if ms.type == "research" and ms.tech then
                local tech = force.technologies[ms.tech]
                if tech and tech.researched then
                    completed = true
                end
            elseif ms.type == "planet" and ms.surface then
                for _, surface in pairs(game.surfaces) do
                    if surface.name == ms.surface then
                        completed = true
                        break
                    end
                end
            end

            if completed then
                storage.milestones[ms.id] = game.tick
                update_pb()
                update_all_guis()
            end
        end
    end
end

---------------------------------------------------------------------------
-- GUI
---------------------------------------------------------------------------

local function get_milestone_color(ms_id)
    if storage.milestones[ms_id] then
        return { 0.3, 1, 0.3 }
    else
        return { 0.6, 0.6, 0.6 }
    end
end

local function get_delta_color(current_ticks, pb_ticks)
    if not current_ticks or not pb_ticks then return { 0.6, 0.6, 0.6 } end
    if current_ticks <= pb_ticks then
        return { 0.3, 1, 0.3 } -- green = faster
    else
        return { 1, 0.3, 0.3 } -- red = slower
    end
end

local function get_current_split_id()
    for _, ms in ipairs(MILESTONES) do
        if not storage.milestones[ms.id] then
            return ms.id
        end
    end
    return nil
end

local function create_gui(player)
    if player.gui.screen["speedrun-timer-frame"] then
        player.gui.screen["speedrun-timer-frame"].destroy()
    end

    local frame = player.gui.screen.add{
        type = "frame",
        name = "speedrun-timer-frame",
        direction = "vertical",
    }
    frame.location = storage.gui_location or { x = 10, y = 10 }
    frame.style.padding = 4
    frame.style.minimal_width = 300

    -- Title bar (drag + toggle only)
    local titlebar = frame.add{
        type = "flow",
        name = "titlebar",
        direction = "horizontal",
    }
    titlebar.style.horizontal_spacing = 4

    local drag = titlebar.add{
        type = "empty-widget",
        name = "drag",
        style = "draggable_space",
    }
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.drag_target = frame

    titlebar.add{
        type = "sprite-button",
        name = "speedrun-timer-toggle",
        sprite = storage.gui_collapsed and "utility/expand" or "utility/collapse",
        style = "frame_action_button",
        tooltip = "Toggle milestones",
    }

    -- Progress bar
    local completed = 0
    local total = #MILESTONES
    for _, ms in ipairs(MILESTONES) do
        if storage.milestones[ms.id] then
            completed = completed + 1
        end
    end

    local progress = frame.add{
        type = "progressbar",
        name = "progress-bar",
        value = completed / total,
    }
    progress.style.horizontally_stretchable = true
    progress.style.height = 8
    progress.style.color = { 0.3, 0.9, 0.3 }
    progress.style.top_margin = 2
    progress.style.bottom_margin = 4

    -- Milestones panel
    local panel = frame.add{
        type = "flow",
        name = "milestones-panel",
        direction = "vertical",
    }

    local current_split = get_current_split_id()

    if storage.gui_collapsed then
        -- Collapsed: show only current split
        panel.visible = false

        if current_split then
            local collapsed_flow = frame.add{
                type = "flow",
                name = "collapsed-current",
                direction = "horizontal",
            }
            collapsed_flow.style.vertical_align = "center"
            collapsed_flow.style.horizontal_spacing = 6

            for _, ms in ipairs(MILESTONES) do
                if ms.id == current_split then
                    collapsed_flow.add{
                        type = "sprite",
                        sprite = ms.icon,
                    }.style.size = { 20, 20 }

                    local lbl = collapsed_flow.add{
                        type = "label",
                        caption = ms.name,
                    }
                    lbl.style.font = "default-semibold"
                    lbl.style.font_color = { 1, 1, 1 }
                    break
                end
            end
        end
    else
        -- Expanded: full milestone table
        -- Header
        local header = panel.add{
            type = "table",
            name = "milestones-header",
            column_count = 4,
        }
        header.style.horizontal_spacing = 6
        header.style.cell_padding = 0

        header.add{ type = "empty-widget" }.style.width = 20
        local h1 = header.add{ type = "label", caption = "Split" }
        h1.style.font = "default-small-semibold"
        h1.style.font_color = { 0.5, 0.5, 0.5 }
        h1.style.width = 120
        local h2 = header.add{ type = "label", caption = "Time" }
        h2.style.font = "default-small-semibold"
        h2.style.font_color = { 0.5, 0.5, 0.5 }
        h2.style.width = 80
        h2.style.horizontal_align = "right"
        local h3 = header.add{ type = "label", caption = "+/-" }
        h3.style.font = "default-small-semibold"
        h3.style.font_color = { 0.5, 0.5, 0.5 }
        h3.style.width = 65
        h3.style.horizontal_align = "right"

        -- Milestone rows
        local mtable = panel.add{
            type = "table",
            name = "milestones-table",
            column_count = 4,
        }
        mtable.style.horizontal_spacing = 6
        mtable.style.vertical_spacing = 1
        mtable.style.cell_padding = 1

        for _, ms in ipairs(MILESTONES) do
            local is_current = (current_split == ms.id)
            local color = get_milestone_color(ms.id)
            local ms_ticks = storage.milestones[ms.id]
            local pb_ticks = storage.pb and storage.pb[ms.id] or nil

            -- Icon
            local icon = mtable.add{
                type = "sprite",
                name = "ms-icon-" .. ms.id,
                sprite = ms.icon,
            }
            icon.style.size = { 20, 20 }

            -- Name
            local name_label = mtable.add{
                type = "label",
                name = "ms-name-" .. ms.id,
                caption = ms.name,
            }
            name_label.style.font = "default-semibold"
            name_label.style.width = 120
            if is_current then
                name_label.style.font_color = { 1, 1, 1 }
            else
                name_label.style.font_color = color
            end

            -- Split time
            local time_label = mtable.add{
                type = "label",
                name = "ms-time-" .. ms.id,
                caption = ms_ticks and format_time(ms_ticks) or "",
            }
            time_label.style.font = "default-semibold"
            time_label.style.font_color = color
            time_label.style.width = 80
            time_label.style.horizontal_align = "right"

            -- Delta vs PB
            local delta_text = ""
            local delta_color = { 0.6, 0.6, 0.6 }
            if ms_ticks and pb_ticks then
                delta_text = format_delta(ms_ticks, pb_ticks)
                delta_color = get_delta_color(ms_ticks, pb_ticks)
            end

            local delta_label = mtable.add{
                type = "label",
                name = "ms-delta-" .. ms.id,
                caption = delta_text,
            }
            delta_label.style.font = "default-semibold"
            delta_label.style.font_color = delta_color
            delta_label.style.width = 65
            delta_label.style.horizontal_align = "right"
        end

        -- Separator before timer
        local sep2 = panel.add{ type = "line" }
        sep2.style.top_margin = 4
        sep2.style.bottom_margin = 2
    end

    -- Big timer at bottom
    local timer_label = frame.add{
        type = "label",
        name = "timer-label",
        caption = format_time(game.tick),
    }
    timer_label.style.font = "heading-1"
    timer_label.style.font_color = { 0.4, 0.9, 0.4 }
    timer_label.style.horizontal_align = "center"
    timer_label.style.top_margin = 2
end

local function update_timer(player)
    local frame = player.gui.screen["speedrun-timer-frame"]
    if not frame then return end

    local timer_label = frame["timer-label"]
    if timer_label then
        timer_label.caption = format_time(game.tick)
    end
end

function update_all_guis()
    for _, player in pairs(game.players) do
        create_gui(player)
    end
end

---------------------------------------------------------------------------
-- Tips GUI (first join)
---------------------------------------------------------------------------

local function create_tips_gui(player)
    if player.gui.screen["speedrun-tips-frame"] then return end

    local frame = player.gui.screen.add{
        type = "frame",
        name = "speedrun-tips-frame",
        direction = "vertical",
    }
    frame.style.maximal_width = 450
    frame.style.padding = 12
    frame.auto_center = true

    -- Header
    local titlebar = frame.add{
        type = "flow",
        direction = "horizontal",
    }
    titlebar.style.horizontal_spacing = 8
    titlebar.style.bottom_margin = 8

    local title = titlebar.add{
        type = "label",
        caption = "[img=item/rocket-silo] 스피드런 서버에 오신 것을 환영합니다!",
    }
    title.style.font = "heading-2"
    title.style.font_color = { 1, 0.85, 0.2 }

    local spacer = titlebar.add{ type = "empty-widget" }
    spacer.style.horizontally_stretchable = true

    titlebar.add{
        type = "sprite-button",
        name = "speedrun-tips-close",
        sprite = "utility/close",
        style = "frame_action_button",
    }

    frame.add{ type = "line" }.style.bottom_margin = 8

    -- Main message
    local main_msg = frame.add{
        type = "label",
        caption = "[color=cyan][font=heading-2]나만의 스피드런 빌드를 만들어보세요![/font][/color]",
    }
    main_msg.style.bottom_margin = 12
    main_msg.style.horizontal_align = "center"

    -- Tips
    local tips = {
        {
            icon = "item/logistic-science-pack",
            title = "목표",
            text = "태양계 가장자리(Solar System Edge)에 도달하세요. 모든 마일스톤은 자동으로 기록됩니다.",
        },
        {
            icon = "item/blueprint",
            title = "블루프린트",
            text = "이 서버에서는 블루프린트를 사용할 수 없습니다. 직접 설계하고 건설하세요!",
        },
        {
            icon = "item/speed-module",
            title = "스플릿 타이머",
            text = "화면 왼쪽 상단의 타이머로 실시간 진행 상황을 확인하세요. 접기/펼치기가 가능합니다.",
        },
        {
            icon = "space-location/vulcanus",
            title = "행성 탐험",
            text = "Vulcanus, Gleba, Fulgora, Aquilo — 어떤 순서로 방문해도 OK! 나만의 루트를 찾아보세요.",
        },
        {
            icon = "item/rocket-part",
            title = "PB 기록",
            text = "이전 최고 기록과 비교하여 각 마일스톤의 +/- 시간이 표시됩니다. 기록을 갱신해보세요!",
        },
        {
            icon = "entity/small-biter",
            title = "바이터",
            text = "바이터가 활성화되어 있습니다. 방어를 소홀히 하면 공장이 위험해질 수 있어요.",
        },
    }

    for _, tip in ipairs(tips) do
        local row = frame.add{
            type = "flow",
            direction = "horizontal",
        }
        row.style.vertical_align = "center"
        row.style.horizontal_spacing = 8
        row.style.bottom_margin = 6

        local icon = row.add{
            type = "sprite",
            sprite = tip.icon,
        }
        icon.style.size = { 32, 32 }

        local text_flow = row.add{
            type = "flow",
            direction = "vertical",
        }
        text_flow.style.vertical_spacing = 0

        local tip_title = text_flow.add{
            type = "label",
            caption = tip.title,
        }
        tip_title.style.font = "default-bold"
        tip_title.style.font_color = { 1, 1, 1 }

        local tip_text = text_flow.add{
            type = "label",
            caption = tip.text,
        }
        tip_text.style.font = "default"
        tip_text.style.font_color = { 0.8, 0.8, 0.8 }
        tip_text.style.single_line = false
        tip_text.style.maximal_width = 350
    end

    frame.add{ type = "line" }.style.top_margin = 4

    -- Close button
    local btn_flow = frame.add{
        type = "flow",
        direction = "horizontal",
    }
    btn_flow.style.horizontally_stretchable = true
    btn_flow.style.top_margin = 4

    local spacer2 = btn_flow.add{ type = "empty-widget" }
    spacer2.style.horizontally_stretchable = true

    btn_flow.add{
        type = "button",
        name = "speedrun-tips-start",
        caption = "확인",
    }
end

---------------------------------------------------------------------------
-- RCON interface for PB management
---------------------------------------------------------------------------

-- Load PB data via RCON: /sc remote.call("speedrun", "load_pb", '{"automation":12345}')
-- Get PB data via RCON: /sc remote.call("speedrun", "get_pb")
remote.add_interface("speedrun", {
    load_pb = function(json_str)
        storage.pb = {}
        -- Simple JSON parser for flat key:number objects
        for key, value in string.gmatch(json_str, '"([^"]+)":(%d+)') do
            storage.pb[key] = tonumber(value)
        end
        update_all_guis()
        return "PB loaded"
    end,
    get_pb = function()
        if not storage.milestones then return "{}" end
        local data = "{"
        local first = true
        for id, ticks in pairs(storage.milestones) do
            if not first then data = data .. "," end
            data = data .. '"' .. id .. '":' .. ticks
            first = false
        end
        data = data .. "}"
        return data
    end,
    get_status = function()
        local current = get_current_split_id() or "FINISHED"
        return "Current: " .. current .. " | Tick: " .. game.tick
    end,
})

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

script.on_event(defines.events.on_gui_click, function(event)
    if event.element.name == "speedrun-timer-toggle" then
        local player = game.get_player(event.player_index)
        storage.gui_collapsed = not storage.gui_collapsed
        create_gui(player)
    elseif event.element.name == "speedrun-tips-close" or event.element.name == "speedrun-tips-start" then
        local player = game.get_player(event.player_index)
        if player.gui.screen["speedrun-tips-frame"] then
            player.gui.screen["speedrun-tips-frame"].destroy()
        end
        if not storage.tips_shown then storage.tips_shown = {} end
        storage.tips_shown[player.name] = true
    end
end)

script.on_event(defines.events.on_gui_location_changed, function(event)
    if event.element.name == "speedrun-timer-frame" then
        storage.gui_location = event.element.location
    end
end)

script.on_nth_tick(TIMER_UPDATE_INTERVAL, function()
    for _, player in pairs(game.players) do
        update_timer(player)
    end

    if game.tick % 60 == 0 then
        for _, force in pairs(game.forces) do
            check_milestones(force)
        end
    end
end)

script.on_event(defines.events.on_rocket_launched, function(event)
    if not storage.milestones["rocket_launch"] then
        storage.milestones["rocket_launch"] = game.tick
        update_pb()
        update_all_guis()
    end
end)

script.on_event(defines.events.on_surface_created, function(event)
    local surface = game.get_surface(event.surface_index)
    if surface and surface.platform then
        if not storage.milestones["space_platform"] then
            storage.milestones["space_platform"] = game.tick
            update_pb()
            update_all_guis()
        end
    end
end)

script.on_nth_tick(300, function()
    if not storage.milestones["space_age_clear"] then
        if game.finished then
            storage.milestones["space_age_clear"] = game.tick
            update_pb()
            update_all_guis()
        end
    end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    create_gui(player)

    -- Show tips on first join
    if not storage.tips_shown then storage.tips_shown = {} end
    if not storage.tips_shown[player.name] then
        create_tips_gui(player)
    end
end)

script.on_init(function()
    storage.milestones = {}
    storage.pb = {}
    storage.gui_collapsed = false
    storage.gui_location = nil
    storage.tips_shown = {}
end)

script.on_configuration_changed(function()
    if not storage.milestones then storage.milestones = {} end
    if not storage.pb then storage.pb = {} end
    if storage.gui_collapsed == nil then storage.gui_collapsed = false end
    for _, player in pairs(game.players) do
        create_gui(player)
    end
end)
