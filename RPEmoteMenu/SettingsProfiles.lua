local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local Widgets = addon.SettingsWidgets
local GetExchangeDialog = UI.GetExchangeDialog
local CreateInfoLink = UI.CreateInfoLink

-- Profile management keeps character selection, Theme assignment, and lifecycle actions together.
local function CreateProfilesSettingsPanel()
    local panel = CreateFrame("Frame")
    local rows = UI.CreateRows(panel, 20, -85, 30)
    local profileLabelY = rows:Next(27)
    local profileSelectorY = rows:Next(37)
    local themeLabelY = rows:Next(22)
    local themeSelectorY = rows:Next(53)
    local restoreY = rows:Next(43)
    local descriptionY = rows:Next(32)
    local noteY = rows:Next(38)
    local actionsY = rows:Next(33)
    local exchangeY = rows:Next(50)
    local statusY = rows:Next()

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Profiles")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Profiles are shared account-wide; each character selects one. " ..
        "Default can be edited and restored, but not renamed or deleted."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local currentProfileLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentProfileLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, profileLabelY)
    currentProfileLabel:SetText("Selected profile")

    local selector

    local profileDescription = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    profileDescription:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, descriptionY)
    profileDescription:SetWidth(620)
    profileDescription:SetJustifyH("LEFT")
    profileDescription:SetTextColor(0.75, 0.75, 0.75)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, statusY)
    status:SetWidth(620)
    status:SetJustifyH("LEFT")

    local createButton
    local copyButton
    local renameButton
    local deleteButton
    local exportProfileButton
    local importProfileButton
    local themeSelector

    local themeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    themeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, themeLabelY)
    themeLabel:SetText("Theme assigned to this Profile")

    local function UpdateButtonState()
        local editable = Database.CanEditActiveProfile()
        local manageable = Database.CanRenameOrDeleteActiveProfile()
        renameButton:SetEnabled(manageable)
        deleteButton:SetEnabled(manageable)
        exportProfileButton:SetEnabled(editable)
        importProfileButton:SetEnabled(true)
    end

    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.35, 0.35, 1)
        else
            status:SetTextColor(0.35, 1, 0.45, 1)
        end
    end

    UI.RegisterProfileDialogs(SetStatus)

    selector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for _, name in ipairs(Database.GetProfileNames()) do
            options[#options + 1] = {label = Database.GetProfileDisplayName(name), value = name}
        end
        return options
    end, function(name)
        local success, errorMessage = Database.SetActiveProfile(name)
        if success then SetStatus("Using profile " .. name .. ".")
        else SetStatus(errorMessage, true); panel.Refresh() end
    end)
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, profileSelectorY)

    themeSelector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for _, name in ipairs(Database.GetThemeNames()) do
            options[#options + 1] = {label = name, value = name}
        end
        return options
    end, function(name)
        local success, errorMessage = Database.SetProfileTheme(Database.GetActiveProfileName(), name)
        if success then SetStatus("Assigned " .. name .. " to this Profile.")
        else SetStatus(errorMessage, true); panel.Refresh() end
    end)
    themeSelector:SetWidth(250)
    themeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, themeSelectorY)

    local restoreDefaultButton = Widgets.CreateButton(panel, "Restore Default", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_DEFAULT_PROFILE")
    end, 140, 24)
    restoreDefaultButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, restoreY)

    CreateInfoLink(panel, selector:GetFrame(), "RPEMOTEMENU_PROFILE_INFO")

    local profileNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, noteY)
    profileNote:SetWidth(620)
    profileNote:SetJustifyH("LEFT")
    profileNote:SetText(
        "Create starts with built-in emotes and the current Theme; Copy duplicates " ..
        "the selected Profile and its Theme reference."
    )
    profileNote:SetTextColor(0.8, 0.8, 0.8)

    local function OpenNameDialog(action)
        local name = Database.GetActiveProfileName()
        StaticPopup_Show("RPEMOTEMENU_NEW_PROFILE", nil, nil, {
            action = action,
            source = name,
            initial = action == "copy" and name .. " Copy" or ""
        })
    end

    createButton = Widgets.CreateButton(panel, "Create", function() OpenNameDialog("create") end, 95, 24)
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, actionsY)
    copyButton = Widgets.CreateButton(panel, "Copy", function() OpenNameDialog("copy") end, 95, 24)
    copyButton:SetPoint("LEFT", createButton, "RIGHT", 8, 0)

    renameButton = Widgets.CreateButton(panel, "Rename", function()
        local name = Database.GetActiveProfileName()
        if not Database.CanRenameOrDeleteActiveProfile() then return end
        StaticPopup_Show("RPEMOTEMENU_RENAME_PROFILE", name, nil, name)
    end, 95, 24)
    renameButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0)

    deleteButton = Widgets.CreateButton(panel, "Delete", function()
        local name = Database.GetActiveProfileName()
        if not Database.CanRenameOrDeleteActiveProfile() then return end
        StaticPopup_Show("RPEMOTEMENU_DELETE_PROFILE", name, nil, name)
    end, 95, 24)
    deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 8, 0)

    exportProfileButton = Widgets.CreateButton(panel, "Export Profile", function()
        GetExchangeDialog():OpenProfileExport()
    end, 125, 24)
    exportProfileButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, exchangeY)
    importProfileButton = Widgets.CreateButton(panel, "Import Profile", function()
        GetExchangeDialog():OpenProfileImport(UpdateButtonState)
    end, 125, 24)
    importProfileButton:SetPoint("LEFT", exportProfileButton, "RIGHT", 8, 0)

    panel.Refresh = function()
        local profileName = Database.GetActiveProfileName()
        -- CRUD/import refreshes invalidate choices; labels refresh without rebuilding.
        selector:InvalidateOptions()
        themeSelector:InvalidateOptions()
        selector:SetValue(profileName, Database.GetProfileDisplayName(profileName))
        local themeName = Database.GetActiveThemeName()
        themeSelector:SetValue(themeName, themeName)
        profileDescription:SetText(Database.GetProfileDescription(profileName))
        UpdateButtonState()
    end

    panel:SetScript("OnShow", panel.Refresh)

    panel.Refresh()
    return panel
end


UI.CreateProfilesSettingsPanel = CreateProfilesSettingsPanel
