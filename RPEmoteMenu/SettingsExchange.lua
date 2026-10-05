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
    -- Assign the entire session before SetText can dispatch native events.
    -- Every route clears unrelated targets/callbacks through this one boundary.
    local function OpenSession(options)
        dialog.mode = options.mode
        dialog.dataType = options.dataType
        dialog.categoryIndex = options.categoryIndex
        dialog.categoryTarget = options.categoryTarget
        dialog.profileName = nil
        dialog.onProfileImported = options.onProfileImported
        dialog.onThemeImported = options.onThemeImported
        dialog.title:SetText(options.title)
        dialog.instructions:SetText(options.instructions)
        dialog.actionButton:SetText(options.actionText or "Select All")
        dialog.SetStatus("")
        dialog.editBox:SetText(options.text or "")
        if options.mode == "export" then dialog.editBox:SetCursorPosition(0) end
        dialog.scrollFrame:SetVerticalScroll(0)
        dialog:UpdateActionState()
        dialog:Show()
        dialog.editBox:SetFocus()
        if options.mode == "export" then dialog.editBox:HighlightText() end
        return true
    end

    function dialog:OpenExport(categoryIndex)
        local exported, errorMessage = Serialization.ExportCategory(categoryIndex)
        if not exported then
            return false, errorMessage
        end
        return OpenSession({
            mode = "export", dataType = "category",
            categoryIndex = categoryIndex,
            text = exported,
            title = "Export Category " .. categoryIndex,
            instructions = "Copy this JSON to share or save the category and its emotes.",
        })
    end

    function dialog:OpenImport(categoryIndex)
        return OpenSession({
            mode = "import", dataType = "category",
            categoryIndex = categoryIndex,
            categoryTarget = Database.CaptureContentTarget(categoryIndex),
            title = "Import Category " .. categoryIndex,
            instructions = "Paste exported category JSON below. Importing replaces this category.",
            actionText = "Import",
        })
    end

    function dialog:OpenProfileExport(profileName)
        profileName = profileName or Database.GetActiveProfileName()
        local exported, errorMessage = Serialization.ExportProfile(profileName)
        if not exported then
            return false, errorMessage
        end
        return OpenSession({
            mode = "export", dataType = "profile",
            text = exported,
            title = "Export Profile: " .. profileName,
            instructions = "Copy this JSON to save the Profile's settings, categories, "
                .. "emotes, and Theme name. Export the Theme separately to share its appearance.",
        })
    end

    function dialog:OpenProfileImport(onProfileImported)
        return OpenSession({
            mode = "import", dataType = "profile",
            onProfileImported = onProfileImported,
            title = "Import Profile",
            instructions = "Paste exported profile JSON below. Importing adds a new profile without "
                .. "changing the current profile or character assignments. A missing "
                .. "Theme is reported and replaced with Default Theme.",
            actionText = "Import Profile",
        })
    end

    function dialog:OpenThemeExport(themeName)
        local exported, errorMessage = Serialization.ExportTheme(themeName)
        if not exported then return false, errorMessage end
        return OpenSession({
            mode = "export", dataType = "theme",
            text = exported,
            title = "Export Theme: " .. themeName,
            instructions = "Copy this JSON to save this Theme's appearance. Export its Profiles separately.",
        })
    end

    function dialog:OpenThemeImport(onThemeImported)
        return OpenSession({
            mode = "import", dataType = "theme",
            onThemeImported = onThemeImported,
            title = "Import Theme",
            instructions = "Paste exported Theme JSON below. Importing adds a new Theme and assigns it to the active Profile.",
            actionText = "Import Theme",
        })
    end

    function dialog:OpenEverythingExport()
        local exported, errorMessage = Serialization.ExportEverything()

        if not exported then
            return false, errorMessage
        end
        return OpenSession({
            mode = "export", dataType = "everything",
            text = exported,
            title = "Export Everything",
            instructions = "Copy this JSON to save all Profiles, Themes, and their relationships. "
                .. "Character assignments are not included.",
        })
    end

    function dialog:OpenEverythingImport()
        return OpenSession({
            mode = "import", dataType = "everything",
            title = "Import Everything",
            instructions = "Paste an Everything export below. Importing adds Profiles and Themes "
                .. "with unique names, preserving their links. It does not replace or "
                .. "activate existing data or change character assignments.",
            actionText = "Import Everything",
        })
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

