local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local MainWindow = addon.MainWindow
local AddonSettings = addon.Settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local FIELD_GAP = UI.FIELD_GAP
local Widgets = addon.SettingsWidgets
local GetExchangeDialog = UI.GetExchangeDialog
local resetAllCategoriesButton

local function EmoteHasContent(emote)
    return emote and (strtrim(emote.label or "") ~= ""
        or strtrim(emote.defaultCommand or "") ~= ""
        or strtrim(emote.targetedCommand or "") ~= "")
end

UI.EmoteHasContent = EmoteHasContent

local function HasEmptyCategorySlot(selectedCategoryIndex)
    for categoryIndex = 1, MAX_CATEGORIES do
        if categoryIndex ~= selectedCategoryIndex then
            local category = Database.GetCategory(categoryIndex)
            local empty = category and strtrim(category.name or "") == ""

            for emoteIndex = 1, MAX_EMOTES do
                if empty and EmoteHasContent(category.emotes[emoteIndex]) then
                    empty = false
                end
            end

            if empty then
                return true
            end
        end
    end

    return false
end

local function CreateCategoriesSettingsPanel()
    local settings = Database.GetSettings()
    local panel = CreateFrame("Frame")
    local rows = UI.CreateRows(panel, 16, -16, 32)
    local headingY = rows:Next()
    local selectorY = rows:Next(34)
    local exchangeY = rows:Next()
    local actionsY = rows:Next(40)
    local noteY = rows:Next(76)
    local nameY = rows:Next(39)
    local listHeadingY = rows:Next(30)
    local listTopY = rows:Next()
    local selectedCategoryIndex = settings.selectedCategory

    if type(selectedCategoryIndex) ~= "number"
        or selectedCategoryIndex < 1
        or selectedCategoryIndex > MAX_CATEGORIES then
        selectedCategoryIndex = 1
    end

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, headingY)
    heading:SetText("Emotes")

    local SelectCategory
    local function GetCategoryLabel(categoryIndex)
        local category = Database.GetCategory(categoryIndex)
        local categoryName = strtrim(category and category.name or "")
        local label = "Category " .. categoryIndex

        if categoryName ~= "" then
            label = label .. ": " .. categoryName
        end

        return label
    end

    local selector = Widgets.CreateDropdown(panel, function()
        local options = {}
        for index = 1, MAX_CATEGORIES do
            options[#options + 1] = {label = GetCategoryLabel(index), value = index}
        end
        return options
    end, function(index) SelectCategory(index) end)
    selector:SetWidth(300)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, selectorY)

    local resetButton = Widgets.CreateButton(panel, "Restore Built-in Category", function()
        StaticPopup_Show(
            "RPEMOTEMENU_RESTORE_CATEGORY",
            "Category " .. selectedCategoryIndex,
            nil,
            {categoryIndex = selectedCategoryIndex,
                target = Database.CaptureContentTarget(selectedCategoryIndex)}
        )
    end, 190, 24)

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the built-in category?\n\nThis cannot be undone.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            if Database.IsCurrentContentTarget(data and data.target) then
                Database.ResetCategoryToDefaults(data.categoryIndex)
            else
                print("RP Emote Menu: The Profile or category changed. Reopen the restore confirmation.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_ALL_CATEGORIES"] = {
        text = "Replace every category and emote in the current profile with the built-in set?\n\nThis cannot be undone.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            if not Database.IsCurrentContentTarget(data and data.target) then
                print("RP Emote Menu: The Profile or categories changed. Reopen the restore confirmation.")
                return
            end
            if Database.ResetAllCategoriesToDefaults() then
                print("RP Emote Menu: Restored all built-in categories and emotes.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    resetAllCategoriesButton = Widgets.CreateButton(panel,
        "Restore All Built-in Categories", function()
            StaticPopup_Show("RPEMOTEMENU_RESTORE_ALL_CATEGORIES", nil, nil,
                {target = Database.CaptureContentTarget()})
        end, 240, 24)
    resetAllCategoriesButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 188, actionsY)

    local duplicateCategoryButton = Widgets.CreateButton(panel,
        "Duplicate Category", function()
            local success, result = Database.DuplicateCategory(selectedCategoryIndex)
            if success then
                SelectCategory(result)
                MainWindow.SetSelectedCategory(result)
                MainWindow.UpdateMenu()
            end
        end, 160, 24)
    duplicateCategoryButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, actionsY)

    local importButton = Widgets.CreateButton(panel, "Import", function()
        GetExchangeDialog():OpenImport(selectedCategoryIndex)
    end, 90, 24)
    local exportButton = Widgets.CreateButton(panel, "Export", function()
        GetExchangeDialog():OpenExport(selectedCategoryIndex)
    end, 90, 24)
    exportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, exchangeY)

    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    resetButton:SetPoint("LEFT", selector, "RIGHT", FIELD_GAP, 0)

    local placeholderText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    placeholderText:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, noteY)
    placeholderText:SetWidth(630)
    placeholderText:SetJustifyH("LEFT")
    placeholderText:SetText(
        "Named categories appear in the sidebar; blank categories stay hidden.\n" ..
        "{target} - Target's name without the realm.\n" ..
        "{player} - Current character's name without the realm.\n" ..
        "Targeted Command is used only when another unit is targeted.\n" ..
        "Drag an emote row to reorder it. Import replaces this category."
    )
    placeholderText:SetTextColor(0.8, 0.8, 0.8)

    local nameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, nameY - 5)
    nameLabel:SetWidth(180)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText("Category Name")
    local nameBox = Widgets.CreateTextEntry(panel, function()
        return Database.GetCategory(selectedCategoryIndex).name or ""
    end, function(value)
        if not Database.CanEditActiveProfile() then return end
        Database.GetCategory(selectedCategoryIndex).name = value
        MainWindow.UpdateMenu()
        if AddonSettings.RefreshCategorySelector then
            AddonSettings.RefreshCategorySelector()
        end
    end, {width = 420, refreshAfterShow = true,
        getOwner = function() return Database.GetCategory(selectedCategoryIndex) end})
    nameBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + 180 + FIELD_GAP, nameY)
    local RefreshEmoteRows = UI.CreateEmoteList(panel, function()
        return selectedCategoryIndex
    end, listHeadingY, listTopY)

    local function RefreshCategorySelector()
        selector:InvalidateOptions()
        selector:SetValue(selectedCategoryIndex, GetCategoryLabel(selectedCategoryIndex))
    end

    SelectCategory = function(categoryIndex)
        if type(categoryIndex) ~= "number"
            or categoryIndex < 1
            or categoryIndex > MAX_CATEGORIES then
            return
        end

        selectedCategoryIndex = categoryIndex

        panel.RefreshEditors()
    end

    panel.RefreshEditors = function(changedCategoryIndex)
        if changedCategoryIndex
            and changedCategoryIndex ~= selectedCategoryIndex then
            return
        end

        local editable = Database.CanEditActiveProfile()
        resetButton:SetEnabled(editable)
        resetAllCategoriesButton:SetEnabled(editable)
        importButton:SetEnabled(editable)
        duplicateCategoryButton:SetEnabled(editable and HasEmptyCategorySlot(selectedCategoryIndex))

        nameBox:SetEnabled(editable)
        nameBox:RefreshValue()
        nameBox:GetFrame():HighlightText(0, 0)
        RefreshEmoteRows()

        RefreshCategorySelector()
    end

    panel:SetScript("OnShow", function(self)
        self.RefreshEditors()
    end)

    panel:HookScript("OnHide", function() nameBox:CancelEdit() end)

    panel.categorySelector = selector
    panel.SelectCategory = SelectCategory
    panel.GetSelectedCategory = function()
        return selectedCategoryIndex
    end
    AddonSettings.RefreshCategorySelector = RefreshCategorySelector

    panel.RefreshEditors()

    return panel
end


UI.CreateCategoriesSettingsPanel = CreateCategoriesSettingsPanel

