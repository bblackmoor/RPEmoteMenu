local _, addon = ...
local L = addon.L
local UI = addon.SettingsUI
local Widgets = addon.SettingsWidgets
local GetExchangeDialog = UI.GetExchangeDialog

local function CreateImportExportPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -18)
    heading:SetText(L.UI_IMPORT_EXPORT)

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        L.UI_SAVE_OR_TRANSFER_ALL_PROFILES_AND_THEMES_TOGETHER
    )
    description:SetTextColor(0.72, 0.72, 0.72)

    local profilesDescription = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    profilesDescription:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    profilesDescription:SetWidth(620)
    profilesDescription:SetJustifyH("LEFT")
    profilesDescription:SetText(
        L.UI_EVERYTHING_INCLUDES_ALL_PROFILES_THEMES_THEIR_SETTINGS_CATEGORIES_EMOTES_AND
    )
    profilesDescription:SetTextColor(0.8, 0.8, 0.8)

    local exportButton = Widgets.CreateButton(panel, L.UI_EXPORT_EVERYTHING, function()
        GetExchangeDialog():OpenEverythingExport()
    end, 160, 24)
    exportButton:SetPoint("TOPLEFT", profilesDescription, "BOTTOMLEFT", 0, -18)
    local importButton = Widgets.CreateButton(panel, L.UI_IMPORT_EVERYTHING, function()
        GetExchangeDialog():OpenEverythingImport()
    end, 160, 24)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)

    local importNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importNote:SetPoint("TOPLEFT", exportButton:GetFrame(), "BOTTOMLEFT", 0, -18)
    importNote:SetWidth(620)
    importNote:SetJustifyH("LEFT")
    importNote:SetText(
        L.UI_IMPORTING_ADDS_NEW_PROFILES_AND_THEMES_AND_PRESERVES_THEIR_LINKS
    )
    importNote:SetTextColor(0.7, 0.7, 0.7)

    return panel
end


addon.SettingsPanels.ImportExport = CreateImportExportPanel


