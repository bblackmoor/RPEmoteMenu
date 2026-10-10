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
    local model, selected, session = nil, nil, nil
    local orLabel = Widgets.CreateDialogLabel(picker.frame, L.PICKER_OR, 12)
    orLabel:SetJustifyH("CENTER")
    orLabel:SetJustifyV("MIDDLE")
    local selector
    local scroll, content = Widgets.CreateCanvasScrollBox(picker.frame, {step = 20})
    local preview = Widgets.CreateDialogLabel(content, "", 12)
    preview:SetJustifyH("LEFT")
    preview:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    picker.Preview, picker.PreviewScroll = preview, scroll

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
        else preview:SetText("") end
        scroll:SetVerticalScroll(0)
        dialog:RefreshLayout()
    end
    selector = Widgets.CreateDropdown(picker.frame, function()
        local choices = {}
        for _, entry in ipairs(model and model:GetChoices() or {}) do
            choices[#choices + 1] = {label = entry.command, value = entry.value}
        end
        return choices
    end, function(value)
        if not session or not model then return end
        local entry = model:Resolve(value)
        if not entry then return end
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
        local available = model ~= nil and model.count > 0
        orLabel:SetShown(available)
        selector:GetFrame():SetShown(available)
        dialog.NameBox:SetWidth(available and 240 or width)
        local offset = 24 + 6
        if available then
            local orWidth = 40
            local labelHeight = Widgets.MeasureDialogLabel(orLabel, orWidth)
            local rowHeight = math.max(24, labelHeight)
            orLabel:SetHeight(rowHeight)
            orLabel:ClearAllPoints()
            orLabel:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 252, 0)
            selector:ClearAllPoints()
            selector:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 304, 0)
            selector:SetWidth(width - 304)
            offset = rowHeight + 6
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
        return y + offset + 8
    end
    function picker:Open()
        session, selected = {}, nil
        model, self.state = Catalog.GetForClient({clientBuild = ClientBuild()})
        selector:InvalidateOptions()
        selector:SetValue(nil, L.PICKER_CHOOSE)
        selector:SetEnabled(model ~= nil and model.count > 0)
        self.frame:Show()
        SetPreview()
    end
    function picker:Close()
        session, selected, model = nil, nil, nil
        selector:InvalidateOptions(); selector:SetEnabled(false)
        preview:SetText("")
        self.frame:Hide()
    end
    return picker
end

