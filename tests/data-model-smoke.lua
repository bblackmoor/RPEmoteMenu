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
assert(db.GetThemeSettings().borderColor == nil and db.GetThemeSettings().borderStyle == nil)
local serialization = addon.Serialization
local json = addon.JSON
local function decodeDocument(document, expectedType)
    return serialization.Decode(json.Encode(document, true), expectedType)
end
local categoryExport = assert(json.Decode(assert(serialization.ExportCategory(1))))
local profileExport = assert(json.Decode(assert(serialization.ExportProfile())))
local themeExport = assert(json.Decode(assert(serialization.ExportTheme('Teal'))))
local everythingExport = assert(json.Decode(assert(serialization.ExportEverything())))
assert(categoryExport.version == 2 and profileExport.version == 2)
assert(themeExport.version == 2 and everythingExport.version == 2)
profileExport.settings.height = 333
profileExport.settings.fadeDelay = 90
profileExport.settings.x = 'invalid'
profileExport.settings.locked = true
profileExport.settings.minimizedIconCorner = 'TOPRIGHT'
profileExport.settings.unrecognized = {value = true}
local imported = assert(decodeDocument(profileExport, 'profile'))
assert(imported.settings.height == 333 and imported.settings.locked)
assert(imported.settings.fadeDelay == addon.DefaultProfileSettings.fadeDelay)
assert(imported.settings.x == addon.DefaultProfileSettings.x)
assert(imported.settings.minimizedIconCorner == nil and imported.settings.unrecognized == nil)
profileExport.settings = 'invalid'
imported = assert(decodeDocument(profileExport, 'profile'))
assert(imported.settings.height == addon.DefaultProfileSettings.height)
profileExport.version = 3
assert(not decodeDocument(profileExport, 'profile'))
profileExport.version = 2
profileExport.categories[1].emotes[1].label = 42
assert(not decodeDocument(profileExport, 'profile'))

themeExport.settings.categoryFontSize = 20
themeExport.settings.windowOpacity = 4
themeExport.settings.borderColor = {r = 1, g = 0, b = 0}
themeExport.settings.borderStyle = 'blizzard'
themeExport.settings.titleBarPosition = 'SIDE'
themeExport.settings.unrecognized = true
local importedTheme = assert(decodeDocument(themeExport, 'theme'))
assert(importedTheme.settings.categoryFontSize == 20)
assert(importedTheme.settings.windowOpacity == addon.DefaultThemeSettings.windowOpacity)
assert(importedTheme.settings.borderColor == nil and importedTheme.settings.borderStyle == nil)
assert(importedTheme.settings.titleBarPosition == addon.DefaultThemeSettings.titleBarPosition)
assert(importedTheme.settings.unrecognized == nil)
everythingExport.profiles[1].settings.fadeDelay = -1
everythingExport.themes[1].settings.categoryFontSize = 18
local importedEverything = assert(decodeDocument(everythingExport, 'everything'))
assert(importedEverything.profiles[1].settings.fadeDelay == addon.DefaultProfileSettings.fadeDelay)
assert(importedEverything.themes[1].settings.categoryFontSize == 18)
local exportedThemeSettings = assert(json.Decode(assert(serialization.ExportTheme('Teal')))).settings
assert(exportedThemeSettings.borderColor == nil and exportedThemeSettings.borderStyle == nil)
RPEmoteMenuDB.themes.Default.settings.borderColor={r=1,g=0,b=0}
RPEmoteMenuDB.themes.Default.settings.borderStyle='blizzard'
RPEmoteMenuDB.profiles.Default.settings.minimizedIconCorner='TOPRIGHT'
db.InitializeDatabase()
assert(db.GetProfileSettings().minimizedIconCorner==nil)
assert(db.GetThemeSettings().borderColor==nil and db.GetThemeSettings().borderStyle==nil)

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

-- False global activation survives normalization/reload.
db.SetActive(false)
assert(db.GetGlobalSettings().active == false)
db.InitializeDatabase()
assert(db.GetGlobalSettings().active == false and db.GetGlobalSettings().showAtLogin == nil)
db.SetActive(true); db.InitializeDatabase()
assert(db.GetGlobalSettings().active == true)

print('PASS default ownership, character selection, shared Themes, deletion, reload, restore')
