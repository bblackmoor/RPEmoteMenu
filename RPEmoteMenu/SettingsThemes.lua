local _, addon = ...
local definitions = addon.SettingDefinitions
local limits = definitions.limits
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local GetExchangeDialog = UI.GetExchangeDialog
local Widgets = addon.SettingsWidgets
local FIELD_GAP = UI.FIELD_GAP

-- Theme-local labels and rows compose the shared widget adapters.
local function CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateNumberSetting(parent, text, key, x, y, minimum, maximum,
    getValue, applyValue, suffix, controlX)
    local label = CreateLabel(parent, text, x, y)
    local control = Widgets.CreateIntegerEntry(parent, getValue, applyValue, {
        width = 70, minimum = minimum, maximum = maximum,
        getOwner = Database.GetThemeSettings,
    })
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX or x,
        controlX and y + 4 or y - 26)
    control:GetFrame().settingKey = key
    control.Label = label
    if suffix then
        local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        caption:SetPoint("LEFT", control:GetFrame(), "RIGHT", FIELD_GAP, 0)
        caption:SetText(suffix)
        control.SuffixLabel = caption
    end
    return control
end

local function CreateColorSetting(parent, text, key, x, y, getValue, applyValue, controlX)
    CreateLabel(parent, text, x, y)
    local control = Widgets.CreateColorPicker(parent, getValue, applyValue)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX or x,
        controlX and y + 4 or y - 26)
    control:GetFrame().settingKey = key
    return control
end

local function CreateFontSetting(parent, text, key, x, y, getSettings, onChange, controlX)
    CreateLabel(parent, text, x, y)
    local control
    control = Widgets.CreateDropdown(parent, function()
        local choices = {}
        for _, font in ipairs(addon.GetAvailableFonts(getSettings()[key])) do
            choices[#choices + 1] = {value = font.name,
                label = font.unavailable and font.name .. " (unavailable)" or font.name,
                font = font.path}
        end
        return choices
    end, function(name)
        getSettings()[key] = name
        control:RefreshValue()
        onChange()
    end)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", controlX or x,
        controlX and y + 5 or y - 26)
    control:GetFrame().settingKey = key
    local function HideOwnedTooltip()
        if GameTooltip:IsOwned(control:GetFrame()) then GameTooltip:Hide() end
    end
    function control:RefreshValue()
        HideOwnedTooltip()
        local name = getSettings()[key] or ""
        local available = addon.IsFontAvailable(name)
        self.MissingFontName = not available and name or nil
        self:InvalidateOptions()
        self:SetValue(name, available and name or name .. " (unavailable)")
        -- Menu rows preview fonts; the selected label must stay readable.
        self:SetLabelStyle(STANDARD_TEXT_FONT, 12, 1, available and 1 or 0.35, available and 1 or 0.35)
    end
    control:HookScript("OnEnter", function(frame)
        if not control.MissingFontName then return end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetText("Font unavailable")
        GameTooltip:AddLine(control.MissingFontName .. " is not registered by WoW or LibSharedMedia.", 1, 1, 1, true)
        GameTooltip:AddLine("RP Emote Menu is displaying Friz Quadrata instead.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", HideOwnedTooltip)
    control:HookScript("OnHide", HideOwnedTooltip)
    control:RefreshValue()
    return control
end

-- The editor always follows the Theme assigned to the active Profile.
local function CreateThemeManagementControls(panel)
    local selectedName = Database.GetActiveThemeName()
    local rows = UI.CreateRows(panel, 20, -81, 33)
    local labelY = rows:Next(22)
    local selectorY = rows:Next(40)
    local descriptionY = rows:Next(40)
    local primaryY = rows:Next(38)
    local secondaryY = rows:Next()
    local restoreY = rows:Next()
    local statusY = rows:Next()

    local selector

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, labelY)
    label:SetText("Theme to edit")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, descriptionY)
    description:SetWidth(630)
    description:SetJustifyH("LEFT")
    description:SetTextColor(0.75, 0.75, 0.75)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, statusY)
    status:SetWidth(630)
    status:SetJustifyH("LEFT")

    local function SetStatus(message, isError)
        status:SetText(message or "")
        status:SetTextColor(isError and 1 or 0.35, isError and 0.35 or 1,
            isError and 0.35 or 0.45, 1)
    end

    local Refresh
    local function SelectTheme(name)
        local success, errorMessage = Database.SetProfileTheme(
            Database.GetActiveProfileName(), name)
        if not success then SetStatus(errorMessage, true); Refresh() end
    end

    local renameButton, deleteButton, restoreButton
    Refresh = function()
        selectedName = Database.GetActiveThemeName()
        selector:InvalidateOptions()
        selector:SetValue(selectedName, selectedName)
        description:SetText((Database.IsBuiltInThemeName(selectedName)
                and "Bundled Theme: " or "") .. Database.GetThemeDescription(selectedName)
            .. " Used by this character.")
        renameButton:SetEnabled(selectedName ~= "Default")
        deleteButton:SetEnabled(selectedName ~= "Default")
        restoreButton:SetEnabled(selectedName == "Default"
            or Database.IsBuiltInThemeName(selectedName))
    end

    selector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for _, name in ipairs(Database.GetThemeNames()) do
            options[#options + 1] = {value = name,
                label = Database.IsBuiltInThemeName(name) and name .. " (Bundled)" or name}
        end
        for _, definition in ipairs(addon.BuiltInThemes) do
            if not Database.GetTheme(definition.name) then
                options[#options + 1] = {label = "Recreate " .. definition.name, value = definition.name}
            end
        end
        return options
    end, function(name)
        if not Database.GetTheme(name) and Database.IsBuiltInThemeName(name) then
            local success, message = Database.RestoreTheme(name)
            if not success then SetStatus(message, true); Refresh(); return end
            SelectTheme(name)
            SetStatus("Recreated " .. name .. ".")
        else
            SelectTheme(name)
        end
    end)
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, selectorY)

    UI.RegisterThemeDialogs(SelectTheme, SetStatus)

    local function Button(caption, x, y, width, action)
        local button = Widgets.CreateButton(panel, caption, action, width, 24)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        return button
    end

    Button("Create", 20, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "create", initial = ""})
    end)
    Button("Copy", 123, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "copy", source = selectedName, initial = selectedName .. " Copy",
                target = UI.CaptureThemeDialogTarget(selectedName)})
    end)
    renameButton = Button("Rename", 226, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "rename", source = selectedName, initial = selectedName,
                target = UI.CaptureThemeDialogTarget(selectedName)})
    end)
    deleteButton = Button("Delete", 329, primaryY, 95, function()
        UI.ConfirmThemeDeletion(selectedName)
    end)
    restoreButton = Button("Restore Theme", 20, secondaryY, 125, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_THEME", selectedName, nil, UI.CaptureThemeDialogTarget(selectedName))
    end)
    Button("Export Theme", 153, secondaryY, 125, function()
        local success, errorMessage = GetExchangeDialog():OpenThemeExport(selectedName)
        if not success then SetStatus(errorMessage, true) end
    end)
    Button("Import Theme", 286, secondaryY, 125, function()
        GetExchangeDialog():OpenThemeImport(function(name) SelectTheme(name) end)
    end)
    Button("Restore Bundled Themes", 20, restoreY, 190, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_BUNDLED_THEMES", nil, nil,
            UI.CaptureBundledThemeDialogTargets())
    end)

    Refresh()
    return {Refresh = Refresh}
end

-- Typography section: controls follow their visual grouping.
local function CreateThemeTypography(editor, state, controls, rows)
    local fontNoteY = rows:Next(28)
    local paneY = rows:Next(28)
    local fontY = rows:Next(39)
    local fontSizeY = rows:Next(67)
    local textY = rows:Next()
    local selectedY = rows:Next()
    local backgroundY = rows:Next()
    local selectionY = rows:Next()

    local categoryPaneHeading = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    categoryPaneHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, paneY)
    categoryPaneHeading:SetText("Category Pane")

    local emotePaneHeading = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    emotePaneHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 330, paneY)
    emotePaneHeading:SetText("Emote Pane")

    local columnDivider = editor:CreateTexture(nil, "ARTWORK")
    columnDivider:SetColorTexture(0.35, 0.35, 0.35, 0.45)
    columnDivider:SetPoint("TOPLEFT", editor, "TOPLEFT", 314, paneY + 2)
    columnDivider:SetSize(1, 300)

    local fontLoadingNote = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    fontLoadingNote:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, fontNoteY)
    fontLoadingNote:SetWidth(620)
    fontLoadingNote:SetJustifyH("LEFT")
    fontLoadingNote:SetText(
        "Shared fonts update when their provider loads; unavailable fonts use Friz Quadrata."
    )
    fontLoadingNote:SetTextColor(0.7, 0.7, 0.7)

    controls.categoryFont = CreateFontSetting(
        editor, "Font", "categoryFont", 20, fontY,
        state.GetSettings, state.Apply, 95
    )

    controls.categoryFontSize = CreateNumberSetting(
        editor, "Font size", "categoryFontSize", 20, fontSizeY, limits.fontSize.min, limits.fontSize.max,
        function() return state.GetSettings().categoryFontSize end,
        function(value)
            state.GetSettings().categoryFontSize = value
            state.Apply()
        end,
        "px", 160
    )
    controls.categoryFontSize:SetWidth(52)

    controls.emoteFont = CreateFontSetting(
        editor, "Font", "emoteFont", 330, fontY,
        state.GetSettings, state.Apply, 405
    )

    controls.emoteFontSize = CreateNumberSetting(
        editor, "Font size", "emoteFontSize", 330, fontSizeY, limits.fontSize.min, limits.fontSize.max,
        function() return state.GetSettings().emoteFontSize end,
        function(value)
            state.GetSettings().emoteFontSize = value
            state.Apply()
        end,
        "px", 470
    )
    controls.emoteFontSize:SetWidth(52)

    controls.categoryTextColor = CreateColorSetting(
        editor, "Category text", "categoryTextColor", 20, textY,
        function() return state.GetSettings().categoryTextColor end,
        function(value)
            state.GetSettings().categoryTextColor = value
            state.Apply()
        end,
        160
    )

    controls.selectedCategoryTextColor = CreateColorSetting(
        editor, "Selected text", "selectedCategoryTextColor", 20, selectedY,
        function() return state.GetSettings().selectedCategoryTextColor end,
        function(value)
            state.GetSettings().selectedCategoryTextColor = value
            state.Apply()
        end,
        160
    )

    controls.emoteTextColor = CreateColorSetting(
        editor, "Emote-label text", "emoteTextColor", 330, textY,
        function() return state.GetSettings().emoteTextColor end,
        function(value)
            state.GetSettings().emoteTextColor = value
            state.Apply()
        end,
        470
    )

    controls.categoryHighlightColor = CreateColorSetting(
        editor,
        "Selection color",
        "categoryHighlightColor",
        20,
        selectionY,
        function() return state.GetSettings().categoryHighlightColor end,
        function(value)
            state.GetSettings().categoryHighlightColor = value
            state.Apply()
        end,
        160
    )

    controls.categoryBackgroundColor = CreateColorSetting(
        editor, "Background", "categoryBackgroundColor", 20, backgroundY,
        function() return state.GetSettings().categoryBackgroundColor end,
        function(value)
            state.GetSettings().categoryBackgroundColor = value
            state.Apply()
        end,
        160
    )

    controls.emoteBackgroundColor = CreateColorSetting(
        editor, "Background", "emoteBackgroundColor", 330, selectedY,
        function() return state.GetSettings().emoteBackgroundColor end,
        function(value)
            state.GetSettings().emoteBackgroundColor = value
            state.Apply()
        end,
        470
    )



end

-- SelectionEffects section: controls follow their visual grouping.
local function CreateThemeSelectionEffects(editor, state, controls, rows)
    local effectY = rows:Next(54)
    local highlightEffectLabel = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    highlightEffectLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, effectY)
    highlightEffectLabel:SetText("Selection effect")

    local highlightEffectSelector

    controls.categoryHighlightThickness = CreateNumberSetting(
        editor, "Thickness", "categoryHighlightThickness", 330, effectY, limits.highlightThickness.min, limits.highlightThickness.max,
        function() return state.GetSettings().categoryHighlightThickness end,
        function(value)
            state.GetSettings().categoryHighlightThickness = value
            state.Apply()
        end,
        "px"
    )

    local highlightEffectLabels = {
        background = "Background",
        outline = "Outline",
        underline = "Underline",
        shadow = "Drop shadow",
        separator = "Separator"
    }

    local function RefreshHighlightControls()
        local usesThickness = state.GetSettings().categoryHighlightEffect == "outline"
            or state.GetSettings().categoryHighlightEffect == "underline"
            or state.GetSettings().categoryHighlightEffect == "separator"
        local thicknessControl = controls.categoryHighlightThickness

        thicknessControl:SetShown(usesThickness)
        thicknessControl.Label:SetShown(usesThickness)
        thicknessControl.SuffixLabel:SetShown(usesThickness)
        highlightEffectSelector:SetValue(state.GetSettings().categoryHighlightEffect,
            highlightEffectLabels[state.GetSettings().categoryHighlightEffect])
    end

    highlightEffectSelector = Widgets.CreateDropdown(editor, function()
        local options = {}
        for _, effect in ipairs(definitions.enums.categoryHighlightEffect.values) do
            options[#options + 1] = {label = highlightEffectLabels[effect], value = effect}
        end
        return options
    end, function(effect)
        state.GetSettings().categoryHighlightEffect = effect
        RefreshHighlightControls()
        state.Apply()
    end)
    highlightEffectSelector:SetWidth(135)
    highlightEffectSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, effectY + 5)
    highlightEffectSelector:GetFrame().settingKey = "categoryHighlightEffect"
    controls.categoryHighlightEffect = highlightEffectSelector

    return RefreshHighlightControls
end

-- Opacity section: controls follow their visual grouping.
local function CreateThemeOpacity(editor, state, controls, rows)
    rows:Heading("Opacity", 28)
    local opacityY = rows:Next(42)

    controls.windowOpacity = CreateNumberSetting(
        editor, "Menu opacity", "windowOpacity", 20, opacityY, limits.opacity.min * 100, limits.opacity.max * 100,
        function() return state.GetSettings().windowOpacity * 100 end,
        function(value)
            state.GetSettings().windowOpacity = value / 100
            state.Apply()
        end,
        "%", 160
    )

    local opacityVisibleNote = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opacityVisibleNote:SetPoint("LEFT", controls.windowOpacity.SuffixLabel, "RIGHT", FIELD_GAP, 0)
    opacityVisibleNote:SetText("(when visible)")

end

-- LayoutAndIcon section: controls follow their visual grouping.
local function CreateThemeLayoutAndIcon(editor, state, controls, rows)
    rows:Heading("Layout", 28)
    local titleY = rows:Next(42)

    local titleBarLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleBarLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, titleY)
    titleBarLabel:SetText("Title bar")

    local titleBarLabels = {TOP = "Top", LEFT = "Left"}
    local titleBarSelector = Widgets.CreateDropdown(editor, function()
        local options = {}
        for _, position in ipairs(definitions.enums.titleBarPosition.values) do
            options[#options + 1] = {label = titleBarLabels[position], value = position}
        end
        return options
    end, function(position)
        state.GetSettings().titleBarPosition = position
        state.Apply()
    end)
    titleBarSelector:SetWidth(150)
    titleBarSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, titleY + 5)
    titleBarSelector:GetFrame().settingKey = "titleBarPosition"
    controls.titleBarPosition = titleBarSelector

    rows:Heading("Minimized Icon", 30)

    local refreshIconColor = UI.CreateThemeIconColorControls(
        editor, 20, rows:Next(), true, state.GetName
    )

    return titleBarSelector, titleBarLabels, refreshIconColor
end

-- The editor operates on the Theme selected above it.
local function CreateThemesSettingsPanel()
    local container = CreateFrame("Frame")
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        container,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 0)

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetSize(700, 900)
    scrollFrame:SetScrollChild(panel)
    local controls = {}
    local themeName = Database.GetActiveThemeName()
    local themeSettings = Database.GetThemeSettings(themeName)
    local function ApplyIfActive()
        if themeName == Database.GetActiveThemeName() then
            MainWindow.ApplyThemeSettings()
        end
    end

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -18)
    heading:SetText("Themes")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Edit shared Themes here. Selecting a Theme assigns it to the active Profile."
    )
    description:SetTextColor(0.72, 0.72, 0.72)

    local editor = CreateFrame("Frame", nil, panel)
    editor:SetSize(700, 590)
    editor:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -285)

    local state = {
        GetSettings = function() return themeSettings end,
        GetName = function() return themeName end,
        Apply = ApplyIfActive
    }
    local rows = UI.CreateRows(editor, 20, -30, 38)
    CreateThemeTypography(editor, state, controls, rows)
    local RefreshHighlightControls =
        CreateThemeSelectionEffects(editor, state, controls, rows)
    CreateThemeOpacity(editor, state, controls, rows)
    local titleBarSelector, titleBarLabels, refreshIconColor =
        CreateThemeLayoutAndIcon(editor, state, controls, rows)

    local function RefreshFontControls()
        themeSettings = Database.GetThemeSettings(themeName)
        controls.categoryFont:RefreshValue()
        controls.emoteFont:RefreshValue()
    end

    local function RefreshControls()
        for key, control in pairs(controls) do
            if control.RefreshValue then
                control:RefreshValue()
            end
        end

        RefreshHighlightControls()
        titleBarSelector:SetValue(themeSettings.titleBarPosition,
            titleBarLabels[themeSettings.titleBarPosition] or titleBarLabels.TOP)
        refreshIconColor()
    end

    local management = CreateThemeManagementControls(panel)

    container.RefreshControls = function()
        themeName = Database.GetActiveThemeName()
        themeSettings = Database.GetThemeSettings(themeName)
        management.Refresh()
        RefreshControls()
    end
    container.RefreshFontControls = RefreshFontControls
    container.themeControls = controls
    AddonSettings.RefreshFontControls = RefreshFontControls
    container:SetScript("OnShow", container.RefreshControls)
    container:SetScript("OnHide", function()
        for _, control in pairs(controls) do
            if control.CancelEdit then control:CancelEdit() end
        end
        UI.CancelColorEdit()
    end)
    container.RefreshControls()
    return container
end


UI.CreateThemesSettingsPanel = CreateThemesSettingsPanel

