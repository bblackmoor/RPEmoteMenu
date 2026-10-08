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
addon.Localization = {locale = locale, English = English, RejectedStrings = {}}

-- Lua format arguments are positional. A translation must retain their order
-- and types; literal percent signs in a formatted sentence use %%.
local function FormatSignature(text)
    local signature, position = {}, 1
    while true do
        local start = text:find("%", position, true)
        if not start then return table.concat(signature, ",") end
        if text:sub(start + 1, start + 1) == "%" then
            position = start + 2
        else
            local specifier = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])")
            local token = text:sub(start):match("^%%[-+ #0]*%d*%.?%d*[cdiouxXeEfgGqs]")
            if not token then return nil end
            local sample = (specifier == "s" or specifier == "q") and "text" or 1
            if not pcall(string.format, token, sample) then return nil end
            signature[#signature + 1] = specifier
            position = start + #token
        end
    end
end

local function ValidTranslation(key, value)
    local original = English[key]
    if not original then return false, "Unknown English key" end
    local expected = FormatSignature(original)
    local actual = FormatSignature(value)
    if expected and ((expected ~= "" and actual ~= expected)
        or (expected == "" and actual and actual ~= "")) then
        return false, "Format arguments differ from English"
    end
    for _, token in ipairs({"{player}", "{target}"}) do
        local _, before = original:gsub(token, "")
        local _, after = value:gsub(token, "")
        if before ~= after then return false, "Command tokens differ from English" end
    end
    return true
end

-- Locale files load in .toc order: enUS first, then optional translations.
-- Translations can omit keys; lookup falls back to the English table.
function addon.Localization.Register(localeCode, strings, standardEmotes)
    assert(type(localeCode) == "string" and type(strings) == "table", "Invalid locale")
    local destination = localeCode == "enUS" and English or (localeCode == locale and active)
    for key, value in pairs(strings) do
        assert(type(key) == "string" and type(value) == "string", "Invalid locale string")
        local valid, reason = true, nil
        if localeCode ~= "enUS" then valid, reason = ValidTranslation(key, value) end
        if not valid then
            local rejected = addon.Localization.RejectedStrings
            rejected[localeCode] = rejected[localeCode] or {}
            rejected[localeCode][key] = reason
            if destination then destination[key] = nil end -- Restore English fallback.
        else
            local rejected = addon.Localization.RejectedStrings[localeCode]
            if rejected then rejected[key] = nil end
            if destination then destination[key] = value end
        end
    end
    -- Catalog data is independent of interface keys and never enters SavedVariables.
    -- Keep each locale's catalog separate: English slash aliases are not universal.
    if standardEmotes then
        addon.Localization.StandardEmotes = addon.Localization.StandardEmotes or {}
        addon.Localization.StandardEmotes[localeCode] = standardEmotes
    end
end
