-- Dockerio Timelapse Mod
-- Planets (nauvis etc): screenshot every 1 hour
-- Space platforms: screenshot every 30 minutes
-- Nauvis: spawn(0,0) fixed with logarithmic zoom-out

local HOUR = 216000 -- 1 hour in ticks (60 ticks/sec * 3600 sec)
local HALF_HOUR = 108000 -- 30 minutes in ticks
local RESOLUTION = { x = 1280, y = 720 }

-- Logarithmic zoom-out for nauvis
-- Starts zoomed in, gradually zooms out as factory grows
local function get_nauvis_zoom(tick)
    local hours = tick / HOUR
    -- Start at zoom 1.0, asymptotically approach 0.1
    local zoom = 1.0 / (1 + 0.5 * math.log(1 + hours))
    if zoom < 0.1 then zoom = 0.1 end
    return zoom
end

local function is_space_platform(surface)
    return surface.platform ~= nil
end

local function take_screenshot(surface)
    local name = surface.name

    if not storage.screenshot_count[name] then
        storage.screenshot_count[name] = 0
    end

    storage.screenshot_count[name] = storage.screenshot_count[name] + 1
    local count = storage.screenshot_count[name]
    local filename = string.format("timelapse/%s/%04d.png", name, count)

    local zoom
    local position = { x = 0, y = 0 }

    if name == "nauvis" then
        zoom = get_nauvis_zoom(game.tick)
    else
        zoom = 0.5
    end

    game.take_screenshot{
        surface = surface,
        position = position,
        resolution = RESOLUTION,
        zoom = zoom,
        path = filename,
        show_gui = false,
        show_entity_info = false,
        show_cursor_building_preview = false,
        anti_alias = false,
        daytime = 0,
    }
end

script.on_event(defines.events.on_tick, function(event)
    if event.tick <= 0 then return end

    local is_hour = event.tick % HOUR == 0
    local is_half_hour = event.tick % HALF_HOUR == 0

    if not is_half_hour then return end

    for _, surface in pairs(game.surfaces) do
        if is_space_platform(surface) then
            -- Space platforms: every 30 minutes
            take_screenshot(surface)
        elseif is_hour then
            -- Planets: every 1 hour
            take_screenshot(surface)
        end
    end
end)

script.on_init(function()
    storage.screenshot_count = {}
    -- Take first screenshot after a short delay (10 seconds)
    script.on_nth_tick(600, function()
        for _, surface in pairs(game.surfaces) do
            take_screenshot(surface)
        end
        script.on_nth_tick(600, nil)
    end)
end)
