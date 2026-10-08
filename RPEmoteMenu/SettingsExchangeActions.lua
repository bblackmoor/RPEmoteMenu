-- Import execution, confirmation targets, action state and result messages.
local _, addon = ...
local L = addon.L
local Database = addon.Database
local Serialization = addon.Serialization
local MAX_EMOTES = addon.MAX_EMOTES
local Actions = {}
addon.ExchangeActions = Actions

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

function Actions.Install(dialog)
    local editBox = dialog.editBox
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
                SetStatus(L.UI_THE_PROFILE_OR_CATEGORY_CHANGED_REOPEN_IMPORT_BEFORE_REPLACING_CONTENT, true)
            end
        else
            actionButton:SetEnabled(true)
        end
    end

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
                SetStatus(L.UI_THE_PROFILE_OR_CATEGORY_CHANGED_REOPEN_IMPORT_BEFORE_REPLACING_CONTENT, true)
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

            local message = string.format(L.UI_IMPORTED_PROFILE_S_AS_S, sourceProfileName, result)
            if detail then
                message = string.format(L.UI_IMPORTED_PROFILE_MISSING_THEME, sourceProfileName, result, detail)
            end
            SetStatus(message)
        elseif dataType == "theme" then
            if dialog.onThemeImported then
                dialog.onThemeImported(result)
            end
            SetStatus(string.format(L.UI_IMPORTED_THEME_S_AS_S, sourceProfileName, result))
        elseif dataType == "category" then
            SetStatus(string.format(L.UI_IMPORTED_CATEGORY_S, result))
        else
            SetStatus(string.format(L.UI_ADDED_S_PROFILES_AND_S_THEMES, result, detail))
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_IMPORT_OVER_CATEGORY"] = {
        text = L.UI_REPLACE_S_AND_ALL_OF_ITS_EMOTES_WITH_THE_IMPORTED,
        button1 = L.UI_REPLACE,
        button2 = CANCEL or L.UI_CANCEL,
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
            SetStatus(L.UI_PRESS_CTRL_C_TO_COPY_THE_SELECTED_TEXT)
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
                string.format(L.UI_CATEGORY_S, dialog.categoryIndex),
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

    dialog.SetStatus = SetStatus
end

