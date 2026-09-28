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
local function CreateStartupSection(panel, switches)
    local behaviorHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    behaviorHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -95)
    behaviorHeading:SetText("Startup & Interaction")

    local showAtLoginSwitch = CreateSwitch(panel, "Show the addon at login", -125,
        function() return settings.showAtLogin end,
        function(value) settings.showAtLogin = value end)
    showAtLoginSwitch:ClearAllPoints()
    showAtLoginSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -121)
    switches[#switches + 1] = showAtLoginSwitch

    local tooltipDelayBox = CreateNumberSetting(
        panel, "Tooltip delay (0-1000)", "tooltipDelayMs", 20, -155, 0, 1000,
        function() return settings.tooltipDelayMs end,
        function(value) settings.tooltipDelayMs = value end,
        "ms"
    )

    tooltipDelayBox:ClearAllPoints()
    tooltipDelayBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -151)

    local hideSettingsSwitch = CreateSwitch(panel, "Hide settings gear icon", -185,
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
        end)
    hideSettingsSwitch:ClearAllPoints()
    hideSettingsSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -181)
    switches[#switches + 1] = hideSettingsSwitch

    local hideEmoteSwitch = CreateSwitch(
        panel,
        "Hide emote edit gear icons",
        -215,
        function() return settings.hideEmoteEditGears end,
        function(value)
            settings.hideEmoteEditGears = value
            MainWindow.UpdateMenu()
        end
    )
    hideEmoteSwitch:ClearAllPoints()
    hideEmoteSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -211)
    switches[#switches + 1] = hideEmoteSwitch

    local emoteGearNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emoteGearNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -215)
    emoteGearNote:SetText("(right-click an emote to edit)")

    return tooltipDelayBox
end

-- Fade and minimize behavior.
local function CreateInactivitySection(panel, switches)
    local inactiveHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inactiveHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -260)
    inactiveHeading:SetText("Window Behavior")

    local RefreshInactiveControls
    local RefreshIconControls
    local fadeSwitch = CreateSwitch(panel, "Fade the menu when inactive", -290,
        function() return settings.fadeEnabled end,
        function(value)
            settings.fadeEnabled = value
            MainWindow.ApplyFadeSettings()
            if RefreshInactiveControls then
                RefreshInactiveControls()
            end
        end)
    fadeSwitch:ClearAllPoints()
    fadeSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -286)
    switches[#switches + 1] = fadeSwitch

    local fadeDelayBox = CreateNumberSetting(
        panel, "Fade after", "fadeDelay", 20, -320, 0, 60,
        function() return settings.fadeDelay end,
        function(value)
            settings.fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        "seconds"
    )

    local inactiveOpacityBox = CreateNumberSetting(
        panel, "Inactive opacity", "inactiveOpacity", 20, -350, 10, 100,
        function() return settings.inactiveOpacity * 100 end,
        function(value)
            settings.inactiveOpacity = value / 100
            MainWindow.ApplyFadeSettings()
        end,
        "%"
    )

    fadeDelayBox:ClearAllPoints()
    fadeDelayBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -316)
    inactiveOpacityBox:ClearAllPoints()
    inactiveOpacityBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -346)

    local minimizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -380)
    minimizeLabel:SetText("Minimize to")

    local minimizeSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    minimizeSelector:SetWidth(150)
    minimizeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -375)
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

    local iconSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -410)
    iconSizeLabel:SetText("Minimized icon size")

    local iconSizeBox = CreateIntegerEditBox(
        panel, 255, -406, 70,
        function() return settings.minimizedIconSize end,
        function(value)
            settings.minimizedIconSize = value
            MainWindow.ApplyMinimizeToIconSettings()
        end
    )

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox, "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText("(16-64 px)")

    local iconCornerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconCornerLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -440)
    iconCornerLabel:SetText("Icon side")

    local iconCornerSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    iconCornerSelector:SetWidth(150)
    iconCornerSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -435)
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

        for _, control in ipairs({
            iconSizeBox,
            iconCornerSelector
        }) do
            control:SetEnabled(enabled)
            control:SetAlpha(alpha)
        end

        iconSizeLabel:SetAlpha(alpha)
        iconCornerLabel:SetAlpha(alpha)
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
local function CreateLayoutSection(panel, switches)
    local layoutHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -485)
    layoutHeading:SetText("Layout")

    local lockSwitch = CreateSwitch(panel, "Lock window", -625,
        function() return settings.locked end,
        function(value)
            settings.locked = value
            MainWindow.ApplyMovementLock()
        end)
    lockSwitch:ClearAllPoints()
    lockSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -621)
    switches[#switches + 1] = lockSwitch

    local positionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -555)
    positionLabel:SetText("Exact position (advanced)")

    local positionXBox = CreateIntegerEditBox(
        panel, 255, -551, 80,
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
        panel, 405, -551, 80,
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

    local centerButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    centerButton:SetSize(130, 24)
    centerButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -510)
    centerButton:SetText("Center Window")
    centerButton:SetScript("OnClick", MainWindow.CenterWindow)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(125, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -510)
    resetButton:SetText("Reset Window")
    resetButton:SetScript("OnClick", MainWindow.ResetWindowPosition)

    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -590)
    heightLabel:SetText("Window height")

    local heightBox = CreateIntegerEditBox(
        panel, 255, -586, 80,
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

    local widthNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widthNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -655)
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

    local tooltipDelayBox = CreateStartupSection(panel, switches)
    local fadeSwitch, fadeDelayBox, inactiveOpacityBox,
        minimizeSelector, iconSizeBox, iconCornerSelector,
        minimizeLabels, iconCornerLabels, RefreshInactiveControls =
        CreateInactivitySection(panel, switches)
    local lockSwitch, positionXBox, positionYBox, heightBox =
        CreateLayoutSection(panel, switches)

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
