local _, addon = ...
local UI = addon.SettingsUI
local AddonSettings = addon.Settings
local Database = addon.Database
local MainWindow = addon.MainWindow
local FIELD_GAP = UI.FIELD_GAP

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

local function CreateFontSetting(parent, labelText, settingKey, x, y, getSettings, onChange)
    getSettings = getSettings or Database.GetSettings
    onChange = onChange or function() MainWindow.ScheduleFontRefreshes() end
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
        local fontName = getSettings()[settingKey] or ""
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
                function() return getSettings()[settingKey] == fontName end,
                function()
                    getSettings()[settingKey] = fontName
                    selector:RefreshValue()
                    onChange()
                end
            )
        end
    end)

    selector:RefreshValue()
    return selector
end


UI.CreateSwitch = CreateSwitch
UI.CreateInfoLink = CreateInfoLink
UI.CreateLabeledEditBox = CreateLabeledEditBox
UI.CreateIntegerEditBox = CreateIntegerEditBox
UI.CreateNumberSetting = CreateNumberSetting
UI.CreateColorSetting = CreateColorSetting
UI.CreateFontSetting = CreateFontSetting
