local _, addon = ...

local MinimizedIconColor = {}
addon.MinimizedIconColor = MinimizedIconColor

local function GetThemeSettings()
    local themeSettings = addon.Database.GetThemeSettings()
    if type(themeSettings.minimizedIconColor) ~= "table" then
        local default = addon.DefaultThemeSettings.minimizedIconColor
        themeSettings.minimizedIconColor = {
            r = tonumber(default.r) or 1.0,
            g = tonumber(default.g) or 0.82,
            b = tonumber(default.b) or 0.0
        }
    end
    return themeSettings
end

local function GetMinimizedIconButton()
    return addon.MainWindow.GetMinimizedIconButton()
end


function MinimizedIconColor.Apply()
    local button = GetMinimizedIconButton()
    if not button or not button.Icon then
        return
    end

    local color = GetThemeSettings().minimizedIconColor

    -- Desaturating first lets the tint cover the full RGB range. A plain
    -- vertex multiply cannot turn the yellow source art blue, grey, etc.
    button.Icon:SetDesaturated(true)
    button.Icon:SetVertexColor(color.r, color.g, color.b, 1)
end


hooksecurefunc(addon.MainWindow, "CreateMainWindow", function()
    C_Timer.After(0, MinimizedIconColor.Apply)
end)

hooksecurefunc(addon.MainWindow, "ApplyMinimizeToIconSettings", function()
    MinimizedIconColor.Apply()
end)

hooksecurefunc(addon.MainWindow, "ApplyProfileSettings", function()
    MinimizedIconColor.Apply()
end)

hooksecurefunc(addon.MainWindow, "ApplyThemeSettings", function()
    MinimizedIconColor.Apply()
end)
