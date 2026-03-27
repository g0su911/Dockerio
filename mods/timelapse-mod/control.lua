-- Dockerio Timelapse Mod
-- TLBE-inspired auto base tracking with smooth camera transitions
-- Multi-surface support (planets + space platforms)
-- No GUI, fully automatic, configured via mod settings

local Tracker = require("scripts.tracker")
local Camera = require("scripts.camera")

---------------------------------------------------------------------------
-- Settings helpers
---------------------------------------------------------------------------

local function get_settings()
    local framerate = settings.global["dockerio-timelapse-framerate"].value
    local speed_gain = settings.global["dockerio-timelapse-speed-gain"].value
    local transition_period = settings.global["dockerio-timelapse-transition-period"].value

    -- TLBE formula: interval = (60 * speedGain) / frameRate
    local screenshot_interval = math.floor((60 * speed_gain) / framerate)
    if screenshot_interval < 1 then screenshot_interval = 1 end

    -- Transition ticks
    local transition_ticks = math.floor(transition_period * 60)

    -- Realtime interval (for smooth transitions)
    local realtime_interval = math.floor(60 / framerate)
    if realtime_interval < 1 then realtime_interval = 1 end

    return {
        width = settings.global["dockerio-timelapse-width"].value,
        height = settings.global["dockerio-timelapse-height"].value,
        always_day = settings.global["dockerio-timelapse-always-day"].value,
        boundary = settings.global["dockerio-timelapse-boundary"].value,
        format = settings.global["dockerio-timelapse-format"].value,
        screenshot_interval = screenshot_interval,
        realtime_interval = realtime_interval,
        transition_ticks = transition_ticks,
        framerate = framerate,
        speed_gain = speed_gain,
    }
end

---------------------------------------------------------------------------
-- Camera management
---------------------------------------------------------------------------

local function get_or_create_camera(surface_name)
    if not storage.cameras[surface_name] then
        storage.cameras[surface_name] = Camera.new(surface_name)
    end
    return storage.cameras[surface_name]
end

---------------------------------------------------------------------------
-- Screenshot logic
---------------------------------------------------------------------------

local function take_screenshot(cam, s)
    cam.screenshot_count = cam.screenshot_count + 1
    local filename = string.format("timelapse/%s/%06d.%s",
        cam.surface_name, cam.screenshot_count, s.format)

    local daytime = nil
    if s.always_day then daytime = 0 end

    game.take_screenshot{
        surface = cam.surface_name,
        position = cam.current_pos or { x = 0, y = 0 },
        resolution = { x = s.width, y = s.height },
        zoom = cam.current_zoom or 0.5,
        path = filename,
        show_gui = false,
        show_entity_info = false,
        show_cursor_building_preview = false,
        anti_alias = false,
        daytime = daytime,
    }
end

local function process_cameras()
    -- Skip if multiplayer and no players
    if game.is_multiplayer() and #game.connected_players == 0 then return end

    local s = get_settings()

    for _, surface in pairs(game.surfaces) do
        local name = surface.name
        local tracker_data = Tracker.get_surface_data(storage.tracker, name)

        if not Tracker.has_data(tracker_data) then goto continue end

        local cam = get_or_create_camera(name)
        local target_pos = Tracker.get_position(tracker_data)
        local target_zoom = Tracker.get_zoom(tracker_data, s.width, s.height)

        -- Check if camera needs transition
        if cam.current_pos then
            local dx = math.abs(cam.current_pos.x - target_pos.x)
            local dy = math.abs(cam.current_pos.y - target_pos.y)
            local dz = math.abs((cam.current_zoom or 0.5) - target_zoom)

            if dx > 0.5 or dy > 0.5 or dz > 0.01 then
                if not cam.transitioning and s.transition_ticks > 0 then
                    -- Start transition: take rapid screenshots during transition
                    cam.transitioning = true
                    cam.transition = Camera.create_transition(
                        cam.current_pos, target_pos,
                        cam.current_zoom, target_zoom,
                        s.transition_ticks
                    )
                end
            end
        else
            -- First time: jump directly
            cam.current_pos = { x = target_pos.x, y = target_pos.y }
            cam.current_zoom = target_zoom
        end

        -- During transition: update position and take screenshot at realtime interval
        if cam.transitioning and cam.transition then
            Camera.update_transition(cam)
            take_screenshot(cam, s)

            if not cam.transition then
                cam.transitioning = false
            end
        else
            -- Normal: take screenshot at timelapse interval
            if game.tick % s.screenshot_interval == 0 then
                cam.current_pos = { x = target_pos.x, y = target_pos.y }
                cam.current_zoom = target_zoom
                take_screenshot(cam, s)
            end
        end

        ::continue::
    end
end

---------------------------------------------------------------------------
-- Event handlers
---------------------------------------------------------------------------

-- Track entity placement for base expansion
local function on_entity_built(event)
    local s = get_settings()
    Tracker.entity_built(storage.tracker, event.entity, s.boundary)
end

script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)

-- Main tick: process cameras
script.on_event(defines.events.on_tick, function(event)
    if event.tick <= 0 then return end
    process_cameras()
end)

-- Take initial screenshot shortly after game start
script.on_init(function()
    storage.tracker = Tracker.new()
    storage.cameras = {}

    script.on_nth_tick(600, function()
        process_cameras()
        script.on_nth_tick(600, nil)
    end)
end)

script.on_configuration_changed(function()
    if not storage.tracker then
        storage.tracker = Tracker.new()
    end
    if not storage.cameras then
        storage.cameras = {}
    end
end)
