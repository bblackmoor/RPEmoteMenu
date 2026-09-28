local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local MainWindow = addon.MainWindow
local AddonSettings = addon.Settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local FIELD_GAP = UI.FIELD_GAP
local CreateLabeledEditBox = UI.CreateLabeledEditBox
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

    local selector = CreateFrame(
        "DropdownButton",
        nil,
        panel,
        "WowStyle1DropdownTemplate"
    )
    selector:SetWidth(300)
    selector:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, selectorY)

    local function GetCategoryLabel(categoryIndex)
        local category = Database.GetCategory(categoryIndex)
        local categoryName = strtrim(category and category.name or "")
        local label = "Category " .. categoryIndex

        if categoryName ~= "" then
            label = label .. ": " .. categoryName
        end

        return label
    end

    selector:SetDefaultText(GetCategoryLabel(selectedCategoryIndex))

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(190, 24)
    resetButton:SetText("Restore Built-in Category")
    resetButton:SetEnabled(Database.CanEditActiveProfile())
    resetButton:SetScript("OnClick", function()
        StaticPopup_Show(
            "RPEMOTEMENU_RESTORE_CATEGORY",
            "Category " .. selectedCategoryIndex,
            nil,
            {categoryIndex = selectedCategoryIndex}
        )
    end)

    StaticPopupDialogs["RPEMOTEMENU_RESTORE_CATEGORY"] = {
        text = "Replace %s and all of its emotes with the built-in category?\n\nThis cannot be undone.",
        button1 = "Restore",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            Database.ResetCategoryToDefaults(data.categoryIndex)
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
        OnAccept = function()
            if Database.ResetAllCategoriesToDefaults() then
                print("RP Emote Menu: Restored all built-in categories and emotes.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    resetAllCategoriesButton = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )
    resetAllCategoriesButton:SetSize(240, 24)
    resetAllCategoriesButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 188, actionsY)
    resetAllCategoriesButton:SetText("Restore All Built-in Categories")
    resetAllCategoriesButton:SetEnabled(Database.CanEditActiveProfile())
    resetAllCategoriesButton:SetScript("OnClick", function()
        StaticPopup_Show("RPEMOTEMENU_RESTORE_ALL_CATEGORIES")
    end)

    local duplicateCategoryButton = CreateFrame(
        "Button",
        nil,
        panel,
        "UIPanelButtonTemplate"
    )
    duplicateCategoryButton:SetSize(160, 24)
    duplicateCategoryButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, actionsY)
    duplicateCategoryButton:SetText("Duplicate Category")

    local importButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    importButton:SetSize(90, 24)
    importButton:SetText("Import")
    importButton:SetEnabled(Database.CanEditActiveProfile())
    importButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenImport(selectedCategoryIndex)
    end)

    local exportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    exportButton:SetSize(90, 24)
    exportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, exchangeY)
    exportButton:SetText("Export")
    exportButton:SetScript("OnClick", function()
        GetExchangeDialog():OpenExport(selectedCategoryIndex)
    end)

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

    local nameBox = CreateLabeledEditBox(
        panel,
        "Category Name",
        16,
        nameY,
        420,
        selectedCategoryIndex,
        nil,
        "name"
    )
    local RefreshEmoteRows = UI.CreateEmoteList(panel, function()
        return selectedCategoryIndex
    end, listHeadingY, listTopY)

    local function RefreshCategorySelector()
        selector:OverrideText(GetCategoryLabel(selectedCategoryIndex))
    end

    local function SelectCategory(categoryIndex)
        if type(categoryIndex) ~= "number"
            or categoryIndex < 1
            or categoryIndex > MAX_CATEGORIES then
            return
        end

        selectedCategoryIndex = categoryIndex

        nameBox.categoryIndex = categoryIndex
        panel.RefreshEditors()
    end

    duplicateCategoryButton:SetScript("OnClick", function()
        local success, result = Database.DuplicateCategory(selectedCategoryIndex)
        if success then
            SelectCategory(result)
            MainWindow.SetSelectedCategory(result)
            MainWindow.UpdateMenu()
        end
    end)

    selector:SetupMenu(function(_, rootDescription)
        for categoryIndex = 1, MAX_CATEGORIES do
            rootDescription:CreateRadio(
                GetCategoryLabel(categoryIndex),
                function()
                    return selectedCategoryIndex == categoryIndex
                end,
                function()
                    SelectCategory(categoryIndex)
                end
            )
        end
    end)

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

        nameBox:RefreshFromDatabase()
        RefreshEmoteRows()

        RefreshCategorySelector()
    end

    panel:SetScript("OnShow", function(self)
        self.RefreshEditors()
    end)

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
