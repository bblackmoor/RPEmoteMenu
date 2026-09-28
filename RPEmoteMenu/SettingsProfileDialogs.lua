local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database

-- Profile lifecycle prompts are independent of panel construction.
function UI.RegisterProfileDialogs(SetStatus)
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
        text = "Restore Default Profile's original categories, emotes, window settings, and Default Theme assignment?\n\nChanges to Default Profile will be lost. Default Theme appearance will not change.",
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
        text = "Default can be edited and restored, but not renamed or deleted. Create starts with built-in emotes and the current Theme. Copy duplicates the selected Profile, including its Theme assignment.",
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

end
