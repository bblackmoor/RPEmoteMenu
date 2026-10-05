local _, addon = ...

addon.Settings = {}
addon.SettingsUI = {FIELD_GAP = 12}

local AddonSettings = addon.Settings
local UI = addon.SettingsUI
local Database = addon.Database
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local settings
local settingsCategory
local generalSettingsCategory
local profilesSettingsCategory
local categoriesSettingsCategory
local importExportSettingsCategory
local categoriesSettingsPanel

function AddonSettings.CreateSettingsPanel()
    settings = Database.GetSettings()
    local aboutPanel = UI.CreateAboutPanel()
    local generalPanel = UI.CreateGeneralSettingsPanel()
    local themesPanel = UI.CreateThemesSettingsPanel()
    local profilesPanel = UI.CreateProfilesSettingsPanel()
    categoriesSettingsPanel = UI.CreateCategoriesSettingsPanel()
    local importExportPanel = UI.CreateImportExportSettingsPanel()

    settingsCategory = Settings.RegisterCanvasLayoutCategory(aboutPanel, "RP Emote Menu")
    Settings.RegisterAddOnCategory(settingsCategory)

    generalSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        generalPanel,
        "Behavior"
    )

    profilesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        profilesPanel,
        "Profiles"
    )

    Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        themesPanel,
        "Themes"
    )

    AddonSettings.RefreshProfiles = profilesPanel.Refresh

    categoriesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        categoriesSettingsPanel,
        "Emotes"
    )

    importExportSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        importExportPanel,
        "Import & Export"
    )

    AddonSettings.RefreshSettingsPanels = function()
        settings = Database.GetSettings()
        generalPanel.RefreshControls()
        themesPanel.RefreshControls()
        profilesPanel.Refresh()
        categoriesSettingsPanel.SelectCategory(settings.selectedCategory)
    end

    AddonSettings.RefreshEditors = function(categoryIndex)
        UI.RefreshExchangeDialog()

        categoriesSettingsPanel.RefreshEditors(categoryIndex)
    end
end

AddonSettings.OpenAbout = function()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

AddonSettings.Open = function()
    if generalSettingsCategory then
        Settings.OpenToCategory(generalSettingsCategory:GetID())
    elseif settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

AddonSettings.OpenEmotes = function(categoryIndex)
    if categoriesSettingsPanel
        and type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= MAX_CATEGORIES then
        categoriesSettingsPanel.SelectCategory(categoryIndex)
    end

    if categoriesSettingsCategory then
        Settings.OpenToCategory(categoriesSettingsCategory:GetID())
    else
        AddonSettings.Open()
    end
end

