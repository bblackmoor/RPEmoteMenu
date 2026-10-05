local _, addon = ...
local UI = addon.SettingsUI
local Database = addon.Database
local MainWindow = addon.MainWindow
local Widgets = addon.SettingsWidgets
local MAX_EMOTES = addon.MAX_EMOTES
local EmoteHasContent = UI.EmoteHasContent

local function GetPopulatedEmotes(categoryIndex)
    local populated = {}
    local category = Database.GetCategory(categoryIndex)

    for emoteIndex = 1, MAX_EMOTES do
        local emote = category and category.emotes[emoteIndex]
        if EmoteHasContent(emote) then
            populated[#populated + 1] = {
                emote = emote,
                index = emoteIndex
            }
        end
    end

    return populated
end

-- Fixed visual structure for the scrollable list.
local function CreateEmoteListLayout(panel, headingY, topY)
    local listHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, headingY)
    listHeading:SetText("Emotes in this category")

    local countText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", listHeading, "RIGHT", 10, 0)
    countText:SetTextColor(0.7, 0.7, 0.7, 1)

    local listScrollFrame, listContent = Widgets.CreateCanvasScrollBox(panel)
    listScrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, topY)
    listScrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -48, 18)
    listContent:SetSize(590, 1)

    local addButton = Widgets.CreateButton(listContent, "Add Emote", nil, 110, 24)

    local emptyText = listContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", listContent, "TOPLEFT", 10, -15)
    emptyText:SetText("No emotes yet. Use Add Emote below.")
    emptyText:SetTextColor(0.65, 0.65, 0.65, 1)

    return countText, listContent, addButton, emptyText
end

-- Dynamic rows, edit actions, and drag ordering are managed separately.
function UI.CreateEmoteList(panel, getSelectedCategoryIndex, headingY, topY)
    local countText, listContent, addButton, emptyText =
        CreateEmoteListLayout(panel, headingY, topY)
    local emoteRows = {}
    local draggedRow

    local function CancelRowDrag()
        if draggedRow then draggedRow:SetAlpha(1); draggedRow = nil end
    end
    panel:HookScript("OnHide", CancelRowDrag)

    local function RefreshEmoteRows()
        -- Pooled rows may now represent another category, Profile or record.
        CancelRowDrag()
        local populated = GetPopulatedEmotes(getSelectedCategoryIndex())
        local editable = Database.CanEditActiveProfile()

        countText:SetText("(" .. #populated .. " of " .. MAX_EMOTES .. ")")
        emptyText:SetShown(#populated == 0)
        addButton:SetEnabled(editable and #populated < MAX_EMOTES)
        local rowsHeight = #populated * 45
        local addButtonOffset = rowsHeight + (#populated == 0 and 38 or 6)
        addButton:ClearAllPoints()
        addButton:SetPoint("TOP", listContent, "TOP", 0, -addButtonOffset)
        listContent:SetHeight(math.max(addButtonOffset + 30, 68))

        for rowIndex, row in ipairs(emoteRows) do
            local entry = populated[rowIndex]
            if entry then
                local label = strtrim(entry.emote.label or "")
                row.emoteIndex = entry.index
                row.visiblePosition = rowIndex
                row.Label:SetText(label ~= "" and label or "Unnamed emote")

                local summary = entry.emote.defaultCommand or ""
                if strtrim(entry.emote.targetedCommand or "") ~= "" then
                    summary = summary .. "  |  " .. entry.emote.targetedCommand
                end
                row.Summary:SetText(summary)
                row.EditButton:SetText(editable and "Edit" or "View")
                row.DuplicateButton:SetEnabled(editable and #populated < MAX_EMOTES)
                row.DeleteButton:SetEnabled(editable)
                row:Show()
            else
                row.emoteIndex = nil
                row.visiblePosition = nil
                row:Hide()
            end
        end
    end

    local function DeleteEmote(data)
        if not Database.CanEditActiveProfile() then
            return
        end

        if not Database.IsCurrentContentTarget(data and data.target) then
            print("RP Emote Menu: The Profile or emote changed. Reopen the delete confirmation.")
            return
        end
        local category = Database.GetCategory(data.categoryIndex)
        category.emotes[data.emoteIndex] = {
            label = "",
            defaultCommand = "",
            targetedCommand = ""
        }
        MainWindow.UpdateMenu()
        RefreshEmoteRows()
    end

    StaticPopupDialogs["RPEMOTEMENU_DELETE_EMOTE"] = {
        text = "Delete the emote %s?\n\nThis cannot be undone.",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            DeleteEmote(data)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    local function FinishRowDrag(row)
        if draggedRow ~= row then
            return
        end

        row:SetAlpha(1)
        local targetPosition
        for _, candidate in ipairs(emoteRows) do
            if candidate:IsShown() and candidate:IsMouseOver() then
                targetPosition = candidate.visiblePosition
                break
            end
        end

        local sourcePosition = row.visiblePosition
        draggedRow = nil
        if not Database.CanEditActiveProfile()
            or not targetPosition or not sourcePosition or targetPosition == sourcePosition then
            return
        end

        local category = Database.GetCategory(getSelectedCategoryIndex())
        local populated = GetPopulatedEmotes(getSelectedCategoryIndex())
        local records = {}
        for _, entry in ipairs(populated) do
            records[#records + 1] = entry.emote
        end

        local moved = table.remove(records, sourcePosition)
        table.insert(records, targetPosition, moved)
        for index = 1, MAX_EMOTES do
            category.emotes[index] = records[index] or {
                label = "",
                defaultCommand = "",
                targetedCommand = ""
            }
        end

        MainWindow.UpdateMenu()
        RefreshEmoteRows()
    end

    local function CreateEmoteRow(rowIndex)
        local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        row:SetSize(590, 42)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -((rowIndex - 1) * 45))
        row:SetBackdrop({bgFile = "Interface\\ChatFrame\\ChatFrameBackground"})
        row:SetBackdropColor(0.08, 0.08, 0.08, rowIndex % 2 == 0 and 0.5 or 0.3)
        row:RegisterForDrag("LeftButton")

        local dragHandle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dragHandle:SetPoint("LEFT", row, "LEFT", 8, 0)
        dragHandle:SetText("::")
        dragHandle:SetTextColor(0.55, 0.55, 0.55, 1)

        row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", 28, -5)
        row.Label:SetPoint("RIGHT", row, "RIGHT", -220, 0)
        row.Label:SetJustifyH("LEFT")
        row.Label:SetWordWrap(false)

        row.Summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Summary:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 28, 5)
        row.Summary:SetPoint("RIGHT", row, "RIGHT", -220, 0)
        row.Summary:SetJustifyH("LEFT")
        row.Summary:SetWordWrap(false)
        row.Summary:SetTextColor(0.7, 0.7, 0.7, 1)

        row.EditButton = Widgets.CreateButton(row, "Edit", nil, 52, 22)
        row.EditButton:SetPoint("RIGHT", row, "RIGHT", -154, 0)
        row.DuplicateButton = Widgets.CreateButton(row, "Duplicate", nil, 76, 22)
        row.DuplicateButton:SetPoint("RIGHT", row, "RIGHT", -73, 0)
        row.DeleteButton = Widgets.CreateButton(row, "Delete", nil, 62, 22)
        row.DeleteButton:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row:Hide()
        return row
    end

    -- Editing and drag behavior is wired after the row's visual structure exists.
    local function WireEmoteRow(row)
        row.EditButton.onChanged = function()
            if row.emoteIndex then
                MainWindow.OpenEmoteEditor(getSelectedCategoryIndex(), row.emoteIndex)
            end
        end

        row.DuplicateButton.onChanged = function()
            if row.emoteIndex then
                local success = Database.DuplicateEmote(
                    getSelectedCategoryIndex(),
                    row.emoteIndex
                )
                if success then
                    MainWindow.UpdateMenu()
                    RefreshEmoteRows()
                end
            end
        end

        row.DeleteButton.onChanged = function()
            if row.emoteIndex then
                StaticPopup_Show(
                    "RPEMOTEMENU_DELETE_EMOTE",
                    row.Label:GetText() or "this emote",
                    nil,
                    {
                        categoryIndex = getSelectedCategoryIndex(),
                        emoteIndex = row.emoteIndex,
                        target = Database.CaptureContentTarget(
                            getSelectedCategoryIndex(), row.emoteIndex)
                    }
                )
            end
        end

        row:SetScript("OnDragStart", function(self)
            if Database.CanEditActiveProfile() and self.emoteIndex then
                draggedRow = self
                self:SetAlpha(0.45)
            end
        end)
        row:SetScript("OnDragStop", FinishRowDrag)
    end

    for rowIndex = 1, MAX_EMOTES do
        emoteRows[rowIndex] = CreateEmoteRow(rowIndex)
        WireEmoteRow(emoteRows[rowIndex])
    end

    addButton.onChanged = function()
        if not Database.CanEditActiveProfile() then
            return
        end

        local category = Database.GetCategory(getSelectedCategoryIndex())
        for emoteIndex = 1, MAX_EMOTES do
            if not EmoteHasContent(category.emotes[emoteIndex]) then
                MainWindow.OpenEmoteEditor(getSelectedCategoryIndex(), emoteIndex, true)
                return
            end
        end
    end

    return RefreshEmoteRows
end

