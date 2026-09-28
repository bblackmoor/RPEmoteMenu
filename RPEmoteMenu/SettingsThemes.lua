local _, addon = ...
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local GetExchangeDialog = UI.GetExchangeDialog
local CreateNumberSetting = UI.CreateNumberSetting
local CreateColorSetting = UI.CreateColorSetting
local CreateFontSetting = UI.CreateFontSetting
local FIELD_GAP = UI.FIELD_GAP

-- Theme selection here is an editor selection; Profile assignment is made on Profiles.
local function CreateThemeManagementControls(panel, onSelectionChanged)
    local selectedName = Database.GetActiveThemeName()
    local rows = UI.CreateRows(panel, 20, -81, 33)
    local labelY = rows:Next(22)
    local selectorY = rows:Next(40)
    local descriptionY = rows:Next(40)
    local primaryY = rows:Next(38)
    local secondaryY = rows:Next()
    local restoreY = rows:Next()
    local statusY = rows:Next()

    local selector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, selectorY)
    selector:SetDefaultText(selectedName)

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
        selectedName = name
        Refresh()
        onSelectionChanged(name)
    end

    local renameButton, deleteButton, restoreButton
    Refresh = function()
        if not Database.GetTheme(selectedName) then
            selectedName = Database.GetActiveThemeName()
        end
        selector:OverrideText(selectedName)
        description:SetText((Database.IsBuiltInThemeName(selectedName)
                and "Bundled Theme: " or "") .. Database.GetThemeDescription(selectedName)
            .. (selectedName == Database.GetActiveThemeName()
                and " Used by this character." or " Editing does not assign it to this character."))
        renameButton:SetEnabled(selectedName ~= "Default")
        deleteButton:SetEnabled(selectedName ~= "Default")
        restoreButton:SetEnabled(selectedName == "Default"
            or Database.IsBuiltInThemeName(selectedName))
    end

    selector:SetupMenu(function(_, root)
        for _, name in ipairs(Database.GetThemeNames()) do
            root:CreateRadio(Database.IsBuiltInThemeName(name)
                    and (name .. " (Bundled)") or name,
                function() return selectedName == name end,
                function() SelectTheme(name) end)
        end
        for _, definition in ipairs(addon.BuiltInThemes) do
            if not Database.GetTheme(definition.name) then
                root:CreateButton("Recreate " .. definition.name, function()
                    Database.RestoreTheme(definition.name)
                    SelectTheme(definition.name)
                    SetStatus("Recreated " .. definition.name .. ".")
                end)
            end
        end
    end)

    UI.RegisterThemeDialogs(SelectTheme, SetStatus)

    local function Button(caption, x, y, width, action)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(width, 24)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        button:SetText(caption)
        button:SetScript("OnClick", action)
        return button
    end

    Button("Create", 20, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "create", initial = ""})
    end)
    Button("Copy", 123, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "copy", source = selectedName, initial = selectedName .. " Copy"})
    end)
    renameButton = Button("Rename", 226, primaryY, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "rename", source = selectedName, initial = selectedName})
    end)
    deleteButton = Button("Delete", 329, primaryY, 95, function()
        UI.ConfirmThemeDeletion(selectedName)
    end)
    restoreButton = Button("Restore Theme", 20, secondaryY, 125, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_THEME", selectedName, nil, selectedName)
    end)
    Button("Export Theme", 153, secondaryY, 125, function()
        local success, errorMessage = GetExchangeDialog():OpenThemeExport(selectedName)
        if not success then SetStatus(errorMessage, true) end
    end)
    Button("Import Theme", 286, secondaryY, 125, function()
        GetExchangeDialog():OpenThemeImport(function(name) SelectTheme(name) end)
    end)
    Button("Restore Bundled Themes", 20, restoreY, 190, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_BUNDLED_THEMES")
    end)

    Refresh()
    return {GetSelectedName = function() return selectedName end, Refresh = Refresh}
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
        "Custom fonts may take |cffffff0010 to 30 seconds|r to appear the first time they are selected."
    )
    fontLoadingNote:SetTextColor(0.7, 0.7, 0.7)

    controls.categoryFont = CreateFontSetting(
        editor, "Font", "categoryFont", 20, fontY,
        state.GetSettings, state.Apply, 95
    )

    controls.categoryFontSize = CreateNumberSetting(
        editor, "Font size", "categoryFontSize", 20, fontSizeY, 8, 24,
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
        editor, "Font size", "emoteFontSize", 330, fontSizeY, 8, 24,
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

    local highlightEffectSelector = CreateFrame(
        "DropdownButton",
        nil,
        editor,
        "WowStyle1DropdownTemplate"
    )
    highlightEffectSelector:SetWidth(135)
    highlightEffectSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, effectY + 5)
    highlightEffectSelector:SetDefaultText("Background")
    highlightEffectSelector.settingKey = "categoryHighlightEffect"
    controls.categoryHighlightEffect = highlightEffectSelector

    controls.categoryHighlightThickness = CreateNumberSetting(
        editor, "Thickness", "categoryHighlightThickness", 330, effectY, 1, 6,
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
        highlightEffectSelector:OverrideText(
            highlightEffectLabels[state.GetSettings().categoryHighlightEffect]
        )
    end

    highlightEffectSelector:SetupMenu(function(_, rootDescription)
        for _, effect in ipairs({
            "background", "outline", "separator", "underline", "shadow"
        }) do
            rootDescription:CreateRadio(
                highlightEffectLabels[effect],
                function() return state.GetSettings().categoryHighlightEffect == effect end,
                function()
                    state.GetSettings().categoryHighlightEffect = effect
                    RefreshHighlightControls()
                    state.Apply()
                end
            )
        end
    end)

    return RefreshHighlightControls
end

-- Opacity section: controls follow their visual grouping.
local function CreateThemeOpacity(editor, state, controls, rows)
    rows:Heading("Opacity", 28)
    local opacityY = rows:Next(42)

    controls.windowOpacity = CreateNumberSetting(
        editor, "Menu opacity", "windowOpacity", 20, opacityY, 10, 100,
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

    local titleBarSelector = CreateFrame(
        "DropdownButton",
        nil,
        editor,
        "WowStyle1DropdownTemplate"
    )
    titleBarSelector:SetWidth(150)
    titleBarSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, titleY + 5)
    titleBarSelector:SetDefaultText("Top")
    titleBarSelector.settingKey = "titleBarPosition"
    controls.titleBarPosition = titleBarSelector

    local titleBarLabels = {TOP = "Top", LEFT = "Left"}

    titleBarSelector:SetupMenu(function(_, rootDescription)
        for _, position in ipairs({"TOP", "LEFT"}) do
            rootDescription:CreateRadio(
                titleBarLabels[position],
                function() return state.GetSettings().titleBarPosition == position end,
                function()
                    state.GetSettings().titleBarPosition = position
                    titleBarSelector:OverrideText(titleBarLabels[position])
                    state.Apply()
                end
            )
        end
    end)

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
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Themes")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Edit shared Themes here. Assign a Theme to the character's Profile on Profiles."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

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
        titleBarSelector:OverrideText(
            titleBarLabels[themeSettings.titleBarPosition] or titleBarLabels.TOP
        )
        refreshIconColor()
    end

    local management = CreateThemeManagementControls(panel, function(name)
        themeName = name
        themeSettings = Database.GetThemeSettings(name)
        RefreshControls()
    end)

    container.RefreshControls = function()
        themeSettings = Database.GetThemeSettings(themeName)
        if not themeSettings then
            themeName = Database.GetActiveThemeName()
            themeSettings = Database.GetThemeSettings(themeName)
        end
        management.Refresh()
        RefreshControls()
    end
    container.RefreshFontControls = RefreshFontControls
    container.themeControls = controls
    AddonSettings.RefreshFontControls = RefreshFontControls
    container:SetScript("OnShow", container.RefreshControls)
    container.RefreshControls()
    return container
end


UI.CreateThemesSettingsPanel = CreateThemesSettingsPanel
