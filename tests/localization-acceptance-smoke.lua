-- Contract audit and expanded/non-Latin text with real dialog components.
-- Synthetic glyph measurements check geometry, not native font coverage.
local native = dofile('tests/details-framework-ui-stubs.lua')
local methods = getmetatable(UIParent).__index
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
local function Characters(text) return #(text:gsub('[\128-\191]', '')) end
function methods:GetStringWidth() return Characters(self:GetText()) * 7 end
function methods:GetStringHeight()
    local width, lines = math.max(1, self:GetWidth()), 0
    for line in (self:GetText() .. '\n'):gmatch('(.-)\n') do
        lines = lines + math.max(1, math.ceil(Characters(line) * 7 / width))
    end
    return lines * 14
end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
GetLocale = function() return 'deDE' end
StaticPopupDialogs = {}
local addon = {VERSION = 'test', SettingsUI = {FIELD_GAP = 12}, Settings = {}, MainWindow = {UpdateMenu = function() end}}
local function Load(name) assert(loadfile('RPEmoteMenu/' .. name))('RPEmoteMenu', addon) end
Load('Localization.lua'); Load('Locales/enUS.lua')
local localization, L = addon.Localization, addon.L
-- All interface references must have English entries; duplicate keys are errors.
local lfs = require('lfs')
for filename in lfs.dir('RPEmoteMenu') do
    if filename:match('%.lua$') then
        local file = assert(io.open('RPEmoteMenu/' .. filename)); local text = file:read('*a'); file:close()
        for key in text:gmatch('%f[%w]L%.([A-Z_0-9]+)') do assert(localization.English[key], filename .. ': missing ' .. key) end
    end
end
local file = assert(io.open('RPEmoteMenu/Locales/enUS.lua')); local english = file:read('*a'); file:close()
local seen, count = {}, 0
for key in english:gmatch('\n    ([A-Z_0-9]+) = ') do assert(not seen[key], 'Duplicate key: ' .. key); seen[key] = true; count = count + 1 end
assert(count == 288)
local pseudo = {}
for key, value in pairs(localization.English) do pseudo[key] = '⟦長い翻訳 ' .. value .. ' расширенный текст⟧' end
localization.Register('deDE', pseudo)
assert(not localization.RejectedStrings.deDE, 'Valid expanded templates rejected')
local bad = {MENU_DEFAULT_COMMAND = 'Broken %d', UI_S_S = 'Missing %s', EDITOR_HELP = 'Lost command tokens', TYPO_KEY = 'Typo'}
localization.Register('deDE', bad)
for key in pairs(bad) do assert(localization.RejectedStrings.deDE[key], key) end
assert(L.MENU_DEFAULT_COMMAND == localization.English.MENU_DEFAULT_COMMAND)
assert(L.EDITOR_HELP == localization.English.EDITOR_HELP)
localization.Register('deDE', {MENU_DEFAULT_COMMAND = '100%% translated: %s'})
assert(string.format(L.MENU_DEFAULT_COMMAND, '/e {player} %s') == '100% translated: /e {player} %s')
assert(not localization.RejectedStrings.deDE.MENU_DEFAULT_COMMAND)
localization.Register('frFR', {MENU_DEFAULT_COMMAND = 'Broken %'})
assert(localization.RejectedStrings.frFR.MENU_DEFAULT_COMMAND and L.MENU_DEFAULT_COMMAND == '100%% translated: %s')
localization.Register('deDE', {MENU_DEFAULT_COMMAND = 'Broken %'})
assert(L.MENU_DEFAULT_COMMAND == localization.English.MENU_DEFAULT_COMMAND)
localization.Register('deDE', {MENU_DEFAULT_COMMAND = 'Invalid %999999s'})
assert(L.MENU_DEFAULT_COMMAND == localization.English.MENU_DEFAULT_COMMAND)
localization.Register('deDE', pseudo)
for _, name in ipairs({'Defaults.lua', 'SettingDefinitions.lua', 'BuiltInThemes.lua', 'Database.lua', 'JSON.lua', 'Serialization.lua', 'Scheduling.lua', 'SettingsWidgets.lua', 'SettingsControls.lua', 'EmoteEditor.lua', 'SettingsExchangeText.lua', 'SettingsExchangeActions.lua', 'SettingsExchangeLifecycle.lua', 'SettingsExchange.lua'}) do Load(name) end
addon.Database.InitializeDatabase()
UIParent:SetSize(1000, 800)
-- Deliberately expand help, labels, action captions and validation/status text.
local expanded = {}
for _, key in ipairs({'EDITOR_HELP', 'EDITOR_EMOTE_NAME', 'EDITOR_DEFAULT_EMOTE', 'EDITOR_TARGETED_EMOTE_OPTIONAL', 'EDITOR_SAVE', 'UI_CLOSE', 'UI_SELECT_ALL', 'EDITOR_TARGET_CHANGED', 'UI_PRESS_CTRL_C_TO_COPY_THE_SELECTED_TEXT', 'UI_COPY_THIS_JSON_TO_SAVE_ALL_PROFILES_THEMES_AND_THEIR'}) do
    expanded[key] = pseudo[key] .. string.rep(' 長い説明 русский текст ', 5)
end
localization.Register('deDE', expanded)
addon.EmoteEditor.Open(1, 1, false)
local dialog
for _, object in ipairs(native.objects) do if object.NameBox then dialog = object end end
assert(dialog:GetHeight() > 330 and dialog:GetHeight() < UIParent:GetHeight())
local previousBottom = -dialog.HelpText.point[5] + dialog.HelpText:GetHeight()
for _, field in ipairs(dialog.Fields) do
    local labelTop, entryTop = -field.label.point[5], -field.editBox.point[5]
    assert(labelTop > previousBottom and entryTop > labelTop + field.label:GetHeight())
    previousBottom = entryTop + field.editBox:GetHeight()
end
assert(-dialog.Status.point[5] > previousBottom)
local before = dialog:GetHeight()
addon.Database.GetCategories()[1].emotes[1] = {}
dialog.SaveButton.scripts.OnClick()
assert(dialog:GetHeight() > before and dialog.Status:GetText() == expanded.EDITOR_TARGET_CHANGED)
assert(dialog.SaveButton:GetHeight() > 24 and dialog.SaveButton:GetWidth() <= (dialog:GetWidth() - 48) / 2)
local exchange = addon.SettingsUI.GetExchangeDialog()
assert(exchange:OpenEverythingExport())
local exportText = exchange.editBox:GetText()
local originalHeight = exchange:GetHeight()
exchange.SetStatus(expanded.UI_PRESS_CTRL_C_TO_COPY_THE_SELECTED_TEXT)
assert(exchange:GetHeight() > originalHeight and exchange.editBox:GetText() == exportText)
assert(exchange.actionButton:GetHeight() > 24)
-- The text viewport retains 300px even when translated copy grows.
local background = exchange.scrollFrame:GetParent()
local top, bottom = -background.points.TOPLEFT[5], background.points.BOTTOMRIGHT[5]
assert(exchange:GetHeight() - top - bottom >= 300)
exchange.SetStatus('')
assert(exchange:GetHeight() == originalHeight, 'Layout must shrink after clearing status')
print('PASS all locale keys, format/token rejection and fallback, expanded Unicode editor/exchange geometry and preserved export text')
