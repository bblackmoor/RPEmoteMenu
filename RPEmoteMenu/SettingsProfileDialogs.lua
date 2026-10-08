local _, addon = ...
local L = addon.L
local UI = addon.SettingsUI
local Database = addon.Database

function UI.CaptureProfileDialogTarget(name)
    return {name = name, object = Database.GetProfile(name)}
end

-- Profile lifecycle prompts are independent of panel construction.
function UI.RegisterProfileDialogs(SetStatus)
    local function CheckTarget(target)
        if target and target.object and Database.GetProfile(target.name) == target.object then
            return true
        end
        SetStatus(L.UI_THE_PROFILE_CHANGED_REOPEN_THE_DIALOG_BEFORE_CONTINUING, true)
        return false
    end
    local function GetEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end

    local function GetAcceptButton(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end

    StaticPopupDialogs["RPEMOTEMENU_NEW_PROFILE"] = {
        text = L.UI_ENTER_A_NAME_FOR_THE_NEW_PROFILE,
        button1 = L.UI_CREATE,
        button2 = CANCEL or L.UI_CANCEL,
        hasEditBox = true,
        maxLetters = addon.SettingDefinitions.nameLengths.profile,
        editBoxWidth = 260,
        OnShow = function(self, data)
            local editBox = GetEditBox(self)
            editBox:SetText(data.initial)
            editBox:SetFocus()
            editBox:HighlightText()
            GetAcceptButton(self):SetText(data.action == "copy" and L.UI_COPY or L.UI_CREATE)
            local valid = Database.ValidateNewProfileName(editBox:GetText())
            GetAcceptButton(self):SetEnabled(valid ~= nil)
        end,
        OnAccept = function(self, data)
            local name = GetEditBox(self):GetText()
            local success, result
            if data.action == "copy" then
                if not CheckTarget(data.target) then return end
                success, result = Database.CopyProfile(data.source, name)
            else
                success, result = Database.CreateProfile(name)
            end
            if success then
                SetStatus(string.format(data.action == "copy" and L.UI_COPIED_PROFILE_TO_S or L.UI_CREATED_PROFILE_S, result))
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnTextChanged = function(self)
            local valid = Database.ValidateNewProfileName(self:GetText())
            GetAcceptButton(self:GetParent()):SetEnabled(valid ~= nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local button = GetAcceptButton(self:GetParent())
            if button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_DEFAULT_PROFILE"] = {
        text = L.UI_RESTORE_DEFAULT_PROFILE_S_ORIGINAL_CATEGORIES_EMOTES_WINDOW_SETTINGS_AND,
        button1 = L.UI_RESTORE,
        button2 = CANCEL or L.UI_CANCEL,
        OnAccept = function(_, target)
            if not CheckTarget(target) then return end
            Database.RestoreDefaultProfile()
            SetStatus(L.UI_RESTORED_THE_DEFAULT_PROFILE)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_PROFILE_INFO"] = {
        text = L.UI_DEFAULT_CAN_BE_EDITED_AND_RESTORED_BUT_NOT_RENAMED_OR,
        button1 = OKAY or L.UI_OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RENAME_PROFILE"] = {
        text = L.UI_RENAME_THE_PROFILE_S,
        button1 = L.UI_RENAME,
        button2 = CANCEL or L.UI_CANCEL,
        hasEditBox = true,
        maxLetters = addon.SettingDefinitions.nameLengths.profile,
        editBoxWidth = 260,
        OnShow = function(self, target)
            local editBox = GetEditBox(self)

            editBox:SetText((target or self.data).name)
            editBox:HighlightText()
            editBox:SetFocus()
            GetAcceptButton(self):SetEnabled(false)
        end,
        OnAccept = function(self, target)
            if not CheckTarget(target) then return end
            local success, result = Database.RenameProfile(
                target.name,
                GetEditBox(self):GetText()
            )

            if success then
                SetStatus(string.format(L.UI_RENAMED_PROFILE_TO_S, result))
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnTextChanged = function(self)
            local popup = self:GetParent()
            local validName = Database.ValidateNewProfileName(
                self:GetText(),
                popup.data.name
            )

            GetAcceptButton(popup):SetEnabled(validName ~= nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local popup = self:GetParent()
            local acceptButton = GetAcceptButton(popup)

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

    local function DeleteProfile(_, target)
        if not CheckTarget(target) then return end
        local profileName = target.name
        local success, errorMessage = Database.DeleteProfile(profileName)

        if success then
            SetStatus(string.format(L.UI_DELETED_PROFILE_S, profileName))
        else
            SetStatus(errorMessage, true)
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_DELETE_PROFILE"] = {
        text = L.UI_DELETE_THE_PROFILE_S_CHARACTERS_USING_IT_WILL_RETURN_TO,
        button1 = DELETE or L.UI_DELETE,
        button2 = CANCEL or L.UI_CANCEL,
        OnAccept = DeleteProfile,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

end


