local addon = {}
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
function UnitName() return 'Components', 'Realm' end
for _, file in ipairs({'Localization.lua','Locales/enUS.lua','Defaults.lua','SettingDefinitions.lua',
    'BuiltInThemes.lua','DatabaseNormalization.lua','DatabasePresentation.lua','Database.lua'}) do
    assert(loadfile('RPEmoteMenu/'..file))('RPEmoteMenu', addon)
end
local normalize, db = addon.DatabaseNormalization, addon.Database
-- Normalizing saved records preserves identities used by pending dialog guards.
local emote = {label='Example',defaultCommand='/wave',targetedCommand='/e waits',defaultSend=false}
local category = {name='Example',emotes={emote}}
local categories = {category}
assert(normalize.NormalizeCategories(categories) == categories)
assert(categories[1] == category and categories[1].emotes[1] == emote)
assert(emote.defaultSend == false and emote.targetedSend == true)
-- Every copy is isolated, including nested colors and default emote records.
local copied = normalize.CopyCategories(categories)
assert(copied ~= categories and copied[1] ~= category and copied[1].emotes[1] ~= emote)
copied[1].emotes[1].label = 'Changed'
copied[1].emotes[1].defaultSend = true
assert(emote.label == 'Example' and emote.defaultSend == false)
local first = normalize.CopyDefaultCategories()
local second = normalize.CopyDefaultCategories()
first[1].emotes[1].label = 'Changed default copy'
assert(second[1].emotes[1].label ~= first[1].emotes[1].label)
local source = {categoryTextColor={r=0.2,g=0.3,b=0.4},windowOpacity=0.5}
local theme = normalize.CopyThemeSettings(source)
theme.categoryTextColor.r = 0.9
assert(source.categoryTextColor.r == 0.2)
local defaults = normalize.CopyThemeSettings(nil)
defaults.categoryTextColor.r = -1
assert(addon.DefaultThemeSettings.categoryTextColor.r ~= -1)
local profile = normalize.CopyProfileSettings({fadeEnabled=false,locked=false,fadeDelay=9000,
    selectedCategory=1.5,height=0/0,windowOpacity=0.1,active=false})
assert(profile.fadeEnabled == false and profile.locked == false)
assert(profile.fadeDelay == addon.SettingDefinitions.limits.fadeDelay.max)
assert(profile.selectedCategory == addon.DefaultProfileSettings.selectedCategory)
assert(profile.height == addon.DefaultProfileSettings.height)
assert(profile.windowOpacity == nil and profile.active == nil)
local globals = normalize.NormalizeGlobalSettings({active=false,tooltipDelayMs=math.huge,fadeDelay=100})
assert(globals.active == false and globals.fadeDelay == nil)
assert(globals.tooltipDelayMs == addon.DefaultGlobalSettings.tooltipDelayMs)

-- Headless mutations need no UI, and reset selection still belongs to the data.
db.InitializeDatabase()
assert(db.CreateProfile('First'))
db.GetProfileSettings().selectedCategory = 3
assert(db.ResetAllCategoriesToDefaults())
assert(db.GetProfileSettings().selectedCategory == 1)
assert(db.ResetCategoryToDefaults(1))
assert(db.CreateProfile('Second'))
assert(db.SetActiveProfile('First'))
local order = {}
local function Record(name) order[#order+1]=name end
local function Expect(expected)
    assert(table.concat(order, ',') == expected, table.concat(order, ','))
    order = {}
end
addon.SettingsUI = {CancelColorEdit=function()
    assert(db.GetActiveProfileName() == 'First', 'preview cancellation ran after selection changed')
    Record('cancel')
end}
addon.MainWindow = {ApplyProfileSettings=function()
    assert(db.GetActiveProfileName() == 'Second', 'refresh ran before mutation')
    Record('profile')
end}
addon.Settings = {RefreshSettingsPanels=function() Record('panels') end}
assert(db.SetActiveProfile('Second'))
Expect('cancel,profile,panels')
assert(not db.SetActiveProfile('Missing'))
Expect('')
-- Callbacks are resolved at dispatch time; inactive Theme edits refresh only panels.
addon.SettingsUI.CancelColorEdit=function() Record('new cancel') end
addon.MainWindow.ApplyThemeSettings=function() Record('theme') end
assert(db.CreateTheme('Custom'))
Expect('new cancel,panels')
assert(db.SetProfileTheme('Second', 'Custom'))
Expect('new cancel,theme,panels')
assert(db.SetProfileTheme('First', 'Custom'))
Expect('new cancel,panels')
-- Batch import applies one presentation refresh and keeps the active Profile.
local savedName = db.GetActiveProfileName()
local profiles, themes = db.AddImportedEverything({{name='Imported',theme='Imported theme',
    categories=categories,settings={}}}, {{name='Imported theme',settings={}}})
assert(#profiles == 1 and #themes == 1 and db.GetActiveProfileName() == savedName)
Expect('panels')
-- Category refresh order and selection synchronization are distinct from Profile refresh.
addon.Settings.RefreshEditors=function(index) Record(index and 'category '..index or 'categories') end
addon.MainWindow.SetSelectedCategory=function(index)
    assert(index == 1 and db.GetProfileSettings().selectedCategory == 1)
    Record('selection')
end
addon.MainWindow.UpdateMenu=function() Record('menu') end
db.ResetCategoryToDefaults(2)
Expect('category 2,menu')
db.GetProfileSettings().selectedCategory = 4
db.ResetAllCategoriesToDefaults()
Expect('categories,selection,menu')
-- Older/fewer view callbacks retain the fallback refresh order.
addon.Settings.RefreshSettingsPanels = nil
addon.Settings.RefreshProfiles = function() Record('profiles') end
addon.MainWindow.ApplyProfileSettings = nil
addon.DatabasePresentation.RefreshProfileViews()
Expect('menu,categories,profiles')
addon.MainWindow.ApplyActivation=function() Record('activation') end
db.SetActive(false)
Expect('new cancel,activation')
print('PASS isolated copies, saved identity/Send preservation, explicit ownership and database presentation ordering/fallbacks')
