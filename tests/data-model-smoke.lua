-- Run from the repository root: texlua --luaonly tests/data-model-smoke.lua
local addon = {}
local function loadModule(path)
    assert(loadfile(path))('RPEmoteMenu', addon)
end
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local character = 'First'
function UnitName() return character, 'Example' end
loadModule('RPEmoteMenu/Defaults.lua')
loadModule('RPEmoteMenu/BuiltInThemes.lua')
loadModule('RPEmoteMenu/JSON.lua')
loadModule('RPEmoteMenu/Database.lua')
loadModule('RPEmoteMenu/Serialization.lua')
local db = addon.Database
db.InitializeDatabase()
assert(db.GetActiveProfileName() == 'Default')
assert(db.GetActiveThemeName() == 'Default')
assert(db.GetProfileSettings().inactiveOpacity == 0.5)
assert(db.GetTheme('Teal') and not db.GetProfile('Teal'))
local oldExport=assert(addon.JSON.Decode(assert(addon.Serialization.ExportProfile())))
oldExport.settings.minimizedIconCorner='TOPRIGHT'
local imported=assert(addon.Serialization.Decode(
  addon.JSON.Encode(oldExport,true),'profile'))
assert(imported.settings.minimizedIconCorner==nil)
RPEmoteMenuDB.profiles.Default.settings.minimizedIconCorner='TOPRIGHT'
db.InitializeDatabase()
assert(db.GetProfileSettings().minimizedIconCorner==nil)

local ok = db.CreateProfile('Shared')
assert(ok and db.GetActiveProfileName() == 'Shared')
assert(db.SetProfileTheme('Shared', 'Teal'))
assert(db.GetActiveThemeName() == 'Teal')
assert(db.CreateProfile('Also Shared'))
assert(db.GetProfileThemeName('Also Shared') == 'Teal')
local teal = db.GetThemeSettings('Teal')
teal.categoryFontSize = 19
assert(db.GetThemeSettings().categoryFontSize == 19)

character = 'Second'
assert(db.GetActiveProfileName() == 'Default')
assert(db.GetActiveThemeName() == 'Default')
assert(db.SetActiveProfile('Shared'))
assert(db.GetActiveThemeName() == 'Teal')
character = 'First'
assert(db.GetActiveProfileName() == 'Also Shared')
db.InitializeDatabase() -- Simulate reload with the saved table still present.
assert(db.GetActiveProfileName() == 'Also Shared')
assert(db.GetThemeSettings('Teal').categoryFontSize == 19)
local deleted, _, users = db.DeleteTheme('Teal')
assert(not deleted and #users == 2)
assert(db.GetTheme('Teal'))
assert(db.DeleteTheme('Teal', true))
assert(db.GetProfileThemeName('Shared') == 'Default')
assert(db.GetProfileThemeName('Also Shared') == 'Default')
assert(db.RestoreTheme('Teal') and db.GetTheme('Teal'))
assert(not db.DeleteProfile('Default'))
db.GetThemeSettings('Default').categoryFontSize = 18
assert(db.RestoreDefaultProfile())
assert(db.GetProfileThemeName('Default') == 'Default')
assert(db.GetThemeSettings('Default').categoryFontSize == 18)
print('PASS default ownership, character selection, shared Themes, deletion, reload, restore')
