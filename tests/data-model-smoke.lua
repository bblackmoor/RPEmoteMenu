-- Run from the repository root: texlua --luaonly tests/data-model-smoke.lua
local addon = {}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
local function loadModule(path)
    assert(loadfile(path))('RPEmoteMenu', addon)
end
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local character = 'First'
function UnitName() return character, 'Example' end
loadModule('RPEmoteMenu/Defaults.lua')
loadModule('RPEmoteMenu/SettingDefinitions.lua')
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

-- Shared metadata must preserve recovery versus strict field validation.
local definitions = addon.SettingDefinitions
for _, enum in pairs(definitions.enums) do
    for _, value in ipairs(enum.values) do assert(enum.allowed[value]) end
    local count = 0
    for _ in pairs(enum.allowed) do count = count + 1 end
    assert(count == #enum.values)
end
assert(table.concat(definitions.enums.categoryHighlightEffect.values, ',') == 'background,outline,separator,underline,shadow')
assert(table.concat(definitions.enums.minimizeMode.values, ',') == 'NONE,TITLE_BAR,ICON')
assert(table.concat(definitions.enums.titleBarPosition.values, ',') == 'TOP,LEFT')
local function CheckLimit(copy, export, kind, key, limit, default, integer)
    for _, value in ipairs({limit.min, limit.max}) do
        assert(copy({[key] = value})[key] == value)
        local document = assert(json.Decode(assert(export())))
        document.settings[key] = value
        assert(assert(decodeDocument(document, kind)).settings[key] == value)
    end
    for _, value in ipairs({limit.min - 1, limit.max + 1, math.huge, -math.huge, 0/0}) do
        local normalized = copy({[key] = value})[key]
        if value ~= value or value == math.huge or value == -math.huge then
            assert(normalized == default)
        else
            assert(normalized == (value < limit.min and limit.min or limit.max))
            local document = assert(json.Decode(assert(export())))
            document.settings[key] = value
            assert(assert(decodeDocument(document, kind)).settings[key] == default)
        end
    end
    if integer then
        local value = limit.min + 0.5
        assert(copy({[key] = value})[key] == limit.min)
        local document = assert(json.Decode(assert(export())))
        document.settings[key] = value
        assert(assert(decodeDocument(document, kind)).settings[key] == default)
    end
end
for _, field in ipairs({{'height','height'}, {'x','position'}, {'y','position'},
    {'fadeDelay','fadeDelay'}, {'minimizedIconSize','minimizedIconSize'}, {'inactiveOpacity','opacity'}}) do
    CheckLimit(db.CopyProfileSettings, serialization.ExportProfile, 'profile', field[1],
        definitions.limits[field[2]], addon.DefaultProfileSettings[field[1]], field[2] ~= 'opacity')
end
for _, field in ipairs({{'categoryFontSize','fontSize'}, {'emoteFontSize','fontSize'},
    {'categoryHighlightThickness','highlightThickness'}, {'windowOpacity','opacity'}}) do
    CheckLimit(db.CopyThemeSettings, serialization.ExportTheme, 'theme', field[1],
        definitions.limits[field[2]], addon.DefaultThemeSettings[field[1]], field[2] ~= 'opacity')
end
for _, field in ipairs({{'minimizeMode','minimizeMode','profile'}, {'point','anchorPoint','profile'},
    {'relativePoint','anchorPoint','profile'}, {'titleBarPosition','titleBarPosition','theme'},
    {'categoryHighlightEffect','categoryHighlightEffect','theme'}}) do
    local profile = field[3] == 'profile'
    local copy = profile and db.CopyProfileSettings or db.CopyThemeSettings
    local export = profile and serialization.ExportProfile or serialization.ExportTheme
    local defaults = profile and addon.DefaultProfileSettings or addon.DefaultThemeSettings
    for _, value in ipairs(definitions.enums[field[2]].values) do
        assert(copy({[field[1]] = value})[field[1]] == value)
        local document = assert(json.Decode(assert(export())))
        document.settings[field[1]] = value
        assert(assert(decodeDocument(document, field[3])).settings[field[1]] == value)
    end
    assert(copy({[field[1]] = 'unsupported'})[field[1]] == defaults[field[1]])
    local document = assert(json.Decode(assert(export())))
    document.settings[field[1]] = 'unsupported'
    assert(assert(decodeDocument(document, field[3])).settings[field[1]] == defaults[field[1]])
end
print('PASS shared setting boundaries, enum order and recovery versus invalid import field fallback')

for _, value in ipairs({definitions.limits.selectedCategory.min, definitions.limits.selectedCategory.max}) do
    assert(db.CopyProfileSettings({selectedCategory = value}).selectedCategory == value)
    local document = assert(json.Decode(assert(serialization.ExportProfile())))
    document.settings.selectedCategory = value
    assert(assert(decodeDocument(document, 'profile')).settings.selectedCategory == value)
end
for _, value in ipairs({0, addon.MAX_CATEGORIES + 1, 1.5}) do
    assert(db.CopyProfileSettings({selectedCategory = value}).selectedCategory == addon.DefaultProfileSettings.selectedCategory)
    local document = assert(json.Decode(assert(serialization.ExportProfile())))
    document.settings.selectedCategory = value
    assert(assert(decodeDocument(document, 'profile')).settings.selectedCategory == addon.DefaultProfileSettings.selectedCategory)
end

-- Collision suffixes must preserve complete UTF-8 characters within 64 bytes.
for caseIndex, case in ipairs({{'é',51}, {'界',51}, {'🙂',51}, {'界',50}, {'界',54}}) do
    local character, prefixLength = case[1], case[2]
    local prefix = string.rep(string.char(64+caseIndex),prefixLength)
    local name = prefix .. string.rep(character,math.floor((64-prefixLength)/#character))
    assert(db.CreateTheme(name)); assert(db.CreateProfile(name))
    assert(db.SetProfileTheme(name,name))
    local themeText = assert(serialization.ExportTheme(name))
    local profileText = assert(serialization.ExportProfile(name))
    for number = 1,10 do
        local suffix = number == 1 and ' (Imported)' or ' (Imported '..number..')'
        local budget = 64-#suffix
        local expected = prefix:sub(1,budget)
            .. string.rep(character,math.max(0,math.floor((budget-prefixLength)/#character))) .. suffix
        local ok,themeName = serialization.ImportThemeAsNew(themeText)
        assert(ok and themeName == expected and #themeName <= 64)
        local ok,profileName = serialization.ImportProfileAsNew(profileText)
        assert(ok and profileName == expected and #profileName <= 64)
        assert(assert(json.Decode(assert(serialization.ExportTheme(themeName)))).name == expected)
        assert(assert(json.Decode(assert(serialization.ExportProfile(profileName)))).name == expected)
        assert(db.GetProfile(profileName).theme == name)
    end
end

-- Name errors describe the byte limit, including short multibyte names.
local oversizedName = string.rep('界',22)
local valid,message = db.ValidateNewProfileName(oversizedName)
assert(not valid and message == 'Profile names cannot exceed 64 bytes.')
valid,message = db.ValidateNewThemeName(oversizedName)
assert(not valid and message == 'Theme names cannot exceed 64 bytes.')
assert(db.ValidateNewProfileName(string.rep('B',64)))
assert(db.ValidateNewThemeName(string.rep('B',64)))
print('PASS UTF-8 import collision names, numbered suffixes, exports and byte-limit messages')

