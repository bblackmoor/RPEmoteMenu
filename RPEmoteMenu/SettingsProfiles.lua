local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
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

    local selector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, profileSelectorY)
    selector:SetDefaultText(
        Database.GetProfileDisplayName(Database.GetActiveProfileName())
    )

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
    local themeSelector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    themeSelector:SetWidth(250)
    themeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, themeSelectorY)
    themeSelector:SetDefaultText(Database.GetActiveThemeName())

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

    local function BuildProfileMenu(_, rootDescription)
        for _, profileName in ipairs(Database.GetProfileNames()) do
            rootDescription:CreateRadio(
                Database.GetProfileDisplayName(profileName),
                function()
                    return Database.GetActiveProfileName() == profileName
                end,
                function()
                    local success, errorMessage = Database.SetActiveProfile(profileName)

                    if success then
                        SetStatus("Using profile " .. profileName .. ".")
                    else
                        SetStatus(errorMessage, true)
                    end
                end
            )
        end
    end

    selector:SetupMenu(BuildProfileMenu)

    themeSelector:SetupMenu(function(_, root)
        for _, themeName in ipairs(Database.GetThemeNames()) do
            root:CreateRadio(themeName,
                function() return Database.GetActiveThemeName() == themeName end,
                function()
                    local success, errorMessage = Database.SetProfileTheme(
                        Database.GetActiveProfileName(), themeName)
                    if success then
                        SetStatus("Assigned " .. themeName .. " to this Profile.")
                    else
                        SetStatus(errorMessage, true)
                    end
                end)
        end
    end)

    local restoreDefaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restoreDefaultButton:SetSize(140, 24)
    restoreDefaultButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, restoreY)
    restoreDefaultButton:SetText("Restore Default")
    restoreDefaultButton:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_DEFAULT_PROFILE")
    end)

    CreateInfoLink(panel, selector, "RPEMOTEMENU_PROFILE_INFO")

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

    createButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    createButton:SetSize(95, 24)
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, actionsY)
    createButton:SetText("Create")
    createButton:SetScript("OnClick", function() OpenNameDialog("create") end)

    copyButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyButton:SetSize(95, 24)
    copyButton:SetPoint("LEFT", createButton, "RIGHT", 8, 0)
    copyButton:SetText("Copy")
    copyButton:SetScript("OnClick", function() OpenNameDialog("copy") end)

    renameButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    renameButton:SetSize(95, 24)
    renameButton:SetPoint("LEFT", copyButton, "RIGHT", 8, 0)
    renameButton:SetText("Rename")
    renameButton:SetScript("OnClick", function()
        local profileName = Database.GetActiveProfileName()

        if not Database.CanRenameOrDeleteActiveProfile() then
            return
        end

        StaticPopup_Show("RPEMOTEMENU_RENAME_PROFILE", profileName, nil, profileName)
    end)

    deleteButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    deleteButton:SetSize(95, 24)
    deleteButton:SetPoint("LEFT", renameButton, "RIGHT", 8, 0)
    deleteButton:SetText("Delete")
    deleteButton:SetScript("OnClick", function()
        local profileName = Database.GetActiveProfileName()

        if not Database.CanRenameOrDeleteActiveProfile() then
            return
        end

        StaticPopup_Show("RPEMOTEMENU_DELETE_PROFILE", profileName, nil, profileName)
    end)

    exportProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportProfileButton:SetSize(125, 24)
    exportProfileButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, exchangeY)
    exportProfileButton:SetText("Export Profile")
    exportProfileButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenProfileExport()
    end)

    importProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importProfileButton:SetSize(125, 24)
    importProfileButton:SetPoint("LEFT", exportProfileButton, "RIGHT", 8, 0)
    importProfileButton:SetText("Import Profile")
    importProfileButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenProfileImport(UpdateButtonState)
    end)

    panel.Refresh = function()
        local profileName = Database.GetActiveProfileName()
        selector:OverrideText(Database.GetProfileDisplayName(profileName))
        themeSelector:OverrideText(Database.GetActiveThemeName())
        profileDescription:SetText(Database.GetProfileDescription(profileName))
        UpdateButtonState()
    end

    panel:SetScript("OnShow", panel.Refresh)

    panel.Refresh()
    return panel
end


UI.CreateProfilesSettingsPanel = CreateProfilesSettingsPanel
