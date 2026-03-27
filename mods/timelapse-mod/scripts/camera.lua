-- Camera: handles smooth transitions between positions

local Camera = {}

function Camera.new(surface_name)
    return {
        surface_name = surface_name,
        screenshot_count = 0,
        current_pos = nil,
        current_zoom = nil,
        transition = nil,
        transitioning = false,
    }
end

function Camera.create_transition(start_pos, end_pos, start_zoom, end_zoom, ticks)
    return {
        start_pos = { x = start_pos.x, y = start_pos.y },
        end_pos = { x = end_pos.x, y = end_pos.y },
        start_zoom = start_zoom,
        end_zoom = end_zoom,
        ticks_total = ticks,
        ticks_left = ticks,
    }
end

function Camera.update_transition(cam)
    if not cam.transition then return end

    local t = cam.transition
    local progress = (t.ticks_total - t.ticks_left) / t.ticks_total

    -- Linear interpolation
    cam.current_pos = {
        x = t.start_pos.x + (t.end_pos.x - t.start_pos.x) * progress,
        y = t.start_pos.y + (t.end_pos.y - t.start_pos.y) * progress,
    }
    cam.current_zoom = t.start_zoom + (t.end_zoom - t.start_zoom) * progress

    t.ticks_left = t.ticks_left - 1
    if t.ticks_left <= 0 then
        cam.current_pos = { x = t.end_pos.x, y = t.end_pos.y }
        cam.current_zoom = t.end_zoom
        cam.transition = nil
    end
end

return Camera
