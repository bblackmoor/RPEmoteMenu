local _, addon = ...

local Serialization = {}
addon.Serialization = Serialization

local Database = addon.Database
local JSON = addon.JSON
local FORMAT_NAME = "RPEmoteMenu"
local FORMAT_VERSION = 3
local MAX_DOCUMENT_BYTES = 4 * 1024 * 1024
local MAX_PROFILE_NAME_LENGTH = 64
local MAX_THEME_NAME_LENGTH = 64
local MAX_CATEGORY_NAME_LENGTH = 128
local MAX_LABEL_LENGTH = 128
local MAX_COMMAND_LENGTH = 4096
local MAX_FONT_NAME_LENGTH = 128

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
local PROFILE_SETTING_FIELDS = {}
local THEME_SETTING_FIELDS = {}
for _, key in ipairs(addon.ProfileSettingKeys) do PROFILE_SETTING_FIELDS[key] = true end
for _, key in ipairs(addon.ThemeSettingKeys) do THEME_SETTING_FIELDS[key] = true end

local COLOR_SETTING_KEYS = {
    "categoryTextColor",
    "selectedCategoryTextColor",
    "emoteTextColor",
    "categoryHighlightColor",
    "categoryBackgroundColor",
    "emoteBackgroundColor",
    "borderColor",
    "minimizedIconColor"
}
local VALID_CATEGORY_HIGHLIGHT_EFFECTS = {
    background = true, outline = true, underline = true, shadow = true,
    separator = true
}
local VALID_BORDER_STYLES = {none = true, thin = true, blizzard = true}
local VALID_TITLE_BAR_POSITIONS = {TOP = true, LEFT = true}
local VALID_MINIMIZE_MODES = {NONE = true, TITLE_BAR = true, ICON = true}
local VALID_MINIMIZED_ICON_CORNERS = {TOPLEFT = true, TOPRIGHT = true}
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true
}

local function ValidateObject(value, allowedFields, description)
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, description .. " must be an object."
    end

    for key in pairs(value) do
        if not allowedFields[key] then
            return nil, description .. " contains an unsupported field: " .. tostring(key) .. "."
        end
    end

    return true
end


local function ValidateString(value, maximumLength, description)
    if type(value) ~= "string" then
        return nil, description .. " must be a string."
    end
    if #value > maximumLength then
        return nil, description .. " exceeds " .. maximumLength .. " characters."
    end
    return value
end


local function ValidateNumber(value, minimum, maximum, description, integer)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge then
        return nil, description .. " must be a number."
    end
    if integer and value % 1 ~= 0 then
        return nil, description .. " must be a whole number."
    end
    if value < minimum or value > maximum then
        return nil, description .. " must be between " .. minimum .. " and " .. maximum .. "."
    end
    return value
end


local function ValidateBoolean(value, description)
    if type(value) ~= "boolean" then
        return nil, description .. " must be true or false."
    end
    return value
end


local function ValidateEnum(value, allowed, description)
    if type(value) ~= "string" or not allowed[value] then
        return nil, description .. " has an unsupported value."
    end
    return value
end


local function ValidateName(value, maximumLength, description)
    local name, errorMessage = ValidateString(value, maximumLength, description)
    if not name then return nil, errorMessage end
    if strtrim(name) == "" then
        return nil, description .. " cannot be empty."
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
            value[component], 0, 1, description .. " " .. component, false
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
    local description = (prefix or "Emote") .. " " .. index
    local valid, errorMessage = ValidateObject(value, EMOTE_FIELDS, description)
    if not valid then
        return nil, errorMessage
    end

    local label
    label, errorMessage = ValidateString(value.label, MAX_LABEL_LENGTH, description .. " label")
    if not label then
        return nil, errorMessage
    end

    local defaultCommand
    defaultCommand, errorMessage = ValidateString(
        value.defaultCommand,
        MAX_COMMAND_LENGTH,
        description .. " default command"
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
            description .. " targeted command"
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
    name, errorMessage = ValidateString(value.name, MAX_CATEGORY_NAME_LENGTH, description .. " name")
    if not name then
        return nil, errorMessage
    end
    if not JSON.IsArray(value.emotes) then
        return nil, description .. " emotes must be an array."
    end
    if #value.emotes > addon.MAX_EMOTES then
        return nil, description .. " cannot contain more than " .. addon.MAX_EMOTES .. " emotes."
    end

    local category = {name = name, emotes = {}}
    for index = 1, addon.MAX_EMOTES do
        if index <= #value.emotes then
            local emote
            emote, errorMessage = ValidateEmote(
                value.emotes[index], index, description .. " emote"
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
        return nil, description .. " categories must be an array."
    end
    if #value == 0 or #value > addon.MAX_CATEGORIES then
        return nil, description .. " must contain between 1 and "
            .. addon.MAX_CATEGORIES .. " categories."
    end

    local categories = {}
    local errorMessage
    for index = 1, addon.MAX_CATEGORIES do
        if index <= #value then
            categories[index], errorMessage = ValidateCategory(
                value[index], description .. " category " .. index
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


local function ValidateProfileSettings(value)
    local valid, errorMessage = ValidateObject(
        value, PROFILE_SETTING_FIELDS, "Profile settings"
    )
    if not valid then return nil, errorMessage end

    local settings = {}
    for _, key in ipairs({"locked", "fadeEnabled"}) do
        settings[key], errorMessage = ValidateBoolean(value[key], key)
        if settings[key] == nil then return nil, errorMessage end
    end
    for _, key in ipairs({"x", "y"}) do
        settings[key], errorMessage = ValidateNumber(
            value[key], -100000, 100000, key, true
        )
        if not settings[key] then return nil, errorMessage end
    end
    for _, field in ipairs({
        {"height", 150, 630},
        {"minimizedIconSize", addon.MIN_MINIMIZED_ICON_SIZE, addon.MAX_MINIMIZED_ICON_SIZE},
        {"selectedCategory", 1, addon.MAX_CATEGORIES},
        {"fadeDelay", 0, 60}
    }) do
        local key, minimum, maximum = field[1], field[2], field[3]
        settings[key], errorMessage = ValidateNumber(
            value[key], minimum, maximum, key, true
        )
        if not settings[key] then return nil, errorMessage end
    end
    settings.inactiveOpacity, errorMessage = ValidateNumber(
        value.inactiveOpacity, 0.1, 1, "inactiveOpacity", false
    )
    if not settings.inactiveOpacity then return nil, errorMessage end

    for _, field in ipairs({
        {"minimizeMode", VALID_MINIMIZE_MODES},
        {"minimizedIconCorner", VALID_MINIMIZED_ICON_CORNERS},
        {"point", VALID_ANCHOR_POINTS},
        {"relativePoint", VALID_ANCHOR_POINTS}
    }) do
        local key = field[1]
        settings[key], errorMessage = ValidateEnum(value[key], field[2], key)
        if not settings[key] then return nil, errorMessage end
    end
    return Database.CopyProfileSettings(settings)
end


local function ValidateThemeSettings(value)
    local valid, errorMessage = ValidateObject(
        value, THEME_SETTING_FIELDS, "Theme settings"
    )
    if not valid then return nil, errorMessage end

    local settings = {}
    for _, key in ipairs({"categoryFont", "emoteFont"}) do
        settings[key], errorMessage = ValidateName(
            value[key], MAX_FONT_NAME_LENGTH, key
        )
        if not settings[key] then return nil, errorMessage end
    end
    for _, key in ipairs({"categoryFontSize", "emoteFontSize"}) do
        settings[key], errorMessage = ValidateNumber(value[key], 8, 24, key, true)
        if not settings[key] then return nil, errorMessage end
    end
    settings.categoryHighlightThickness, errorMessage = ValidateNumber(
        value.categoryHighlightThickness, 1, 6, "categoryHighlightThickness", true
    )
    if not settings.categoryHighlightThickness then return nil, errorMessage end
    settings.windowOpacity, errorMessage = ValidateNumber(
        value.windowOpacity, 0.1, 1, "windowOpacity", false
    )
    if not settings.windowOpacity then return nil, errorMessage end

    for _, key in ipairs(COLOR_SETTING_KEYS) do
        settings[key], errorMessage = ValidateColor(value[key], key)
        if not settings[key] then return nil, errorMessage end
    end
    for _, field in ipairs({
        {"categoryHighlightEffect", VALID_CATEGORY_HIGHLIGHT_EFFECTS},
        {"borderStyle", VALID_BORDER_STYLES},
        {"titleBarPosition", VALID_TITLE_BAR_POSITIONS}
    }) do
        local key = field[1]
        settings[key], errorMessage = ValidateEnum(value[key], field[2], key)
        if not settings[key] then return nil, errorMessage end
    end
    return Database.CopyThemeSettings(settings)
end


local function ValidateProfile(value, description, allowedFields)
    local valid, errorMessage = ValidateObject(value, allowedFields, description)
    if not valid then return nil, errorMessage end

    local name
    name, errorMessage = ValidateName(
        value.name, MAX_PROFILE_NAME_LENGTH, description .. " name"
    )
    if not name then return nil, errorMessage end
    local theme
    theme, errorMessage = ValidateName(
        value.theme, MAX_THEME_NAME_LENGTH, description .. " theme"
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
        value.name, MAX_THEME_NAME_LENGTH, description .. " name"
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
        return nil, "Profiles must be a nonempty array."
    end
    local profiles, seen = {}, {}
    for index, source in ipairs(value) do
        local profile, errorMessage = ValidateProfile(
            source, "Profile " .. index, PROFILE_FIELDS
        )
        if not profile then return nil, errorMessage end
        local normalizedName = string.lower(profile.name)
        if seen[normalizedName] then
            return nil, "The import contains more than one profile named "
                .. profile.name .. "."
        end
        seen[normalizedName] = true
        profiles[#profiles + 1] = profile
    end
    return profiles
end


local function ValidateThemeArray(value)
    if not JSON.IsArray(value) or #value == 0 then
        return nil, "Themes must be a nonempty array."
    end
    local themes, seen = {}, {}
    for index, source in ipairs(value) do
        local theme, errorMessage = ValidateTheme(
            source, "Theme " .. index, THEME_FIELDS
        )
        if not theme then return nil, errorMessage end
        local normalizedName = string.lower(theme.name)
        if seen[normalizedName] then
            return nil, "The import contains more than one theme named "
                .. theme.name .. "."
        end
        seen[normalizedName] = true
        themes[#themes + 1] = theme
    end
    return themes
end


function Serialization.ExportCategory(categoryIndex)
    if not IsValidCategoryIndex(categoryIndex) then
        return nil, "Choose a valid category to export."
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
    if not profile then return nil, "That profile does not exist." end

    local result = ExportProfileData(profileName, profile)
    result.format = FORMAT_NAME
    result.version = FORMAT_VERSION
    result.type = "profile"
    return JSON.Encode(result, true)
end


function Serialization.ExportTheme(themeName)
    themeName = themeName or Database.GetActiveThemeName()
    local theme = Database.GetTheme(themeName)
    if not theme then return nil, "That theme does not exist." end

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
        return nil, "Paste exported RP Emote Menu data."
    end
    if #text > MAX_DOCUMENT_BYTES then
        return nil, "The imported data exceeds the maximum supported size."
    end

    local value, errorMessage = JSON.Decode(text)
    if not value then return nil, "Invalid JSON: " .. errorMessage end
    if type(value) ~= "table" or JSON.IsArray(value) or value == JSON.Null then
        return nil, "Import data must be an object."
    end
    if value.format ~= FORMAT_NAME then
        return nil, "This data was not exported by RP Emote Menu."
    end
    if value.version ~= FORMAT_VERSION then
        return nil, "This import format version is not supported."
    end

    local actualType = value.type
    if actualType ~= "category" and actualType ~= "profile"
        and actualType ~= "theme" and actualType ~= "everything" then
        return nil, "The import data has an unsupported type."
    end
    if expectedType and actualType ~= expectedType then
        return nil, "This is " .. actualType .. " data, not " .. expectedType .. " data."
    end

    if actualType == "category" then
        local valid
        valid, errorMessage = ValidateObject(
            value, CATEGORY_DOCUMENT_FIELDS, "Import data"
        )
        if not valid then return nil, errorMessage end
        local category
        category, errorMessage = ValidateCategory(
            value, "Category", CATEGORY_DOCUMENT_FIELDS
        )
        if not category then return nil, errorMessage end
        return {type = "category", name = category.name, category = category}
    end

    if actualType == "profile" then
        local profile
        profile, errorMessage = ValidateProfile(
            value, "Profile", PROFILE_DOCUMENT_FIELDS
        )
        if not profile then return nil, errorMessage end
        profile.type = "profile"
        return profile
    end

    if actualType == "theme" then
        local theme
        theme, errorMessage = ValidateTheme(
            value, "Theme", THEME_DOCUMENT_FIELDS
        )
        if not theme then return nil, errorMessage end
        theme.type = "theme"
        return theme
    end

    local valid
    valid, errorMessage = ValidateObject(
        value, EVERYTHING_DOCUMENT_FIELDS, "Import data"
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
            return nil, "Profile " .. profile.name
                .. " references a Theme missing from this export: "
                .. profile.theme .. "."
        end
    end
    if not exactThemeNames.Default or not hasDefaultProfile then
        return nil, "Everything must include Default Profile and Default Theme."
    end
    return {type = "everything", profiles = profiles, themes = themes}
end


function Serialization.ImportCategory(categoryIndex, text)
    if not IsValidCategoryIndex(categoryIndex) then
        return false, "Choose a valid category to import."
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
