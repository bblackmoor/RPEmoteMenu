local _, addon = ...

addon.Settings = {}

local AddonSettings = addon.Settings
local MainWindow = addon.MainWindow
local Database = addon.Database
local Serialization = addon.Serialization
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SOURCE_URL = "https://github.com/bblackmoor/rpemotemenu"
local settingsCategory
local generalSettingsCategory
local appearanceSettingsCategory
local profilesSettingsCategory
local categoriesSettingsCategory
local importExportSettingsCategory
local categoriesSettingsPanel
local resetAllCategoriesButton
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

-- SETTINGS PANEL
local FIELD_GAP = 12

local function CreateSwitch(parent, label, y, getValue, setValue)
    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    caption:SetText(label)

    local switch = CreateFrame("Button", nil, parent)
    switch:SetSize(44, 20)
    switch:SetPoint("LEFT", caption, "RIGHT", FIELD_GAP, 0)
    local track = switch:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    local thumb = switch:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(18, 16)
    thumb:SetColorTexture(0.72, 0.72, 0.73, 1)

    function switch:SetChecked(value)
        self.checked = value == true
        thumb:ClearAllPoints()
        if self.checked then
            track:SetColorTexture(0.19, 0.42, 0.31, 1)
            thumb:SetPoint("RIGHT", self, "RIGHT", -2, 0)
        else
            track:SetColorTexture(0.25, 0.25, 0.26, 1)
            thumb:SetPoint("LEFT", self, "LEFT", 2, 0)
        end
    end

    function switch:GetChecked()
        return self.checked
    end

    switch:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        setValue(self:GetChecked())
    end)
    switch.RefreshValue = function(self)
        self:SetChecked(getValue())
    end
    switch:RefreshValue()
    return switch
end

local function CreateInfoLink(parent, anchor, dialogName)
    local link = CreateFrame("Button", nil, parent)
    link:SetPoint("LEFT", anchor, "RIGHT", FIELD_GAP, 0)
    local circle = link:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    circle:SetPoint("CENTER")
    circle:SetText("O")
    local letter = link:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letter:SetPoint("CENTER")
    letter:SetText("i")
    link:SetSize(
        math.ceil(math.max(circle:GetStringWidth(), letter:GetStringWidth()) + 6),
        math.ceil(math.max(circle:GetStringHeight(), letter:GetStringHeight()) + 4)
    )
    link:SetScript("OnClick", function()
        StaticPopup_Show(dialogName)
    end)
    return link
end

local function CreateLabeledEditBox(
    parent,
    labelText,
    x,
    y,
    width,
    categoryIndex,
    emoteIndex,
    fieldName
)
    local labelWidth = 180
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 5)
    label:SetWidth(labelWidth)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 24)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x + labelWidth + FIELD_GAP, y)
    editBox:SetAutoFocus(false)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)

    editBox.categoryIndex = categoryIndex
    editBox.emoteIndex = emoteIndex
    editBox.fieldName = fieldName

    local function GetCurrentValue(self)
        local category = Database.GetCategory(self.categoryIndex)

        if self.emoteIndex then
            return category.emotes[self.emoteIndex][self.fieldName] or ""
        end

        return category[self.fieldName] or ""
    end

    local function SetCurrentValue(self, value)
        if not Database.CanEditActiveProfile() then
            return false
        end

        local category = Database.GetCategory(self.categoryIndex)

        if self.emoteIndex then
            category.emotes[self.emoteIndex][self.fieldName] = value
        else
            category[self.fieldName] = value
        end

        return true
    end

    local function DisplayCurrentValue(self)
        local value = GetCurrentValue(self)
        if self:GetText() ~= value then
            self:SetText(value)
        end
    end

    editBox.RefreshFromDatabase = function(self)
        self.isDirty = false
        DisplayCurrentValue(self)
        self:SetCursorPosition(0)
        self:HighlightText(0, 0)

        if Database.CanEditActiveProfile() then
            self:Enable()
            self:SetTextColor(1, 1, 1, 1)
        else
            self:ClearFocus()
            self:Disable()
            self:SetTextColor(0.65, 0.65, 0.65, 1)
        end
    end

    -- Blizzard's Settings panel can clear edit-box text during layout.
    -- Reapply the saved value after the box is shown. Later profile changes and
    -- reset actions refresh their editors explicitly, avoiding per-frame polling.
    editBox:SetScript("OnShow", function(self)
        DisplayCurrentValue(self)
        self:SetCursorPosition(0)

        C_Timer.After(0, function()
            if self and self:IsShown() then
                DisplayCurrentValue(self)
                self:SetCursorPosition(0)
            end
        end)
    end)

    local function Commit(self)
        if not self.isDirty then
            return
        end

        if SetCurrentValue(self, self:GetText() or "") then
            self.isDirty = false
            MainWindow.UpdateMenu()

            if not self.emoteIndex
                and self.fieldName == "name"
                and AddonSettings.RefreshCategorySelector then
                AddonSettings.RefreshCategorySelector()
            end
        else
            self.isDirty = false
            DisplayCurrentValue(self)
        end
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self.isDirty = true
        end
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        Commit(self)
        DisplayCurrentValue(self)
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self.isDirty = false
        DisplayCurrentValue(self)
        self:ClearFocus()
    end)

    editBox:RefreshFromDatabase()
    return editBox
end

local function GetExchangeDialog()
    if exchangeDialog then
        return exchangeDialog
    end

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
            actionButton:SetEnabled(hasText)
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

    local function PerformImport(importText, dataType, categoryIndex)
        dataType = dataType or dialog.dataType
        local success
        local result
        local sourceProfileName

        if dataType == "profile" then
            success, result, sourceProfileName = Serialization.ImportProfileAsNew(importText)
        elseif dataType == "category" then
            success, result = Serialization.ImportCategory(
                categoryIndex or dialog.categoryIndex,
                importText
            )
        else
            success, result = Serialization.ImportAllProfiles(importText)
        end

        if not success then
            SetStatus(result, true)
            dialog:UpdateActionState()
            return
        end

        editBox:SetText("")
        dialog:UpdateActionState()

        if dataType == "profile" then
            if dialog.onProfileImported then
                dialog.onProfileImported()
            end

            SetStatus("Imported profile " .. sourceProfileName .. " as " .. result .. ".")
        elseif dataType == "category" then
            SetStatus("Imported category " .. result .. ".")
        else
            local profileLabel = result == 1 and "profile" or "profiles"
            SetStatus("Added " .. result .. " " .. profileLabel .. ".")
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_IMPORT_OVER_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the imported category?\n\nThis cannot be undone.",
        button1 = "Replace",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            PerformImport(data.importText, "category", data.categoryIndex)
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
            and CategoryHasContent(Database.GetCategory(dialog.categoryIndex)) then
            StaticPopup_Show(
                "RPEMOTEMENU_IMPORT_OVER_CATEGORY",
                "Category " .. dialog.categoryIndex,
                nil,
                {
                    importText = importText,
                    categoryIndex = dialog.categoryIndex
                }
            )
            return
        end

        PerformImport(importText, dialog.dataType)
    end)

    dialog:SetScript("OnHide", function()
        editBox:ClearFocus()
    end)

    function dialog:OpenExport(categoryIndex)
        local exported, errorMessage = Serialization.ExportCategory(categoryIndex)
        if not exported then
            return false, errorMessage
        end

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

    function dialog:OpenProfileExport()
        local exported, errorMessage = Serialization.ExportProfile()
        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "profile"
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Export Profile: " .. Database.GetActiveProfileName())
        instructions:SetText(
            "Copy this JSON to share or save this profile's appearance, "
            .. "categories, and emotes."
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
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = onProfileImported
        title:SetText("Import Profile")
        instructions:SetText(
            "Paste exported profile JSON below. Importing adds a new profile without "
            .. "changing the current profile or any character assignments."
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

    function dialog:OpenAllProfilesExport()
        local exported, errorMessage = Serialization.ExportAllProfiles()

        if not exported then
            return false, errorMessage
        end

        self.mode = "export"
        self.dataType = "profiles"
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Export All Profiles")
        instructions:SetText(
            "Copy this JSON to save every profile. Character assignments are not included."
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

    function dialog:OpenAllProfilesImport()
        self.mode = "import"
        self.dataType = "profiles"
        self.categoryIndex = nil
        self.profileName = nil
        self.onProfileImported = nil
        title:SetText("Import Profiles")
        instructions:SetText(
            "Paste an all-profiles export below. Importing only adds profiles; it "
            .. "does not replace, activate, or assign them to characters. Imported "
            .. "Default profiles receive a unique name."
        )
        actionButton:SetText("Import Profiles")
        SetStatus("")
        editBox:SetText("")
        scrollFrame:SetVerticalScroll(0)
        self:UpdateActionState()
        self:Show()
        editBox:SetFocus()
        return true
    end

    exchangeDialog = dialog
    return dialog
end

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
        "commands, category and custom-profile sharing, and " ..
        "per-profile fonts, colors, and appearance."
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

    local sourceLink = CreateFrame("Button", nil, panel)
    sourceLink:SetPoint("LEFT", sourceLabel, "RIGHT", 0, 0)

    local sourceText = sourceLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceText:SetPoint("LEFT", sourceLink, "LEFT")
    sourceText:SetText(SOURCE_URL)
    sourceText:SetTextColor(0.35, 0.7, 1, 1)

    sourceLink:SetSize(sourceText:GetStringWidth(), 16)
    sourceLink:SetScript("OnEnter", function()
        sourceText:SetTextColor(0.65, 0.85, 1, 1)
    end)
    sourceLink:SetScript("OnLeave", function()
        sourceText:SetTextColor(0.35, 0.7, 1, 1)
    end)
    sourceLink:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)

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

local function CreateIntegerEditBox(
    parent,
    x,
    y,
    width,
    getValue,
    applyValue,
    allowNegative
)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, 24)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    editBox:SetAutoFocus(false)
    -- SetNumeric(true) rejects a typed minus sign. Coordinate fields need a
    -- normal edit box with signed-integer validation at commit time.
    editBox:SetNumeric(not allowNegative)
    editBox:EnableMouseWheel(true)
    editBox:SetMaxLetters(allowNegative and 7 or 6)
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    editBox:SetTextColor(1, 1, 1, 1)

    editBox.RefreshValue = function(self)
        local value = math.floor(tonumber(getValue()) or 0)
        self:SetText(tostring(value))
        self:SetCursorPosition(0)
    end

    local function Commit(self)
        local text = self:GetText()
        local value = tonumber(text)

        if not value or (allowNegative and not text:match("^%-?%d+$")) then
            self:RefreshValue()
            return
        end

        applyValue(math.floor(value))
        self:RefreshValue()
    end

    editBox:SetScript("OnEnterPressed", function(self)
        Commit(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", Commit)
    editBox:SetScript("OnEscapePressed", function(self)
        self:RefreshValue()
        self:ClearFocus()
    end)

    editBox:SetScript("OnMouseWheel", function(self, delta)
        local currentValue = math.floor(tonumber(getValue()) or 0)

        if delta > 0 then
            currentValue = currentValue + 1
        elseif delta < 0 then
            currentValue = currentValue - 1
        else
            return
        end

        applyValue(currentValue)
        self:RefreshValue()
    end)

    editBox:RefreshValue()
    return editBox
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function CopyColor(color)
    return {
        r = color.r,
        g = color.g,
        b = color.b
    }
end

local function GetPickerColor(value, fallback)
    if type(value) ~= "table" then
        return CopyColor(fallback)
    end

    return {
        r = value.r or value[1] or fallback.r,
        g = value.g or value[2] or fallback.g,
        b = value.b or value[3] or fallback.b
    }
end

local function CreateNumberSetting(
    parent,
    labelText,
    settingKey,
    x,
    y,
    minimum,
    maximum,
    getValue,
    applyValue,
    suffix
)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local editBox = CreateIntegerEditBox(
        parent,
        x,
        y - 26,
        70,
        getValue,
        function(value)
            applyValue(Clamp(value, minimum, maximum))
        end
    )
    editBox.settingKey = settingKey
    editBox.Label = label

    if suffix then
        local suffixLabel = parent:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )
        suffixLabel:SetPoint("LEFT", editBox, "RIGHT", FIELD_GAP, 0)
        suffixLabel:SetText(suffix)
        editBox.SuffixLabel = suffixLabel
    end

    return editBox
end

local function CreateColorSetting(
    parent,
    labelText,
    settingKey,
    x,
    y,
    getValue,
    applyValue
)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(52, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 26)
    button:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    button:SetBackdropColor(0.08, 0.08, 0.08, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    button.settingKey = settingKey

    button.Swatch = button:CreateTexture(nil, "ARTWORK")
    button.Swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
    button.Swatch:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)

    button.RefreshValue = function(self)
        local color = getValue()
        self.Swatch:SetColorTexture(color.r, color.g, color.b, 1)
    end

    button:SetScript("OnClick", function(self)
        local originalColor = CopyColor(getValue())

        local function ApplyPickerColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            applyValue({r = r, g = g, b = b})
            self:RefreshValue()
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = originalColor.r,
            g = originalColor.g,
            b = originalColor.b,
            swatchFunc = ApplyPickerColor,
            cancelFunc = function(previousColor)
                applyValue(GetPickerColor(previousColor, originalColor))
                self:RefreshValue()
            end
        })
    end)

    button:RefreshValue()
    return button
end

local function CreateFontSetting(parent, labelText, settingKey, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)

    local selector = CreateFrame(
        "DropdownButton",
        nil,
        parent,
        "WowStyle1DropdownTemplate"
    )
    selector:SetWidth(190)
    selector:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 26)
    selector.settingKey = settingKey

    local internalText = selector.Text
    if not internalText and type(selector.GetFontString) == "function" then
        internalText = selector:GetFontString()
    end
    if internalText then
        internalText:SetAlpha(0)
    end
    selector.InternalText = internalText

    selector.PreviewText = selector:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    selector.PreviewText:SetPoint("LEFT", selector, "LEFT", 10, 0)
    selector.PreviewText:SetPoint("RIGHT", selector, "RIGHT", -30, 0)
    selector.PreviewText:SetJustifyH("LEFT")
    selector.PreviewText:SetWordWrap(false)
    selector.PreviewText:SetFont(STANDARD_TEXT_FONT, 12, "")
    selector.PreviewText:SetTextColor(1, 1, 1, 1)

    selector.RefreshValue = function(self)
        local fontName = settings[settingKey] or ""
        local fontAvailable = addon.IsFontAvailable(fontName)
        self.MissingFontName = not fontAvailable and fontName or nil
        self:OverrideText(fontName)
        if self.InternalText then
            self.InternalText:SetAlpha(0)
        end

        local previewText = self.PreviewText
        if previewText then
            -- The selected-font label must remain readable while a custom font
            -- is still loading. Only the menu itself previews custom fonts.
            previewText:SetFont(STANDARD_TEXT_FONT, 12, "")
            if fontAvailable then
                previewText:SetTextColor(1, 1, 1, 1)
            else
                previewText:SetTextColor(1, 0.35, 0.35, 1)
            end
            previewText:SetText(
                fontAvailable and fontName or fontName .. " (unavailable)"
            )
        end
    end

    selector:HookScript("OnEnter", function(self)
        if not self.MissingFontName then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Font unavailable")
        GameTooltip:AddLine(
            self.MissingFontName .. " is not registered by WoW or LibSharedMedia.",
            1,
            1,
            1,
            true
        )
        GameTooltip:AddLine(
            "RP Emote Menu is displaying Friz Quadrata instead.",
            0.8,
            0.8,
            0.8,
            true
        )
        GameTooltip:Show()
    end)
    selector:HookScript("OnLeave", function(self)
        if self.MissingFontName then
            GameTooltip:Hide()
        end
    end)

    selector:SetupMenu(function(_, rootDescription)
        for _, font in ipairs(addon.GetAvailableFonts()) do
            local fontName = font.name

            rootDescription:CreateRadio(
                fontName,
                function() return settings[settingKey] == fontName end,
                function()
                    settings[settingKey] = fontName
                    selector:RefreshValue()
                    MainWindow.ScheduleFontRefreshes()
                end
            )
        end
    end)

    selector:RefreshValue()
    return selector
end

-- Appearance is organized by pane typography/colors, selection effects, borders, opacity, and icon styling.
local function CreateAppearanceSettingsPanel()
    local container = CreateFrame("Frame")
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        container,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 0)

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetSize(700, 760)
    scrollFrame:SetScrollChild(panel)
    local controls = {}

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Appearance")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Customize the main menu for the current profile. Changes appear immediately."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local categoryPaneHeading = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    categoryPaneHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -120)
    categoryPaneHeading:SetText("Category Pane")

    local emotePaneHeading = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )
    emotePaneHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 330, -120)
    emotePaneHeading:SetText("Emote Pane")

    local columnDivider = panel:CreateTexture(nil, "ARTWORK")
    columnDivider:SetColorTexture(0.35, 0.35, 0.35, 0.45)
    columnDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 314, -118)
    columnDivider:SetSize(1, 300)

    local fontLoadingNote = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    fontLoadingNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -92)
    fontLoadingNote:SetWidth(620)
    fontLoadingNote:SetJustifyH("LEFT")
    fontLoadingNote:SetText(
        "Custom fonts may take |cffffff0010 to 30 seconds|r to appear the first time they are selected."
    )
    fontLoadingNote:SetTextColor(0.7, 0.7, 0.7)

    controls.categoryFont = CreateFontSetting(
        panel, "Font", "categoryFont", 20, -148
    )
    controls.categoryFont:ClearAllPoints()
    controls.categoryFont:SetPoint("TOPLEFT", panel, "TOPLEFT", 95, -143)

    controls.categoryFontSize = CreateNumberSetting(
        panel, "Font size", "categoryFontSize", 20, -187, 8, 24,
        function() return settings.categoryFontSize end,
        function(value)
            settings.categoryFontSize = value
            MainWindow.RefreshFontDisplays()
        end,
        "px"
    )
    controls.categoryFontSize:SetWidth(52)

    controls.emoteFont = CreateFontSetting(
        panel, "Font", "emoteFont", 330, -148
    )
    controls.emoteFont:ClearAllPoints()
    controls.emoteFont:SetPoint("TOPLEFT", panel, "TOPLEFT", 405, -143)

    controls.emoteFontSize = CreateNumberSetting(
        panel, "Font size", "emoteFontSize", 330, -187, 8, 24,
        function() return settings.emoteFontSize end,
        function(value)
            settings.emoteFontSize = value
            MainWindow.RefreshFontDisplays()
        end,
        "px"
    )
    controls.emoteFontSize:SetWidth(52)

    controls.categoryTextColor = CreateColorSetting(
        panel, "Category text", "categoryTextColor", 20, -254,
        function() return settings.categoryTextColor end,
        function(value)
            settings.categoryTextColor = value
            MainWindow.RefreshFontDisplays()
        end
    )

    controls.selectedCategoryTextColor = CreateColorSetting(
        panel, "Selected text", "selectedCategoryTextColor", 20, -292,
        function() return settings.selectedCategoryTextColor end,
        function(value)
            settings.selectedCategoryTextColor = value
            MainWindow.RefreshFontDisplays()
        end
    )

    controls.emoteTextColor = CreateColorSetting(
        panel, "Emote-label text", "emoteTextColor", 330, -254,
        function() return settings.emoteTextColor end,
        function(value)
            settings.emoteTextColor = value
            MainWindow.RefreshFontDisplays()
        end
    )

    controls.categoryHighlightColor = CreateColorSetting(
        panel,
        "Selection color",
        "categoryHighlightColor",
        20,
        -368,
        function() return settings.categoryHighlightColor end,
        function(value)
            settings.categoryHighlightColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.categoryBackgroundColor = CreateColorSetting(
        panel, "Background", "categoryBackgroundColor", 20, -330,
        function() return settings.categoryBackgroundColor end,
        function(value)
            settings.categoryBackgroundColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.emoteBackgroundColor = CreateColorSetting(
        panel, "Background", "emoteBackgroundColor", 330, -292,
        function() return settings.emoteBackgroundColor end,
        function(value)
            settings.emoteBackgroundColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.categoryFontSize:ClearAllPoints()
    controls.categoryFontSize:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -183)
    controls.emoteFontSize:ClearAllPoints()
    controls.emoteFontSize:SetPoint("TOPLEFT", panel, "TOPLEFT", 470, -183)

    controls.categoryTextColor:ClearAllPoints()
    controls.categoryTextColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -250)
    controls.selectedCategoryTextColor:ClearAllPoints()
    controls.selectedCategoryTextColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -288)
    controls.categoryBackgroundColor:ClearAllPoints()
    controls.categoryBackgroundColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -326)
    controls.categoryHighlightColor:ClearAllPoints()
    controls.categoryHighlightColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -364)
    controls.emoteTextColor:ClearAllPoints()
    controls.emoteTextColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 470, -250)
    controls.emoteBackgroundColor:ClearAllPoints()
    controls.emoteBackgroundColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 470, -288)

    local highlightEffectLabel = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )
    highlightEffectLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -406)
    highlightEffectLabel:SetText("Selection effect")

    local highlightEffectSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    highlightEffectSelector:SetWidth(135)
    highlightEffectSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -401)
    highlightEffectSelector:SetDefaultText("Background")
    highlightEffectSelector.settingKey = "categoryHighlightEffect"
    controls.categoryHighlightEffect = highlightEffectSelector

    controls.categoryHighlightThickness = CreateNumberSetting(
        panel, "Thickness", "categoryHighlightThickness", 330, -406, 1, 6,
        function() return settings.categoryHighlightThickness end,
        function(value)
            settings.categoryHighlightThickness = value
            MainWindow.ApplyAppearance()
        end,
        "px"
    )

    local highlightEffectLabels = {
        background = "Background",
        outline = "Outline",
        underline = "Underline",
        shadow = "Drop shadow",
        separator = "Separator"
    }

    local function RefreshHighlightControls()
        local usesThickness = settings.categoryHighlightEffect == "outline"
            or settings.categoryHighlightEffect == "underline"
            or settings.categoryHighlightEffect == "separator"
        local thicknessControl = controls.categoryHighlightThickness

        thicknessControl:SetShown(usesThickness)
        thicknessControl.Label:SetShown(usesThickness)
        thicknessControl.SuffixLabel:SetShown(usesThickness)
        highlightEffectSelector:OverrideText(
            highlightEffectLabels[settings.categoryHighlightEffect]
        )
    end

    highlightEffectSelector:SetupMenu(function(_, rootDescription)
        for _, effect in ipairs({
            "background", "outline", "separator", "underline", "shadow"
        }) do
            rootDescription:CreateRadio(
                highlightEffectLabels[effect],
                function() return settings.categoryHighlightEffect == effect end,
                function()
                    settings.categoryHighlightEffect = effect
                    RefreshHighlightControls()
                    MainWindow.ApplyAppearance()
                end
            )
        end
    end)

    local windowHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -460)
    windowHeading:SetText("Borders")

    controls.borderColor = CreateColorSetting(
        panel, "Border color", "borderColor", 20, -488,
        function() return settings.borderColor end,
        function(value)
            settings.borderColor = value
            MainWindow.ApplyAppearance()
        end
    )

    controls.borderColor:ClearAllPoints()
    controls.borderColor:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -484)

    local borderLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    borderLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -526)
    borderLabel:SetText("Border style")

    local borderSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    borderSelector:SetWidth(170)
    borderSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -521)
    borderSelector:SetDefaultText("Thin")
    borderSelector.settingKey = "borderStyle"
    controls.borderStyle = borderSelector

    local borderLabels = {
        none = "None",
        thin = "Thin",
        blizzard = "Blizzard"
    }

    local function BuildBorderMenu(_, rootDescription)
        for _, style in ipairs({"none", "thin", "blizzard"}) do
            rootDescription:CreateRadio(
                borderLabels[style],
                function() return settings.borderStyle == style end,
                function()
                    settings.borderStyle = style
                    borderSelector:OverrideText(borderLabels[style])
                    MainWindow.ApplyAppearance()
                end
            )
        end
    end

    borderSelector:SetupMenu(BuildBorderMenu)

    local opacityHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    opacityHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -565)
    opacityHeading:SetText("Opacity")

    controls.windowOpacity = CreateNumberSetting(
        panel, "Menu opacity", "windowOpacity", 20, -593, 10, 100,
        function() return settings.windowOpacity * 100 end,
        function(value)
            settings.windowOpacity = value / 100
            MainWindow.ApplyAppearance()
        end,
        "%"
    )

    controls.windowOpacity:ClearAllPoints()
    controls.windowOpacity:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -589)

    local opacityVisibleNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    opacityVisibleNote:SetPoint("LEFT", controls.windowOpacity.SuffixLabel, "RIGHT", FIELD_GAP, 0)
    opacityVisibleNote:SetText("(when visible)")

    local layoutHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -635)
    layoutHeading:SetText("Layout")

    local titleBarLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleBarLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -663)
    titleBarLabel:SetText("Title bar")

    local titleBarSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    titleBarSelector:SetWidth(150)
    titleBarSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -658)
    titleBarSelector:SetDefaultText("Top")
    titleBarSelector.settingKey = "titleBarPosition"
    controls.titleBarPosition = titleBarSelector

    local titleBarLabels = {TOP = "Top", LEFT = "Left"}

    titleBarSelector:SetupMenu(function(_, rootDescription)
        for _, position in ipairs({"TOP", "LEFT"}) do
            rootDescription:CreateRadio(
                titleBarLabels[position],
                function() return settings.titleBarPosition == position end,
                function()
                    settings.titleBarPosition = position
                    titleBarSelector:OverrideText(titleBarLabels[position])
                    MainWindow.ApplyTitleBarPosition()
                end
            )
        end
    end)

    local iconHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -705)
    iconHeading:SetText("Minimized Icon")

    addon.MinimizedIconColor.CreateSettingsControls(panel, 20, -735, true)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(170, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
    resetButton:SetText("Restore Defaults")
    resetButton.settingKey = "resetAppearance"
    controls.resetAppearance = resetButton

    local appearanceKeys = {
        "titleBarPosition",
        "categoryFont",
        "emoteFont",
        "categoryFontSize",
        "emoteFontSize",
        "categoryTextColor",
        "selectedCategoryTextColor",
        "emoteTextColor",
        "categoryHighlightColor",
        "categoryHighlightEffect",
        "categoryHighlightThickness",
        "categoryBackgroundColor",
        "emoteBackgroundColor",
        "borderColor",
        "borderStyle",
        "windowOpacity",
        "minimizedIconColor"
    }

    local function RefreshFontControls()
        settings = Database.GetSettings()
        controls.categoryFont:RefreshValue()
        controls.emoteFont:RefreshValue()
    end

    local function RefreshControls()
        for key, control in pairs(controls) do
            if control.RefreshValue then
                control:RefreshValue()
            end
        end

        RefreshHighlightControls()
        borderSelector:OverrideText(borderLabels[settings.borderStyle])
        titleBarSelector:OverrideText(
            titleBarLabels[settings.titleBarPosition] or titleBarLabels.TOP
        )
        addon.MinimizedIconColor.RefreshControl()
    end

    resetButton:SetScript("OnClick", function()
        for _, key in ipairs(appearanceKeys) do
            local value = addon.DefaultSettings[key]

            if type(value) == "table" then
                settings[key] = CopyColor(value)
            else
                settings[key] = value
            end
        end

        RefreshControls()
        MainWindow.ApplyAppearance()
        MainWindow.ApplyTitleBarPosition()
    end)

    container.RefreshControls = RefreshControls
    container.RefreshFontControls = RefreshFontControls
    container.appearanceControls = controls
    AddonSettings.RefreshFontControls = RefreshFontControls
    container:SetScript("OnShow", RefreshControls)
    RefreshControls()
    return container
end

-- Global behavior is organized by startup/interaction, inactivity/minimize behavior, and layout.
local function CreateGeneralSettingsPanel()
    local container = CreateFrame("Frame")
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        container,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local nextOffset = (self:GetVerticalScroll() or 0) - (delta * 40)
        self:SetVerticalScroll(math.max(
            0,
            math.min(self:GetVerticalScrollRange() or 0, nextOffset)
        ))
    end)

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetSize(700, 700)
    scrollFrame:SetScrollChild(panel)
    local switches = {}

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("App Behavior & Preferences")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetText(
        "These settings apply globally, regardless of the active profile."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local behaviorHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    behaviorHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -95)
    behaviorHeading:SetText("Startup & Interaction")

    local lockSwitch = CreateSwitch(panel, "Lock window", -625,
        function() return settings.locked end,
        function(value)
            settings.locked = value
            MainWindow.ApplyMovementLock()
        end)
    lockSwitch:ClearAllPoints()
    lockSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -621)
    switches[#switches + 1] = lockSwitch

    local hideSettingsSwitch = CreateSwitch(panel, "Hide settings gear icon", -185,
        function() return settings.hideSettingsGear end,
        function(value)
            settings.hideSettingsGear = value
            MainWindow.ApplySettingsGearVisibility()
        end)
    hideSettingsSwitch:ClearAllPoints()
    hideSettingsSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -181)
    switches[#switches + 1] = hideSettingsSwitch

    local hideEmoteSwitch = CreateSwitch(
        panel,
        "Hide emote edit gear icons",
        -215,
        function() return settings.hideEmoteEditGears end,
        function(value)
            settings.hideEmoteEditGears = value
            MainWindow.UpdateMenu()
        end
    )
    hideEmoteSwitch:ClearAllPoints()
    hideEmoteSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -211)
    switches[#switches + 1] = hideEmoteSwitch

    local showAtLoginSwitch = CreateSwitch(panel, "Show the addon at login", -125,
        function() return settings.showAtLogin end,
        function(value) settings.showAtLogin = value end)
    showAtLoginSwitch:ClearAllPoints()
    showAtLoginSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -121)
    switches[#switches + 1] = showAtLoginSwitch

    local tooltipDelayBox = CreateNumberSetting(
        panel, "Tooltip delay (0-1000)", "tooltipDelayMs", 20, -155, 0, 1000,
        function() return settings.tooltipDelayMs end,
        function(value) settings.tooltipDelayMs = value end,
        "ms"
    )

    tooltipDelayBox:ClearAllPoints()
    tooltipDelayBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -151)

    local emoteGearNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emoteGearNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -215)
    emoteGearNote:SetText("(right-click an emote to edit)")

    local inactiveHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inactiveHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -260)
    inactiveHeading:SetText("Window Behavior")

    local RefreshInactiveControls
    local RefreshIconControls
    local fadeSwitch = CreateSwitch(panel, "Fade the menu when inactive", -290,
        function() return settings.fadeEnabled end,
        function(value)
            settings.fadeEnabled = value
            MainWindow.ApplyFadeSettings()
            if RefreshInactiveControls then
                RefreshInactiveControls()
            end
        end)
    fadeSwitch:ClearAllPoints()
    fadeSwitch:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -286)
    switches[#switches + 1] = fadeSwitch

    local fadeDelayBox = CreateNumberSetting(
        panel, "Fade after", "fadeDelay", 20, -320, 0, 60,
        function() return settings.fadeDelay end,
        function(value)
            settings.fadeDelay = value
            MainWindow.ApplyFadeSettings()
        end,
        "seconds"
    )

    local inactiveOpacityBox = CreateNumberSetting(
        panel, "Inactive opacity", "inactiveOpacity", 20, -350, 10, 100,
        function() return settings.inactiveOpacity * 100 end,
        function(value)
            settings.inactiveOpacity = value / 100
            MainWindow.ApplyFadeSettings()
        end,
        "%"
    )

    fadeDelayBox:ClearAllPoints()
    fadeDelayBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -316)
    inactiveOpacityBox:ClearAllPoints()
    inactiveOpacityBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -346)

    local minimizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -380)
    minimizeLabel:SetText("Minimize to")

    local minimizeSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    minimizeSelector:SetWidth(150)
    minimizeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -375)
    minimizeSelector:SetDefaultText("None")

    local minimizeLabels = {
        NONE = "None",
        TITLE_BAR = "Title Bar",
        ICON = "Icon"
    }

    minimizeSelector:SetupMenu(function(_, rootDescription)
        for _, mode in ipairs({"NONE", "TITLE_BAR", "ICON"}) do
            rootDescription:CreateRadio(
                minimizeLabels[mode],
                function() return settings.minimizeMode == mode end,
                function()
                    settings.minimizeMode = mode
                    minimizeSelector:OverrideText(minimizeLabels[mode])
                    MainWindow.ApplyMinimizeToIconSettings()
                    if RefreshIconControls then
                        RefreshIconControls()
                    end
                end
            )
        end
    end)

    local iconSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconSizeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -410)
    iconSizeLabel:SetText("Minimized icon size")

    local iconSizeBox = CreateIntegerEditBox(
        panel, 255, -406, 70,
        function() return settings.minimizedIconSize end,
        function(value)
            settings.minimizedIconSize = value
            MainWindow.ApplyMinimizeToIconSettings()
        end
    )

    local iconSizeRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    iconSizeRange:SetPoint("LEFT", iconSizeBox, "RIGHT", FIELD_GAP, 0)
    iconSizeRange:SetText("(16-64 px)")

    local iconCornerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    iconCornerLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -440)
    iconCornerLabel:SetText("Icon side")

    local iconCornerSelector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    iconCornerSelector:SetWidth(150)
    iconCornerSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 255, -435)
    iconCornerSelector:SetDefaultText("Left")

    local iconCornerLabels = {
        TOPLEFT = "Left",
        TOPRIGHT = "Right"
    }

    iconCornerSelector:SetupMenu(function(_, rootDescription)
        for _, corner in ipairs({"TOPLEFT", "TOPRIGHT"}) do
            rootDescription:CreateRadio(
                iconCornerLabels[corner],
                function() return settings.minimizedIconCorner == corner end,
                function()
                    settings.minimizedIconCorner = corner
                    iconCornerSelector:OverrideText(iconCornerLabels[corner])
                    MainWindow.ApplyMinimizeToIconSettings()
                end
            )
        end
    end)

    RefreshIconControls = function()
        local enabled = settings.fadeEnabled and settings.minimizeMode == "ICON"
        local alpha = enabled and 1 or 0.45

        for _, control in ipairs({
            iconSizeBox,
            iconCornerSelector
        }) do
            control:SetEnabled(enabled)
            control:SetAlpha(alpha)
        end

        iconSizeLabel:SetAlpha(alpha)
        iconCornerLabel:SetAlpha(alpha)
    end

    RefreshInactiveControls = function()
        local enabled = settings.fadeEnabled
        local alpha = enabled and 1 or 0.45

        for _, control in ipairs({fadeDelayBox, inactiveOpacityBox}) do
            if enabled then
                control:Enable()
            else
                control:ClearFocus()
                control:Disable()
            end

            control:SetAlpha(alpha)
            control.Label:SetAlpha(alpha)
            control.SuffixLabel:SetAlpha(alpha)
        end

        minimizeSelector:SetEnabled(enabled)
        minimizeSelector:SetAlpha(alpha)
        minimizeLabel:SetAlpha(alpha)
        RefreshIconControls()
    end

    local layoutHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    layoutHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -485)
    layoutHeading:SetText("Layout")

    local positionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    positionLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -555)
    positionLabel:SetText("Exact position (advanced)")

    local positionXBox = CreateIntegerEditBox(
        panel, 255, -551, 80,
        function() return settings.x end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                value,
                settings.y,
                nil,
                settings.height,
                true
            )
        end,
        true
    )

    local positionYBox = CreateIntegerEditBox(
        panel, 405, -551, 80,
        function() return settings.y end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                value,
                nil,
                settings.height,
                true
            )
        end,
        true
    )

    local xLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("RIGHT", positionXBox, "LEFT", -FIELD_GAP, 0)
    xLabel:SetText("X")

    local yLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("RIGHT", positionYBox, "LEFT", -FIELD_GAP, 0)
    yLabel:SetText("Y")

    local centerButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    centerButton:SetSize(130, 24)
    centerButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -510)
    centerButton:SetText("Center Window")
    centerButton:SetScript("OnClick", MainWindow.CenterWindow)

    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    heightLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -590)
    heightLabel:SetText("Window height")

    local heightBox = CreateIntegerEditBox(
        panel, 255, -586, 80,
        function() return settings.height end,
        function(value)
            MainWindow.ApplyWindowGeometry(
                settings.x,
                settings.y,
                nil,
                value
            )
        end
    )

    local heightRange = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    heightRange:SetPoint("LEFT", heightBox, "RIGHT", FIELD_GAP, 0)
    heightRange:SetText("(150-630 px)")

    local widthNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widthNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -655)
    widthNote:SetWidth(620)
    widthNote:SetJustifyH("LEFT")
    widthNote:SetText("Window width adjusts automatically to fit all category and emote labels in the profile.")
    widthNote:SetTextColor(0.8, 0.8, 0.8, 1)

    AddonSettings.RefreshGeneralWindowFields = function()
        lockSwitch:RefreshValue()
        positionXBox:RefreshValue()
        positionYBox:RefreshValue()
        heightBox:RefreshValue()
        fadeSwitch:RefreshValue()
        fadeDelayBox:RefreshValue()
        tooltipDelayBox:RefreshValue()
        inactiveOpacityBox:RefreshValue()
        minimizeSelector:OverrideText(
            minimizeLabels[settings.minimizeMode] or minimizeLabels.NONE
        )
        iconSizeBox:RefreshValue()
        iconCornerSelector:OverrideText(
            iconCornerLabels[settings.minimizedIconCorner]
                or iconCornerLabels.TOPLEFT
        )
        RefreshInactiveControls()
    end

    local function RefreshControls()
        for _, switch in ipairs(switches) do
            switch:RefreshValue()
        end

        AddonSettings.RefreshGeneralWindowFields()
    end

    container.RefreshControls = RefreshControls
    container:SetScript("OnShow", RefreshControls)

    local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaultsButton:SetSize(170, 24)
    defaultsButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -60)
    defaultsButton:SetText("Restore Global Defaults")
    defaultsButton:SetScript("OnClick", function()
        Database.ResetGlobalSettings()
        settings = Database.GetSettings()
        MainWindow.ApplyProfileSettings()
        RefreshControls()
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(125, 24)
    resetButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, -510)
    resetButton:SetText("Reset Window")
    resetButton:SetScript("OnClick", MainWindow.ResetWindowPosition)

    return container
end

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
        "Save or transfer profiles, including the editable Default profile."
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
        "Each profile includes appearance, categories, and emotes. Global "
        .. "behavior, preferences, window layout, character names, realms, and "
        .. "character assignments are not exported."
    )
    profilesDescription:SetTextColor(0.8, 0.8, 0.8)

    local exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportButton:SetSize(160, 24)
    exportButton:SetPoint("TOPLEFT", profilesDescription, "BOTTOMLEFT", 0, -18)
    exportButton:SetText("Export All Profiles")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenAllProfilesExport()
    end)

    local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importButton:SetSize(160, 24)
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)
    importButton:SetText("Import Profiles")
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenAllProfilesImport()
    end)

    local importNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importNote:SetPoint("TOPLEFT", exportButton, "BOTTOMLEFT", 0, -18)
    importNote:SetWidth(620)
    importNote:SetJustifyH("LEFT")
    importNote:SetText(
        "Importing only adds profiles. It does not replace existing profiles, "
        .. "change the current profile, or assign profiles to characters. Imported "
        .. "Default entries and other name conflicts are renamed automatically. "
        .. "Review profile names and custom emote text before sharing."
    )
    importNote:SetTextColor(0.7, 0.7, 0.7)

    return panel
end

-- Profile management keeps selection, lifecycle actions, import/export, and bundled-profile restore together.
local function CreateProfilesSettingsPanel()
    local panel = CreateFrame("Frame")

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Profiles")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    description:SetWidth(620)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Profiles are shared account-wide; each character selects one. Default " ..
        "can be edited and restored. Bundled profiles can be edited, renamed, or deleted."
    )
    description:SetTextColor(0.8, 0.8, 0.8)

    local currentProfileLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentProfileLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -85)
    currentProfileLabel:SetText("Selected profile")

    local selector = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    selector:SetWidth(250)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -112)
    selector:SetDefaultText(
        Database.GetProfileDisplayName(Database.GetActiveProfileName())
    )

    local profileDescription = panel:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlightSmall"
    )
    profileDescription:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -188)
    profileDescription:SetWidth(620)
    profileDescription:SetJustifyH("LEFT")
    profileDescription:SetTextColor(0.75, 0.75, 0.75)

    local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -330)
    status:SetWidth(620)
    status:SetJustifyH("LEFT")

    local createButton
    local copyButton
    local renameButton
    local deleteButton
    local exportProfileButton
    local importProfileButton

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

    local function GetPopupEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end

    local function GetPopupButton1(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end

    StaticPopupDialogs["RPEMOTEMENU_NEW_PROFILE"] = {
        text = "Enter a name for the new profile.",
        button1 = "Create",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 64,
        editBoxWidth = 260,
        OnShow = function(self, data)
            local editBox = GetPopupEditBox(self)
            editBox:SetText(data.initial)
            editBox:SetFocus()
            editBox:HighlightText()
            GetPopupButton1(self):SetText(data.action == "copy" and "Copy" or "Create")
            local valid = Database.ValidateNewProfileName(editBox:GetText())
            GetPopupButton1(self):SetEnabled(valid ~= nil)
        end,
        OnAccept = function(self, data)
            local name = GetPopupEditBox(self):GetText()
            local success, result
            if data.action == "copy" then
                success, result = Database.CopyProfile(data.source, name)
            else
                success, result = Database.CreateProfile(name)
            end
            if success then
                SetStatus((data.action == "copy" and "Copied profile to "
                    or "Created profile ") .. result .. ".")
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnTextChanged = function(self)
            local valid = Database.ValidateNewProfileName(self:GetText())
            GetPopupButton1(self:GetParent()):SetEnabled(valid ~= nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local button = GetPopupButton1(self:GetParent())
            if button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_DEFAULT_PROFILE"] = {
        text = "Restore Default's original appearance, categories, and emotes?\n\nChanges to Default will be lost. Other profiles will not be changed.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            Database.RestoreDefaultProfile()
            SetStatus("Restored the Default profile.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_PROFILE_INFO"] = {
        text = "Default can be edited and restored, but not renamed or deleted. Create starts with built-in emotes and the current appearance. Copy duplicates the selected profile. Bundled profiles may be edited or deleted; Restore Bundled Profiles recreates and resets them.",
        button1 = OKAY or "Okay",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RENAME_PROFILE"] = {
        text = 'Rename the profile "%s".',
        button1 = "Rename",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 64,
        editBoxWidth = 260,
        OnShow = function(self, profileName)
            local editBox = GetPopupEditBox(self)

            editBox:SetText(profileName or self.data)
            editBox:HighlightText()
            editBox:SetFocus()
            GetPopupButton1(self):SetEnabled(false)
        end,
        OnAccept = function(self, profileName)
            local success, result = Database.RenameProfile(
                profileName,
                GetPopupEditBox(self):GetText()
            )

            if success then
                SetStatus("Renamed profile to " .. result .. ".")
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnTextChanged = function(self)
            local popup = self:GetParent()
            local validName = Database.ValidateNewProfileName(
                self:GetText(),
                popup.data
            )

            GetPopupButton1(popup):SetEnabled(validName ~= nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local popup = self:GetParent()
            local acceptButton = GetPopupButton1(popup)

            if acceptButton:IsEnabled() then
                acceptButton:Click()
            end
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    local function DeleteProfile(_, profileName)
        local success, errorMessage = Database.DeleteProfile(profileName)

        if success then
            SetStatus("Deleted profile " .. profileName .. ".")
        else
            SetStatus(errorMessage, true)
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_DELETE_PROFILE"] = {
        text = 'Delete the profile "%s"?\n\nCharacters using it will return to Default.',
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = DeleteProfile,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_DELETE_BUNDLED_PROFILE"] = {
        text = 'Delete the bundled profile "%s"?\n\nCharacters using it will return to Default. Restore Bundled Profiles can recreate it.',
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = DeleteProfile,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_BUILT_IN_PROFILES"] = {
        text = "Restore all bundled profiles to their original categories and appearance?\n\nExisting bundled profiles will be reset and missing ones will be recreated. Renamed profiles and other custom profiles will not be changed.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            local count = Database.RestoreBuiltInProfiles()
            SetStatus("Restored " .. count .. " bundled profiles.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

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

    local restoreDefaultButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restoreDefaultButton:SetSize(140, 24)
    restoreDefaultButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -150)
    restoreDefaultButton:SetText("Restore Default")
    restoreDefaultButton:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_DEFAULT_PROFILE")
    end)

    CreateInfoLink(panel, selector, "RPEMOTEMENU_PROFILE_INFO")

    local profileNote = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profileNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -218)
    profileNote:SetWidth(620)
    profileNote:SetJustifyH("LEFT")
    profileNote:SetText(
        "Create starts with built-in emotes and the current appearance; Copy duplicates " ..
        "the selected profile."
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
    createButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -258)
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

        local popupName = Database.IsBuiltInProfileName(profileName)
            and "RPEMOTEMENU_DELETE_BUNDLED_PROFILE"
            or "RPEMOTEMENU_DELETE_PROFILE"
        StaticPopup_Show(popupName, profileName, nil, profileName)
    end)

    exportProfileButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportProfileButton:SetSize(125, 24)
    exportProfileButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -290)
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

    local restoreBuiltInsButton = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )
    restoreBuiltInsButton:SetSize(190, 24)
    restoreBuiltInsButton:SetPoint("LEFT", restoreDefaultButton, "RIGHT", 8, 0)
    restoreBuiltInsButton:SetText("Restore Bundled Profiles")
    restoreBuiltInsButton:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_BUILT_IN_PROFILES")
    end)

    panel.Refresh = function()
        local profileName = Database.GetActiveProfileName()
        selector:OverrideText(Database.GetProfileDisplayName(profileName))
        profileDescription:SetText(Database.GetProfileDescription(profileName))
        UpdateButtonState()
    end

    panel:SetScript("OnShow", panel.Refresh)

    panel.Refresh()
    return panel
end

local function HasEmptyCategorySlot(selectedCategoryIndex)
    for categoryIndex = 1, MAX_CATEGORIES do
        if categoryIndex ~= selectedCategoryIndex then
            local category = Database.GetCategory(categoryIndex)
            local empty = category and strtrim(category.name or "") == ""

            for emoteIndex = 1, MAX_EMOTES do
                if empty and EmoteHasContent(category.emotes[emoteIndex]) then
                    empty = false
                end
            end

            if empty then
                return true
            end
        end
    end

    return false
end

local function GetPopulatedEmotes(categoryIndex)
    local populated = {}
    local category = Database.GetCategory(categoryIndex)

    for emoteIndex = 1, MAX_EMOTES do
        local emote = category and category.emotes[emoteIndex]
        if EmoteHasContent(emote) then
            populated[#populated + 1] = {
                emote = emote,
                index = emoteIndex
            }
        end
    end

    return populated
end

local function CreateCategoriesSettingsPanel()
    local panel = CreateFrame("Frame")
    local selectedCategoryIndex = settings.selectedCategory

    if type(selectedCategoryIndex) ~= "number"
        or selectedCategoryIndex < 1
        or selectedCategoryIndex > MAX_CATEGORIES then
        selectedCategoryIndex = 1
    end

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    heading:SetText("Emotes")

    local selector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    selector:SetWidth(300)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -48)

    local function GetCategoryLabel(categoryIndex)
        local category = Database.GetCategory(categoryIndex)
        local categoryName = strtrim(category and category.name or "")
        local label = "Category " .. categoryIndex

        if categoryName ~= "" then
            label = label .. ": " .. categoryName
        end

        return label
    end

    selector:SetDefaultText(GetCategoryLabel(selectedCategoryIndex))

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(190, 24)
    resetButton:SetText("Restore Built-in Category")
    resetButton:SetEnabled(Database.CanEditActiveProfile())
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show(
            "RPEMOTEMENU_RESTORE_CATEGORY",
            "Category " .. selectedCategoryIndex,
            nil,
            {categoryIndex = selectedCategoryIndex}
        )
    end)

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the built-in category?\n\nThis cannot be undone.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            Database.ResetCategoryToDefaults(data.categoryIndex)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_ALL_CATEGORIES"] = {
        text = "Replace every category and emote in the current profile with the built-in set?\n\nThis cannot be undone.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function()
            if Database.ResetAllCategoriesToDefaults() then
                print("RP Emote Menu: Restored all built-in categories and emotes.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    resetAllCategoriesButton = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )
    resetAllCategoriesButton:SetSize(240, 24)
    resetAllCategoriesButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 188, -114)
    resetAllCategoriesButton:SetText("Restore All Built-in Categories")
    resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
    resetAllCategoriesButton:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_ALL_CATEGORIES")
    end)

    local duplicateCategoryButton = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )
    duplicateCategoryButton:SetSize(160, 24)
    duplicateCategoryButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -114)
    duplicateCategoryButton:SetText("Duplicate Category")

    local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importButton:SetSize(90, 24)
    importButton:SetText("Import")
    importButton:SetEnabled(Database.CanEditActiveProfile())
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenImport(selectedCategoryIndex)
    end)

    local exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportButton:SetSize(90, 24)
    exportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -82)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenExport(selectedCategoryIndex)
    end)

    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    resetButton:SetPoint("LEFT", selector, "RIGHT", FIELD_GAP, 0)

    local placeholderText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholderText:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -154)
    placeholderText:SetWidth(630)
    placeholderText:SetJustifyH("LEFT")
    placeholderText:SetText(
        "Named categories appear in the sidebar; blank categories stay hidden.\n" ..
        "{target} - Target's name without the realm.\n" ..
        "{player} - Current character's name without the realm.\n" ..
        "Targeted Command is used only when another unit is targeted.\n" ..
        "Drag an emote row to reorder it. Import replaces this category."
    )
    placeholderText:SetTextColor(0.8, 0.8, 0.8)

    local nameBox = CreateLabeledEditBox(
        panel,
        "Category Name",
        16,
        -230,
        420,
        selectedCategoryIndex,
        nil,
        "name"
    )
    local listHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -269)
    listHeading:SetText("Emotes in this category")

    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", listHeading, "RIGHT", 10, 0)
    countText:SetTextColor(0.7, 0.7, 0.7, 1)

    local listScrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        panel,
        "UIPanelScrollFrameTemplate"
    )
    listScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -299)
    listScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -48, 18)

    local listContent = CreateFrame("Frame", nil, listScrollFrame)
    listContent:SetSize(590, 1)
    listScrollFrame:SetScrollChild(listContent)

    local addButton = CreateFrame("Button", nil, listContent, "UIPanelButtonTemplate")
    addButton:SetSize(110, 24)
    addButton:SetText("Add Emote")

    local emptyText = listContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", listContent, "TOPLEFT", 10, -15)
    emptyText:SetText("No emotes yet. Use Add Emote below.")
    emptyText:SetTextColor(0.65, 0.65, 0.65, 1)

    local emoteRows = {}
    local draggedRow

    local function RefreshEmoteRows()
        local populated = GetPopulatedEmotes(selectedCategoryIndex)
        local editable = Database.CanEditActiveProfile()

        countText:SetText("(" .. #populated .. " of " .. MAX_EMOTES .. ")")
        emptyText:SetShown(#populated == 0)
        addButton:SetEnabled(editable and #populated < MAX_EMOTES)
        local rowsHeight = #populated * 45
        local addButtonOffset = rowsHeight + (#populated == 0 and 38 or 6)
        addButton:ClearAllPoints()
        addButton:SetPoint("TOP", listContent, "TOP", 0, -addButtonOffset)
        listContent:SetHeight(math.max(addButtonOffset + 30, 68))

        for rowIndex, row in ipairs(emoteRows) do
            local entry = populated[rowIndex]
            if entry then
                local label = strtrim(entry.emote.label or "")
                row.emoteIndex = entry.index
                row.visiblePosition = rowIndex
                row.Label:SetText(label ~= "" and label or "Unnamed emote")

                local summary = entry.emote.defaultCommand or ""
                if strtrim(entry.emote.targetedCommand or "") ~= "" then
                    summary = summary .. "  |  " .. entry.emote.targetedCommand
                end
                row.Summary:SetText(summary)
                row.EditButton:SetText(editable and "Edit" or "View")
                row.DuplicateButton:SetEnabled(editable and #populated < MAX_EMOTES)
                row.DeleteButton:SetEnabled(editable)
                row:Show()
            else
                row.emoteIndex = nil
                row.visiblePosition = nil
                row:Hide()
            end
        end
    end

    local function DeleteEmote(categoryIndex, emoteIndex)
        if not Database.CanEditActiveProfile() then
            return
        end

        local category = Database.GetCategory(categoryIndex)
        category.emotes[emoteIndex] = {
            label = "",
            defaultCommand = "",
            targetedCommand = ""
        }
        MainWindow.UpdateMenu()
        RefreshEmoteRows()
    end

    StaticPopupDialogs["RPEMOTEMENU_DELETE_EMOTE"] = {
        text = "Delete the emote %s?\n\nThis cannot be undone.",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            DeleteEmote(data.categoryIndex, data.emoteIndex)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    local function FinishRowDrag(row)
        if draggedRow ~= row then
            return
        end

        row:SetAlpha(1)
        local targetPosition
        for _, candidate in ipairs(emoteRows) do
            if candidate:IsShown() and candidate:IsMouseOver() then
                targetPosition = candidate.visiblePosition
                break
            end
        end

        local sourcePosition = row.visiblePosition
        draggedRow = nil
        if not targetPosition or not sourcePosition or targetPosition == sourcePosition then
            return
        end

        local category = Database.GetCategory(selectedCategoryIndex)
        local populated = GetPopulatedEmotes(selectedCategoryIndex)
        local records = {}
        for _, entry in ipairs(populated) do
            records[#records + 1] = entry.emote
        end

        local moved = table.remove(records, sourcePosition)
        table.insert(records, targetPosition, moved)
        for index = 1, MAX_EMOTES do
            category.emotes[index] = records[index] or {
                label = "",
                defaultCommand = "",
                targetedCommand = ""
            }
        end

        MainWindow.UpdateMenu()
        RefreshEmoteRows()
    end

    local function CreateEmoteRow(rowIndex)
        local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        row:SetSize(590, 42)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -((rowIndex - 1) * 45))
        row:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        row:SetBackdropColor(0.08, 0.08, 0.08, rowIndex % 2 == 0 and 0.5 or 0.3)
        row:RegisterForDrag("LeftButton")

        local dragHandle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dragHandle:SetPoint("LEFT", row, "LEFT", 8, 0)
        dragHandle:SetText("::")
        dragHandle:SetTextColor(0.55, 0.55, 0.55, 1)

        row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -5)
        row.Label:SetPoint("RIGHT", row, "RIGHT", -220, 0)
        row.Label:SetJustifyH("LEFT")
        row.Label:SetWordWrap(false)

        row.Summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Summary:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 28, 5)
        row.Summary:SetPoint("RIGHT", row, "RIGHT", -220, 0)
        row.Summary:SetJustifyH("LEFT")
        row.Summary:SetWordWrap(false)
        row.Summary:SetTextColor(0.7, 0.7, 0.7, 1)

        row.EditButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.EditButton:SetSize(52, 22)
        row.EditButton:SetPoint("RIGHT", row, "RIGHT", -154, 0)
        row.EditButton:SetScript("OnClick", function()
            if row.emoteIndex then
                MainWindow.OpenEmoteEditor(selectedCategoryIndex, row.emoteIndex)
            end
        end)

        row.DuplicateButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.DuplicateButton:SetSize(76, 22)
        row.DuplicateButton:SetPoint("RIGHT", row, "RIGHT", -73, 0)
        row.DuplicateButton:SetText("Duplicate")
        row.DuplicateButton:SetScript("OnClick", function()
            if row.emoteIndex then
                local success = Database.DuplicateEmote(
                    selectedCategoryIndex,
                    row.emoteIndex
                )
                if success then
                    MainWindow.UpdateMenu()
                    RefreshEmoteRows()
                end
            end
        end)

        row.DeleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.DeleteButton:SetSize(62, 22)
        row.DeleteButton:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.DeleteButton:SetText("Delete")
        row.DeleteButton:SetScript("OnClick", function()
            if row.emoteIndex then
                StaticPopup_Show(
                    "RPEMOTEMENU_DELETE_EMOTE",
                    row.Label:GetText() or "this emote",
                    nil,
                    {
                        categoryIndex = selectedCategoryIndex,
                        emoteIndex = row.emoteIndex
                    }
                )
            end
        end)

        row:SetScript("OnDragStart", function(self)
            if Database.CanEditActiveProfile() and self.emoteIndex then
                draggedRow = self
                self:SetAlpha(0.45)
            end
        end)
        row:SetScript("OnDragStop", FinishRowDrag)
        row:Hide()
        return row
    end

    for rowIndex = 1, MAX_EMOTES do
        emoteRows[rowIndex] = CreateEmoteRow(rowIndex)
    end

    addButton:SetScript("OnClick", function()
        if not Database.CanEditActiveProfile() then
            return
        end

        local category = Database.GetCategory(selectedCategoryIndex)
        for emoteIndex = 1, MAX_EMOTES do
            if not EmoteHasContent(category.emotes[emoteIndex]) then
                MainWindow.OpenEmoteEditor(selectedCategoryIndex, emoteIndex, true)
                return
            end
        end
    end)

    local function RefreshCategorySelector()
        selector:OverrideText(GetCategoryLabel(selectedCategoryIndex))
    end

    local function SelectCategory(categoryIndex)
        if type(categoryIndex) ~= "number"
            or categoryIndex < 1
            or categoryIndex > MAX_CATEGORIES then
            return
        end

        selectedCategoryIndex = categoryIndex

        nameBox.categoryIndex = categoryIndex
        panel.RefreshEditors()
    end

    duplicateCategoryButton:SetScript("OnClick", function()
        local success, result = Database.DuplicateCategory(selectedCategoryIndex)
        if success then
            SelectCategory(result)
            MainWindow.SetSelectedCategory(result)
            MainWindow.UpdateMenu()
        end
    end)

    selector:SetupMenu(function(_, rootDescription)
        for categoryIndex = 1, MAX_CATEGORIES do
            rootDescription:CreateRadio(
                GetCategoryLabel(categoryIndex),
                function()
                    return selectedCategoryIndex == categoryIndex
                end,
                function()
                    SelectCategory(categoryIndex)
                end
            )
        end
    end)

    panel.RefreshEditors = function(changedCategoryIndex)
        if changedCategoryIndex
            and changedCategoryIndex ~= selectedCategoryIndex then
            return
        end

        local editable = Database.CanEditActiveProfile()
        resetButton:SetEnabled(editable)
        resetAllCategoriesButton:SetEnabled(editable)
        importButton:SetEnabled(editable)
        duplicateCategoryButton:SetEnabled(editable and HasEmptyCategorySlot(selectedCategoryIndex))

        nameBox:RefreshFromDatabase()
        RefreshEmoteRows()

        RefreshCategorySelector()
    end

    panel:SetScript("OnShow", function(self)
        self.RefreshEditors()
    end)

    panel.categorySelector = selector
    panel.SelectCategory = SelectCategory
    panel.GetSelectedCategory = function()
        return selectedCategoryIndex
    end
    AddonSettings.RefreshCategorySelector = RefreshCategorySelector

    panel.RefreshEditors()

    return panel
end

function AddonSettings.CreateSettingsPanel()
    settings = Database.GetSettings()
    local aboutPanel = CreateAboutPanel()
    local generalPanel = CreateGeneralSettingsPanel()
    local appearancePanel = CreateAppearanceSettingsPanel()
    local profilesPanel = CreateProfilesSettingsPanel()
    categoriesSettingsPanel = CreateCategoriesSettingsPanel()
    local importExportPanel = CreateImportExportSettingsPanel()

    settingsCategory = Settings.RegisterCanvasLayoutCategory(aboutPanel, "RP Emote Menu")
    Settings.RegisterAddOnCategory(settingsCategory)

    generalSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        generalPanel,
        "Behavior"
    )

    appearanceSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        appearancePanel,
        "Appearance"
    )

    profilesSettingsCategory = Settings.RegisterCanvasLayoutSubcategory(
        settingsCategory,
        profilesPanel,
        "Profiles"
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
        appearancePanel.RefreshControls()
        profilesPanel.Refresh()
        categoriesSettingsPanel.SelectCategory(settings.selectedCategory)
    end

    AddonSettings.RefreshEditors = function(categoryIndex)
        if resetAllCategoriesButton then
            resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
        end

        if exchangeDialog and exchangeDialog:IsShown() then
            exchangeDialog:UpdateActionState()
        end

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
