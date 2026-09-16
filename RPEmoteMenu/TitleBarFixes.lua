local _, addon = ...

-- Title-bar fixes kept separate so they can be applied after both MainWindow
-- and Settings have finished defining their public APIs.

local function RefreshInitialPinState()
    local frame = addon.MainWindow and addon.MainWindow.GetFrame
        and addon.MainWindow.GetFrame()
    local settings = addon.Database and addon.Database.GetSettings
        and addon.Database.GetSettings()

    if not frame or not settings then
        return
    end

    for _, child in ipairs({frame:GetChildren()}) do
        local icon = child.Icon
        if icon and icon.GetAtlas
            and icon:GetAtlas() == "waypoint-mappin-minimap-tracked" then
            icon:SetDesaturated(not settings.keepOpen)
            icon:SetAlpha(settings.keepOpen and 1 or 0.45)
            break
        end
    end
end

local function ApplyAutoHideDelay()
    local frame = addon.MainWindow and addon.MainWindow.GetFrame
        and addon.MainWindow.GetFrame()

    if not frame or frame.rpemAutoHideDelayApplied then
        return
    end

    frame.rpemAutoHideDelayApplied = true

    local nativeIsMouseOver = frame.IsMouseOver
    local graceUntil = 0

    frame:HookScript("OnLeave", function()
        local settings = addon.Database and addon.Database.GetSettings
            and addon.Database.GetSettings()
        local delay = settings and tonumber(settings.fadeDelay) or 0
        graceUntil = GetTime() + math.max(delay, 0)
    end)

    frame:HookScript("OnEnter", function()
        graceUntil = 0
    end)

    -- MainWindow's existing auto-hide check uses IsMouseOver(). During the
    -- same delay used by inactive fading, report the frame as still active.
    -- This leaves the existing hide/minimize logic untouched while preventing
    -- the title bar or full window from disappearing immediately on mouse-out.
    frame.IsMouseOver = function(self, ...)
        if graceUntil > GetTime() then
            return true
        end

        return nativeIsMouseOver(self, ...)
    end
end

-- The atlas can finish applying after the button is created, which can leave
-- its startup appearance out of sync with the saved keepOpen value. Reapply
-- the visual state on the next frame after window creation.
local originalCreateMainWindow = addon.MainWindow.CreateMainWindow
addon.MainWindow.CreateMainWindow = function(...)
    originalCreateMainWindow(...)
    ApplyAutoHideDelay()
    C_Timer.After(0, RefreshInitialPinState)
end

-- The title-bar gear is a settings shortcut, so open General rather than the
-- About landing page. MainWindow resolves this function when the button is
-- clicked, making the corrected target effective for the existing handler.
addon.Settings.OpenAbout = addon.Settings.Open
