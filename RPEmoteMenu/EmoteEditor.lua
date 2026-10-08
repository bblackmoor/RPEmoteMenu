-- Owns the emote editor's draft fields, validation and captured session target.
local _, addon = ...
local L = addon.L
local Database = addon.Database
local EmoteEditor = {}
addon.EmoteEditor = EmoteEditor
local editorDialog

local function CreateFields(dialog, Widgets)
    local title = Widgets.CreateDialogLabel(dialog, "", 16)
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    title:SetText(L.EDITOR_EDIT_EMOTE)
    dialog.Title = title

    local helpText = Widgets.CreateDialogLabel(dialog, "", 12)
    helpText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    helpText:SetWidth(570)
    helpText:SetJustifyH("LEFT")
    helpText:SetText(
        L.EDITOR_HELP
    )
    helpText:SetTextColor(0.8, 0.8, 0.8, 1)
    dialog.HelpText = helpText
    dialog.Fields = {}

    local function CreateEditor(labelText, y)
        local label = Widgets.CreateDialogLabel(dialog, "", 12)
        label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, y)
        label:SetWidth(170)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local editBox = Widgets.CreateDialogTextEntry(dialog, 390, 24)
        editBox:SetSize(390, 24)
        editBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 188, y + 5)
        editBox:SetAutoFocus(false)
        editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
        editBox:SetTextColor(1, 1, 1, 1)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        dialog.Fields[#dialog.Fields + 1] = {label = label, editBox = editBox}
        return editBox
    end

    dialog.NameBox = CreateEditor(L.EDITOR_EMOTE_NAME, -112)
    dialog.DefaultBox = CreateEditor(L.EDITOR_DEFAULT_EMOTE, -152)
    dialog.TargetedBox = CreateEditor(L.EDITOR_TARGETED_EMOTE_OPTIONAL, -192)

    local status = Widgets.CreateDialogLabel(dialog, "", 12)
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 51)
    status:SetWidth(420)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.8, 0.8, 0.8, 1)
    dialog.Status = status

    local saveButton = Widgets.CreateDialogButton(dialog, "", 110, 24)
    saveButton:SetSize(110, 24)
    saveButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -138, 16)
    saveButton:SetText(L.EDITOR_SAVE)
    dialog.SaveButton = saveButton

    local cancelButton = Widgets.CreateDialogButton(dialog, "", 110, 24)
    cancelButton:SetSize(110, 24)
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 16)
    cancelButton:SetText(CANCEL or L.UI_CANCEL)
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)

    function dialog:RefreshLayout()
        local width = 570
        local titleHeight = Widgets.MeasureDialogLabel(self.Title, width - 20)
        local helpHeight = Widgets.MeasureDialogLabel(self.HelpText, width)
        self.HelpText:ClearAllPoints()
        self.HelpText:SetPoint("TOPLEFT", self, "TOPLEFT", 18, -(16 + titleHeight + 10))
        local y = 16 + titleHeight + 10 + helpHeight + 18
        if self.StandardPicker then y = self.StandardPicker:Layout(y, width) end
        for _, field in ipairs(self.Fields) do
            local labelHeight = Widgets.MeasureDialogLabel(field.label, width)
            field.label:ClearAllPoints()
            field.label:SetPoint("TOPLEFT", self, "TOPLEFT", 18, -y)
            field.editBox:ClearAllPoints()
            field.editBox:SetWidth(width)
            field.editBox:SetPoint("TOPLEFT", self, "TOPLEFT", 18, -(y + labelHeight + 6))
            y = y + labelHeight + 6 + 24 + 14
        end
        local statusHeight = Widgets.MeasureDialogLabel(self.Status, width)
        local buttonHeight = Widgets.LayoutDialogButtons(self, saveButton, cancelButton)
        self.Status:ClearAllPoints()
        self.Status:SetPoint("TOPLEFT", self, "TOPLEFT", 18, -y)
        self:SetHeight(math.max(330, y + statusHeight + 14 + buttonHeight + 16))
    end

end

local function InstallSaveActions(dialog)
    local function SaveEmote()
        if not Database.CanEditActiveProfile() then
            return
        end

        local category = Database.GetCategory(dialog.categoryIndex)
        local emote = category and category.emotes
            and category.emotes[dialog.emoteIndex]

        if not emote or not Database.IsCurrentContentTarget(dialog.contentTarget) then
            dialog.Status:SetText(L.EDITOR_TARGET_CHANGED)
            dialog.Status:SetTextColor(1, 0.35, 0.35, 1)
            dialog.SaveButton:SetEnabled(false)
            dialog:RefreshLayout()
            return
        end

        for _, field in ipairs({
            {dialog.NameBox, "emoteLabel", L.EDITOR_EMOTE_NAME_FIELD},
            {dialog.DefaultBox, "command", L.EDITOR_DEFAULT_EMOTE_FIELD},
            {dialog.TargetedBox, "command", L.EDITOR_TARGETED_EMOTE_FIELD}
        }) do
            local valid, errorMessage = Database.ValidateContentText(field[1]:GetText() or "", field[2], field[3])
            if not valid then
                dialog.Status:SetText(errorMessage)
                dialog.Status:SetTextColor(1, 0.35, 0.35, 1)
                dialog:RefreshLayout()
                return -- Keep every field intact and save nothing.
            end
        end

        emote.label = dialog.NameBox:GetText() or ""
        emote.defaultCommand = dialog.DefaultBox:GetText() or ""
        emote.targetedCommand = dialog.TargetedBox:GetText() or ""

        addon.MainWindow.UpdateMenu()
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors(dialog.categoryIndex)
        end
        dialog:Hide()
    end

    dialog.SaveButton:SetScript("OnClick", SaveEmote)
    for _, editBox in ipairs({dialog.NameBox, dialog.DefaultBox, dialog.TargetedBox}) do
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            SaveEmote()
        end)
    end

end

local function InstallSessionLifecycle(dialog)
    function dialog:Open(categoryIndex, emoteIndex, isNew)
        local category = Database.GetCategory(categoryIndex)
        local emote = category and category.emotes and category.emotes[emoteIndex]
        if not emote then
            return
        end

        self.categoryIndex = categoryIndex
        self.emoteIndex = emoteIndex
        self.contentTarget = Database.CaptureContentTarget(categoryIndex, emoteIndex)
        self.NameBox:SetText(emote.label or "")
        self.DefaultBox:SetText(emote.defaultCommand or "")
        self.TargetedBox:SetText(emote.targetedCommand or "")

        local editable = Database.CanEditActiveProfile()
        for _, editBox in ipairs({self.NameBox, self.DefaultBox, self.TargetedBox}) do
            if editable then
                editBox:Enable()
                editBox:SetTextColor(1, 1, 1, 1)
            else
                editBox:Disable()
                editBox:SetTextColor(0.65, 0.65, 0.65, 1)
            end
        end

        self.SaveButton:SetEnabled(editable)
        self.Status:SetTextColor(0.8, 0.8, 0.8, 1)
        self.Status:SetText(editable
            and L.EDITOR_CHANGES_APPLY
            or L.EDITOR_READ_ONLY_HELP)
        self.Title:SetText(
            editable and (isNew and L.UI_ADD_EMOTE or L.EDITOR_EDIT_EMOTE) or L.EDITOR_VIEW_EMOTE
        )
        self:Show()
        self.StandardPicker:Open()
        self:RefreshLayout()
        self:Raise()
    end

    dialog:SetScript("OnHide", function(self)
        self.contentTarget = nil
        self.StandardPicker:Close()
        for _, box in ipairs({self.NameBox, self.DefaultBox, self.TargetedBox}) do
            box:ClearFocus()
        end
    end)
end

local function GetDialog()
    if not editorDialog then
        local Widgets = addon.SettingsWidgets
        local dialog = Widgets.CreateDialog("RPEmoteMenuEmoteEditorDialog", 610, 330)
        CreateFields(dialog, Widgets)
        dialog.StandardPicker = addon.StandardEmotePicker.Install(dialog, Widgets)
        InstallSaveActions(dialog)
        InstallSessionLifecycle(dialog)
        editorDialog = dialog
    end
    return editorDialog
end

function EmoteEditor.Open(categoryIndex, emoteIndex, isNew)
    GetDialog():Open(categoryIndex, emoteIndex, isNew)
end

