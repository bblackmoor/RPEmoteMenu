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
    local selector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -103)
    selector:SetDefaultText(selectedName)

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -81)
    label:SetText("Theme to edit")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -143)
    description:SetWidth(630)
    description:SetJustifyH("LEFT")
    description:SetTextColor(0.75, 0.75, 0.75)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -287)
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

    Button("Create", 20, -183, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "create", initial = ""})
    end)
    Button("Copy", 123, -183, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "copy", source = selectedName, initial = selectedName .. " Copy"})
    end)
    renameButton = Button("Rename", 226, -183, 95, function()
        StaticPopup_Show("RPEMOTEMENU_THEME_NAME", nil, nil,
            {action = "rename", source = selectedName, initial = selectedName})
    end)
    deleteButton = Button("Delete", 329, -183, 95, function()
        UI.ConfirmThemeDeletion(selectedName)
    end)
    restoreButton = Button("Restore Theme", 20, -221, 125, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_THEME", selectedName, nil, selectedName)
    end)
    Button("Export Theme", 153, -221, 125, function()
        local success, errorMessage = GetExchangeDialog():OpenThemeExport(selectedName)
        if not success then SetStatus(errorMessage, true) end
    end)
    Button("Import Theme", 286, -221, 125, function()
        GetExchangeDialog():OpenThemeImport(function(name) SelectTheme(name) end)
    end)
    Button("Restore Bundled Themes", 20, -254, 190, function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_BUNDLED_THEMES")
    end)

    Refresh()
    return {GetSelectedName = function() return selectedName end, Refresh = Refresh}
end

-- Typography section: controls follow their visual grouping.
local function CreateThemeTypography(editor, state, controls)
    local categoryPaneHeading = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    categoryPaneHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -120)
    categoryPaneHeading:SetText("Category Pane")

    local emotePaneHeading = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    emotePaneHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 330, -120)
    emotePaneHeading:SetText("Emote Pane")

    local columnDivider = editor:CreateTexture(nil, "ARTWORK")
    columnDivider:SetColorTexture(0.35, 0.35, 0.35, 0.45)
    columnDivider:SetPoint("TOPLEFT", editor, "TOPLEFT", 314, -118)
    columnDivider:SetSize(1, 300)

    local fontLoadingNote = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    fontLoadingNote:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -92)
    fontLoadingNote:SetWidth(620)
    fontLoadingNote:SetJustifyH("LEFT")
    fontLoadingNote:SetText(
        "Custom fonts may take |cffffff0010 to 30 seconds|r to appear the first time they are selected."
    )
    fontLoadingNote:SetTextColor(0.7, 0.7, 0.7)

    controls.categoryFont = CreateFontSetting(
        editor, "Font", "categoryFont", 20, -148,
        state.GetSettings, ApplyIfActive
    )
    controls.categoryFont:ClearAllPoints()
    controls.categoryFont:SetPoint("TOPLEFT", editor, "TOPLEFT", 95, -143)

    controls.categoryFontSize = CreateNumberSetting(
        editor, "Font size", "categoryFontSize", 20, -187, 8, 24,
        function() return state.GetSettings().categoryFontSize end,
        function(value)
            state.GetSettings().categoryFontSize = value
            state.Apply()
        end,
        "px"
    )
    controls.categoryFontSize:SetWidth(52)

    controls.emoteFont = CreateFontSetting(
        editor, "Font", "emoteFont", 330, -148,
        state.GetSettings, ApplyIfActive
    )
    controls.emoteFont:ClearAllPoints()
    controls.emoteFont:SetPoint("TOPLEFT", editor, "TOPLEFT", 405, -143)

    controls.emoteFontSize = CreateNumberSetting(
        editor, "Font size", "emoteFontSize", 330, -187, 8, 24,
        function() return state.GetSettings().emoteFontSize end,
        function(value)
            state.GetSettings().emoteFontSize = value
            state.Apply()
        end,
        "px"
    )
    controls.emoteFontSize:SetWidth(52)

    controls.categoryTextColor = CreateColorSetting(
        editor, "Category text", "categoryTextColor", 20, -254,
        function() return state.GetSettings().categoryTextColor end,
        function(value)
            state.GetSettings().categoryTextColor = value
            state.Apply()
        end
    )

    controls.selectedCategoryTextColor = CreateColorSetting(
        editor, "Selected text", "selectedCategoryTextColor", 20, -292,
        function() return state.GetSettings().selectedCategoryTextColor end,
        function(value)
            state.GetSettings().selectedCategoryTextColor = value
            state.Apply()
        end
    )

    controls.emoteTextColor = CreateColorSetting(
        editor, "Emote-label text", "emoteTextColor", 330, -254,
        function() return state.GetSettings().emoteTextColor end,
        function(value)
            state.GetSettings().emoteTextColor = value
            state.Apply()
        end
    )

    controls.categoryHighlightColor = CreateColorSetting(
        editor,
        "Selection color",
        "categoryHighlightColor",
        20,
        -368,
        function() return state.GetSettings().categoryHighlightColor end,
        function(value)
            state.GetSettings().categoryHighlightColor = value
            state.Apply()
        end
    )

    controls.categoryBackgroundColor = CreateColorSetting(
        editor, "Background", "categoryBackgroundColor", 20, -330,
        function() return state.GetSettings().categoryBackgroundColor end,
        function(value)
            state.GetSettings().categoryBackgroundColor = value
            state.Apply()
        end
    )

    controls.emoteBackgroundColor = CreateColorSetting(
        editor, "Background", "emoteBackgroundColor", 330, -292,
        function() return state.GetSettings().emoteBackgroundColor end,
        function(value)
            state.GetSettings().emoteBackgroundColor = value
            state.Apply()
        end
    )

    controls.categoryFontSize:ClearAllPoints()
    controls.categoryFontSize:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -183)
    controls.emoteFontSize:ClearAllPoints()
    controls.emoteFontSize:SetPoint("TOPLEFT", editor, "TOPLEFT", 470, -183)

    controls.categoryTextColor:ClearAllPoints()
    controls.categoryTextColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -250)
    controls.selectedCategoryTextColor:ClearAllPoints()
    controls.selectedCategoryTextColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -288)
    controls.categoryBackgroundColor:ClearAllPoints()
    controls.categoryBackgroundColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -326)
    controls.categoryHighlightColor:ClearAllPoints()
    controls.categoryHighlightColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -364)
    controls.emoteTextColor:ClearAllPoints()
    controls.emoteTextColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 470, -250)
    controls.emoteBackgroundColor:ClearAllPoints()
    controls.emoteBackgroundColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 470, -288)

end

-- SelectionEffects section: controls follow their visual grouping.
local function CreateThemeSelectionEffects(editor, state, controls)
    local highlightEffectLabel = editor:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    highlightEffectLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -406)
    highlightEffectLabel:SetText("Selection effect")

    local highlightEffectSelector = CreateFrame(
        "DropdownButton",
        nil,
        editor,
        "WowStyle1DropdownTemplate"
    )
    highlightEffectSelector:SetWidth(135)
    highlightEffectSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -401)
    highlightEffectSelector:SetDefaultText("Background")
    highlightEffectSelector.settingKey = "categoryHighlightEffect"
    controls.categoryHighlightEffect = highlightEffectSelector

    controls.categoryHighlightThickness = CreateNumberSetting(
        editor, "Thickness", "categoryHighlightThickness", 330, -406, 1, 6,
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

-- Borders section: controls follow their visual grouping.
local function CreateThemeBorders(editor, state, controls)
    local windowHeading = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -460)
    windowHeading:SetText("Borders")

    controls.borderColor = CreateColorSetting(
        editor, "Border color", "borderColor", 20, -488,
        function() return state.GetSettings().borderColor end,
        function(value)
            state.GetSettings().borderColor = value
            state.Apply()
        end
    )

    controls.borderColor:ClearAllPoints()
    controls.borderColor:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -484)

    local borderLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -526)
    borderLabel:SetText("Border style")

    local borderSelector = CreateFrame(
        "DropdownButton",
        nil,
        editor,
        "WowStyle1DropdownTemplate"
    )
    borderSelector:SetWidth(170)
    borderSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -521)
    borderSelector:SetDefaultText("Thin")
    borderSelector.settingKey = "borderStyle"
    controls.borderStyle = borderSelector

    local borderLabels = {
        none = "None",
        thin = "Thin",
        blizzard = "Blizzard"
    }

    local function BuildBorderMenu(_, rootDescription)
        for _, style in ipairs({"none", "thin", "blizzard"}) do
            rootDescription:CreateRadio(
                borderLabels[style],
                function() return state.GetSettings().borderStyle == style end,
                function()
                    state.GetSettings().borderStyle = style
                    borderSelector:OverrideText(borderLabels[style])
                    state.Apply()
                end
            )
        end
    end

    borderSelector:SetupMenu(BuildBorderMenu)

    return borderSelector, borderLabels
end

-- Opacity section: controls follow their visual grouping.
local function CreateThemeOpacity(editor, state, controls)
    local opacityHeading = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -565)
    opacityHeading:SetText("Opacity")

    controls.windowOpacity = CreateNumberSetting(
        editor, "Menu opacity", "windowOpacity", 20, -593, 10, 100,
        function() return state.GetSettings().windowOpacity * 100 end,
        function(value)
            state.GetSettings().windowOpacity = value / 100
            state.Apply()
        end,
        "%"
    )

    controls.windowOpacity:ClearAllPoints()
    controls.windowOpacity:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -589)

    local opacityVisibleNote = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opacityVisibleNote:SetPoint("LEFT", controls.windowOpacity.SuffixLabel, "RIGHT", FIELD_GAP, 0)
    opacityVisibleNote:SetText("(when visible)")

end

-- LayoutAndIcon section: controls follow their visual grouping.
local function CreateThemeLayoutAndIcon(editor, state, controls)
    local layoutHeading = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -635)
    layoutHeading:SetText("Layout")

    local titleBarLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleBarLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -663)
    titleBarLabel:SetText("Title bar")

    local titleBarSelector = CreateFrame(
        "DropdownButton",
        nil,
        editor,
        "WowStyle1DropdownTemplate"
    )
    titleBarSelector:SetWidth(150)
    titleBarSelector:SetPoint("TOPLEFT", editor, "TOPLEFT", 160, -658)
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

    local iconHeading = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconHeading:SetPoint("TOPLEFT", editor, "TOPLEFT", 20, -705)
    iconHeading:SetText("Minimized Icon")

    local refreshIconColor = UI.CreateThemeIconColorControls(
        editor, 20, -735, true, state.GetName
    )

    return titleBarSelector, titleBarLabels, refreshIconColor
end

-- The appearance editor operates on the Theme selected above it.
local function CreateAppearanceSettingsPanel()
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
    panel:SetSize(700, 1110)
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
    editor:SetSize(700, 780)
    editor:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -335)

    local state = {
        GetSettings = function() return themeSettings end,
        GetName = function() return themeName end,
        Apply = ApplyIfActive
    }
    CreateThemeTypography(editor, state, controls)
    local RefreshHighlightControls =
        CreateThemeSelectionEffects(editor, state, controls)
    local borderSelector, borderLabels = CreateThemeBorders(editor, state, controls)
    CreateThemeOpacity(editor, state, controls)
    local titleBarSelector, titleBarLabels, refreshIconColor =
        CreateThemeLayoutAndIcon(editor, state, controls)

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
        borderSelector:OverrideText(borderLabels[themeSettings.borderStyle])
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
    container.appearanceControls = controls
    AddonSettings.RefreshFontControls = RefreshFontControls
    container:SetScript("OnShow", container.RefreshControls)
    container.RefreshControls()
    return container
end


UI.CreateAppearanceSettingsPanel = CreateAppearanceSettingsPanel
