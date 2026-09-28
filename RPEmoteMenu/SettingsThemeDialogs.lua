local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database

-- Theme lifecycle prompts and their mutation rules live outside the visual panel.
function UI.RegisterThemeDialogs(SelectTheme, SetStatus)
    local function GetEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end
    local function GetAcceptButton(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end

    StaticPopupDialogs["RPEMOTEMENU_THEME_NAME"] = {
        text = "Enter a Theme name.", button1 = "Create", button2 = CANCEL or "Cancel",
        hasEditBox = true, maxLetters = 64, editBoxWidth = 260,
        OnShow = function(self, data)
            local box = GetEditBox(self)
            box:SetText(data.initial)
            box:SetFocus()
            box:HighlightText()
            GetAcceptButton(self):SetText(data.action == "rename" and "Rename"
                or data.action == "copy" and "Copy" or "Create")
        end,
        OnAccept = function(self, data)
            local name = GetEditBox(self):GetText()
            local success, result
            if data.action == "rename" then
                success, result = Database.RenameTheme(data.source, name)
            elseif data.action == "copy" then
                success, result = Database.CopyTheme(data.source, name)
            else
                success, result = Database.CreateTheme(name)
            end
            if success then
                SelectTheme(result)
                SetStatus("Theme " .. result .. " is ready.")
            else
                SetStatus(result, true)
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local button = GetAcceptButton(self:GetParent())
            if button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_DELETE_THEME"] = {
        text = "%s", button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            local success, result = Database.DeleteTheme(data.name, data.confirmed)
            if success then
                SelectTheme(Database.GetActiveThemeName())
                SetStatus("Deleted " .. data.name .. ".")
            else
                SetStatus(result, true)
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_THEME"] = {
        text = "Restore %s to its factory appearance? Your edits to this Theme will be lost.",
        button1 = "Restore", button2 = CANCEL or "Cancel",
        OnAccept = function(_, name)
            local success, errorMessage = Database.RestoreTheme(name)
            SetStatus(success and ("Restored " .. name .. ".") or errorMessage,
                not success)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_BUNDLED_THEMES"] = {
        text = "Restore all bundled Themes to factory appearance? Edited presets will be reset and missing ones recreated.",
        button1 = "Restore", button2 = CANCEL or "Cancel",
        OnAccept = function()
            local count = Database.RestoreBuiltInThemes()
            SetStatus("Restored " .. count .. " bundled Themes.")
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

end

function UI.ConfirmThemeDeletion(themeName)
    local users = Database.GetProfilesUsingTheme(themeName)
    local message = "Delete Theme " .. themeName .. "?"
    if #users > 0 then
        message = message .. "\n\nProfiles using it: "
            .. table.concat(users, ", ")
            .. "\n\nThey will be assigned Default Theme."
    end
    StaticPopup_Show("RPEMOTEMENU_DELETE_THEME", message, nil,
        {name = themeName, confirmed = #users > 0})
end
