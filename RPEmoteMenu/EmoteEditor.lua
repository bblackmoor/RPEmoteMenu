-- Owns the emote editor's draft fields, validation and captured session target.
local _, addon = ...
local Database = addon.Database
local EmoteEditor = {}
addon.EmoteEditor = EmoteEditor
local editorDialog

local function CreateFields(dialog, Widgets)
    local title = Widgets.CreateDialogLabel(dialog, "", 16)
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    title:SetText("Edit Emote")
    dialog.Title = title

    local helpText = Widgets.CreateDialogLabel(dialog, "", 12)
    helpText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    helpText:SetWidth(570)
    helpText:SetJustifyH("LEFT")
    helpText:SetText(
        "{target} - Target's name without the realm.   " ..
        "{player} - Current character's name without the realm.\n" ..
        "Targeted Emote is used only when another unit is targeted. " ..
        "An emote appears only when it has both a name and a default emote."
    )
    helpText:SetTextColor(0.8, 0.8, 0.8, 1)

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
        return editBox
    end

    dialog.NameBox = CreateEditor("Emote Name", -112)
    dialog.DefaultBox = CreateEditor("Default Emote", -152)
    dialog.TargetedBox = CreateEditor("Targeted Emote (optional)", -192)

    local status = Widgets.CreateDialogLabel(dialog, "", 12)
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 51)
    status:SetWidth(420)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.8, 0.8, 0.8, 1)
    dialog.Status = status

    local saveButton = Widgets.CreateDialogButton(dialog, "", 110, 24)
    saveButton:SetSize(110, 24)
    saveButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -138, 16)
    saveButton:SetText("Save")
    dialog.SaveButton = saveButton

    local cancelButton = Widgets.CreateDialogButton(dialog, "", 110, 24)
    cancelButton:SetSize(110, 24)
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 16)
    cancelButton:SetText(CANCEL or "Cancel")
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)

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
            dialog.Status:SetText("The Profile or emote changed. Reopen the editor before saving.")
            dialog.Status:SetTextColor(1, 0.35, 0.35, 1)
            dialog.SaveButton:SetEnabled(false)
            return
        end

        for _, field in ipairs({
            {dialog.NameBox, "emoteLabel", "Emote name"},
            {dialog.DefaultBox, "command", "Default emote"},
            {dialog.TargetedBox, "command", "Targeted emote"}
        }) do
            local valid, errorMessage = Database.ValidateContentText(field[1]:GetText() or "", field[2], field[3])
            if not valid then
                dialog.Status:SetText(errorMessage)
                dialog.Status:SetTextColor(1, 0.35, 0.35, 1)
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
            and "Changes apply to the current profile."
            or "The Default profile's emotes cannot be edited. Copy it to a custom profile first.")
        self.Title:SetText(
            editable and (isNew and "Add Emote" or "Edit Emote") or "View Emote"
        )
        self:Show()
        self:Raise()
    end

    dialog:SetScript("OnHide", function(self)
        self.contentTarget = nil
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
        InstallSaveActions(dialog)
        InstallSessionLifecycle(dialog)
        editorDialog = dialog
    end
    return editorDialog
end

function EmoteEditor.Open(categoryIndex, emoteIndex, isNew)
    GetDialog():Open(categoryIndex, emoteIndex, isNew)
end
