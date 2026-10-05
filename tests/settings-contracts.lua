-- Identical contract checks in both repositories. Uses actual picker modules;
-- only native frame APIs and domain lookup are fixtures, not picker behavior.
local Contracts = {}
local function Copy(color) return {r = color.r, g = color.g, b = color.b} end
local function Same(a, b) assert(a.r == b.r and a.g == b.g and a.b == b.b, "RGB contract") end
local function Frame()
    local frame = {scripts = {}, shown = false}
    function frame:HookScript(name, callback)
        local previous = self.scripts[name]
        self.scripts[name] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function frame:Hide()
        local shown = self.shown
        self.shown = false
        if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    return frame
end
local function Picker(hideOnSetup)
    local picker = Frame()
    function picker:GetExtraInfo() return self.extraInfo end
    function picker:GetColorRGB() return self.rgb.r, self.rgb.g, self.rgb.b end
    function picker:SetupColorPickerAndShow(info)
        if hideOnSetup then self:Hide() end
        self.info, self.extraInfo, self.rgb = info, info.extraInfo, Copy(info)
        self.shown = true
        info.swatchFunc() -- Blizzard can emit its initial selection during setup.
    end
    return picker
end
local function Load(config)
    local state = {name = "Original", object = {}, color = {r = 0.1, g = 0.2, b = 0.3}, writes = 0}
    local addon = {SettingsUI = {}}
    if config.kind == "theme" then
        addon.Database = {
            GetActiveThemeName = function() return state.name end,
            GetThemeSettings = function(name) if not name or name == state.name then return state.object end end,
        }
    else
        addon.GetActiveProfileName = function() return state.name end
        addon.GetProfile = function(name) if name == state.name then return state.object end end
    end
    assert(loadfile(config.path))(config.name, addon)
    local UI = addon.SettingsUI
    local owner = Frame()
    owner.shown = true
    UI.InstallColorEditorOwner(owner)
    function state:Open()
        UI.OpenColorEditor(owner, function() return Copy(self.color) end, function(color)
            self.color = Copy(color); self.writes = self.writes + 1
        end)
        local info = ColorPickerFrame.info
        assert(info.extraInfo.owner == owner and info.extraInfo.target.name == self.name)
        assert(info.extraInfo.target.object == self.object and info.hasOpacity == false)
        return info
    end
    state.UI, state.owner = UI, owner
    return state
end
local function Preview(info, color)
    ColorPickerFrame.rgb = Copy(color)
    info.swatchFunc()
end
local sample = {r = 0.6, g = 0.7, b = 0.8}
function Contracts.PickerLifecycle(config)
    ColorPickerFrame = Picker(false)
    local state = Load(config)
    local original = Copy(state.color)
    local info = state:Open()
    assert(state.writes == 0, "opening and initial swatch selection are silent")
    Preview(info, sample); Same(state.color, sample)
    state.UI.CancelColorEdit({})
    assert(ColorPickerFrame.shown, "another owner cannot cancel the session")
    state.UI.CancelColorEdit(state.owner); Same(state.color, original)
    assert(not ColorPickerFrame.shown)
    local count = state.writes
    Preview(info, sample); info.cancelFunc()
    assert(state.writes == count, "retired callbacks are inert")
    info = state:Open(); Preview(info, sample)
    ColorPickerFrame:Hide(); Same(state.color, sample)
    count = state.writes; info.cancelFunc()
    assert(state.writes == count, "native Okay/hide commits")
    info = state:Open(); Preview(info, original)
    state.owner:Hide(); Same(state.color, sample)
    assert(not ColorPickerFrame.shown, "owner hide cancels")
    info = state:Open()
    state.object = {}
    count = state.writes
    Preview(info, original); info.cancelFunc()
    assert(state.writes == count, "same-name replacement rejects preview and rollback")
    state.UI.CancelColorEdit()
end
function Contracts.PickerCoexistence(first, second)
    for _, hideOnSetup in ipairs({false, true}) do
        ColorPickerFrame = Picker(hideOnSetup)
        local a, b = Load(first), Load(second)
        local aInfo = a:Open(); Preview(aInfo, sample)
        local originalB = Copy(b.color)
        local bInfo = b:Open()
        local writesA, writesB = a.writes, b.writes
        a.UI.CancelColorEdit(); aInfo.cancelFunc(); Preview(aInfo, originalB)
        assert(ColorPickerFrame.shown and ColorPickerFrame:GetExtraInfo() == bInfo.extraInfo,
            "displaced addon leaves the current picker open")
        assert(a.writes == writesA and b.writes == writesB, "displaced callbacks cannot write")
        Preview(bInfo, sample); b.UI.CancelColorEdit(); Same(b.color, originalB)
        Same(a.color, sample) -- Displacement does not roll back another owner's preview.
        aInfo = a:Open()
        writesA, writesB = a.writes, b.writes
        b.UI.CancelColorEdit(); bInfo.cancelFunc(); Preview(bInfo, originalB)
        assert(ColorPickerFrame.shown and ColorPickerFrame:GetExtraInfo() == aInfo.extraInfo)
        assert(a.writes == writesA and b.writes == writesB, "ownership works in both directions")
        a.UI.CancelColorEdit()
    end
end
return Contracts
