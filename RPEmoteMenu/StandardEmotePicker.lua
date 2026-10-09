-- Optional reference selection owns draft insertion; the editor still owns Save.
local _, addon = ...
local L = addon.L
local Picker = {}
addon.StandardEmotePicker = Picker

local function ClientBuild()
    if type(GetBuildInfo) ~= "function" then return nil end
    local _, build = GetBuildInfo()
    if type(build) == "string" or type(build) == "number" then return tostring(build) end
end

function Picker.Install(dialog, Widgets)
    local Catalog, Database = addon.StandardEmoteCatalog, addon.Database
    local picker = {frame = CreateFrame("Frame", nil, dialog)}
    local model, selected, session, filter = nil, nil, nil, ""
    local refreshing = false
    local title = Widgets.CreateDialogLabel(picker.frame, L.PICKER_TITLE, 12)
    local filterLabel = Widgets.CreateDialogLabel(picker.frame, L.PICKER_FILTER, 12)
    local filterBox = Widgets.CreateDialogTextEntry(picker.frame, 430, 24)
    filterBox:SetAutoFocus(false)
    filterBox:SetMaxBytes(128)
    local selector
    local scroll, content = Widgets.CreateCanvasScrollBox(picker.frame, {step = 20})
    local preview = Widgets.CreateDialogLabel(content, "", 12)
    preview:SetJustifyH("LEFT")
    preview:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    picker.FilterBox, picker.Preview, picker.PreviewScroll = filterBox, preview, scroll

    local function ShowStatus(text)
        dialog.Status:SetText(text)
        dialog.Status:SetTextColor(1, 0.35, 0.35, 1)
        dialog:RefreshLayout()
    end
    local function CurrentEntry()
        if not session or not selected or not model then return end
        return model:Resolve(selected)
    end
    local function FreshEntry()
        local current = Catalog.GetForClient({clientBuild = ClientBuild()})
        return current and selected and current:Resolve(selected)
    end
    local function CanInsert(entry)
        return session ~= nil and dialog:IsShown() and entry and entry.selectable
            and Database.CanEditActiveProfile()
            and Database.IsCurrentContentTarget(dialog.contentTarget)
    end
    local function SetPreview()
        local entry = CurrentEntry()
        if entry then
            local note = L.PICKER_REFERENCE_NOTE
            if entry.supportStatus == "unverified" then note = L.PICKER_UNVERIFIED
            elseif entry.supportStatus == "unsupported" then note = L.PICKER_UNSUPPORTED end
            preview:SetText(string.format(L.PICKER_PREVIEW, entry.defaultPreview, entry.targetedPreview, note))
        elseif not model then
            preview:SetText(picker.state == "invalid" and L.PICKER_INVALID or L.PICKER_UNAVAILABLE)
        elseif model.count == 0 then preview:SetText(L.PICKER_EMPTY)
        elseif #model:GetChoices(filter) == 0 then preview:SetText(L.PICKER_NO_RESULTS)
        else preview:SetText("") end
        scroll:SetVerticalScroll(0)
        dialog:RefreshLayout()
    end
    selector = Widgets.CreateDropdown(picker.frame, function()
        local choices = {}
        for _, entry in ipairs(model and model:GetChoices(filter) or {}) do
            choices[#choices + 1] = {label = entry.command, value = entry.value}
        end
        return choices
    end, function(value)
        if not session or not model then return end
        local entry = model:Resolve(value)
        local visible = false
        for _, choice in ipairs(model:GetChoices(filter)) do
            if choice.value == value then visible = true; break end
        end
        if not entry or not visible then return end
        selected = value
        selector:SetValue(value, entry.command)
        SetPreview()
        entry = FreshEntry()
        if not CanInsert(entry) then
            ShowStatus(Database.IsCurrentContentTarget(dialog.contentTarget)
                and L.PICKER_CANNOT_INSERT or L.EDITOR_TARGET_CHANGED)
            return
        end
        dialog.NameBox:SetText(entry.command)
        dialog.DefaultBox:SetText(entry.command)
        dialog.TargetedBox:SetText("")
        dialog.Status:SetText(L.PICKER_INSERTED)
        dialog.Status:SetTextColor(0.8, 0.8, 0.8, 1)
        dialog:RefreshLayout()
    end)
    selector:SetMenuSize(570, 240)
    picker.Selector = selector

    filterBox:SetScript("OnTextChanged", function()
        if refreshing or not session then return end
        filter = filterBox:GetText() or ""
        selected = nil
        selector:InvalidateOptions()
        selector:SetValue(nil, L.PICKER_CHOOSE)
        selector:SetEnabled(model ~= nil and #model:GetChoices(filter) > 0)
        SetPreview()
    end)
    filterBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Enter in the filter never saves the editor or executes the selection.
    filterBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Keep framework text-entry callbacks intact. Programmatic auto-fill and
    -- editor initialization do not count as manual changes.
    for _, box in ipairs({dialog.NameBox, dialog.DefaultBox, dialog.TargetedBox}) do
        box:HookScript("OnTextChanged", function(_, byUser)
            if not byUser or not session or not selected then return end
            selected = nil
            selector:InvalidateOptions()
            selector:SetValue(nil, L.PICKER_CHOOSE)
            dialog.Status:SetText(L.EDITOR_CHANGES_APPLY)
            dialog.Status:SetTextColor(0.8, 0.8, 0.8, 1)
            SetPreview()
        end)
    end

    function picker:Layout(y, width)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -y)
        self.frame:SetWidth(width)
        title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
        local offset = Widgets.MeasureDialogLabel(title, width) + 6
        local available = model ~= nil and model.count > 0
        filterLabel:SetShown(available); filterBox:SetShown(available)
        selector:GetFrame():SetShown(available)
        if available then
            local labelHeight = Widgets.MeasureDialogLabel(filterLabel, 120)
            filterLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offset)
            filterBox:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 132, -offset)
            filterBox:SetWidth(width - 132)
            offset = offset + math.max(24, labelHeight) + 6
            selector:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offset)
            selector:SetWidth(width)
            offset = offset + 24 + 6
        end
        local hasPreview = (preview:GetText() or "") ~= ""
        scroll:SetShown(hasPreview)
        if hasPreview then
            scroll:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offset)
            local previewHeight = Widgets.MeasureDialogLabel(preview, width - 34)
            scroll:SetSize(width, math.min(previewHeight, available and 72 or 40))
            content:SetSize(width - 34, math.max(previewHeight, scroll:GetHeight()))
            scroll:RefreshViewport()
            offset = offset + scroll:GetHeight() + 6
        end
        self.frame:SetHeight(offset)
        return y + offset + 6
    end
    function picker:Open()
        session, selected, filter = {}, nil, ""
        model, self.state = Catalog.GetForClient({clientBuild = ClientBuild()})
        refreshing = true; filterBox:SetText(""); refreshing = false
        selector:InvalidateOptions()
        selector:SetValue(nil, L.PICKER_CHOOSE)
        selector:SetEnabled(model ~= nil and model.count > 0)
        self.frame:Show()
        SetPreview()
    end
    function picker:Close()
        session, selected, model, filter = nil, nil, nil, ""
        selector:InvalidateOptions(); selector:SetEnabled(false)
        filterBox:ClearFocus()
        refreshing = true; filterBox:SetText(""); refreshing = false
        preview:SetText("")
        self.frame:Hide()
    end
    return picker
end

