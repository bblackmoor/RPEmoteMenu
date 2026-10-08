local _, addon = ...
local L = addon.L
local UI = addon.SettingsUI
local Database = addon.Database

function UI.CaptureThemeDialogTarget(name)
    return {name = name, object = Database.GetTheme(name)}
end

function UI.CaptureBundledThemeDialogTargets()
    local targets = {UI.CaptureThemeDialogTarget("Default")}
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
        SetStatus(L.UI_THE_THEME_CHANGED_REOPEN_THE_DIALOG_BEFORE_CONTINUING, true)
        return false
    end
    local function GetEditBox(popup)
        return popup.GetEditBox and popup:GetEditBox() or popup.editBox
    end
    local function GetAcceptButton(popup)
        return popup.GetButton1 and popup:GetButton1() or popup.button1
    end

    StaticPopupDialogs["RPEMOTEMENU_THEME_NAME"] = {
        text = L.UI_ENTER_A_THEME_NAME, button1 = L.UI_CREATE, button2 = CANCEL or L.UI_CANCEL,
        hasEditBox = true, maxLetters = addon.SettingDefinitions.nameLengths.theme, editBoxWidth = 260,
        OnShow = function(self, data)
            local box = GetEditBox(self)
            box:SetText(data.initial)
            box:SetFocus()
            box:HighlightText()
            GetAcceptButton(self):SetText(data.action == "rename" and L.UI_RENAME
                or data.action == "copy" and L.UI_COPY or L.UI_CREATE)
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
                SetStatus(string.format(L.UI_THEME_S_IS_READY, result))
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
        text = "%s", button1 = DELETE or L.UI_DELETE, button2 = CANCEL or L.UI_CANCEL,
        OnAccept = function(_, data)
            if not CheckTarget(data.target) then return end
            local users = Database.GetProfilesUsingTheme(data.name)
            if not data.profiles or #users ~= #data.profiles then
                SetStatus(L.UI_PROFILES_USING_THIS_THEME_CHANGED_REOPEN_THE_DELETION_DIALOG_TO, true)
                return
            end
            local confirmedProfiles = {}
            for _, target in ipairs(data.profiles) do
                confirmedProfiles[target.name] = target.object
            end
            for _, name in ipairs(users) do
                if confirmedProfiles[name] ~= Database.GetProfile(name) then
                    SetStatus(L.UI_PROFILES_USING_THIS_THEME_CHANGED_REOPEN_THE_DELETION_DIALOG_TO, true)
                    return
                end
            end
            local success, result = Database.DeleteTheme(data.name, data.confirmed)
            if success then
                SelectTheme(Database.GetActiveThemeName())
                SetStatus(string.format(L.UI_DELETED_S, data.name))
            else
                SetStatus(result, true)
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_THEME"] = {
        text = L.UI_RESTORE_S_TO_ITS_FACTORY_APPEARANCE_YOUR_EDITS_TO_THIS,
        button1 = L.UI_RESTORE, button2 = CANCEL or L.UI_CANCEL,
        OnAccept = function(_, target)
            if not CheckTarget(target) then return end
            local name = target.name
            local success, errorMessage = Database.RestoreTheme(name)
            SetStatus(success and (string.format(L.UI_RESTORED_S, name)) or errorMessage,
                not success)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_BUNDLED_THEMES"] = {
        text = L.UI_RESTORE_DEFAULT_THEME_AND_ALL_BUNDLED_THEMES_TO_FACTORY_APPEARANCE,
        button1 = L.UI_RESTORE, button2 = CANCEL or L.UI_CANCEL,
        OnAccept = function(_, targets)
            -- Check every slot before restoring any, including intentionally missing presets.
            if not targets then
                CheckTarget(nil)
                return
            end
            for _, target in ipairs(targets) do
                if not CheckTarget(target, true) then return end
            end
            local count, errorMessage = Database.RestoreBuiltInThemes()
            if not count then
                SetStatus(errorMessage, true)
                return
            end
            SetStatus(string.format(L.UI_RESTORED_S_THEMES_INCLUDING_DEFAULT, count))
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3
    }

end

function UI.ConfirmThemeDeletion(themeName)
    local users = Database.GetProfilesUsingTheme(themeName)
    local profiles = {}
    for _, name in ipairs(users) do
        profiles[#profiles + 1] = {name = name, object = Database.GetProfile(name)}
    end
    local message = string.format(L.UI_DELETE_THEME_S, themeName)
    if #users > 0 then
        message = string.format(L.UI_DELETE_USED_THEME, themeName, table.concat(users, ", "))
    end
    StaticPopup_Show("RPEMOTEMENU_DELETE_THEME", message, nil,
        {name = themeName, confirmed = #users > 0, profiles = profiles,
            target = UI.CaptureThemeDialogTarget(themeName)})
end

