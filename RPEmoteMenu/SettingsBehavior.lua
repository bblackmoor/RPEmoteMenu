local _, addon = ...
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local settings
local FIELD_GAP = UI.FIELD_GAP
local Widgets = addon.SettingsWidgets

-- Behavior-local labels and rows compose the shared widget adapters.
local function CreateSwitch(parent, label, y, getValue, setValue, controlX)
    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    caption:SetText(label)
    local control = Widgets.CreateSwitch(parent, setValue)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX, y + 4)
    function control:RefreshValue() self:SetChecked(getValue()) end
    control:RefreshValue()
    return control
end

local function CreateIntegerEditBox(parent, x, y, width, getValue, applyValue,
    allowNegative, minimum, maximum, getOwner)
    local control = Widgets.CreateIntegerEntry(parent, getValue, applyValue, {
        width = width, allowNegative = allowNegative,
        minimum = minimum, maximum = maximum,
        getOwner = getOwner or Database.GetProfileSettings,
    })
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return control
end

local function CreateNumberSetting(parent, labelText, settingKey, x, y,
    minimum, maximum, getValue, applyValue, suffix, controlX, getOwner)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    local control = CreateIntegerEditBox(parent, controlX, y + 4, 70,
        getValue, applyValue, false, minimum, maximum, getOwner)
    control.Label = label
    control:GetFrame().settingKey = settingKey
    if suffix then
        local suffixLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        suffixLabel:SetPoint("LEFT", control:GetFrame(), "RIGHT", FIELD_GAP, 0)
        suffixLabel:SetText(suffix)
        control.SuffixLabel = suffixLabel
    end
    return control
end

-- Startup and interaction settings.
local function CreateStartupSection(panel, switches, rows)
    rows:Heading("Startup & Interaction")

    local activeSwitch = CreateSwitch(panel, "Enable RP Emote Menu", rows:Next(),
        function() return settings.active end,
        Database.SetActive, 255)
    -- Match Simple Nameplates' switch plus Active/Inactive status presentation.
    local activeStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    activeStatus:SetPoint("LEFT", activeSwitch:GetFrame(), "RIGHT", 8, 0)
    activeStatus:SetWidth(56)
    activeStatus:SetJustifyH("LEFT")
    function activeSwitch:RefreshValue()
        self:SetChecked(settings.active)
        activeStatus:SetText(settings.active and "Active" or "Inactive")
    end
    activeSwitch:RefreshValue()
    switches[#switches + 1] = activeSwitch

    local tooltipDelayBox = CreateNumberSetting(
        panel, "Tooltip delay (0-1000)", "tooltipDelayMs", 20, rows:Next(), 0, 1000,
        function() return settings.tooltipDelayMs end,
        function(value) settings.tooltipDelayMs = value end,
        "ms", 255, Database.GetGlobalSettings
    )

    local hideSettingsSwitch = CreateSwitch(panel, "Hide setting gear icons", rows:Next(),
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
            MainWindow.UpdateMenu()
        end, 255)
    switches[#switches + 1] = hideSettingsSwitch

    local gearNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gearNote:SetPoint("LEFT", hideSettingsSwitch:GetFrame(), "RIGHT", FIELD_GAP, 0)
    gearNote:SetText("(right-click an emote to edit)")

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

    local minimizeLabels = {NONE = "None", TITLE_BAR = "Title Bar", ICON = "Icon"}
    local minimizeSelector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for _, mode in ipairs({"NONE", "TITLE_BAR", "ICON"}) do
            options[#options + 1] = {label = minimizeLabels[mode], value = mode}
        end
        return options
    end, function(mode)
        settings.minimizeMode = mode
        MainWindow.ApplyMinimizeToIconSettings()
        if RefreshIconControls then RefreshIconControls() end
    end)
    minimizeSelector:SetWidth(150)
    minimizeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, minimizeY + 5)

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
        end,
        false, addon.MIN_MINIMIZED_ICON_SIZE, addon.MAX_MINIMIZED_ICON_SIZE
    )

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText("(16-64 px)")

    RefreshIconControls = function()
        local enabled = settings.fadeEnabled and settings.minimizeMode == "ICON"
        local alpha = enabled and 1 or 0.45

        iconSizeBox:SetEnabled(enabled)
        iconSizeBox:SetAlpha(alpha)
        iconSizeLabel:SetAlpha(alpha)
    end

    RefreshInactiveControls = function()
        local enabled = settings.fadeEnabled
        local alpha = enabled and 1 or 0.45

        for _, control in ipairs({fadeDelayBox, inactiveOpacityBox}) do
            -- Disable cancels before clearing focus; ClearFocus first would commit.
            control:SetEnabled(enabled)

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
        minimizeSelector, iconSizeBox, minimizeLabels, RefreshInactiveControls
end

-- Window position, size, and lock settings.
local function CreateLayoutSection(panel, switches, rows)
    rows:Gap(15)
    rows:Heading("Layout", 25)

    local centerY = rows:Next(45)
    local centerButton = Widgets.CreateButton(panel, "Center Window", MainWindow.CenterWindow, 130, 24)
    centerButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, centerY)
    local resetButton = Widgets.CreateButton(panel, "Reset Window", MainWindow.ResetWindowPosition, 125, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, centerY)

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
    xLabel:SetPoint("RIGHT", positionXBox:GetFrame(), "LEFT", -FIELD_GAP, 0)
    xLabel:SetText("X")

    local yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("RIGHT", positionYBox:GetFrame(), "LEFT", -FIELD_GAP, 0)
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
        end,
        false, 150, 630
    )

    local heightRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightRange:SetPoint("LEFT", heightBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
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

-- Global/Profile behavior is organized by startup/interaction, inactivity/minimize behavior, and layout.
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
    panel:SetSize(700, 670)
    scrollFrame:SetScrollChild(panel)
    local switches = {}
    local RefreshControls

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("App Behavior & Preferences")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText(
        "Startup preferences are global; window behavior and layout belong to the selected Profile."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local defaultsButton = Widgets.CreateButton(panel, "Restore Global Defaults", function()
        Database.ResetGlobalSettings()
        settings = Database.GetSettings()
        MainWindow.ApplyProfileSettings()
        Database.SetActive(settings.active)
        RefreshControls()
    end, 170, 24)
    defaultsButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)

    local rows = UI.CreateRows(panel, 20, -95, 30)
    local tooltipDelayBox = CreateStartupSection(panel, switches, rows)
    local fadeSwitch, fadeDelayBox, inactiveOpacityBox,
        minimizeSelector, iconSizeBox, minimizeLabels, RefreshInactiveControls =
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
        minimizeSelector:SetValue(settings.minimizeMode,
            minimizeLabels[settings.minimizeMode] or minimizeLabels.NONE)
        iconSizeBox:RefreshValue()
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
    container:SetScript("OnHide", function()
        for _, control in ipairs({tooltipDelayBox, fadeDelayBox, inactiveOpacityBox,
            iconSizeBox, positionXBox, positionYBox, heightBox}) do
            control:CancelEdit()
        end
    end)

    return container
end


UI.CreateGeneralSettingsPanel = CreateGeneralSettingsPanel
