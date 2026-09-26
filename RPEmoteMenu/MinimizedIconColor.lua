local _, addon = ...

local MinimizedIconColor = {}
addon.MinimizedIconColor = MinimizedIconColor

local colorControl
local previewControl

local function CopyColor(color)
    return {
        r = tonumber(color and color.r) or 1.0,
        g = tonumber(color and color.g) or 0.82,
        b = tonumber(color and color.b) or 0.0
    }
end

local function GetSettings()
    local settings = addon.Database.GetSettings()
    if type(settings.minimizedIconColor) ~= "table" then
        settings.minimizedIconColor = CopyColor(addon.DefaultSettings.minimizedIconColor)
    end
    return settings
end

local function GetMinimizedIconButton()
    return addon.MainWindow.GetMinimizedIconButton()
end


function MinimizedIconColor.Apply()
    local button = GetMinimizedIconButton()
    if not button or not button.Icon then
        return
    end

    local color = GetSettings().minimizedIconColor

    -- Desaturating first lets the tint cover the full RGB range. A plain
    -- vertex multiply cannot turn the yellow source art blue, grey, etc.
    button.Icon:SetDesaturated(true)
    button.Icon:SetVertexColor(color.r, color.g, color.b, 1)
end


local function RefreshSwatch()
    local color = GetSettings().minimizedIconColor
    if colorControl then
        colorControl.Swatch:SetColorTexture(color.r, color.g, color.b, 1)
    end
    if previewControl and previewControl.Icon then
        previewControl.Icon:SetDesaturated(true)
        previewControl.Icon:SetVertexColor(color.r, color.g, color.b, 1)
    end
end


local function SetColor(color)
    GetSettings().minimizedIconColor = CopyColor(color)
    RefreshSwatch()
    MinimizedIconColor.Apply()
end


function MinimizedIconColor.CreateSettingsControls(parent, x, y, inline)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText("Icon color")

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(52, 24)
    if inline then
        button:SetPoint("LEFT", label, "RIGHT", 80, 0)
    else
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 22)
    end
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    button.Swatch = button:CreateTexture(nil, "ARTWORK")
    button.Swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.Swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
    colorControl = button

    button:SetScript("OnClick", function()
        local original = CopyColor(GetSettings().minimizedIconColor)

        local function ApplyPickerColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            SetColor({r = r, g = g, b = b})
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = original.r,
            g = original.g,
            b = original.b,
            swatchFunc = ApplyPickerColor,
            cancelFunc = function(previousColor)
                if type(previousColor) == "table" then
                    SetColor(previousColor)
                else
                    SetColor(original)
                end
            end
        })
    end)

    local resetButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 24)
    resetButton:SetPoint("LEFT", button, "RIGHT", 12, 0)
    resetButton:SetText("Restore Yellow")
    resetButton:SetScript("OnClick", function()
        SetColor(addon.DefaultSettings.minimizedIconColor)
    end)

    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(32, 32)
    preview:SetPoint("LEFT", resetButton, "RIGHT", 12, 0)
    preview.Icon = preview:CreateTexture(nil, "ARTWORK")
    preview.Icon:SetAllPoints(preview)
    preview.Icon:SetTexture(
        "Interface\\AddOns\\RPEmoteMenu\\Media\\icon-minimized.tga"
    )
    previewControl = preview

    RefreshSwatch()
    return label, button, resetButton, preview
end


function MinimizedIconColor.RefreshControl()
    RefreshSwatch()
end


hooksecurefunc(addon.MainWindow, "CreateMainWindow", function()
    C_Timer.After(0, MinimizedIconColor.Apply)
end)

hooksecurefunc(addon.MainWindow, "ApplyMinimizeToIconSettings", function()
    MinimizedIconColor.Apply()
end)

hooksecurefunc(addon.MainWindow, "ApplyProfileSettings", function()
    MinimizedIconColor.Apply()
    RefreshSwatch()
end)
