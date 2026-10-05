local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database

function UI.CaptureThemeDialogTarget(name)
    return {name = name, object = Database.GetTheme(name)}
end

function UI.CaptureBundledThemeDialogTargets()
    local targets = {}
    for _, definition in ipairs(addon.BuiltInThemes) do
        targets[#targets + 1] = UI.CaptureThemeDialogTarget(definition.name)
    end
    return targets
end

-- Theme lifecycle prompts and their mutation rules live outside the visual panel.
function UI.RegisterThemeDialogs(SelectTheme, SetStatus)
    local function CheckTarget(target, allowMissing)
        if target and (target.object or allowMissing)
            and Database.GetTheme(target.name) == target.object then
            return true
        end
        SetStatus("The Theme changed. Reopen the dialog before continuing.", true)
        return false
    end
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
            if data.action ~= "create" and not CheckTarget(data.target) then return end
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
            if not CheckTarget(data.target) then return end
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
        OnAccept = function(_, target)
            if not CheckTarget(target) then return end
            local name = target.name
            local success, errorMessage = Database.RestoreTheme(name)
            SetStatus(success and ("Restored " .. name .. ".") or errorMessage,
                not success)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_BUNDLED_THEMES"] = {
        text = "Restore all bundled Themes to factory appearance? Edited presets will be reset and missing ones recreated.",
        button1 = "Restore", button2 = CANCEL or "Cancel",
        OnAccept = function(_, targets)
            -- Check every slot before restoring any, including intentionally missing presets.
            if not targets then
                CheckTarget(nil)
                return
            end
            for _, target in ipairs(targets) do
                if not CheckTarget(target, true) then return end
            end
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
        {name = themeName, confirmed = #users > 0,
            target = UI.CaptureThemeDialogTarget(themeName)})
end
