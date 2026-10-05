-- Details Framework boundary for converted settings pages.
-- Switch/menu/button templates and wrapper boundary adapted from SimpleNameplates
-- commit 044722657498da26ecbc74c05bfe7cd70ab5b8bc; editing/picker policy is ours.
-- Construction is lazy. Existing pages keep their native controls in Phase 2.
local _, addon = ...
local UI = addon.SettingsUI
local Widgets = {}
addon.SettingsWidgets = Widgets

local WHITE = "Interface\\Buttons\\WHITE8X8"
local backdrop = {bgFile = WHITE, edgeFile = WHITE, edgeSize = 1}
local buttonTemplate = {
    backdrop = backdrop, backdropcolor = {0.22, 0.22, 0.23, 1},
    backdropbordercolor = {0.45, 0.45, 0.46, 1},
    onentercolor = {0.32, 0.32, 0.33, 1}, textsize = 12,
}
local swatchTemplate = {
    backdrop = backdrop, backdropcolor = {0.04, 0.04, 0.04, 1},
    backdropbordercolor = {0.45, 0.45, 0.45, 1},
    onentercolor = {0.04, 0.04, 0.04, 1},
    onleavecolor = {0.04, 0.04, 0.04, 1},
    onenterbordercolor = {1, 1, 1, 1},
    onleavebordercolor = {0.45, 0.45, 0.45, 1},
}
local switchTemplate = {
    width = 44, height = 20,
    backdrop = backdrop, is_toggle = true, toggle_knob_padding = 2,
    enabled_backdropcolor = {0.19, 0.42, 0.31, 1},
    disabled_backdropcolor = {0.25, 0.25, 0.26, 1},
    toggle_knob_color_on = {0.72, 0.72, 0.73, 1},
    toggle_knob_color_off = {0.72, 0.72, 0.73, 1},
}
local dropdownTemplate = {
    backdrop = backdrop, backdropcolor = {0.22, 0.22, 0.23, 1},
    backdropbordercolor = {0.45, 0.45, 0.46, 1},
    dropicon = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
    dropiconsize = {16, 16},
}
local requiredMethods = {"CreateSwitch", "CreateDropDown",
    "CreateButton", "CreateColorPickButton", "CreateTextEntry"}

-- Resolve at construction time: another embedder can upgrade the same LibStub
-- table after this file loads. Converted pages require a compatible library.
function Widgets.GetFramework()
    local framework = LibStub and LibStub:GetLibrary("DetailsFramework-1.0", true)
    if not framework then return nil, "Details Framework is unavailable" end
    for _, method in ipairs(requiredMethods) do
        if type(framework[method]) ~= "function" then
            return nil, "Details Framework is missing " .. method
        end
    end
    return framework
end

local function Framework()
    local framework, reason = Widgets.GetFramework()
    assert(framework, reason)
    return framework
end

function Widgets.GetFrame(control)
    if not control then return nil end
    if control.frame then return control.frame end
    if control.GetUIObject then return control:GetUIObject() end
    return control.widget or control
end

local Handle = {}
Handle.__index = Handle
function Handle:GetFrame() return self.frame end
function Handle:SetPoint(point, relative, relativePoint, x, y)
    self.frame:SetPoint(point, Widgets.GetFrame(relative), relativePoint, x or 0, y or 0)
end
function Handle:SetEnabled(enabled)
    if enabled ~= true and self.CancelEdit then self:CancelEdit() end
    self.enabled = enabled == true
    if self.enabled then self.widget:Enable() else self.widget:Disable() end
    -- Some DF Enable/Disable methods only set wrapper lockdown and alpha.
    if self.enabled then self.frame:Enable() else self.frame:Disable() end
    self.frame:SetAlpha(self.enabled and 1 or 0.5)
end

-- Restore the guard even when a widget method fails. Each handle has its own
-- depth so nested refreshes and refreshes of other controls stay independent.
function Handle:Refresh(method, ...)
    self.refreshDepth = self.refreshDepth + 1
    local ok, result = pcall(method, self.widget, ...)
    self.refreshDepth = self.refreshDepth - 1
    if not ok then error(result, 0) end
    return result
end
local function NewHandle(widget, onChanged)
    return setmetatable({widget = widget, frame = Widgets.GetFrame(widget),
        refreshDepth = 0, enabled = true, onChanged = onChanged}, Handle)
end
local function Notify(handle, ...)
    if handle.enabled and handle.refreshDepth == 0 and handle.onChanged then
        handle.onChanged(...)
    end
end

function Widgets.CreateSwitch(parent, onChanged)
    local handle
    local widget = Framework():CreateSwitch(Widgets.GetFrame(parent),
        function(_, _, value) if handle then Notify(handle, value == true) end end,
        false, 44, 20, nil, nil, nil, nil, nil, nil, nil, nil, switchTemplate)
    handle = NewHandle(widget, onChanged)
    function handle:SetChecked(value) self:Refresh(self.widget.SetValue, value == true) end
    function handle:GetChecked() return self.widget:GetValue() == true end
    return handle
end

function Widgets.CreateDropdown(parent, optionsFunction, onChanged)
    local handle, cached
    local function Options()
        if not cached then
            cached = {}
            for _, option in ipairs(optionsFunction()) do
                local entry = {label = option.label, value = option.value, font = option.font}
                entry.onclick = function(_, _, value) Notify(handle, value) end
                cached[#cached + 1] = entry
            end
        end
        return cached
    end
    local widget = Framework():CreateDropDown(Widgets.GetFrame(parent), Options,
        false, 190, 20, nil, nil, dropdownTemplate)
    -- DF reskins this nested scroll thumb with Details' icons2 texture.
    local thumb = widget.scroll.thumb
    thumb:SetTexture(WHITE)
    thumb:SetTexCoord(0, 1, 0, 1)
    handle = NewHandle(widget, onChanged)
    function handle:InvalidateOptions() cached = nil end
    function handle:SetValue(value, label)
        self.value = value
        if label then
            -- Font labels can refresh while choices are dirty. Selected updates
            -- the DF selection/label directly, without evaluating the provider.
            self:Refresh(self.widget.Selected, {value = value, label = label})
        else
            self:Refresh(self.widget.Select, value, false, false, false)
        end
    end
    function handle:GetValue() return self.value end
    function handle:SetLabel(text) self.widget.label:SetText(text) end
    local notify = onChanged
    handle.onChanged = function(value)
        handle.value = value
        if notify then notify(value) end
    end
    return handle
end

function Widgets.CreateButton(parent, text, onClick, width, height)
    local handle
    local widget = Framework():CreateButton(Widgets.GetFrame(parent),
        function() Notify(handle) end, width or 190, height or 24, text,
        nil, nil, nil, nil, nil, nil, buttonTemplate)
    handle = NewHandle(widget, onClick)
    return handle
end

function Widgets.CreateLink(parent, text, onClick)
    local handle
    local transparent = {0, 0, 0, 0}
    local template = {backdrop = backdrop, backdropcolor = transparent,
        backdropbordercolor = transparent, onentercolor = transparent,
        onleavecolor = transparent, onenterbordercolor = transparent,
        onleavebordercolor = transparent, textsize = 11, textcolor = {0.35, 0.7, 1, 1}}
    local widget = Framework():CreateButton(Widgets.GetFrame(parent),
        function() Notify(handle) end, 190, 16, text,
        nil, nil, nil, nil, nil, nil, template)
    handle = NewHandle(widget, onClick)
    widget.widget.text:SetFontObject("GameFontHighlightSmall")
    widget.widget.text:SetTextColor(0.35, 0.7, 1, 1)
    widget.widget:SetWidth(widget.widget.text:GetStringWidth())
    widget.widget:HookScript("OnEnter", function() widget.widget.text:SetTextColor(0.65, 0.85, 1, 1) end)
    widget.widget:HookScript("OnLeave", function() widget.widget.text:SetTextColor(0.35, 0.7, 1, 1) end)
    return handle
end

-- Native-frame operations stay explicit at the wrapper boundary.
function Handle:Enable() self:SetEnabled(true) end
function Handle:Disable() self:SetEnabled(false) end
function Handle:ClearFocus() self.frame:ClearFocus() end
function Handle:SetSize(w, h) self.frame:SetSize(w, h) end
function Handle:SetWidth(w) self.frame:SetWidth(w) end
function Handle:SetHeight(h) self.frame:SetHeight(h) end
function Handle:SetAlpha(alpha) self.frame:SetAlpha(alpha) end
function Handle:SetShown(shown) self.frame:SetShown(shown) end
function Handle:HookScript(event, callback) self.frame:HookScript(event, callback) end

-- The swatch is a DF control; our existing RGB session owns picker behavior.
function Widgets.CreateColorPicker(parent, getColor, applyColor)
    local widget = Framework():CreateColorPickButton(Widgets.GetFrame(parent),
        nil, nil, function() end, nil, swatchTemplate)
    local handle = NewHandle(widget)
    handle.frame:SetSize(52, 24)
    widget.background_texture:Hide()
    widget.color_texture:ClearAllPoints()
    widget.color_texture:SetPoint("TOPLEFT", handle.frame, "TOPLEFT", 4, -4)
    widget.color_texture:SetPoint("BOTTOMRIGHT", handle.frame, "BOTTOMRIGHT", -4, 4)
    handle.Swatch = widget.color_texture
    function handle:SetColor(r, g, b) self:Refresh(self.widget.SetColor, r, g, b, 1) end
    function handle:RefreshValue()
        local color = getColor()
        self:SetColor(color.r, color.g, color.b)
    end
    function handle:CancelEdit() UI.CancelColorEdit(self.frame) end
    UI.InstallColorEditorOwner(handle.frame)
    widget:SetClickFunction(function()
        if not handle.enabled then return end
        UI.OpenColorEditor(handle.frame, getColor, function(color)
            applyColor(color)
            handle:RefreshValue()
        end)
    end)
    handle:RefreshValue()
    return handle
end

local textTemplate = {
    backdrop = backdrop, backdropcolor = {0.08, 0.08, 0.08, 1},
    backdropbordercolor = {0.5, 0.5, 0.5, 1}, textsize = 12,
}

-- DF's default handlers trim strings and skip some empty commits. Replace only
-- this instance's native editing scripts; never patch the shared library.
-- getOwner returns the Profile/Theme/content identity captured by page bindings.
function Widgets.CreateTextEntry(parent, getValue, applyValue, options)
    options = options or {}
    local widget = Framework():CreateTextEntry(Widgets.GetFrame(parent),
        function() end, options.width or 70, 24, nil, nil, nil, textTemplate)
    local handle = NewHandle(widget)
    local frame = handle.frame
    local dirty, owner
    local function CurrentOwner() return options.getOwner and options.getOwner() end
    -- Refresh uses the native frame rather than DF's text metamethod so an exact
    -- empty or whitespace-only value is never rewritten by framework policy.
    function handle:SetText(value)
        local text = tostring(value or "")
        dirty = false
        owner = CurrentOwner()
        frame:SetText(text)
        frame:SetCursorPosition(0)
    end
    function handle:GetText() return frame:GetText() end
    function handle:RefreshValue() self:SetText(getValue()) end
    function handle:CancelEdit()
        self:RefreshValue()
        frame:ClearFocus()
    end
    local function Commit()
        if not dirty then return end
        dirty = false
        if not handle.enabled or owner ~= CurrentOwner() then handle:RefreshValue(); return end
        local value = frame:GetText()
        if options.normalize then value = options.normalize(value) end
        if value == nil then handle:RefreshValue(); return end
        applyValue(value)
        handle:RefreshValue()
    end
    frame:SetAutoFocus(false)
    frame:SetFont(STANDARD_TEXT_FONT, 12, "")
    frame:SetTextColor(1, 1, 1, 1)
    if options.maxLetters then frame:SetMaxLetters(options.maxLetters) end
    frame:SetScript("OnEditFocusGained", function()
        if owner ~= CurrentOwner() then handle:RefreshValue() end
        owner = CurrentOwner()
    end)
    frame:HookScript("OnShow", function() handle:RefreshValue() end)
    frame:SetScript("OnTextChanged", function(_, byUser)
        if byUser and handle.enabled then dirty = true end
    end)
    frame:SetScript("OnEnterPressed", function() Commit(); frame:ClearFocus() end)
    frame:SetScript("OnEditFocusLost", function() Commit(); handle:RefreshValue() end)
    frame:SetScript("OnEscapePressed", function() handle:CancelEdit() end)
    frame:HookScript("OnHide", function() handle:CancelEdit() end)
    handle:RefreshValue()
    return handle
end

function Widgets.CreateIntegerEntry(parent, getValue, applyValue, options)
    options = options or {}
    local adapted = {}
    for key, value in pairs(options) do adapted[key] = value end
    local function Normalize(text)
        local value = tonumber(text)
        if not value or value ~= value or value == math.huge or value == -math.huge
            or (options.allowNegative and not text:match("^%-?%d+$")) then return end
        value = math.floor(value)
        if options.minimum then value = math.max(options.minimum, value) end
        if options.maximum then value = math.min(options.maximum, value) end
        return value
    end
    adapted.normalize = Normalize
    adapted.maxLetters = options.allowNegative and 7 or 6
    local handle = Widgets.CreateTextEntry(parent,
        function() return tostring(math.floor(tonumber(getValue()) or 0)) end,
        applyValue, adapted)
    handle.frame:SetNumeric(not options.allowNegative)
    handle.frame:EnableMouseWheel(true)
    handle.frame:SetScript("OnMouseWheel", function(_, delta)
        if not handle.enabled or delta == 0 then return end
        local value = math.floor(tonumber(getValue()) or 0) + (delta > 0 and 1 or -1)
        value = Normalize(tostring(value))
        if value then applyValue(value) end
        handle:RefreshValue()
    end)
    return handle
end
