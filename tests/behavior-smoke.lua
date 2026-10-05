-- Real framework + database + geometry policy; only native UI/rendering is stubbed.
-- Run from repository root: luatex --luaonly tests/behavior-smoke.lua
local native = dofile('tests/details-framework-ui-stubs.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml') -- Construct before PLAYER_LOGIN.
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local addon = {Settings = {}, SettingsUI = {FIELD_GAP = 12}}
local function Load(name) assert(loadfile('RPEmoteMenu/' .. name))('RPEmoteMenu', addon) end
Load('Defaults.lua'); Load('BuiltInThemes.lua'); Load('Database.lua')
local db = addon.Database
db.InitializeDatabase()
Load('MainWindow.lua'); Load('SettingsWidgets.lua'); Load('SettingsControls.lua')
local widgets, main = addon.SettingsWidgets, addon.MainWindow
local controls = {Switch = {}, IntegerEntry = {}, Dropdown = {}, Button = {}}
for kind, collection in pairs(controls) do
    local factory = widgets['Create' .. kind]
    widgets['Create' .. kind] = function(...)
        local control = factory(...)
        collection[#collection + 1] = control
        return control
    end
end
-- Exercise actual ClampWindowGeometry, ApplyWindowGeometry, CenterWindow and
-- ResetWindowPosition, replacing unrelated renderer operations/measurements.
local function SetUpvalue(fn, name, value)
    for index = 1, 60 do
        local key = debug.getupvalue(fn, index)
        if key == name then debug.setupvalue(fn, index, value); return end
        if not key then break end
    end
    error('Missing runtime boundary: ' .. name)
end
local frame = CreateFrame('Frame', nil, UIParent)
UIParent:SetSize(1000, 800)
local geometry = main.ApplyWindowGeometry
SetUpvalue(geometry, 'MainFrame', frame)
SetUpvalue(geometry, 'profileSettings', db.GetProfileSettings())
SetUpvalue(geometry, 'CalculateColumnWidths', function() return 400 end)
SetUpvalue(geometry, 'GetCurrentFrameSize', function(w, h) return w, h end)
SetUpvalue(geometry, 'SetInternalFrameSize', function(w, h) frame:SetSize(w, h) end)
SetUpvalue(geometry, 'IsWindowBodyHidden', function() return false end)
SetUpvalue(geometry, 'SetNormalResizeBounds', function() end)
SetUpvalue(geometry, 'ApplyColumnLayout', function() end)
local calls = {fade = 0, minimize = 0, gear = 0, menu = 0, lock = 0, profile = 0, geometry = 0}
main.ApplyWindowGeometry = function(...)
    calls.geometry = calls.geometry + 1
    geometry(...)
end
main.ApplyFadeSettings = function() calls.fade = calls.fade + 1 end
main.ApplyMinimizeToIconSettings = function()
    calls.minimize = calls.minimize + 1
    addon.Settings.RefreshGeneralWindowFields()
end
main.ApplySettingsGearVisibility = function() calls.gear = calls.gear + 1 end
main.UpdateMenu = function() calls.menu = calls.menu + 1 end
main.ApplyMovementLock = function() calls.lock = calls.lock + 1 end
main.ApplyProfileSettings = function()
    calls.profile = calls.profile + 1
    SetUpvalue(geometry, 'profileSettings', db.GetProfileSettings())
end
Load('SettingsBehavior.lua')
local container = addon.SettingsUI.CreateGeneralSettingsPanel()
addon.Settings.RefreshSettingsPanels = container.RefreshControls
container.RefreshControls()
assert(addon.SettingsUI.CreateSwitch == nil and addon.SettingsUI.CreateIntegerEditBox == nil,
    'unused native widget factories remain retired')
assert(type(addon.SettingsUI.CreateRows) == 'function'
    and type(addon.SettingsUI.CreateInfoLink) == 'function', 'used native composition helpers missing')
assert(#controls.Switch == 4 and #controls.IntegerEntry == 7 and #controls.Dropdown == 1 and #controls.Button == 3)
local login, gear, fade, lock = unpack(controls.Switch)
local tooltip, delay, opacity, icon, x, y, height = unpack(controls.IntegerEntry)
local minimize = controls.Dropdown[1]
local restore, center, reset = unpack(controls.Button)
for _, count in pairs(calls) do assert(count == 0, 'construction/refresh must not invoke runtime setters') end
local function Event(control, name, ...) control.frame:GetScript(name)(control.frame, ...) end
local function Switch(control) Event(control, 'OnClick', 'LeftButton') end
local function Click(control)
    Event(control, 'OnMouseDown', 'LeftButton'); Event(control, 'OnMouseUp', 'LeftButton')
end
local function Type(control, text)
    control.frame:SetFocus(); control.frame:SetText(text); Event(control, 'OnTextChanged', true)
end
local function Enter(control, text) Type(control, text); Event(control, 'OnEnterPressed') end
local function Select(mode)
    if not minimize.widget.opened then Event(minimize, 'OnMouseDown', 'LeftButton') end
    if not minimize.enabled then return end
    for _, row in ipairs(minimize.widget.menus) do
        if row.table.value == mode then row:GetScript('OnMouseDown')(row, 'LeftButton'); return end
    end
    error('Missing minimize choice ' .. mode)
end
local function Position(control, px, py, width)
    assert(control.frame.point[4] == px and control.frame.point[5] == py)
    assert(control.frame:GetWidth() == width)
end
Position(login, 255, -121, 44); Position(gear, 255, -181, 44)
Position(fade, 255, -256, 44); Position(lock, 255, -561, 44)
Position(tooltip, 255, -151, 70); Position(delay, 255, -286, 70)
Position(opacity, 255, -316, 70); Position(icon, 255, -376, 70)
Position(x, 255, -491, 80); Position(y, 405, -491, 80); Position(height, 255, -526, 80)
Position(minimize, 255, -345, 150)
Position(restore, 16, -60, 170); Position(center, 20, -450, 130); Position(reset, 160, -450, 125)
-- Every native anchor must reference a frame, never a wrapper handle.
for _, object in ipairs(native.objects) do
    if object.point and type(object.point[2]) == 'table' then
        assert(not object.point[2].frame and not object.point[2].widget, 'native anchor received wrapper')
    end
end
local global, profile = db.GetGlobalSettings(), db.GetProfileSettings()
Switch(login); assert(not global.showAtLogin)
Switch(gear); assert(global.hideSettingsGear and calls.gear == 1 and calls.menu == 1)
Enter(tooltip, '5000'); assert(global.tooltipDelayMs == 1000)
Enter(tooltip, '-1'); assert(global.tooltipDelayMs == 0)
Enter(tooltip, '350'); Event(tooltip, 'OnMouseWheel', 1)
assert(global.tooltipDelayMs == 351)
assert(not delay.frame:IsEnabled() and not opacity.frame:IsEnabled() and not minimize.frame:IsEnabled())
assert(not icon.frame:IsEnabled() and delay.frame.alpha == 0.45 and delay.Label.alpha == 0.45)
Select('ICON'); Event(delay, 'OnMouseWheel', 1)
assert(profile.minimizeMode == 'NONE' and profile.fadeDelay == 5 and calls.minimize == 0)
Switch(fade)
assert(profile.fadeEnabled and delay.frame:IsEnabled() and opacity.frame:IsEnabled() and minimize.frame:IsEnabled())
assert(not icon.frame:IsEnabled())
Select('TITLE_BAR'); assert(profile.minimizeMode == 'TITLE_BAR' and not icon.frame:IsEnabled())
Select('ICON'); assert(profile.minimizeMode == 'ICON' and icon.frame:IsEnabled())
Event(minimize, 'OnMouseDown', 'LeftButton')
local pendingMode = minimize.widget.menus[1]
Switch(fade); assert(not minimize.widget.opened and not minimize.enabled)
local previousMinimizeCalls = calls.minimize
pendingMode:GetScript('OnMouseDown')(pendingMode, 'LeftButton')
assert(profile.minimizeMode == 'ICON' and minimize.widget.label:GetText() == 'Icon'
    and minimize.widget.myvalue == 'ICON' and calls.minimize == previousMinimizeCalls)
Switch(fade)
Enter(icon, '999'); assert(profile.minimizedIconSize == 64)
Enter(icon, '1'); assert(profile.minimizedIconSize == 16)
Event(icon, 'OnMouseWheel', 1); assert(profile.minimizedIconSize == 17)
Enter(delay, '90'); assert(profile.fadeDelay == 60)
Enter(delay, '-1'); assert(profile.fadeDelay == 0)
Enter(opacity, '1'); assert(profile.inactiveOpacity == 0.1)
Enter(opacity, '150'); assert(profile.inactiveOpacity == 1)
Type(delay, '15'); delay:ClearFocus(); assert(profile.fadeDelay == 15)
local before = calls.fade
Type(delay, '30'); Event(delay, 'OnEscapePressed')
assert(profile.fadeDelay == 15 and calls.fade == before)
Type(delay, 'invalid'); Event(delay, 'OnEnterPressed')
assert(profile.fadeDelay == 15 and calls.fade == before)
Type(delay, '45'); Switch(fade)
assert(not profile.fadeEnabled and profile.fadeDelay == 15 and calls.fade == before + 1,
    'dependency disable cancels without committing pending input')
Event(delay, 'OnEnterPressed'); Event(delay, 'OnMouseWheel', 1)
assert(profile.fadeDelay == 15 and calls.fade == before + 1)
Switch(fade)
Enter(x, '-500'); Enter(y, '-250')
assert(profile.x == -500 and profile.y == -250 and profile.point == 'CENTER')
Enter(x, '-999999'); assert(profile.x == -100000)
Event(y, 'OnMouseWheel', -1); assert(profile.y == -251)
local geometryCalls = calls.geometry
Enter(x, '-1.5'); Enter(x, '-'); Enter(y, '')
assert(calls.geometry == geometryCalls and profile.x == -100000 and profile.y == -251)
Click(center)
assert(profile.point == 'CENTER' and profile.x == 0 and profile.y == 0 and x:GetText() == '0')
Enter(height, '9999')
assert(profile.height == 630 and height:GetText() == '630' and profile.point == 'TOPLEFT')
Enter(height, '1'); assert(profile.height == 150)
Switch(lock); assert(profile.locked and calls.lock == 1)
profile.selectedCategory = 2
local content, theme = db.GetCategories(), db.GetActiveThemeName()
Click(reset)
assert(profile.height == 250 and profile.x == 0 and profile.y == 0 and profile.point == 'CENTER')
assert(profile.fadeEnabled and profile.locked and db.GetCategories() == content and db.GetActiveThemeName() == theme)
Type(tooltip, '999'); Click(restore); Event(tooltip, 'OnEnterPressed')
assert(db.GetGlobalSettings() ~= global and db.GetGlobalSettings().tooltipDelayMs == 350)
assert(profile.fadeEnabled and profile.locked and profile.selectedCategory == 2)
assert(db.GetCategories() == content and db.GetActiveThemeName() == theme, 'global restore preserves Profile/Theme')
-- Exercise real selection changes, refresh callbacks and replacement identities.
assert(db.CreateProfile('Other'))
local other = db.GetProfileSettings()
Enter(x, '-75'); assert(other.x == -75 and profile.x == 0)
Type(x, '-300'); assert(db.SetActiveProfile('Default')); Event(x, 'OnEnterPressed')
assert(profile.x == 0 and other.x == -75 and x:GetText() == '0')
-- Even without an orchestrator refresh, capture the real table, not the proxy.
Type(x, '-123')
RPEmoteMenuDB.activeProfiles[db.GetCharacterKey()] = 'Other'
main.ApplyProfileSettings(); Event(x, 'OnEnterPressed')
assert(other.x == -75 and profile.x == 0 and x:GetText() == '-75')
Type(x, '-555'); container:Hide(); Event(x, 'OnEnterPressed')
assert(other.x == -75, 'hiding the page cancels pending editing')
container.RefreshControls()
local snapshot = {}
for key, value in pairs(calls) do snapshot[key] = value end
container.RefreshControls(); addon.Settings.RefreshGeneralWindowFields()
for key, value in pairs(calls) do assert(snapshot[key] == value, 'runtime refresh reentered setter') end
local scroll = x.frame:GetParent():GetParent()
function scroll:GetVerticalScrollRange() return 200 end
scroll:GetScript('OnMouseWheel')(scroll, -1); assert(scroll:GetVerticalScroll() == 40)
scroll:GetScript('OnMouseWheel')(scroll, -10); assert(scroll:GetVerticalScroll() == 200)
scroll:GetScript('OnMouseWheel')(scroll, 10); assert(scroll:GetVerticalScroll() == 0)
print('PASS real Behavior widgets, ownership, dependencies, resets, input, geometry and scrolling')
