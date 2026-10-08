-- Loaded before every module that uses translated interface strings.
local _, addon = ...
local English = {}
local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
local active = {}

-- Stable symbolic keys separate interface wording from saved data and commands.
-- English is always loaded, including on clients without a translation.
addon.L = setmetatable(active, {__index = function(_, key)
    local value = English[key]
    if value ~= nil then return value end
    return key -- Keep an accidentally missing key visible instead of returning nil.
end})
addon.Localization = {locale = locale, English = English}

-- Locale files load in .toc order: enUS first, then optional translations.
-- Translations can omit keys; lookup falls back to the English table.
function addon.Localization.Register(localeCode, strings, standardEmotes)
    assert(type(localeCode) == "string" and type(strings) == "table", "Invalid locale")
    local destination = localeCode == "enUS" and English or (localeCode == locale and active)
    if destination then
        for key, value in pairs(strings) do
            assert(type(key) == "string" and type(value) == "string", "Invalid locale string")
            destination[key] = value
        end
    end
    -- Catalog data is independent of interface keys and never enters SavedVariables.
    -- Keep each locale's catalog separate: English slash aliases are not universal.
    if standardEmotes then
        addon.Localization.StandardEmotes = addon.Localization.StandardEmotes or {}
        addon.Localization.StandardEmotes[localeCode] = standardEmotes
    end
end
