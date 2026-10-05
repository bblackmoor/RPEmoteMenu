-- Window size/position calculations; callers own persistence and frame changes.
local _, addon = ...
local definitions = addon.SettingDefinitions
local limits = definitions.limits
local Geometry = {}
addon.WindowGeometry = Geometry

function Geometry.Clamp(x, y, width, height, allowOffscreen, options)
    local screenWidth = math.floor(options.screenWidth + 0.5)
    local screenHeight = math.floor(options.screenHeight + 0.5)

    width = math.floor(tonumber(width)
        or options.expandedWidth)
    height = math.floor(tonumber(height) or options.savedHeight or options.defaultHeight)

    width = math.min(screenWidth, width)
    height = math.max(options.minimumHeight, math.min(options.maximumHeight, screenHeight, height))

    x = math.floor(tonumber(x) or options.savedX or 0)
    y = math.floor(tonumber(y) or options.savedY or screenHeight)

    -- Normal movement supplies the window's TOPLEFT point relative to
    -- UIParent's BOTTOMLEFT and keeps the entire frame on-screen. Advanced
    -- position fields supply signed offsets for the saved anchor instead; the
    -- reset and center buttons provide recovery if an extreme value is used.
    if allowOffscreen then
        x = math.max(limits.position.min, math.min(limits.position.max, x))
        y = math.max(limits.position.min, math.min(limits.position.max, y))
    else
        x = math.max(0, math.min(screenWidth - width, x))
        y = math.max(height, math.min(screenHeight, y))
    end

    return x, y, width, height
end

function Geometry.GetFrameSize(width, height, options)
    if not options.hidden or options.minimizeMode == "NONE" then return width, height end
    if options.titleBarOnLeft then
        if options.minimizeMode == "ICON" then return width, height end
        return options.leftTitleBarWidth, height
    end
    return width, options.titleBarThickness
end


-- Convert a physical upper-left corner to offsets for any accepted anchor pair.
-- Coordinates use UIParent's bottom-left origin, as GetLeft/GetTop do.
local anchorFractions = {
    TOPLEFT={0,1}, TOP={0.5,1}, TOPRIGHT={1,1},
    LEFT={0,0.5}, CENTER={0.5,0.5}, RIGHT={1,0.5},
    BOTTOMLEFT={0,0}, BOTTOM={0.5,0}, BOTTOMRIGHT={1,0}
}
function Geometry.GetAnchorOffsets(left, top, options)
    local point = assert(anchorFractions[options.point], "Invalid window anchor")
    local relative = assert(anchorFractions[options.relativePoint], "Invalid relative anchor")
    return left + point[1] * options.width - relative[1] * options.screenWidth,
        top - (1 - point[2]) * options.height - relative[2] * options.screenHeight
end
