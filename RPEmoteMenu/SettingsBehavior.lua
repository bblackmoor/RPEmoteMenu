local _, addon = ...
local L = addon.L
local definitions = addon.SettingDefinitions
local limits = definitions.limits
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local FIELD_GAP = UI.FIELD_GAP
local Widgets = addon.SettingsWidgets

-- Startup and interaction settings.
local function CreateStartupSection(panel, switches, rows)
    rows:Heading(L.UI_STARTUP_INTERACTION)

    local activeSwitch = UI.CreateSwitchSetting(panel, {
        label = L.UI_ENABLE_RP_EMOTE_MENU,
        y = rows:Next(),
        getValue = function() return Database.GetGlobalSettings().active end,
        applyValue = Database.SetActive,
        controlX = 255,
        x = 20,
        controlOffsetY = 4,
    })
    -- Match Simple Nameplates' switch plus Active/Inactive status presentation.
    local activeStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    activeStatus:SetPoint("LEFT", activeSwitch:GetFrame(), "RIGHT", 8, 0)
    activeStatus:SetWidth(56)
    activeStatus:SetJustifyH("LEFT")
    function activeSwitch:RefreshValue()
        self:SetChecked(Database.GetGlobalSettings().active)
        activeStatus:SetText(Database.GetGlobalSettings().active and L.UI_ACTIVE or L.UI_INACTIVE)
    end
    activeSwitch:RefreshValue()
    switches[#switches + 1] = activeSwitch

    local tooltipDelayBox = UI.CreateNumberSetting(panel, {
        label = string.format(L.UI_TOOLTIP_DELAY_D_D,
            limits.tooltipDelayMs.min, limits.tooltipDelayMs.max),
        key = "tooltipDelayMs",
        x = 20, y = rows:Next(),
        minimum = limits.tooltipDelayMs.min, maximum = limits.tooltipDelayMs.max,
        getValue = function() return Database.GetGlobalSettings().tooltipDelayMs end,
        applyValue = function(value) Database.GetGlobalSettings().tooltipDelayMs = value end,
        suffix = "ms",
        controlX = 255,
        getOwner = Database.GetGlobalSettings,
        width = 70,
        controlOffsetY = 4,
        allowNegative = false,
    })

    local hideSettingsSwitch = UI.CreateSwitchSetting(panel, {
        label = L.UI_HIDE_SETTING_GEAR_ICONS,
        y = rows:Next(),
        getValue = function() return Database.GetGlobalSettings().hideSettingsGear end,
        applyValue = function(value)
            Database.GetGlobalSettings().hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
            MainWindow.UpdateMenu()
        end,
        controlX = 255,
        x = 20,
        controlOffsetY = 4,
    })
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
    local fadeSwitch = UI.CreateSwitchSetting(panel, {
        label = L.UI_FADE_THE_MENU_WHEN_INACTIVE,
        y = rows:Next(),
        getValue = function() return Database.GetProfileSettings().fadeEnabled end,
        applyValue = function(value)
            Database.GetProfileSettings().fadeEnabled = value
            MainWindow.ApplyFadeSettings()
            if RefreshInactiveControls then
                RefreshInactiveControls()
            end
        end,
        controlX = 255,
        x = 20,
        controlOffsetY = 4,
    })
    switches[#switches + 1] = fadeSwitch

    local fadeDelayBox = UI.CreateNumberSetting(panel, {
        label = L.UI_FADE_AFTER,
        key = "fadeDelay",
        x = 20, y = rows:Next(),
        minimum = limits.fadeDelay.min, maximum = limits.fadeDelay.max,
        getValue = function() return Database.GetProfileSettings().fadeDelay end,
        applyValue = function(value)
            Database.GetProfileSettings().fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        suffix = "seconds",
        controlX = 255,
        getOwner = Database.GetProfileSettings,
        width = 70,
        controlOffsetY = 4,
        allowNegative = false,
    })

    local inactiveOpacityBox = UI.CreateNumberSetting(panel, {
        label = L.UI_INACTIVE_OPACITY,
        key = "inactiveOpacity",
        x = 20, y = rows:Next(),
        minimum = limits.opacity.min * 100, maximum = limits.opacity.max * 100,
        getValue = function() return Database.GetProfileSettings().inactiveOpacity * 100 end,
        applyValue = function(value)
            Database.GetProfileSettings().inactiveOpacity = value / 100
            MainWindow.ApplyFadeSettings()
        end,
        suffix = "%",
        controlX = 255,
        getOwner = Database.GetProfileSettings,
        width = 70,
        controlOffsetY = 4,
        allowNegative = false,
    })

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
        Database.GetProfileSettings().minimizeMode = mode
        MainWindow.ApplyMinimizeToIconSettings()
        if RefreshIconControls then RefreshIconControls() end
    end)
    minimizeSelector:SetWidth(150)
    minimizeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, minimizeY + 5)

    local iconSizeY = rows:Next()
    local iconSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, iconSizeY)
    iconSizeLabel:SetText(L.UI_MINIMIZED_ICON_SIZE)

    local iconSizeBox = UI.CreateIntegerControl(panel, {
        x = 255, y = iconSizeY + 4,
        width = 70,
        getValue = function() return Database.GetProfileSettings().minimizedIconSize end,
        applyValue = function(value)
            Database.GetProfileSettings().minimizedIconSize = value
            MainWindow.ApplyMinimizeToIconSettings()
        end,
        allowNegative = false,
        minimum = limits.minimizedIconSize.min, maximum = limits.minimizedIconSize.max,
        getOwner = Database.GetProfileSettings,
    })

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText(string.format(L.UI_D_D_PX, limits.minimizedIconSize.min, limits.minimizedIconSize.max))

    RefreshIconControls = function()
        local enabled = Database.GetProfileSettings().fadeEnabled and Database.GetProfileSettings().minimizeMode == "ICON"
        local alpha = enabled and 1 or 0.45

        iconSizeBox:SetEnabled(enabled)
        iconSizeBox:SetAlpha(alpha)
        iconSizeLabel:SetAlpha(alpha)
    end

    RefreshInactiveControls = function()
        local enabled = Database.GetProfileSettings().fadeEnabled
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

    local positionXBox = UI.CreateIntegerControl(panel, {
        x = 255, y = positionY + 4,
        width = 80,
        getValue = function() return Database.GetProfileSettings().x end,
        applyValue = function(value)
            MainWindow.ApplyWindowGeometry(
                value,
                Database.GetProfileSettings().y,
                nil,
                Database.GetProfileSettings().height,
                true
            )
        end,
        allowNegative = true,
        getOwner = Database.GetProfileSettings,
    })

    local positionYBox = UI.CreateIntegerControl(panel, {
        x = 405, y = positionY + 4,
        width = 80,
        getValue = function() return Database.GetProfileSettings().y end,
        applyValue = function(value)
            MainWindow.ApplyWindowGeometry(
                Database.GetProfileSettings().x,
                value,
                nil,
                Database.GetProfileSettings().height,
                true
            )
        end,
        allowNegative = true,
        getOwner = Database.GetProfileSettings,
    })

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

    local heightBox = UI.CreateIntegerControl(panel, {
        x = 255, y = heightY + 4,
        width = 80,
        getValue = function() return Database.GetProfileSettings().height end,
        applyValue = function(value)
            MainWindow.ApplyWindowGeometry(
                Database.GetProfileSettings().x,
                Database.GetProfileSettings().y,
                nil,
                value,
                true -- x/y remain offsets for the saved anchor.
            )
        end,
        allowNegative = false,
        minimum = limits.height.min, maximum = limits.height.max,
        getOwner = Database.GetProfileSettings,
    })

    local heightRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightRange:SetPoint("LEFT", heightBox:GetFrame(), "RIGHT", FIELD_GAP, 0)
    heightRange:SetText(string.format(L.UI_D_D_PX, limits.height.min, limits.height.max))

    local lockSwitch = UI.CreateSwitchSetting(panel, {
        label = L.UI_LOCK_WINDOW,
        y = rows:Next(),
        getValue = function() return Database.GetProfileSettings().locked end,
        applyValue = function(value)
            Database.GetProfileSettings().locked = value
            MainWindow.ApplyMovementLock()
        end,
        controlX = 255,
        x = 20,
        controlOffsetY = 4,
    })
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
        MainWindow.ApplyProfileSettings()
        Database.SetActive(Database.GetGlobalSettings().active)
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
        minimizeSelector:SetValue(Database.GetProfileSettings().minimizeMode,
            minimizeLabels[Database.GetProfileSettings().minimizeMode] or minimizeLabels.NONE)
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


