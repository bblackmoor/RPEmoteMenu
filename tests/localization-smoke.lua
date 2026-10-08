-- Locale selection, partial translations, navigation, and reference-data isolation.
local function Load(locale)
    GetLocale = function() return locale end
    local addon = {MAX_CATEGORIES = 8, Database = {}}
    assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
    assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
    return addon
end

local english = Load("enUS")
assert(english.L.TAB_ABOUT == "About")
assert(string.format(english.L.ABOUT_METADATA, "test"):find("Version: test", 1, true))
local catalog = english.Localization.StandardEmotes.enUS
assert(#catalog == 299)
local aliases = {}
for _, row in ipairs(catalog) do
    assert(#row == 3 and type(row[1]) == "string" and type(row[2]) == "string" and type(row[3]) == "string")
    assert(not aliases[row[1]], "duplicate slash alias")
    aliases[row[1]] = row
end
assert(aliases.agree[2] == "You agree." and aliases.agree[3] == "You agree with <target>.")
assert(aliases.absent and aliases.yw)
assert(RPEmoteMenuDB == nil, "catalog must not create saved data")

local addon = Load("deDE")
local L = addon.L -- Consumers retain this table while locale files register.
addon.Localization.Register("frFR", {TAB_ABOUT = "Ignored"})
assert(L.TAB_ABOUT == "About")
addon.Localization.Register("deDE", {TAB_ABOUT = "Über", TAB_PROFILES = "Profile"})
assert(L == addon.L and L.TAB_ABOUT == "Über" and L.TAB_PROFILES == "Profile")
assert(L.TAB_THEMES == "Themes", "missing translations use English")
assert(L.UNKNOWN_KEY == "UNKNOWN_KEY", "missing English keys remain visible")
assert(addon.Localization.English.TAB_ABOUT == "About", "translation cannot modify English")
assert(addon.Localization.StandardEmotes.deDE == nil, "do not relabel English aliases as another locale")

local labels = {}
Settings = {
    RegisterCanvasLayoutCategory = function(_, label) labels[#labels + 1] = label; return {} end,
    RegisterCanvasLayoutSubcategory = function(_, _, label) labels[#labels + 1] = label; return {} end,
    RegisterAddOnCategory = function() end,
}
assert(loadfile("RPEmoteMenu/Settings.lua"))("RPEmoteMenu", addon)
addon.SettingsPanels = {}
for _, key in ipairs({"About", "Behavior", "Profiles", "Themes", "Emotes", "ImportExport"}) do
    addon.SettingsPanels[key] = function() return {} end
end
addon.Settings.RegisterSettingsPanels()
assert(labels[1] == "RP Emote Menu" and labels[3] == "Profile" and labels[4] == "Themes")
assert(Load("unsupported").L.TAB_ABOUT == "About")
GetLocale = nil
local fallback = {}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", fallback)
assert(fallback.Localization.locale == "enUS")
print("PASS locale fallback, partial translations, settings navigation and standard-emote catalog")
