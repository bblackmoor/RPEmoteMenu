local _, addon = ...

addon.DefaultSettings.minimizedIconColor = addon.DefaultSettings.minimizedIconColor
    or {r = 1.0, g = 0.82, b = 0.0}

local MinimizedIconColor = {}
addon.MinimizedIconColor = MinimizedIconColor

local colorControl

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
    if not colorControl then
        return
    end

    local color = GetSettings().minimizedIconColor
    colorControl.Swatch:SetColorTexture(color.r, color.g, color.b, 1)
end


local function SetColor(color)
    GetSettings().minimizedIconColor = CopyColor(color)
    RefreshSwatch()
    MinimizedIconColor.Apply()
end


function MinimizedIconColor.CreateSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Minimized Icon")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(600)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose the color tint used for the on-screen minimized icon. "
        .. "The normal addon icon is not changed."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -90)
    label:SetText("Icon color")

    local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
    button:SetSize(52, 24)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -112)
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

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 24)
    resetButton:SetPoint("LEFT", button, "RIGHT", 12, 0)
    resetButton:SetText("Restore Yellow")
    resetButton:SetScript("OnClick", function()
        SetColor(addon.DefaultSettings.minimizedIconColor)
    end)

    panel:SetScript("OnShow", function()
        RefreshSwatch()
        MinimizedIconColor.Apply()
    end)

    RefreshSwatch()

    local category = Settings.RegisterCanvasLayoutCategory(
        panel,
        "RP Emote Menu - Minimized Icon"
    )
    Settings.RegisterAddOnCategory(category)
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
