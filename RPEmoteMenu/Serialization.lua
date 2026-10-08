local _, addon = ...
local L = addon.L
local definitions = addon.SettingDefinitions
local limits = definitions.limits

local Serialization = {}
addon.Serialization = Serialization

local Database = addon.Database
local JSON = addon.JSON
local FORMAT_NAME = "RPEmoteMenu"
local FORMAT_VERSION = 2
local MAX_DOCUMENT_BYTES = 4 * 1024 * 1024
local MAX_PROFILE_NAME_LENGTH = definitions.nameLengths.profile
local MAX_THEME_NAME_LENGTH = definitions.nameLengths.theme
local MAX_CATEGORY_NAME_LENGTH = addon.ContentTextLimits.categoryName
local MAX_LABEL_LENGTH = addon.ContentTextLimits.emoteLabel
local MAX_COMMAND_LENGTH = addon.ContentTextLimits.command
local MAX_FONT_NAME_LENGTH = definitions.nameLengths.font

local CATEGORY_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, name = true, emotes = true
}
local PROFILE_DOCUMENT_FIELDS = {
    format = true,
    version = true,
    type = true,
    name = true,
    theme = true,
    settings = true,
    categories = true
}
local PROFILE_FIELDS = {name = true, theme = true, settings = true, categories = true}
local THEME_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, name = true, settings = true
}
local THEME_FIELDS = {name = true, settings = true}
local EVERYTHING_DOCUMENT_FIELDS = {
    format = true, version = true, type = true, profiles = true, themes = true
}
local CATEGORY_FIELDS = {name = true, emotes = true}
local EMOTE_FIELDS = {label = true, defaultCommand = true, targetedCommand = true}
local COLOR_SETTING_KEYS = definitions.colorKeys
local VALID_CATEGORY_HIGHLIGHT_EFFECTS = definitions.enums.categoryHighlightEffect.allowed
local VALID_TITLE_BAR_POSITIONS = definitions.enums.titleBarPosition.allowed
local VALID_MINIMIZE_MODES = definitions.enums.minimizeMode.allowed
local VALID_ANCHOR_POINTS = definitions.enums.anchorPoint.allowed

local function ValidateObject(value, allowedFields, description)
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, string.format(L.UI_S_MUST_BE_AN_OBJECT, description)
    end

    for key in pairs(value) do
        if not allowedFields[key] then
            return nil, string.format(L.UI_S_CONTAINS_AN_UNSUPPORTED_FIELD_S, description, tostring(key))
        end
    end

    return true
end


local function ValidateString(value, maximumLength, description)
    if type(value) ~= "string" then
        return nil, string.format(L.UI_S_MUST_BE_A_STRING, description)
    end
    if #value > maximumLength then
        return nil, string.format(L.UI_S_EXCEEDS_S_BYTES, description, maximumLength)
    end
    return value
end


local function ValidateNumber(value, minimum, maximum, description, integer)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        return nil, string.format(L.UI_S_MUST_BE_A_NUMBER, description)
    end
    if integer and value % 1 ~= 0 then
        return nil, string.format(L.UI_S_MUST_BE_A_WHOLE_NUMBER, description)
    end
    if value < minimum or value > maximum then
        return nil, string.format(L.UI_S_MUST_BE_BETWEEN_S_AND_S, description, minimum, maximum)
    end
    return value
end


local function ValidateEnum(value, allowed, description)
    if type(value) ~= "string" or not allowed[value] then
        return nil, string.format(L.UI_S_HAS_AN_UNSUPPORTED_VALUE, description)
    end
    return value
end


local function ValidateName(value, maximumLength, description)
    local name, errorMessage = ValidateString(value, maximumLength, description)
    if not name then return nil, errorMessage end
    if strtrim(name) == "" then
        return nil, string.format(L.UI_S_CANNOT_BE_EMPTY, description)
    end
    return name
end


local function ValidateColor(value, description)
    local valid, errorMessage = ValidateObject(
        value, {r = true, g = true, b = true}, description
    )
    if not valid then
        return nil, errorMessage
    end

    local color = {}
    for _, component in ipairs({"r", "g", "b"}) do
        color[component], errorMessage = ValidateNumber(
            value[component], 0, 1, string.format(L.UI_S_S, description, component), false
        )
        if color[component] == nil then
            return nil, errorMessage
        end
    end

    return color
end


local function CopyColor(value)
    return {r = value.r, g = value.g, b = value.b}
end


local function BlankEmote()
    return {label = "", defaultCommand = "", targetedCommand = ""}
end


local function ValidateEmote(value, index, prefix)
    local description = string.format(L.UI_S_S, prefix or L.UI_EMOTE, index)
    local valid, errorMessage = ValidateObject(value, EMOTE_FIELDS, description)
    if not valid then
        return nil, errorMessage
    end

    local label
    label, errorMessage = ValidateString(value.label, MAX_LABEL_LENGTH, string.format(L.UI_S_LABEL, description))
    if not label then
        return nil, errorMessage
    end

    local defaultCommand
    defaultCommand, errorMessage = ValidateString(
        value.defaultCommand,
        MAX_COMMAND_LENGTH,
        string.format(L.UI_S_DEFAULT_COMMAND, description)
    )
    if not defaultCommand then
        return nil, errorMessage
    end

    local targetedCommand = value.targetedCommand
    if targetedCommand == nil then
        targetedCommand = ""
    else
        targetedCommand, errorMessage = ValidateString(
            targetedCommand,
            MAX_COMMAND_LENGTH,
            string.format(L.UI_S_TARGETED_COMMAND, description)
        )
        if not targetedCommand then
            return nil, errorMessage
        end
    end

    return {
        label = label,
        defaultCommand = defaultCommand,
        targetedCommand = targetedCommand
    }
end


local function ValidateCategory(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(
        value, allowedFields or CATEGORY_FIELDS, description
    )
    if not valid then
        return nil, errorMessage
    end

    local name
    name, errorMessage = ValidateString(value.name, MAX_CATEGORY_NAME_LENGTH, string.format(L.UI_S_NAME, description))
    if not name then
        return nil, errorMessage
    end
    if not JSON.IsArray(value.emotes) then
        return nil, string.format(L.UI_S_EMOTES_MUST_BE_AN_ARRAY, description)
    end
    if #value.emotes > addon.MAX_EMOTES then
        return nil, string.format(L.UI_S_CANNOT_CONTAIN_MORE_THAN_S_EMOTES, description, addon.MAX_EMOTES)
    end

    local category = {name = name, emotes = {}}
    for index = 1, addon.MAX_EMOTES do
        if index <= #value.emotes then
            local emote
            emote, errorMessage = ValidateEmote(
                value.emotes[index], index, string.format(L.UI_S_EMOTE, description)
            )
            if not emote then
                return nil, errorMessage
            end
            category.emotes[index] = emote
        else
            category.emotes[index] = BlankEmote()
        end
    end

    return category
end


local function ValidateCategories(value, description)
    if not JSON.IsArray(value) then
        return nil, string.format(L.UI_S_CATEGORIES_MUST_BE_AN_ARRAY, description)
    end
    if #value == 0 or #value > addon.MAX_CATEGORIES then
        return nil, string.format(L.UI_S_MUST_CONTAIN_BETWEEN_1_AND_S_CATEGORIES, description, addon.MAX_CATEGORIES)
    end

    local categories = {}
    local errorMessage
    for index = 1, addon.MAX_CATEGORIES do
        if index <= #value then
            categories[index], errorMessage = ValidateCategory(
                value[index], string.format(L.UI_S_CATEGORY_S, description, index)
            )
            if not categories[index] then
                return nil, errorMessage
            end
        else
            local emotes = {}
            for emoteIndex = 1, addon.MAX_EMOTES do
                emotes[emoteIndex] = BlankEmote()
            end
            categories[index] = {name = "", emotes = emotes}
        end
    end

    return categories
end


-- Settings are optional per field. Ignore invalid or unknown values and let the
-- Database fill each missing setting with its current default.
local function SettingsObject(value)
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return {}
    end
    return value
end


local function ValidateProfileSettings(value)
    value = SettingsObject(value)
    local settings = {}

    for _, key in ipairs({"locked", "fadeEnabled"}) do
        if type(value[key]) == "boolean" then
            settings[key] = value[key]
        end
    end
    for _, key in ipairs({"x", "y"}) do
        settings[key] = ValidateNumber(value[key], limits.position.min, limits.position.max, key, true)
    end
    for _, field in ipairs({
        {"height", limits.height.min, limits.height.max},
        {"minimizedIconSize", limits.minimizedIconSize.min, limits.minimizedIconSize.max},
        {"selectedCategory", limits.selectedCategory.min, limits.selectedCategory.max},
        {"fadeDelay", limits.fadeDelay.min, limits.fadeDelay.max}
    }) do
        local key = field[1]
        settings[key] = ValidateNumber(
            value[key], field[2], field[3], key, true
        )
    end
    settings.inactiveOpacity = ValidateNumber(
        value.inactiveOpacity, limits.opacity.min, limits.opacity.max, "inactiveOpacity", false
    )
    for _, field in ipairs({
        {"minimizeMode", VALID_MINIMIZE_MODES},
        {"point", VALID_ANCHOR_POINTS},
        {"relativePoint", VALID_ANCHOR_POINTS}
    }) do
        local key = field[1]
        settings[key] = ValidateEnum(value[key], field[2], key)
    end
    return Database.CopyProfileSettings(settings)
end


local function ValidateThemeSettings(value)
    value = SettingsObject(value)
    local settings = {}

    for _, key in ipairs({"categoryFont", "emoteFont"}) do
        settings[key] = ValidateName(value[key], MAX_FONT_NAME_LENGTH, key)
    end
    for _, key in ipairs({"categoryFontSize", "emoteFontSize"}) do
        settings[key] = ValidateNumber(value[key], limits.fontSize.min, limits.fontSize.max, key, true)
    end
    settings.categoryHighlightThickness = ValidateNumber(
        value.categoryHighlightThickness, limits.highlightThickness.min, limits.highlightThickness.max, "categoryHighlightThickness", true
    )
    settings.windowOpacity = ValidateNumber(
        value.windowOpacity, limits.opacity.min, limits.opacity.max, "windowOpacity", false
    )

    for _, key in ipairs(COLOR_SETTING_KEYS) do
        settings[key] = ValidateColor(value[key], key)
    end
    for _, field in ipairs({
        {"categoryHighlightEffect", VALID_CATEGORY_HIGHLIGHT_EFFECTS},
        {"titleBarPosition", VALID_TITLE_BAR_POSITIONS}
    }) do
        local key = field[1]
        settings[key] = ValidateEnum(value[key], field[2], key)
    end
    return Database.CopyThemeSettings(settings)
end


local function ValidateProfile(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(value, allowedFields, description)
    if not valid then return nil, errorMessage end

    local name
    name, errorMessage = ValidateName(
        value.name, MAX_PROFILE_NAME_LENGTH, string.format(L.UI_S_NAME, description)
    )
    if not name then return nil, errorMessage end
    local theme
    theme, errorMessage = ValidateName(
        value.theme, MAX_THEME_NAME_LENGTH, string.format(L.UI_S_THEME, description)
    )
    if not theme then return nil, errorMessage end
    local settings
    settings, errorMessage = ValidateProfileSettings(value.settings)
    if not settings then return nil, errorMessage end
    local categories
    categories, errorMessage = ValidateCategories(value.categories, description)
    if not categories then return nil, errorMessage end

    return {name = name, theme = theme, settings = settings, categories = categories}
end


local function ValidateTheme(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(value, allowedFields, description)
    if not valid then return nil, errorMessage end

    local name
    name, errorMessage = ValidateName(
        value.name, MAX_THEME_NAME_LENGTH, string.format(L.UI_S_NAME, description)
    )
    if not name then return nil, errorMessage end
    local settings
    settings, errorMessage = ValidateThemeSettings(value.settings)
    if not settings then return nil, errorMessage end
    return {name = name, settings = settings}
end


local function ExportCategoryData(category)
    local emotes = JSON.Array()
    local lastPopulated = 0
    for index = 1, addon.MAX_EMOTES do
        local emote = category.emotes[index]
        if emote.label ~= ""
            or emote.defaultCommand ~= ""
            or emote.targetedCommand ~= "" then
            lastPopulated = index
        end
    end

    for index = 1, lastPopulated do
        local source = category.emotes[index]
        local emote = {label = source.label, defaultCommand = source.defaultCommand}
        if source.targetedCommand ~= "" then
            emote.targetedCommand = source.targetedCommand
        end
        emotes[index] = emote
    end

    return {name = category.name, emotes = emotes}
end


local function ExportProfileSettings(source)
    local exported = {}
    for _, key in ipairs(addon.ProfileSettingKeys) do
        exported[key] = source[key]
    end
    return exported
end


local function ExportThemeSettings(source)
    local exported = {}
    for _, key in ipairs(addon.ThemeSettingKeys) do
        if type(source[key]) == "table" then
            exported[key] = CopyColor(source[key])
        else
            exported[key] = source[key]
        end
    end
    return exported
end


local function ExportProfileData(profileName, profile)
    local categories = JSON.Array()
    for index = 1, addon.MAX_CATEGORIES do
        categories[index] = ExportCategoryData(profile.categories[index])
    end
    return {
        name = profileName,
        theme = profile.theme,
        settings = ExportProfileSettings(profile.settings),
        categories = categories
    }
end


local function ExportThemeData(themeName, theme)
    return {name = themeName, settings = ExportThemeSettings(theme.settings)}
end


local function IsValidCategoryIndex(categoryIndex)
    return type(categoryIndex) == "number"
        and categoryIndex % 1 == 0
        and categoryIndex >= 1
        and categoryIndex <= addon.MAX_CATEGORIES
end


local function ValidateProfileArray(value)
    if not JSON.IsArray(value) or #value == 0 then
        return nil, L.UI_PROFILES_MUST_BE_A_NONEMPTY_ARRAY
    end
    local profiles, seen = {}, {}
    for index, source in ipairs(value) do
        local profile, errorMessage = ValidateProfile(
            source, string.format(L.UI_PROFILE_S, index), PROFILE_FIELDS
        )
        if not profile then return nil, errorMessage end
        local normalizedName = string.lower(profile.name)
        if seen[normalizedName] then
            return nil, string.format(L.UI_THE_IMPORT_CONTAINS_MORE_THAN_ONE_PROFILE_NAMED_S, profile.name)
        end
        seen[normalizedName] = true
        profiles[#profiles + 1] = profile
    end
    return profiles
end


local function ValidateThemeArray(value)
    if not JSON.IsArray(value) or #value == 0 then
        return nil, L.UI_THEMES_MUST_BE_A_NONEMPTY_ARRAY
    end
    local themes, seen = {}, {}
    for index, source in ipairs(value) do
        local theme, errorMessage = ValidateTheme(
            source, string.format(L.UI_THEME_S, index), THEME_FIELDS
        )
        if not theme then return nil, errorMessage end
        local normalizedName = string.lower(theme.name)
        if seen[normalizedName] then
            return nil, string.format(L.UI_THE_IMPORT_CONTAINS_MORE_THAN_ONE_THEME_NAMED_S, theme.name)
        end
        seen[normalizedName] = true
        themes[#themes + 1] = theme
    end
    return themes
end


function Serialization.ExportCategory(categoryIndex)
    if not IsValidCategoryIndex(categoryIndex) then
        return nil, L.UI_CHOOSE_A_VALID_CATEGORY_TO_EXPORT
    end
    local result = ExportCategoryData(Database.GetCategory(categoryIndex))
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "category"
    return JSON.Encode(result, true)
end


function Serialization.ExportProfile(profileName)
    profileName = profileName or Database.GetActiveProfileName()
    local profile = Database.GetProfile(profileName)
    if not profile then return nil, L.UI_THAT_PROFILE_DOES_NOT_EXIST end

    local result = ExportProfileData(profileName, profile)
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "profile"
    return JSON.Encode(result, true)
end


function Serialization.ExportTheme(themeName)
    themeName = themeName or Database.GetActiveThemeName()
    local theme = Database.GetTheme(themeName)
    if not theme then return nil, L.UI_THAT_THEME_DOES_NOT_EXIST end

    local result = ExportThemeData(themeName, theme)
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "theme"
    return JSON.Encode(result, true)
end


function Serialization.ExportEverything()
    local profiles, themes = JSON.Array(), JSON.Array()
    for _, profileName in ipairs(Database.GetProfileNames()) do
        profiles[#profiles + 1] = ExportProfileData(
            profileName, Database.GetProfile(profileName)
        )
    end
    for _, themeName in ipairs(Database.GetThemeNames()) do
        themes[#themes + 1] = ExportThemeData(
            themeName, Database.GetTheme(themeName)
        )
    end
    return JSON.Encode({
        format = FORMAT_NAME, version = FORMAT_VERSION, type = "everything",
        profiles = profiles, themes = themes
    }, true)
end


-- Transitional aliases retained until obsolete API cleanup.
function Serialization.ExportAllProfiles()
    return Serialization.ExportEverything()
end


function Serialization.Decode(text, expectedType)
    if type(text) ~= "string" or text == "" then
        return nil, L.UI_PASTE_EXPORTED_RP_EMOTE_MENU_DATA
    end
    if #text > MAX_DOCUMENT_BYTES then
        return nil, L.UI_THE_IMPORTED_DATA_EXCEEDS_THE_MAXIMUM_SUPPORTED_SIZE
    end

    local value, errorMessage = JSON.Decode(text)
    if not value then return nil, string.format(L.UI_INVALID_JSON_S, errorMessage) end
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, L.UI_IMPORT_DATA_MUST_BE_AN_OBJECT
    end
    if value.format ~= FORMAT_NAME then
        return nil, L.UI_THIS_DATA_WAS_NOT_EXPORTED_BY_RP_EMOTE_MENU
    end
    if value.version ~= FORMAT_VERSION then
        return nil, L.UI_THIS_IMPORT_FORMAT_VERSION_IS_NOT_SUPPORTED
    end

    local actualType = value.type
    if actualType ~= "category" and actualType ~= "profile"
        and actualType ~= "theme" and actualType ~= "everything" then
        return nil, L.UI_THE_IMPORT_DATA_HAS_AN_UNSUPPORTED_TYPE
    end
    if expectedType and actualType ~= expectedType then
        return nil, string.format(L.UI_THIS_IS_S_DATA_NOT_S_DATA, actualType, expectedType)
    end

    if actualType == "category" then
        local valid
        valid, errorMessage = ValidateObject(
            value, CATEGORY_DOCUMENT_FIELDS, L.UI_IMPORT_DATA
        )
        if not valid then return nil, errorMessage end
        local category
        category, errorMessage = ValidateCategory(
            value, L.UI_CATEGORY, CATEGORY_DOCUMENT_FIELDS
        )
        if not category then return nil, errorMessage end
        return {type = "category", name = category.name, category = category}
    end

    if actualType == "profile" then
        local profile
        profile, errorMessage = ValidateProfile(
            value, L.UI_PROFILE, PROFILE_DOCUMENT_FIELDS
        )
        if not profile then return nil, errorMessage end
        profile.type = "profile"
        return profile
    end

    if actualType == "theme" then
        local theme
        theme, errorMessage = ValidateTheme(
            value, L.UI_THEME, THEME_DOCUMENT_FIELDS
        )
        if not theme then return nil, errorMessage end
        theme.type = "theme"
        return theme
    end

    local valid
    valid, errorMessage = ValidateObject(
        value, EVERYTHING_DOCUMENT_FIELDS, L.UI_IMPORT_DATA
    )
    if not valid then return nil, errorMessage end
    local themes, themeError = ValidateThemeArray(value.themes)
    if not themes then return nil, themeError end
    local profiles, profileError = ValidateProfileArray(value.profiles)
    if not profiles then return nil, profileError end
    local exactThemeNames = {}
    for _, theme in ipairs(themes) do exactThemeNames[theme.name] = true end
    local hasDefaultProfile = false
    for _, profile in ipairs(profiles) do
        if profile.name == "Default" then hasDefaultProfile = true end
        if not exactThemeNames[profile.theme] then
            return nil, string.format(L.UI_PROFILE_S_REFERENCES_A_THEME_MISSING_FROM_THIS_EXPORT_S, profile.name, profile.theme)
        end
    end
    if not exactThemeNames.Default or not hasDefaultProfile then
        return nil, L.UI_EVERYTHING_MUST_INCLUDE_DEFAULT_PROFILE_AND_DEFAULT_THEME
    end
    return {type = "everything", profiles = profiles, themes = themes}
end


function Serialization.ImportCategory(categoryIndex, text)
    if not IsValidCategoryIndex(categoryIndex) then
        return false, L.UI_CHOOSE_A_VALID_CATEGORY_TO_IMPORT
    end
    local imported, errorMessage = Serialization.Decode(text, "category")
    if not imported then return false, errorMessage end

    Database.GetCategories()[categoryIndex] = imported.category
    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end
    if addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end
    return true, imported.name
end


function Serialization.ImportProfileAsNew(text)
    local imported, errorMessage = Serialization.Decode(text, "profile")
    if not imported then return false, errorMessage end

    local names, missingThemes = Database.AddImportedProfiles({imported})
    local missingTheme = missingThemes[1] and missingThemes[1].theme or nil
    return true, names[1], imported.name, missingTheme
end


function Serialization.ImportThemeAsNew(text)
    local imported, errorMessage = Serialization.Decode(text, "theme")
    if not imported then return false, errorMessage end

    local names = Database.AddImportedThemes({imported})
    return true, names[1], imported.name
end


function Serialization.ImportEverything(text)
    local imported, errorMessage = Serialization.Decode(text, "everything")
    if not imported then return false, errorMessage end

    local profileNames, themeNames = Database.AddImportedEverything(
        imported.profiles, imported.themes
    )
    return true, #profileNames, profileNames, #themeNames, themeNames
end


function Serialization.ImportAllProfiles(text)
    return Serialization.ImportEverything(text)
end

