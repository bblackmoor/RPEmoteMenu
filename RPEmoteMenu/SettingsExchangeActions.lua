-- Import execution, confirmation targets, action state and result messages.
local _, addon = ...
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
                SetStatus("The Profile or category changed. Reopen Import before replacing content.", true)
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
                SetStatus("The Profile or category changed. Reopen Import before replacing content.", true)
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

            local message = "Imported profile " .. sourceProfileName
                .. " as " .. result .. "."
            if detail then
                message = message .. " Theme " .. detail
                    .. " was unavailable; assigned Default Theme."
            end
            SetStatus(message)
        elseif dataType == "theme" then
            if dialog.onThemeImported then
                dialog.onThemeImported(result)
            end
            SetStatus("Imported Theme " .. sourceProfileName .. " as " .. result .. ".")
        elseif dataType == "category" then
            SetStatus("Imported category " .. result .. ".")
        else
            SetStatus("Added " .. result .. " Profiles and "
                .. detail .. " Themes.")
        end
    end

    StaticPopupDialogs["RPEMOTEMENU_IMPORT_OVER_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the imported category?\n\nThis cannot be undone.",
        button1 = "Replace",
        button2 = CANCEL or "Cancel",
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
            SetStatus("Press Ctrl+C to copy the selected text.")
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
                "Category " .. dialog.categoryIndex,
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
