-- Dockerio Speedrun Timer
-- LiveSplit-style timer with milestone tracking
-- Top-left, draggable, collapsible

-- Timer update interval (every 3 ticks ≈ 20fps, smooth for 2 decimal places)
local TIMER_UPDATE_INTERVAL = 3

-- Milestones definition
-- { id, name, type, check_fn }
-- type: "research", "event", "planet"
local MILESTONES = {
    -- Early game
    { id = "automation",       name = "Automation",           type = "research", tech = "automation" },
    { id = "logistics",        name = "Logistics",            type = "research", tech = "logistics" },
    { id = "steel",            name = "Steel Processing",     type = "research", tech = "steel-processing" },
    { id = "oil",              name = "Oil Processing",       type = "research", tech = "oil-processing" },
    { id = "advanced_circuits", name = "Advanced Circuits",   type = "research", tech = "advanced-circuit" },
    { id = "chemical_science", name = "Chemical Science",     type = "research", tech = "chemical-science-pack" },
    { id = "utility_science",  name = "Utility Science",      type = "research", tech = "utility-science-pack" },
    { id = "production_science", name = "Production Science", type = "research", tech = "production-science-pack" },
    { id = "rocket_silo",      name = "Rocket Silo",          type = "research", tech = "rocket-silo" },

    -- Space Age
    { id = "rocket_launch",    name = "Rocket Launch",        type = "event" },
    { id = "space_platform",   name = "Space Platform",       type = "event" },
    { id = "planet_vulcanus",  name = "Vulcanus",             type = "planet", surface = "vulcanus" },
    { id = "planet_fulgora",   name = "Fulgora",              type = "planet", surface = "fulgora" },
    { id = "planet_gleba",     name = "Gleba",                type = "planet", surface = "gleba" },
    { id = "planet_aquilo",    name = "Aquilo",               type = "planet", surface = "aquilo" },
    { id = "space_age_clear",  name = "Solar System Edge",    type = "event" },
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

local function format_split(current_ticks, milestone_ticks)
    if not milestone_ticks then return "" end
    return format_time(milestone_ticks)
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
                -- Check if any player has visited this surface
                for _, surface in pairs(game.surfaces) do
                    if surface.name == ms.surface then
                        completed = true
                        break
                    end
                end
            end
            -- "event" type milestones are checked via event handlers

            if completed then
                storage.milestones[ms.id] = game.tick
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
        return { 0.2, 1, 0.2 } -- green for completed
    else
        return { 0.7, 0.7, 0.7 } -- gray for pending
    end
end

local function create_gui(player)
    if player.gui.screen["speedrun-timer-frame"] then
        player.gui.screen["speedrun-timer-frame"].destroy()
    end

    -- Main frame
    local frame = player.gui.screen.add{
        type = "frame",
        name = "speedrun-timer-frame",
        direction = "vertical",
    }
    frame.location = { x = 10, y = 10 }

    -- Title bar (draggable)
    local titlebar = frame.add{
        type = "flow",
        name = "titlebar",
        direction = "horizontal",
    }
    titlebar.style.horizontal_spacing = 4
    titlebar.style.vertically_stretchable = false

    -- Drag handle
    local drag = titlebar.add{
        type = "empty-widget",
        name = "drag",
        style = "draggable_space",
    }
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.style.minimal_width = 100
    drag.drag_target = frame

    -- Collapse/expand button
    titlebar.add{
        type = "sprite-button",
        name = "speedrun-timer-toggle",
        sprite = "utility/collapse",
        style = "frame_action_button",
        tooltip = "Toggle milestones",
    }

    -- Timer label (always visible)
    local timer_label = frame.add{
        type = "label",
        name = "timer-label",
        caption = "00:00.00",
    }
    timer_label.style.font = "heading-1"
    timer_label.style.font_color = { 1, 1, 1 }
    timer_label.style.horizontal_align = "center"

    -- Milestones panel (collapsible)
    local panel = frame.add{
        type = "flow",
        name = "milestones-panel",
        direction = "vertical",
    }
    panel.style.top_padding = 4

    -- Milestone table
    local table = panel.add{
        type = "table",
        name = "milestones-table",
        column_count = 2,
    }
    table.style.horizontal_spacing = 12
    table.style.vertical_spacing = 2

    for _, ms in ipairs(MILESTONES) do
        -- Milestone name
        local name_label = table.add{
            type = "label",
            name = "ms-name-" .. ms.id,
            caption = ms.name,
        }
        name_label.style.font = "default-semibold"
        name_label.style.font_color = get_milestone_color(ms.id)

        -- Milestone time
        local time_label = table.add{
            type = "label",
            name = "ms-time-" .. ms.id,
            caption = format_split(game.tick, storage.milestones[ms.id]),
        }
        time_label.style.font = "default-semibold"
        time_label.style.font_color = get_milestone_color(ms.id)
        time_label.style.minimal_width = 80
        time_label.style.horizontal_align = "right"
    end

    -- Set initial collapsed state
    if storage.gui_collapsed == nil then
        storage.gui_collapsed = false
    end
    panel.visible = not storage.gui_collapsed
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
        local frame = player.gui.screen["speedrun-timer-frame"]
        if not frame then
            create_gui(player)
            frame = player.gui.screen["speedrun-timer-frame"]
        end

        -- Update timer
        update_timer(player)

        -- Update milestone colors and times
        local panel = frame["milestones-panel"]
        if panel then
            local table = panel["milestones-table"]
            if table then
                for _, ms in ipairs(MILESTONES) do
                    local name_el = table["ms-name-" .. ms.id]
                    local time_el = table["ms-time-" .. ms.id]
                    if name_el then
                        name_el.style.font_color = get_milestone_color(ms.id)
                    end
                    if time_el then
                        time_el.caption = format_split(game.tick, storage.milestones[ms.id])
                        time_el.style.font_color = get_milestone_color(ms.id)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

-- Toggle collapse/expand
script.on_event(defines.events.on_gui_click, function(event)
    if event.element.name == "speedrun-timer-toggle" then
        local player = game.get_player(event.player_index)
        local frame = player.gui.screen["speedrun-timer-frame"]
        if frame then
            local panel = frame["milestones-panel"]
            if panel then
                panel.visible = not panel.visible
                storage.gui_collapsed = not panel.visible

                -- Update button sprite
                if panel.visible then
                    event.element.sprite = "utility/collapse"
                else
                    event.element.sprite = "utility/expand"
                end
            end
        end
    end
end)

-- Timer update
script.on_nth_tick(TIMER_UPDATE_INTERVAL, function()
    for _, player in pairs(game.players) do
        update_timer(player)
    end

    -- Check milestones every second
    if game.tick % 60 == 0 then
        for _, force in pairs(game.forces) do
            check_milestones(force)
        end
    end
end)

-- Rocket launch detection
script.on_event(defines.events.on_rocket_launched, function(event)
    if not storage.milestones["rocket_launch"] then
        storage.milestones["rocket_launch"] = game.tick
        update_all_guis()
    end
end)

-- Space platform built detection
script.on_event(defines.events.on_surface_created, function(event)
    local surface = game.get_surface(event.surface_index)
    if surface and surface.platform then
        if not storage.milestones["space_platform"] then
            storage.milestones["space_platform"] = game.tick
            update_all_guis()
        end
    end
end)

-- Game finished (Solar System Edge)
script.on_event(defines.events.on_game_created_from_scenario, function()
    -- This won't catch Solar System Edge directly
    -- We check game.finished in the periodic check instead
end)

-- Check for game finished periodically (Solar System Edge)
script.on_nth_tick(300, function() -- every 5 seconds
    if not storage.milestones["space_age_clear"] then
        if game.finished then
            storage.milestones["space_age_clear"] = game.tick
            update_all_guis()
        end
    end
end)

-- Player joined - create GUI
script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    create_gui(player)
end)

-- Init
script.on_init(function()
    storage.milestones = {}
    storage.gui_collapsed = false
end)

-- When mod is added to existing save
script.on_configuration_changed(function()
    if not storage.milestones then
        storage.milestones = {}
    end
    if storage.gui_collapsed == nil then
        storage.gui_collapsed = false
    end
    for _, player in pairs(game.players) do
        create_gui(player)
    end
end)
