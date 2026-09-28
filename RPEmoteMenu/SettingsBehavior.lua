local _, addon = ...
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local settings
local FIELD_GAP = UI.FIELD_GAP
local CreateSwitch = UI.CreateSwitch
local CreateNumberSetting = UI.CreateNumberSetting
local CreateIntegerEditBox = UI.CreateIntegerEditBox

-- Startup and interaction settings.
local function CreateStartupSection(panel, switches, rows)
    rows:Heading("Startup & Interaction")

    local showAtLoginSwitch = CreateSwitch(panel, "Show the addon at login", rows:Next(),
        function() return settings.showAtLogin end,
        function(value) settings.showAtLogin = value end, 255)
    switches[#switches + 1] = showAtLoginSwitch

    local tooltipDelayBox = CreateNumberSetting(
        panel, "Tooltip delay (0-1000)", "tooltipDelayMs", 20, rows:Next(), 0, 1000,
        function() return settings.tooltipDelayMs end,
        function(value) settings.tooltipDelayMs = value end,
        "ms", 255
    )

    local hideSettingsSwitch = CreateSwitch(panel, "Hide settings gear icon", rows:Next(),
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
        end, 255)
    switches[#switches + 1] = hideSettingsSwitch

    local hideEmoteSwitch = CreateSwitch(
        panel,
        "Hide emote edit gear icons",
        rows:Next(),
        function() return settings.hideEmoteEditGears end,
        function(value)
            settings.hideEmoteEditGears = value
            MainWindow.UpdateMenu()
        end,
        255
    )
    switches[#switches + 1] = hideEmoteSwitch

    local emoteGearNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emoteGearNote:SetPoint("LEFT", hideEmoteSwitch, "RIGHT", FIELD_GAP, 0)
    emoteGearNote:SetText("(right-click an emote to edit)")

    return tooltipDelayBox
end

-- Fade and minimize behavior.
local function CreateInactivitySection(panel, switches, rows)
    rows:Gap(15)
    rows:Heading("Window Behavior")

    local RefreshInactiveControls
    local RefreshIconControls
    local fadeSwitch = CreateSwitch(panel, "Fade the menu when inactive", rows:Next(),
        function() return settings.fadeEnabled end,
        function(value)
            settings.fadeEnabled = value
            MainWindow.ApplyFadeSettings()
            if RefreshInactiveControls then
                RefreshInactiveControls()
            end
        end, 255)
    switches[#switches + 1] = fadeSwitch

    local fadeDelayBox = CreateNumberSetting(
        panel, "Fade after", "fadeDelay", 20, rows:Next(), 0, 60,
        function() return settings.fadeDelay end,
        function(value)
            settings.fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        "seconds", 255
    )

    local inactiveOpacityBox = CreateNumberSetting(
        panel, "Inactive opacity", "inactiveOpacity", 20, rows:Next(), 10, 100,
        function() return settings.inactiveOpacity * 100 end,
        function(value)
            settings.inactiveOpacity = value / 100
            MainWindow.ApplyFadeSettings()
        end,
        "%", 255
    )

    local minimizeY = rows:Next()
    local minimizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, minimizeY)
    minimizeLabel:SetText("Minimize to")

    local minimizeSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    minimizeSelector:SetWidth(150)
    minimizeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, minimizeY + 5)
    minimizeSelector:SetDefaultText("None")

    local minimizeLabels = {
        NONE = "None",
        TITLE_BAR = "Title Bar",
        ICON = "Icon"
    }

    minimizeSelector:SetupMenu(function(_, rootDescription)
        for _, mode in ipairs({"NONE", "TITLE_BAR", "ICON"}) do
            rootDescription:CreateRadio(
                minimizeLabels[mode],
                function() return settings.minimizeMode == mode end,
                function()
                    settings.minimizeMode = mode
                    minimizeSelector:OverrideText(minimizeLabels[mode])
                    MainWindow.ApplyMinimizeToIconSettings()
                    if RefreshIconControls then
                        RefreshIconControls()
                    end
                end
            )
        end
    end)

    local iconSizeY = rows:Next()
    local iconSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, iconSizeY)
    iconSizeLabel:SetText("Minimized icon size")

    local iconSizeBox = CreateIntegerEditBox(
        panel, 255, iconSizeY + 4, 70,
        function() return settings.minimizedIconSize end,
        function(value)
            settings.minimizedIconSize = value
            MainWindow.ApplyMinimizeToIconSettings()
        end
    )

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox, "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText("(16-64 px)")

    local iconCornerY = rows:Next()
    local iconCornerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconCornerLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, iconCornerY)
    iconCornerLabel:SetText("Icon side (top bar)")

    local iconCornerSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    iconCornerSelector:SetWidth(150)
    iconCornerSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, iconCornerY + 5)
    iconCornerSelector:SetDefaultText("Left")

    local iconCornerLabels = {
        TOPLEFT = "Left",
        TOPRIGHT = "Right"
    }

    iconCornerSelector:SetupMenu(function(_, rootDescription)
        for _, corner in ipairs({"TOPLEFT", "TOPRIGHT"}) do
            rootDescription:CreateRadio(
                iconCornerLabels[corner],
                function() return settings.minimizedIconCorner == corner end,
                function()
                    settings.minimizedIconCorner = corner
                    iconCornerSelector:OverrideText(iconCornerLabels[corner])
                    MainWindow.ApplyMinimizeToIconSettings()
                end
            )
        end
    end)

    RefreshIconControls = function()
        local enabled = settings.fadeEnabled and settings.minimizeMode == "ICON"
        local alpha = enabled and 1 or 0.45
        local sideEnabled = enabled
            and Database.GetThemeSettings().titleBarPosition ~= "LEFT"

        iconSizeBox:SetEnabled(enabled)
        iconSizeBox:SetAlpha(alpha)
        iconCornerSelector:SetEnabled(sideEnabled)
        iconCornerSelector:SetAlpha(sideEnabled and 1 or 0.45)
        iconSizeLabel:SetAlpha(alpha)
        iconCornerLabel:SetAlpha(sideEnabled and 1 or 0.45)
    end

    RefreshInactiveControls = function()
        local enabled = settings.fadeEnabled
        local alpha = enabled and 1 or 0.45

        for _, control in ipairs({fadeDelayBox, inactiveOpacityBox}) do
            if enabled then
                control:Enable()
            else
                control:ClearFocus()
                control:Disable()
            end

            control:SetAlpha(alpha)
            control.Label:SetAlpha(alpha)
            control.SuffixLabel:SetAlpha(alpha)
        end

        minimizeSelector:SetEnabled(enabled)
        minimizeSelector:SetAlpha(alpha)
        minimizeLabel:SetAlpha(alpha)
        RefreshIconControls()
    end

    return fadeSwitch, fadeDelayBox, inactiveOpacityBox,
        minimizeSelector, iconSizeBox, iconCornerSelector,
        minimizeLabels, iconCornerLabels, RefreshInactiveControls
end

-- Window position, size, and lock settings.
local function CreateLayoutSection(panel, switches, rows)
    rows:Gap(15)
    rows:Heading("Layout", 25)

    local centerY = rows:Next(45)
    local centerButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    centerButton:SetSize(130, 24)
    centerButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, centerY)
    centerButton:SetText("Center Window")
    centerButton:SetScript("OnClick", MainWindow.CenterWindow)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(125, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, centerY)
    resetButton:SetText("Reset Window")
    resetButton:SetScript("OnClick", MainWindow.ResetWindowPosition)

    local positionY = rows:Next(35)
    local positionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, positionY)
    positionLabel:SetText("Exact position (advanced)")

    local positionXBox = CreateIntegerEditBox(
        panel, 255, positionY + 4, 80,
        function() return settings.x end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                value,
                settings.y,
                nil,
                settings.height,
                true
            )
        end,
        true
    )

    local positionYBox = CreateIntegerEditBox(
        panel, 405, positionY + 4, 80,
        function() return settings.y end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                value,
                nil,
                settings.height,
                true
            )
        end,
        true
    )

    local xLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("RIGHT", positionXBox, "LEFT", -FIELD_GAP, 0)
    xLabel:SetText("X")

    local yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("RIGHT", positionYBox, "LEFT", -FIELD_GAP, 0)
    yLabel:SetText("Y")

    local heightY = rows:Next(35)
    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, heightY)
    heightLabel:SetText("Window height")

    local heightBox = CreateIntegerEditBox(
        panel, 255, heightY + 4, 80,
        function() return settings.height end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                settings.y,
                nil,
                value
            )
        end
    )

    local heightRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightRange:SetPoint("LEFT", heightBox, "RIGHT", FIELD_GAP, 0)
    heightRange:SetText("(150-630 px)")

    local lockSwitch = CreateSwitch(panel, "Lock window", rows:Next(),
        function() return settings.locked end,
        function(value)
            settings.locked = value
            MainWindow.ApplyMovementLock()
        end, 255)
    switches[#switches + 1] = lockSwitch

    local widthNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widthNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, rows:Next())
    widthNote:SetWidth(620)
    widthNote:SetJustifyH("LEFT")
    widthNote:SetText("Window width adjusts automatically to fit all category and emote labels in the profile.")
    widthNote:SetTextColor(0.8, 0.8, 0.8, 1)

    return lockSwitch, positionXBox, positionYBox, heightBox
end

-- Global behavior is organized by startup/interaction, inactivity/minimize behavior, and layout.
local function CreateGeneralSettingsPanel()
    settings = Database.GetSettings()
    local container = CreateFrame("Frame")
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        container,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local nextOffset = (self:GetVerticalScroll() or 0) - (delta * 40)
        self:SetVerticalScroll(math.max(
            0,
            math.min(self:GetVerticalScrollRange() or 0, nextOffset)
        ))
    end)

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetSize(700, 700)
    scrollFrame:SetScrollChild(panel)
    local switches = {}
    local RefreshControls

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("App Behavior & Preferences")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText(
        "These settings apply globally, regardless of the active profile."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaultsButton:SetSize(170, 24)
    defaultsButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
    defaultsButton:SetText("Restore Global Defaults")
    defaultsButton:SetScript("OnClick", function()
        Database.ResetGlobalSettings()
        settings = Database.GetSettings()
        MainWindow.ApplyProfileSettings()
        RefreshControls()
    end)

    local rows = UI.CreateRows(panel, 20, -95, 30)
    local tooltipDelayBox = CreateStartupSection(panel, switches, rows)
    local fadeSwitch, fadeDelayBox, inactiveOpacityBox,
        minimizeSelector, iconSizeBox, iconCornerSelector,
        minimizeLabels, iconCornerLabels, RefreshInactiveControls =
        CreateInactivitySection(panel, switches, rows)
    local lockSwitch, positionXBox, positionYBox, heightBox =
        CreateLayoutSection(panel, switches, rows)

    AddonSettings.RefreshGeneralWindowFields = function()
        lockSwitch:RefreshValue()
        positionXBox:RefreshValue()
        positionYBox:RefreshValue()
        heightBox:RefreshValue()
        fadeSwitch:RefreshValue()
        fadeDelayBox:RefreshValue()
        tooltipDelayBox:RefreshValue()
        inactiveOpacityBox:RefreshValue()
        minimizeSelector:OverrideText(
            minimizeLabels[settings.minimizeMode] or minimizeLabels.NONE
        )
        iconSizeBox:RefreshValue()
        iconCornerSelector:OverrideText(
            iconCornerLabels[settings.minimizedIconCorner]
                or iconCornerLabels.TOPLEFT
        )
        RefreshInactiveControls()
    end

    RefreshControls = function()
        for _, switch in ipairs(switches) do
            switch:RefreshValue()
        end

        AddonSettings.RefreshGeneralWindowFields()
    end

    container.RefreshControls = RefreshControls
    container:SetScript("OnShow", RefreshControls)

    return container
end


UI.CreateGeneralSettingsPanel = CreateGeneralSettingsPanel
