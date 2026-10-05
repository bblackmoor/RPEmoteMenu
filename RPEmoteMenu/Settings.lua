local _, addon = ...

addon.Settings = {}
addon.SettingsUI = {FIELD_GAP = 12}

local AddonSettings = addon.Settings
local UI = addon.SettingsUI
local Database = addon.Database
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local settings
local SOURCE_URL = "https://github.com/bblackmoor/rpemotemenu"
local settingsCategory
local generalSettingsCategory
local profilesSettingsCategory
local categoriesSettingsCategory
local importExportSettingsCategory
local categoriesSettingsPanel

local function CreateAboutPanel()
    local panel = CreateFrame("Frame")

    StaticPopupDialogs["RPEMOTEMENU_COPY_SOURCE"] = {
        text = "Press Ctrl+C to copy the source URL.",
        button1 = CLOSE or "Close",
        hasEditBox = true,
        maxLetters = 255,
        editBoxWidth = 340,
        OnShow = function(self, url)
            local editBox = self.GetEditBox and self:GetEditBox() or self.editBox

            editBox:SetText(url or self.data or SOURCE_URL)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self)
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("RP Emote Menu — About")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "A customizable roleplaying emote menu with profiles, targeted " ..
        "commands, Profile sharing, and shared Themes for appearance. " ..
        "Each character selects a Profile; Profiles assign a Theme."
    )

    local details = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
    details:SetWidth(620)
    details:SetJustifyH("LEFT")
    details:SetText(
        "Version " .. addon.VERSION .. "\n" ..
        "Author    Brandon Blackmoor\n" ..
        "Category  Roleplay"
    )

    local sourceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceLabel:SetPoint("TOPLEFT", details, "BOTTOMLEFT", 0, -2)
    sourceLabel:SetText("Source    ")

    -- Settings.lua loads before the adapter; resolve it when constructing pages.
    local sourceLink = addon.SettingsWidgets.CreateLink(panel, SOURCE_URL, function()
        StaticPopup_Show("RPEMOTEMENU_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)
    sourceLink:SetPoint("LEFT", sourceLabel, "RIGHT", 0, 0)

    local information = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    information:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -2)
    information:SetWidth(620)
    information:SetJustifyH("LEFT")
    information:SetText(
        "License   GPL-3.0\n\n" ..

        "Slash commands\n" ..
        "    /rpem - Show or hide the RP Emote Menu.\n" ..
        "    /rpem about - Open the About page.\n" ..
        "    /rpem config - Open the addon settings.\n" ..
        "    /rpem options - Open the addon settings.\n" ..
        "    /rpem settings - Open the addon settings.\n\n" ..

        "Character-name tokens\n" ..
        "    {target}  Target's name without the realm.\n" ..
        "    {player}  Current character's name without the realm."
    )
    return panel
end

function AddonSettings.CreateSettingsPanel()
    settings = Database.GetSettings()
    local aboutPanel = CreateAboutPanel()
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
