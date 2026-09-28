local _, addon = ...
local UI = addon.SettingsUI
local GetExchangeDialog = UI.GetExchangeDialog

local function CreateImportExportSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Import & Export")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Save or transfer all Profiles and Themes together."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local profilesDescription = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    profilesDescription:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    profilesDescription:SetWidth(620)
    profilesDescription:SetJustifyH("LEFT")
    profilesDescription:SetText(
        "Everything includes all Profiles, Themes, their settings, categories, "
        .. "emotes, and Theme references. Global preferences and character "
        .. "assignments are not exported."
    )
    profilesDescription:SetTextColor(0.8, 0.8, 0.8)

    local exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportButton:SetSize(160, 24)
    exportButton:SetPoint("TOPLEFT", profilesDescription, "BOTTOMLEFT", 0, -18)
    exportButton:SetText("Export Everything")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenEverythingExport()
    end)

    local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importButton:SetSize(160, 24)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)
    importButton:SetText("Import Everything")
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenEverythingImport()
    end)

    local importNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importNote:SetPoint("TOPLEFT", exportButton, "BOTTOMLEFT", 0, -18)
    importNote:SetWidth(620)
    importNote:SetJustifyH("LEFT")
    importNote:SetText(
        "Importing adds new Profiles and Themes and preserves their links. "
        .. "It does not replace or activate existing data or change character "
        .. "assignments. Conflicting names are renamed automatically. Review "
        .. "custom emote text before sharing."
    )
    importNote:SetTextColor(0.7, 0.7, 0.7)

    return panel
end


UI.CreateImportExportSettingsPanel = CreateImportExportSettingsPanel
