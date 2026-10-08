local _, addon = ...
local L = addon.L
local definitions = addon.SettingDefinitions
local limits = definitions.limits
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
    rows:Heading(L.UI_STARTUP_INTERACTION)

    local activeSwitch = CreateSwitch(panel, L.UI_ENABLE_RP_EMOTE_MENU, rows:Next(),
        function() return settings.active end,
        Database.SetActive, 255)
    -- Match Simple Nameplates' switch plus Active/Inactive status presentation.
    local activeStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    activeStatus:SetPoint("LEFT", activeSwitch:GetFrame(), "RIGHT", 8, 0)
    activeStatus:SetWidth(56)
    activeStatus:SetJustifyH("LEFT")
    function activeSwitch:RefreshValue()
        self:SetChecked(settings.active)
        activeStatus:SetText(settings.active and L.UI_ACTIVE or L.UI_INACTIVE)
    end
    activeSwitch:RefreshValue()
    switches[#switches + 1] = activeSwitch

    local tooltipDelayBox = CreateNumberSetting(
        panel, string.format(L.UI_TOOLTIP_DELAY_D_D,
            limits.tooltipDelayMs.min, limits.tooltipDelayMs.max),
        "tooltipDelayMs", 20, rows:Next(),
        limits.tooltipDelayMs.min, limits.tooltipDelayMs.max,
        function() return settings.tooltipDelayMs end,
        function(value) settings.tooltipDelayMs = value end,
        "ms", 255, Database.GetGlobalSettings
    )

    local hideSettingsSwitch = CreateSwitch(panel, L.UI_HIDE_SETTING_GEAR_ICONS, rows:Next(),
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
            MainWindow.UpdateMenu()
        end, 255)
    switches[#switches + 1] = hideSettingsSwitch

    local gearNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gearNote:SetPoint("LEFT", hideSettingsSwitch:GetFrame(), "RIGHT", FIELD_GAP, 0)
    gearNote:SetText(L.UI_RIGHT_CLICK_AN_EMOTE_TO_EDIT)

    return tooltipDelayBox
end

-- Fade and minimize behavior.
local function CreateInactivitySection(panel, switches, rows)
    rows:Gap(15)
    rows:Heading(L.UI_WINDOW_BEHAVIOR)

    local RefreshInactiveControls
    local RefreshIconControls
    local fadeSwitch = CreateSwitch(panel, L.UI_FADE_THE_MENU_WHEN_INACTIVE, rows:Next(),
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
        panel, L.UI_FADE_AFTER, "fadeDelay", 20, rows:Next(), limits.fadeDelay.min, limits.fadeDelay.max,
        function() return settings.fadeDelay end,
        function(value)
            settings.fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        "seconds", 255
    )

    local inactiveOpacityBox = CreateNumberSetting(
        panel, L.UI_INACTIVE_OPACITY, "inactiveOpacity", 20, rows:Next(), limits.opacity.min * 100, limits.opacity.max * 100,
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
    minimizeLabel:SetText(L.UI_MINIMIZE_TO)

    local minimizeLabels = {NONE = L.UI_NONE, TITLE_BAR = L.UI_TITLE_BAR, ICON = L.UI_ICON}
    local minimizeSelector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for _, mode in ipairs(definitions.enums.minimizeMode.values) do
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
    iconSizeLabel:SetText(L.UI_MINIMIZED_ICON_SIZE)

    local iconSizeBox = CreateIntegerEditBox(
        panel, 255, iconSizeY + 4, 70,
        function() return settings.minimizedIconSize end,
        function(value)
            settings.minimizedIconSize = value
            MainWindow.ApplyMinimizeToIconSettings()
        end,
        false, limits.minimizedIconSize.min, limits.minimizedIconSize.max
    )

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText(string.format(L.UI_D_D_PX, limits.minimizedIconSize.min, limits.minimizedIconSize.max))

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
    rows:Heading(L.UI_LAYOUT, 25)

    local centerY = rows:Next(45)
    local centerButton = Widgets.CreateButton(panel, L.UI_CENTER_WINDOW, MainWindow.CenterWindow, 130, 24)
    centerButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, centerY)
    local resetButton = Widgets.CreateButton(panel, L.UI_RESET_WINDOW, MainWindow.ResetWindowPosition, 125, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, centerY)

    local positionY = rows:Next(35)
    local positionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, positionY)
    positionLabel:SetText(L.UI_EXACT_POSITION_ADVANCED)

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
    heightLabel:SetText(L.UI_WINDOW_HEIGHT)

    local heightBox = CreateIntegerEditBox(
        panel, 255, heightY + 4, 80,
        function() return settings.height end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                settings.y,
                nil,
                value,
                true -- x/y remain offsets for the saved anchor.
            )
        end,
        false, limits.height.min, limits.height.max
    )

    local heightRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightRange:SetPoint("LEFT", heightBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
    heightRange:SetText(string.format(L.UI_D_D_PX, limits.height.min, limits.height.max))

    local lockSwitch = CreateSwitch(panel, L.UI_LOCK_WINDOW, rows:Next(),
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
    widthNote:SetText(L.UI_WINDOW_WIDTH_ADJUSTS_AUTOMATICALLY_TO_FIT_ALL_CATEGORY_AND_EMOTE)
    widthNote:SetTextColor(0.8, 0.8, 0.8, 1)

    return lockSwitch, positionXBox, positionYBox, heightBox
end

-- Global/Profile behavior is organized by startup/interaction, inactivity/minimize behavior, and layout.
local function CreateBehaviorPanel()
    settings = Database.GetSettings()
    local container = CreateFrame("Frame")
    local scrollFrame, panel = Widgets.CreateCanvasScrollBox(container, {step = 40})
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 0)
    panel:SetSize(700, 670)
    local switches = {}
    local Refresh

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -18)
    heading:SetText(L.UI_APP_BEHAVIOR_PREFERENCES)

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText(
        L.UI_STARTUP_PREFERENCES_ARE_GLOBAL_WINDOW_BEHAVIOR_AND_LAYOUT_BELONG_TO
    )
    description:SetTextColor(0.72, 0.72, 0.72)

    local defaultsButton = Widgets.CreateButton(panel, L.UI_RESTORE_GLOBAL_DEFAULTS, function()
        Database.ResetGlobalSettings()
        settings = Database.GetSettings()
        MainWindow.ApplyProfileSettings()
        Database.SetActive(settings.active)
        Refresh()
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

    Refresh = function()
        for _, switch in ipairs(switches) do
            switch:RefreshValue()
        end

        AddonSettings.RefreshGeneralWindowFields()
    end

    container.Refresh = Refresh
    container:SetScript("OnShow", Refresh)
    container:SetScript("OnHide", function()
        for _, control in ipairs({tooltipDelayBox, fadeDelayBox, inactiveOpacityBox,
            iconSizeBox, positionXBox, positionYBox, heightBox}) do
            control:CancelEdit()
        end
    end)

    return container
end


addon.SettingsPanels.Behavior = CreateBehaviorPanel


