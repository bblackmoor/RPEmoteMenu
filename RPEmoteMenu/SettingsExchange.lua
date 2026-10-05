local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local Serialization = addon.Serialization
local MAX_EMOTES = addon.MAX_EMOTES
local exchangeDialog

local function EmoteHasContent(emote)
    return emote and (
        strtrim(emote.label or "") ~= ""
        or strtrim(emote.defaultCommand or "") ~= ""
        or strtrim(emote.targetedCommand or "") ~= ""
    )
end

local function CategoryHasContent(category)
    if not category then
        return false
    end
    if strtrim(category.name or "") ~= "" then
        return true
    end

    for emoteIndex = 1, MAX_EMOTES do
        if EmoteHasContent(category.emotes and category.emotes[emoteIndex]) then
            return true
        end
    end

    return false
end

-- Frame construction, import actions, and mode-specific copy are kept separate.
local function CreateExchangeDialogFrame()
    local dialog = CreateFrame(
        "Frame",
        "RPEmoteMenuExchangeDialog",
        UIParent,
        "BackdropTemplate"
    )
    dialog:SetSize(620, 470)
    dialog:SetPoint("CENTER", UIParent, "CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dialog:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RPEmoteMenuExchangeDialog")
    end

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    dialog.title = title

    local closeIcon = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeIcon:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)
    closeIcon:SetScript("OnClick", function()
        dialog:Hide()
    end)

    local instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

    local scrollFrame = CreateFrame("ScrollFrame", nil, textBackground, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", textBackground, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", textBackground, "BOTTOMRIGHT", -5, 5)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetWidth(540)
    editBox:SetHeight(300)
    editBox:SetTextInsets(4, 4, 4, 4)
    scrollFrame:SetScrollChild(editBox)
    dialog.editBox = editBox

    local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 49)
    status:SetWidth(570)
    status:SetJustifyH("LEFT")
    dialog.status = status

    local actionButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    actionButton:SetSize(120, 24)
    actionButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -144, 14)
    dialog.actionButton = actionButton

    local closeButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    closeButton:SetSize(110, 24)
    closeButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 14)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog.scrollFrame = scrollFrame
    return dialog
end

local function InstallExchangeActions(dialog)
    local editBox = dialog.editBox
    local scrollFrame = dialog.scrollFrame
    local status = dialog.status
    local actionButton = dialog.actionButton
    local function SetStatus(message, isError)
        status:SetText(message or "")

        if isError then
            status:SetTextColor(1, 0.35, 0.35, 1)
        else
            status:SetTextColor(0.35, 1, 0.45, 1)
        end
    end

    function dialog:UpdateActionState()
        if self.mode == "import" then
            local hasText = strtrim(editBox:GetText() or "") ~= ""
            local validTarget = self.dataType ~= "category"
                or Database.IsCurrentContentTarget(self.categoryTarget)
            actionButton:SetEnabled(hasText and validTarget)
            if not validTarget then
                SetStatus("The Profile or category changed. Reopen Import before replacing content.", true)
            end
        else
            actionButton:SetEnabled(true)
        end
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText() or ""
        local charactersPerLine = math.max(1, math.floor((self:GetWidth() - 8) / 7))
        local lineCount = 0

        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            lineCount = lineCount + math.max(1, math.ceil(#line / charactersPerLine))
        end

        self:SetHeight(math.max(scrollFrame:GetHeight() or 0, (lineCount * 16) + 12))

        if userInput then
            SetStatus("")
        end

        dialog:UpdateActionState()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dialog:Hide()
    end)

    local function PerformImport(importText, dataType, categoryIndex, target)
        dataType = dataType or dialog.dataType
        local success
        local result
        local sourceProfileName
        local detail

        if dataType == "profile" then
            success, result, sourceProfileName, detail =
                Serialization.ImportProfileAsNew(importText)
        elseif dataType == "theme" then
            success, result, sourceProfileName =
                Serialization.ImportThemeAsNew(importText)
        elseif dataType == "category" then
            if dialog.mode ~= "import" or dialog.dataType ~= "category"
                or target ~= dialog.categoryTarget
                or not Database.IsCurrentContentTarget(target) then
                SetStatus("The Profile or category changed. Reopen Import before replacing content.", true)
                dialog:UpdateActionState()
                return
            end
            success, result = Serialization.ImportCategory(
                categoryIndex or dialog.categoryIndex,
                importText
            )
        else
            success, result, sourceProfileName, detail =
                Serialization.ImportEverything(importText)
        end

        if not success then
            SetStatus(result, true)
            dialog:UpdateActionState()
            return
        end

        if dataType == "category" then
            -- A successful import replaces the category; bind the next action to it.
            dialog.categoryTarget = Database.CaptureContentTarget(categoryIndex or dialog.categoryIndex)
        end
        editBox:SetText("")
        dialog:UpdateActionState()

        if dataType == "profile" then
            if dialog.onProfileImported then
                dialog.onProfileImported()
            end

            local message = "Imported profile " .. sourceProfileName
                .. " as " .. result .. "."
            if detail then
                message = message .. " Theme " .. detail
                    .. " was unavailable; assigned Default Theme."
            end
            SetStatus(message)
        elseif dataType == "theme" then
            if dialog.onThemeImported then
                dialog.onThemeImported(result)
            end
            SetStatus("Imported Theme " .. sourceProfileName .. " as " .. result .. ".")
        elseif dataType == "category" then
            SetStatus("Imported category " .. result .. ".")
        else
            SetStatus("Added " .. result .. " Profiles and "
                .. detail .. " Themes.")
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_IMPORT_OVER_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the imported category?\n\nThis cannot be undone.",
        button1 = "Replace",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            PerformImport(data.importText, "category", data.categoryIndex, data.target)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    actionButton:SetScript("OnClick", function()
        if dialog.mode == "export" then
            editBox:SetFocus()
            editBox:HighlightText()
            SetStatus("Press Ctrl+C to copy the selected text.")
            return
        end

        local importText = editBox:GetText()
        if dialog.dataType == "category"
            and not Database.IsCurrentContentTarget(dialog.categoryTarget) then
            dialog:UpdateActionState()
            return
        end
        if dialog.dataType == "category"
            and CategoryHasContent(Database.GetCategory(dialog.categoryIndex)) then
            StaticPopup_Show(
                "RPEMOTEMENU_IMPORT_OVER_CATEGORY",
                "Category " .. dialog.categoryIndex,
                nil,
                {
                    importText = importText,
                    categoryIndex = dialog.categoryIndex,
                    target = dialog.categoryTarget
                }
            )
            return
        end

        PerformImport(importText, dialog.dataType, nil, dialog.categoryTarget)
    end)

    dialog:SetScript("OnHide", function()
        dialog.categoryTarget = nil
        editBox:ClearFocus()
    end)

    dialog.SetStatus = SetStatus
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
        exchangeDialog = CreateExchangeDialogFrame()
        InstallExchangeActions(exchangeDialog)
        InstallExchangeModes(exchangeDialog)
    end
    return exchangeDialog
end

UI.GetExchangeDialog = GetExchangeDialog
UI.RefreshExchangeDialog = function()
    if exchangeDialog and exchangeDialog:IsShown() then
        exchangeDialog:UpdateActionState()
    end
end

