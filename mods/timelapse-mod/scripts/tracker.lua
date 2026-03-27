-- Base tracker: auto-expands bounding box as entities are built
-- Tracks each surface independently

local Tracker = {}

local TILE_SIZE = 32

function Tracker.new()
    return {
        surfaces = {},
        -- surfaces[name] = { minPos, maxPos, centerPos, size }
    }
end

function Tracker.get_surface_data(tracker, surface_name)
    if not tracker.surfaces[surface_name] then
        tracker.surfaces[surface_name] = {
            minPos = nil,
            maxPos = nil,
            centerPos = nil,
            size = nil,
        }
    end
    return tracker.surfaces[surface_name]
end

function Tracker.entity_built(tracker, entity, boundary)
    if not entity or not entity.valid then return false end

    local surface_name = entity.surface.name
    local data = Tracker.get_surface_data(tracker, surface_name)

    local pos = entity.position
    local box = entity.bounding_box
    local left = box.left_top.x - boundary
    local top = box.left_top.y - boundary
    local right = box.right_bottom.x + boundary
    local bottom = box.right_bottom.y + boundary

    local changed = false

    if not data.minPos then
        -- First entity on this surface
        data.minPos = { x = left, y = top }
        data.maxPos = { x = right, y = bottom }
        changed = true
    else
        -- Expand if entity is outside current bounds
        if left < data.minPos.x then data.minPos.x = left; changed = true end
        if top < data.minPos.y then data.minPos.y = top; changed = true end
        if right > data.maxPos.x then data.maxPos.x = right; changed = true end
        if bottom > data.maxPos.y then data.maxPos.y = bottom; changed = true end
    end

    if changed then
        Tracker.update_center_and_size(data)
    end

    return changed
end

function Tracker.update_center_and_size(data)
    data.centerPos = {
        x = (data.minPos.x + data.maxPos.x) / 2,
        y = (data.minPos.y + data.maxPos.y) / 2,
    }
    data.size = {
        x = data.maxPos.x - data.minPos.x,
        y = data.maxPos.y - data.minPos.y,
    }
end

function Tracker.get_zoom(data, width, height)
    if not data.size then return 1.0 end

    local zoom_x = width / (TILE_SIZE * data.size.x)
    local zoom_y = height / (TILE_SIZE * data.size.y)
    local zoom = math.min(zoom_x, zoom_y)

    -- Clamp
    if zoom > 1.0 then zoom = 1.0 end
    if zoom < 0.03125 then zoom = 0.03125 end

    return zoom
end

function Tracker.get_position(data)
    if not data.centerPos then return { x = 0, y = 0 } end
    return data.centerPos
end

function Tracker.has_data(data)
    return data.minPos ~= nil
end

return Tracker
