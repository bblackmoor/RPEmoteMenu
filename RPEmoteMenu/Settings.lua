local _, addon = ...
local L = addon.L

addon.Settings = {}
addon.SettingsUI = {FIELD_GAP = 12}

local AddonSettings = addon.Settings
local UI = addon.SettingsUI
local Database = addon.Database
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local rootCategory
local categories, panels = {}, {}
local pageOrder = {
    {key = "About", label = L.TAB_ABOUT},
    {key = "Behavior", label = L.TAB_BEHAVIOR},
    {key = "Profiles", label = L.TAB_PROFILES},
    {key = "Themes", label = L.TAB_THEMES},
    {key = "Emotes", label = L.TAB_EMOTES},
    {key = "ImportExport", label = L.TAB_IMPORT_EXPORT},
}

function AddonSettings.RegisterSettingsPanels()
    if rootCategory or not addon.SettingsPanels or not Settings or not Settings.RegisterCanvasLayoutCategory
        or not Settings.RegisterCanvasLayoutSubcategory or not Settings.RegisterAddOnCategory then return end
    -- Validate all factories before constructing or registering any page.
    for _, page in ipairs(pageOrder) do
        if type(addon.SettingsPanels[page.key]) ~= "function" then return end
    end
    for _, page in ipairs(pageOrder) do
        panels[page.key] = addon.SettingsPanels[page.key]()
    end
    rootCategory = Settings.RegisterCanvasLayoutCategory(panels.About, L.ADDON_NAME)
    categories.About = rootCategory
    Settings.RegisterAddOnCategory(rootCategory)
    for index = 2, #pageOrder do
        local page = pageOrder[index]
        categories[page.key] = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panels[page.key], page.label)
    end

    AddonSettings.RefreshProfiles = panels.Profiles.Refresh
    AddonSettings.RefreshSettingsPanels = function()
        local settings = Database.GetSettings()
        panels.Behavior.Refresh()
        panels.Themes.Refresh()
        panels.Profiles.Refresh()
        panels.Emotes.SelectCategory(settings.selectedCategory)
    end
    AddonSettings.RefreshEditors = function(categoryIndex)
        UI.RefreshExchangeDialog()
        panels.Emotes.RefreshEditors(categoryIndex)
    end
end

AddonSettings.OpenAbout = function()
    if rootCategory then
        Settings.OpenToCategory(rootCategory:GetID())
    end
end

AddonSettings.Open = function()
    if categories.Behavior then
        Settings.OpenToCategory(categories.Behavior:GetID())
    elseif rootCategory then
        Settings.OpenToCategory(rootCategory:GetID())
    end
end

AddonSettings.OpenEmotes = function(categoryIndex)
    if panels.Emotes
        and type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= MAX_CATEGORIES then
        panels.Emotes.SelectCategory(categoryIndex)
    end

    if categories.Emotes then
        Settings.OpenToCategory(categories.Emotes:GetID())
    else
        AddonSettings.Open()
    end
end


