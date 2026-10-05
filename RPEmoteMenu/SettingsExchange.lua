local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local Serialization = addon.Serialization
local exchangeDialog

-- Frame construction, import actions, and mode-specific copy are kept separate.
local function CreateExchangeDialogFrame()
    local Widgets = addon.SettingsWidgets
    local dialog = Widgets.CreateDialog("RPEmoteMenuExchangeDialog", 620, 470)

    local title = Widgets.CreateDialogLabel(dialog, "", 16)
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    dialog.title = title

    local instructions = Widgets.CreateDialogLabel(dialog, "", 12)
    instructions:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    instructions:SetWidth(570)
    instructions:SetJustifyH("LEFT")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    dialog.instructions = instructions

    local textBackground = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    textBackground:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -80)
    textBackground:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -42, 80)
    textBackground:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    textBackground:SetBackdropColor(0.04, 0.04, 0.04, 1)
    textBackground:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local scrollFrame, scrollContent = Widgets.CreateCanvasScrollBox(textBackground)
    scrollFrame:SetPoint("TOPLEFT", textBackground, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", textBackground, "BOTTOMRIGHT", -5, 5)

    local editBox = Widgets.CreateDialogTextEntry(scrollContent, 540, 300)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetWidth(540)
    editBox:SetHeight(300)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, 0)
    scrollContent:SetSize(540, 300)
    dialog.editBox = editBox
    -- A hidden FontString measures actual wrapping, including final blank rows.
    dialog.textMeasurement = dialog:CreateFontString(nil, "OVERLAY")

    local status = Widgets.CreateDialogLabel(dialog, "", 12)
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 49)
    status:SetWidth(570)
    status:SetJustifyH("LEFT")
    dialog.status = status

    local actionButton = Widgets.CreateDialogButton(dialog, "", 120, 24)
    actionButton:SetSize(120, 24)
    actionButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -144, 14)
    dialog.actionButton = actionButton

    local closeButton = Widgets.CreateDialogButton(dialog, "", 120, 24)
    closeButton:SetSize(110, 24)
    closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 14)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog.scrollContent = scrollContent
    dialog.scrollFrame = scrollFrame
    return dialog
end

local function InstallExchangeModes(dialog)
    local title = dialog.title
    local instructions = dialog.instructions
    local editBox = dialog.editBox
    local scrollFrame = dialog.scrollFrame
    local actionButton = dialog.actionButton
    local SetStatus = dialog.SetStatus
    function dialog:OpenExport(categoryIndex)
        local exported, errorMessage = Serialization.ExportCategory(categoryIndex)
        if not exported then
            return false, errorMessage
        end

        self.categoryTarget = nil
        self.mode = "export"
        self.dataType = "category"
        self.categoryIndex = categoryIndex
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Export Category " .. categoryIndex)
        instructions:SetText("Copy this JSON to share or save the category and its emotes.")
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenImport(categoryIndex)
        self.categoryTarget = Database.CaptureContentTarget(categoryIndex)
        self.mode = "import"
        self.dataType = "category"
        self.categoryIndex = categoryIndex
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Import Category " .. categoryIndex)
        instructions:SetText("Paste exported category JSON below. Importing replaces this category.")
        actionButton:SetText("Import")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    function dialog:OpenProfileExport(profileName)
        profileName = profileName or Database.GetActiveProfileName()
        local exported, errorMessage = Serialization.ExportProfile(profileName)
        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "profile"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Export Profile: " .. profileName)
        instructions:SetText(
            "Copy this JSON to save the Profile's settings, categories, "
            .. "emotes, and Theme name. Export the Theme separately to share its appearance."
        )
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenProfileImport(onProfileImported)
        self.mode = "import"
        self.dataType = "profile"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = onProfileImported
        title:SetText("Import Profile")
        instructions:SetText(
            "Paste exported profile JSON below. Importing adds a new profile without "
            .. "changing the current profile or character assignments. A missing "
            .. "Theme is reported and replaced with Default Theme."
        )
        actionButton:SetText("Import Profile")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    function dialog:OpenThemeExport(themeName)
        local exported, errorMessage = Serialization.ExportTheme(themeName)
        if not exported then return false, errorMessage end

        self.mode = "export"
        self.dataType = "theme"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.onProfileImported = nil
        self.onThemeImported = nil
        title:SetText("Export Theme: " .. themeName)
        instructions:SetText("Copy this JSON to save this Theme's appearance. Export its Profiles separately.")
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenThemeImport(onThemeImported)
        self.mode = "import"
        self.dataType = "theme"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.onProfileImported = nil
        self.onThemeImported = onThemeImported
        title:SetText("Import Theme")
        instructions:SetText("Paste exported Theme JSON below. Importing adds a new Theme and assigns it to the active Profile.")
        actionButton:SetText("Import Theme")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    function dialog:OpenEverythingExport()
        local exported, errorMessage = Serialization.ExportEverything()

        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "everything"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Export Everything")
        instructions:SetText(
            "Copy this JSON to save all Profiles, Themes, and their relationships. "
            .. "Character assignments are not included."
        )
        actionButton:SetText("Select All")
        SetStatus("")
        editBox:SetText(exported)
        editBox:SetCursorPosition(0)
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        editBox:HighlightText()
        return true
    end

    function dialog:OpenEverythingImport()
        self.mode = "import"
        self.dataType = "everything"
        self.categoryTarget = nil
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Import Everything")
        instructions:SetText(
            "Paste an Everything export below. Importing adds Profiles and Themes "
            .. "with unique names, preserving their links. It does not replace or "
            .. "activate existing data or change character assignments."
        )
        actionButton:SetText("Import Everything")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

end

local function GetExchangeDialog()
    if not exchangeDialog then
        local dialog = CreateExchangeDialogFrame()
        addon.ExchangeActions.Install(dialog)
        local layout = addon.ExchangeTextLayout.Create({
            editBox = dialog.editBox, scrollFrame = dialog.scrollFrame,
            scrollContent = dialog.scrollContent, measurement = dialog.textMeasurement,
        })
        addon.ExchangeLifecycle.Install(dialog, layout)
        InstallExchangeModes(dialog)
        exchangeDialog = dialog
    end
    return exchangeDialog
end

UI.GetExchangeDialog = GetExchangeDialog
UI.RefreshExchangeDialog = function()
    if exchangeDialog and exchangeDialog:IsShown() then
        exchangeDialog:UpdateActionState()
    end
end

