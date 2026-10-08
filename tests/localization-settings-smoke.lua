-- Synthetic translations exercise real settings controls and data boundaries.
local native = dofile("tests/details-framework-ui-stubs.lua")
local LoadXML = dofile("tests/details-framework-loader.lua")
LoadXML("Libs/DetailsFramework/load.xml")
function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end

local function LoadData(locale, translations)
    GetLocale = function() return locale end
    local addon = {VERSION = "test", Settings = {}, SettingsUI = {FIELD_GAP = 12}}
    local function Load(name) assert(loadfile("RPEmoteMenu/" .. name))("RPEmoteMenu", addon) end
    Load("Localization.lua"); Load("Locales/enUS.lua")
    if translations then addon.Localization.Register(locale, translations) end
    for _, name in ipairs({"Defaults.lua", "SettingDefinitions.lua", "BuiltInThemes.lua",
        "JSON.lua", "Database.lua", "Serialization.lua", "Scheduling.lua"}) do Load(name) end
    RPEmoteMenuDB = nil
    addon.Database.InitializeDatabase()
    return addon, Load
end

local english = LoadData("enUS")
local expectedExport = english.Serialization.ExportEverything()
local translations = {
    UI_NONE = "Keines", UI_TITLE_BAR = "Titelleiste", UI_ICON = "Symbol",
    UI_ENTER_A_PROFILE_NAME = "Profilnamen eingeben.",
    UI_S_CANNOT_EXCEED_S_BYTES = "%s: höchstens %s Bytes.",
    UI_THIS_IS_S_DATA_NOT_S_DATA = "Datentyp %s statt %s.",
    UI_A_CLEAN_BLACK_AND_CRIMSON_DESIGN_WITH_STRONG_CONTRAST = "Beschreibung des Designs.",
}
local addon, Load = LoadData("deDE", translations)
local db = addon.Database
assert(addon.Serialization.ExportEverything() == expectedExport,
    "translated interface must not alter exported fields, names, settings or emotes")
assert(db.GetTheme("Crimson Night") and not db.GetTheme("Beschreibung des Designs."))
assert(db.GetThemeDescription("Crimson Night") == "Beschreibung des Designs.")
local valid, message = db.ValidateNewProfileName("")
assert(valid == nil and message == translations.UI_ENTER_A_PROFILE_NAME)
valid, message = db.ValidateContentText(string.rep("x", 1000), "emoteLabel", "Name %s")
assert(not valid and message == "Name %s: höchstens " .. addon.ContentTextLimits.emoteLabel .. " Bytes.",
    "user percent signs must remain literal format arguments")
local decoded, errorMessage = addon.Serialization.Decode(expectedExport, "profile")
assert(not decoded and errorMessage == "Datentyp everything statt profile.")

addon.MainWindow = setmetatable({}, {__index = function() return function() end end})
Load("SettingsWidgets.lua"); Load("SettingsControls.lua")
local dropdown
local create = addon.SettingsWidgets.CreateDropdown
addon.SettingsWidgets.CreateDropdown = function(...)
    local control = create(...)
    if not dropdown then dropdown = control end
    return control
end
Load("SettingsBehavior.lua")
local panel = addon.SettingsPanels.Behavior()
db.GetProfileSettings().fadeEnabled = true
panel.Refresh()
local choices = dropdown.widget.func()
assert(choices[1].label == "Keines" and choices[1].value == "NONE")
assert(choices[2].label == "Titelleiste" and choices[2].value == "TITLE_BAR")
assert(choices[3].label == "Symbol" and choices[3].value == "ICON")
choices[3].onclick(dropdown.widget, nil, choices[3].value)
assert(db.GetProfileSettings().minimizeMode == "ICON")
panel.Refresh()
assert(dropdown.widget.label:GetText() == "Symbol")
assert(addon.Localization.StandardEmotes.enUS[2][1] == "agree")
assert(addon.Localization.StandardEmotes.deDE == nil)
print("PASS translated dropdowns, validation, descriptions and unchanged export identities/content")
