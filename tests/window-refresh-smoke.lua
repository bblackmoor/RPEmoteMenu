-- Real database/window integration; only native rendering and coordinates stubbed.
local native = dofile('tests/details-framework-ui-stubs.lua')
dofile('tests/main-window-native.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local addon = {VERSION='test', Settings={}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
for _, name in ipairs({'Defaults.lua','SettingDefinitions.lua','BuiltInThemes.lua','Database.lua',
    'Scheduling.lua','FontMedia.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua',
    'EmoteEditor.lua','MainWindow.lua'}) do
    assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon)
end
local db, main = addon.Database, addon.MainWindow
db.InitializeDatabase()
UIParent:SetSize(1000,800)
local profile, theme = db.GetProfileSettings(), db.GetThemeSettings()
profile.point, profile.relativePoint, profile.x, profile.y = 'TOPLEFT','BOTTOMLEFT',300,600
profile.height = 200
main.CreateMainWindow()
local frame, icon = main.GetFrame(), main.GetMinimizedIconButton()
local category, emote
for _, object in ipairs(native.objects) do
    if object.categoryIndex == 1 then category = object end
    if object.emoteIndex == 1 then emote = object end
end
assert(category and emote)
local sidebar = category:GetParent():GetParent():GetParent()
local emoteScroll = emote:GetParent():GetParent()
-- Count observable rendering work, without reaching into private upvalues.
local methods = getmetatable(UIParent).__index
local measure, setFont = methods.GetStringWidth, methods.SetFont
local measurements, fontCalls, menuCalls, timers, visibleFontCalls = 0, 0, 0, 0, 0
methods.GetStringWidth = function(self)
    if self:GetParent() == frame and self.alpha == 0 then
        measurements = measurements + 1
    end
    return measure(self)
end
methods.SetFont = function(self, ...)
    fontCalls = fontCalls + 1
    if self.alpha ~= 0 then visibleFontCalls = visibleFontCalls + 1 end
    setFont(self, ...)
    return true
end
C_Timer.After = function() timers = timers + 1 end
local updateMenu = main.UpdateMenu
main.UpdateMenu = function(...)
    menuCalls = menuCalls + 1
    return updateMenu(...)
end
local function ResetCounts()
    measurements, fontCalls, menuCalls, timers, visibleFontCalls = 0, 0, 0, 0, 0
end
local function NoContentWork()
    assert(menuCalls == 0 and measurements == 0 and fontCalls == 0,
        'appearance-only edit rebuilt content or refreshed fonts')
end
local handler = emote:GetScript('OnClick')
emoteScroll:SetVerticalScroll(17)
ResetCounts()
theme.emoteTextColor = {r = 0.2, g = 0.4, b = 0.6}
main.ApplyThemeSettings('emoteTextColor')
NoContentWork()
assert(emote.Text.textColor[1] == 0.2 and emote.Text.textColor[3] == 0.6)
assert(emote:GetScript('OnClick') == handler and emoteScroll:GetVerticalScroll() == 17)
assert(timers == 0, 'color edit restarted inactivity or font timers')
for _, effect in ipairs(addon.SettingDefinitions.enums.categoryHighlightEffect.values) do
    theme.categoryHighlightEffect = effect
    main.ApplyThemeSettings('categoryHighlightEffect')
    NoContentWork()
end
ResetCounts()
theme.windowOpacity = 0.7
main.ApplyThemeSettings('windowOpacity')
NoContentWork()
assert(frame:GetAlpha() == 0.7 and emoteScroll:GetVerticalScroll() == 17)
-- A typography edit scans labels once, after building all required rows.
local expectedMeasurements = 0
for _, group in ipairs(db.GetCategories()) do
    if strtrim(group.name) ~= '' then expectedMeasurements = expectedMeasurements + 1 end
    for _, item in ipairs(group.emotes) do
        if strtrim(item.label) ~= '' then expectedMeasurements = expectedMeasurements + 1 end
    end
end
ResetCounts()
theme.emoteFontSize = 18
main.ApplyThemeSettings('emoteFontSize')
assert(menuCalls == 1 and measurements == expectedMeasurements,
    'font edit repeated menu construction or label measurement')
assert(emote:GetHeight() == 26 and fontCalls > 0)
-- Full replacements build content once; unknown keys use the complete path.
for _, key in ipairs({false, 'unknown-setting'}) do
    ResetCounts()
    main.ApplyThemeSettings(key or nil)
    assert(menuCalls == 1, 'Theme replacement rebuilt the menu more than once')
end
ResetCounts()
main.ApplyProfileSettings()
assert(menuCalls == 1, 'Profile replacement rebuilt the menu more than once')
-- Geometry-only edits preserve handlers and scroll offsets on every edge.
for _, position in ipairs({'LEFT', 'RIGHT', 'BOTTOM', 'TOP'}) do
    local left, top = frame:GetLeft(), frame:GetTop()
    handler = emote:GetScript('OnClick')
    emoteScroll:SetVerticalScroll(17)
    ResetCounts()
    theme.titleBarPosition = position
    main.ApplyThemeSettings('titleBarPosition')
    assert(menuCalls == 0 and visibleFontCalls == 0)
    assert(frame:GetLeft() == left and frame:GetTop() == top)
    assert(emote:GetScript('OnClick') == handler and emoteScroll:GetVerticalScroll() == 17)
end
print('PASS selective Theme refresh, single content rebuild, one typography measurement pass and stable scroll/handlers')
