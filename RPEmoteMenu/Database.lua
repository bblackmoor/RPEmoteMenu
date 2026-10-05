local _, addon = ...

addon.Database = {}

local Database = addon.Database
local defaultSections = addon.DefaultSections
local globalDefaults = addon.DefaultGlobalSettings
local profileDefaults = addon.DefaultProfileSettings
local themeDefaults = addon.DefaultThemeSettings
local globalSettingKeys = addon.GlobalSettingKeys
local profileSettingKeys = addon.ProfileSettingKeys
local themeSettingKeys = addon.ThemeSettingKeys
local builtInThemes = addon.BuiltInThemes or {}
local builtInThemeByName = {}
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local SCHEMA_VERSION = 15
local DEFAULT_PROFILE_NAME = "Default"
local DEFAULT_THEME_NAME = "Default"
local MAX_PROFILE_NAME_LENGTH = 64
local MAX_THEME_NAME_LENGTH = 64

for _, definition in ipairs(builtInThemes) do
    builtInThemeByName[definition.name] = definition
end

local VALID_CATEGORY_HIGHLIGHT_EFFECTS = {
    background = true,
    outline = true,
    underline = true,
    shadow = true,
    separator = true
}
local VALID_MINIMIZE_MODES = {NONE = true, TITLE_BAR = true, ICON = true}
local VALID_TITLE_BAR_POSITIONS = {TOP = true, LEFT = true}
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true
}
local COLOR_SETTING_KEYS = {
    "categoryTextColor",
    "selectedCategoryTextColor",
    "emoteTextColor",
    "categoryHighlightColor",
    "categoryBackgroundColor",
    "emoteBackgroundColor",
    "minimizedIconColor"
}
local globalSettingLookup = {}
local profileSettingLookup = {}
local themeSettingLookup = {}

for _, key in ipairs(globalSettingKeys) do
    globalSettingLookup[key] = true
end
for _, key in ipairs(profileSettingKeys) do
    profileSettingLookup[key] = true
end
for _, key in ipairs(themeSettingKeys) do
    themeSettingLookup[key] = true
end

local function NormalizeString(value)
    return type(value) == "string" and value or ""
end

local function CopyDefaultCategories()
    local categories = {}

    for categoryIndex, sourceCategory in ipairs(defaultSections) do
        local category = {
            name = NormalizeString(sourceCategory.name),
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory.emotes[emoteIndex]
            category.emotes[emoteIndex] = {
                label = NormalizeString(source and source[1]),
                defaultCommand = NormalizeString(source and source[2]),
                targetedCommand = NormalizeString(source and source[3])
            }
        end

        categories[categoryIndex] = category
    end

    return categories
end


local function NormalizeCategories(categories)
    categories = type(categories) == "table" and categories or {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = categories[categoryIndex]

        if type(category) ~= "table" then
            category = {}
            categories[categoryIndex] = category
        end

        category.name = NormalizeString(category.name)
        category.emotes = type(category.emotes) == "table" and category.emotes or {}

        for emoteIndex = 1, MAX_EMOTES do
            local emote = category.emotes[emoteIndex]

            if type(emote) ~= "table" then
                emote = {}
                category.emotes[emoteIndex] = emote
            end

            emote.label = NormalizeString(emote.label)
            emote.defaultCommand = NormalizeString(emote.defaultCommand)
            emote.targetedCommand = NormalizeString(emote.targetedCommand)
        end
    end

    return categories
end


local function CopyCategories(sourceCategories)
    local categories = {}
    sourceCategories = type(sourceCategories) == "table" and sourceCategories or {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local sourceCategory = sourceCategories[categoryIndex]
        local category = {
            name = NormalizeString(sourceCategory and sourceCategory.name),
            emotes = {}
        }

        for emoteIndex = 1, MAX_EMOTES do
            local source = sourceCategory
                and sourceCategory.emotes
                and sourceCategory.emotes[emoteIndex]

            category.emotes[emoteIndex] = {
                label = NormalizeString(source and source.label),
                defaultCommand = NormalizeString(source and source.defaultCommand),
                targetedCommand = NormalizeString(source and source.targetedCommand)
            }
        end

        categories[categoryIndex] = category
    end

    return categories
end


local function IsValidSavedValue(value, defaultValue)
    if type(value) ~= type(defaultValue) then
        return false
    end

    if type(value) == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end

    return true
end


local function ClampNumber(value, minimum, maximum, defaultValue)
    value = tonumber(value)

    if not value or value ~= value or value == math.huge or value == -math.huge then
        value = defaultValue
    end

    return math.max(minimum, math.min(maximum, value))
end


local function NormalizeColor(value, defaultValue)
    value = type(value) == "table" and value or {}

    return {
        r = ClampNumber(value.r, 0, 1, defaultValue.r),
        g = ClampNumber(value.g, 0, 1, defaultValue.g),
        b = ClampNumber(value.b, 0, 1, defaultValue.b)
    }
end


local function NormalizeGlobalSettings(source)
    source = type(source) == "table" and source or {}
    local result = {}

    for key, defaultValue in pairs(globalDefaults) do
        if IsValidSavedValue(source[key], defaultValue) then
            result[key] = source[key]
        else
            result[key] = defaultValue
        end
    end

    result.tooltipDelayMs = math.floor(ClampNumber(
        source.tooltipDelayMs, 0, 1000, globalDefaults.tooltipDelayMs
    ))

    return result
end


local function NormalizeProfileSettings(source)
    source = type(source) == "table" and source or {}
    local result = {}
    for key, defaultValue in pairs(profileDefaults) do
        if IsValidSavedValue(source[key], defaultValue) then
            result[key] = source[key]
        else
            result[key] = defaultValue
        end
    end

    if VALID_MINIMIZE_MODES[source.minimizeMode] then
        result.minimizeMode = source.minimizeMode
    else
        result.minimizeMode = profileDefaults.minimizeMode
    end

    result.height = math.floor(ClampNumber(source.height, 150, 630, profileDefaults.height))
    result.minimizedIconSize = math.floor(ClampNumber(
        source.minimizedIconSize,
        addon.MIN_MINIMIZED_ICON_SIZE,
        addon.MAX_MINIMIZED_ICON_SIZE,
        profileDefaults.minimizedIconSize
    ))
    result.x = math.floor(ClampNumber(source.x, -100000, 100000, profileDefaults.x))
    result.y = math.floor(ClampNumber(source.y, -100000, 100000, profileDefaults.y))

    if not VALID_ANCHOR_POINTS[result.point] then
        result.point = profileDefaults.point
    end
    if not VALID_ANCHOR_POINTS[result.relativePoint] then
        result.relativePoint = profileDefaults.relativePoint
    end
    if result.selectedCategory % 1 ~= 0
        or result.selectedCategory < 1
        or result.selectedCategory > MAX_CATEGORIES then
        result.selectedCategory = profileDefaults.selectedCategory
    end

    result.fadeDelay = math.floor(ClampNumber(
        source.fadeDelay, 0, 60, profileDefaults.fadeDelay
    ))
    result.inactiveOpacity = ClampNumber(
        source.inactiveOpacity, 0.1, 1, profileDefaults.inactiveOpacity
    )

    return result
end


local function NormalizeThemeSettings(source)
    source = type(source) == "table" and source or {}
    local result = {}

    for key, defaultValue in pairs(themeDefaults) do
        if type(defaultValue) ~= "table" then
            if IsValidSavedValue(source[key], defaultValue) then
                result[key] = source[key]
            else
                result[key] = defaultValue
            end
        end
    end

    if strtrim(result.categoryFont) == "" then
        result.categoryFont = themeDefaults.categoryFont
    end
    if strtrim(result.emoteFont) == "" then
        result.emoteFont = themeDefaults.emoteFont
    end

    result.categoryFontSize = math.floor(ClampNumber(
        source.categoryFontSize, 8, 24, themeDefaults.categoryFontSize
    ))
    result.emoteFontSize = math.floor(ClampNumber(
        source.emoteFontSize, 8, 24, themeDefaults.emoteFontSize
    ))
    result.categoryHighlightThickness = math.floor(ClampNumber(
        source.categoryHighlightThickness,
        1,
        6,
        themeDefaults.categoryHighlightThickness
    ))

    for _, key in ipairs(COLOR_SETTING_KEYS) do
        result[key] = NormalizeColor(source[key], themeDefaults[key])
    end

    if not VALID_CATEGORY_HIGHLIGHT_EFFECTS[result.categoryHighlightEffect] then
        result.categoryHighlightEffect = themeDefaults.categoryHighlightEffect
    end
    if not VALID_TITLE_BAR_POSITIONS[result.titleBarPosition] then
        result.titleBarPosition = themeDefaults.titleBarPosition
    end

    result.windowOpacity = ClampNumber(
        source.windowOpacity, 0.1, 1, themeDefaults.windowOpacity
    )

    return result
end


local function CopyProfileSettings(source)
    return NormalizeProfileSettings(source)
end


local function CopyThemeSettings(source)
    return NormalizeThemeSettings(source)
end


function Database.GetCharacterKey()
    local name, realm = UnitName("player")

    if type(name) ~= "string" or name == "" then
        return nil
    end

    if (type(realm) ~= "string" or realm == "") and GetRealmName then
        realm = GetRealmName()
    end

    if type(realm) == "string" and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end


function Database.GetActiveProfileName()
    local characterKey = Database.GetCharacterKey()
    local profileName = characterKey and RPEmoteMenuDB.activeProfiles[characterKey]

    if type(profileName) ~= "string"
        or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        profileName = DEFAULT_PROFILE_NAME

        if characterKey then
            RPEmoteMenuDB.activeProfiles[characterKey] = profileName
        end
    end

    return profileName
end


function Database.GetActiveProfile()
    return RPEmoteMenuDB.profiles[Database.GetActiveProfileName()]
end


function Database.GetProfile(profileName)
    return RPEmoteMenuDB.profiles[profileName]
end


function Database.GetProfiles()
    return RPEmoteMenuDB.profiles
end


function Database.GetThemes()
    return RPEmoteMenuDB.themes
end


function Database.GetTheme(themeName)
    return type(themeName) == "string" and RPEmoteMenuDB.themes[themeName] or nil
end


local function GetProfileTheme(profile)
    local themeName = profile and profile.theme
    local theme = type(themeName) == "string" and RPEmoteMenuDB.themes[themeName]
    if type(theme) ~= "table" then
        theme = RPEmoteMenuDB.themes[DEFAULT_THEME_NAME]
        if profile then profile.theme = DEFAULT_THEME_NAME end
    end
    return theme
end


function Database.GetActiveThemeName()
    local profile = Database.GetActiveProfile()
    GetProfileTheme(profile)
    return profile.theme
end


function Database.GetActiveTheme()
    return GetProfileTheme(Database.GetActiveProfile())
end


function Database.GetProfileThemeName(profileName)
    local profile = Database.GetProfile(profileName)
    if not profile then return nil end
    GetProfileTheme(profile)
    return profile.theme
end


local settingsProxy = setmetatable({}, {
    __index = function(_, key)
        if globalSettingLookup[key] then
            return RPEmoteMenuDB.globalSettings[key]
        end
        if profileSettingLookup[key] then
            local profile = Database.GetActiveProfile()
            return profile and profile.settings[key] or profileDefaults[key]
        end
        if themeSettingLookup[key] then
            local theme = GetProfileTheme(Database.GetActiveProfile())
            return theme and theme.settings[key] or themeDefaults[key]
        end
    end,
    __newindex = function(_, key, value)
        if globalSettingLookup[key] then
            RPEmoteMenuDB.globalSettings[key] = value
            return
        end
        if profileSettingLookup[key] then
            Database.GetActiveProfile().settings[key] = value
            return
        end
        if themeSettingLookup[key] then
            GetProfileTheme(Database.GetActiveProfile()).settings[key] = value
            return
        end

        error("Unknown setting: " .. tostring(key))
    end
})


function Database.GetSettings()
    return settingsProxy
end


function Database.GetGlobalSettings()
    return RPEmoteMenuDB.globalSettings
end


function Database.GetProfileSettings(profileName)
    local profile
    if profileName == nil then
        profile = Database.GetActiveProfile()
    else
        profile = Database.GetProfile(profileName)
    end
    return profile and profile.settings
end


function Database.GetThemeSettings(themeName)
    local theme
    if themeName == nil then
        theme = Database.GetActiveTheme()
    else
        theme = Database.GetTheme(themeName)
    end
    return theme and theme.settings
end


function Database.ValidateContentText(text, kind, label)
    local limit = addon.ContentTextLimits[kind]
    if type(text) ~= "string" or #text > limit then
        return false, label .. " cannot exceed " .. limit .. " bytes."
    end
    return true
end


function Database.CopyProfileSettings(source)
    return CopyProfileSettings(source)
end


function Database.CopyThemeSettings(source)
    return CopyThemeSettings(source)
end


function Database.ResetGlobalSettings()
    RPEmoteMenuDB.globalSettings = NormalizeGlobalSettings(globalDefaults)
end


function Database.ResetWindowLayout()
    local settings = Database.GetProfileSettings()

    for _, key in ipairs({"point", "relativePoint", "x", "y", "height"}) do
        settings[key] = profileDefaults[key]
    end
end


function Database.IsDefaultProfile()
    return Database.GetActiveProfileName() == DEFAULT_PROFILE_NAME
end


function Database.CanEditActiveProfile()
    return true
end


function Database.CanRenameOrDeleteActiveProfile()
    return not Database.IsDefaultProfile()
end


function Database.GetCategories()
    return Database.GetActiveProfile().categories
end


function Database.GetCategory(categoryIndex)
    return Database.GetCategories()[categoryIndex]
end


-- Pending content dialogs bind to actual saved records, not mutable slot numbers.
-- A category/all-category operation also captures its contained emote identities.
function Database.CaptureContentTarget(categoryIndex, emoteIndex)
    local profile = Database.GetActiveProfile()
    local target = {profile = profile, categories = profile.categories,
        categoryIndex = categoryIndex, emoteIndex = emoteIndex, records = {}}
    local first, last = categoryIndex or 1, categoryIndex or MAX_CATEGORIES
    for index = first, last do
        local category = profile.categories[index]
        if not category then return nil end
        local record = {category = category, emotes = category.emotes, records = {}}
        local startEmote, endEmote = emoteIndex or 1, emoteIndex or MAX_EMOTES
        for slot = startEmote, endEmote do
            if not category.emotes[slot] then return nil end
            record.records[slot] = category.emotes[slot]
        end
        target.records[index] = record
    end
    return target
end

function Database.IsCurrentContentTarget(target)
    if not target or target.profile ~= Database.GetActiveProfile()
        or target.categories ~= Database.GetCategories() then return false end
    for index, record in pairs(target.records) do
        local category = target.categories[index]
        if category ~= record.category or category.emotes ~= record.emotes then
            return false
        end
        for slot, emote in pairs(record.records) do
            if category.emotes[slot] ~= emote then return false end
        end
    end
    return true
end


local function FindProfileByName(profileName)
    local requestedName = string.lower(profileName)

    for existingName in pairs(RPEmoteMenuDB.profiles) do
        if string.lower(existingName) == requestedName then
            return existingName
        end
    end

    return nil
end


local function CopyBuiltInTheme(definition)
    return {settings = CopyThemeSettings(definition.settings)}
end


local function InstallBuiltInThemes()
    for _, definition in ipairs(builtInThemes) do
        if type(RPEmoteMenuDB.themes[definition.name]) ~= "table" then
            RPEmoteMenuDB.themes[definition.name] = CopyBuiltInTheme(definition)
        end
    end
end


local function ValidateNewProfileName(profileName, existingProfileName)
    if type(profileName) ~= "string" then
        return nil, "Enter a profile name."
    end

    profileName = strtrim(profileName)

    if profileName == "" then
        return nil, "Enter a profile name."
    end
    if #profileName > MAX_PROFILE_NAME_LENGTH then
        return nil, "Profile names cannot exceed 64 characters."
    end
    if string.lower(profileName) == string.lower(DEFAULT_PROFILE_NAME) then
        return nil, "Default is reserved and cannot be changed."
    end

    local matchingProfile = FindProfileByName(profileName)
    if matchingProfile and matchingProfile ~= existingProfileName then
        return nil, "A profile with that name already exists."
    end
    if matchingProfile == existingProfileName and profileName == existingProfileName then
        return nil, "Enter a different profile name."
    end

    return profileName
end


function Database.ValidateNewProfileName(profileName, existingProfileName)
    return ValidateNewProfileName(profileName, existingProfileName)
end


local function FindThemeByName(themeName)
    local requestedName = string.lower(themeName)
    for existingName in pairs(RPEmoteMenuDB.themes) do
        if type(existingName) == "string"
            and string.lower(existingName) == requestedName then
            return existingName
        end
    end
    return nil
end


local function ValidateNewThemeName(themeName, existingThemeName)
    if type(themeName) ~= "string" then
        return nil, "Enter a theme name."
    end

    themeName = strtrim(themeName)
    if themeName == "" then
        return nil, "Enter a theme name."
    end
    if #themeName > MAX_THEME_NAME_LENGTH then
        return nil, "Theme names cannot exceed 64 characters."
    end
    if string.lower(themeName) == string.lower(DEFAULT_THEME_NAME) then
        return nil, "Default is reserved and cannot be changed."
    end

    local matchingTheme = FindThemeByName(themeName)
    if matchingTheme and matchingTheme ~= existingThemeName then
        return nil, "A theme with that name already exists."
    end
    if matchingTheme == existingThemeName and themeName == existingThemeName then
        return nil, "Enter a different theme name."
    end

    return themeName
end


function Database.ValidateNewThemeName(themeName, existingThemeName)
    return ValidateNewThemeName(themeName, existingThemeName)
end


-- Retire Theme previews before changing selection or replacing saved data.
local function CancelThemeColorEdit()
    if addon.SettingsUI and addon.SettingsUI.CancelColorEdit then
        addon.SettingsUI.CancelColorEdit()
    end
end

function Database.SetActive(active)
    RPEmoteMenuDB.globalSettings.active = active == true
    if not active then CancelThemeColorEdit() end
    if addon.MainWindow and addon.MainWindow.ApplyActivation then
        addon.MainWindow.ApplyActivation()
    end
    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    end
end

local function RefreshSettingsViews()
    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    else
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors()
        end
        if addon.Settings and addon.Settings.RefreshProfiles then
            addon.Settings.RefreshProfiles()
        end
    end
end


local function RefreshProfileViews()
    if addon.MainWindow and addon.MainWindow.ApplyProfileSettings then
        addon.MainWindow.ApplyProfileSettings()
    elseif addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end
    RefreshSettingsViews()
end


local function RefreshThemeViews()
    if addon.MainWindow and addon.MainWindow.ApplyThemeSettings then
        addon.MainWindow.ApplyThemeSettings()
    end
    RefreshSettingsViews()
end


function Database.GetProfileNames()
    local names = {}

    for profileName in pairs(RPEmoteMenuDB.profiles) do
        names[#names + 1] = profileName
    end

    table.sort(names, function(first, second)
        if first == DEFAULT_PROFILE_NAME then
            return true
        end
        if second == DEFAULT_PROFILE_NAME then
            return false
        end

        local firstLower = string.lower(first)
        local secondLower = string.lower(second)
        return firstLower == secondLower and first < second or firstLower < secondLower
    end)

    return names
end


function Database.GetThemeNames()
    local names = {}
    for themeName in pairs(RPEmoteMenuDB.themes) do
        names[#names + 1] = themeName
    end
    table.sort(names, function(first, second)
        if first == DEFAULT_THEME_NAME then return true end
        if second == DEFAULT_THEME_NAME then return false end
        local firstLower, secondLower = string.lower(first), string.lower(second)
        return firstLower == secondLower and first < second
            or firstLower < secondLower
    end)
    return names
end


function Database.GetProfilesUsingTheme(themeName)
    local names = {}
    if type(themeName) ~= "string" then return names end
    for _, profileName in ipairs(Database.GetProfileNames()) do
        if RPEmoteMenuDB.profiles[profileName].theme == themeName then
            names[#names + 1] = profileName
        end
    end
    return names
end


function Database.IsBuiltInThemeName(themeName)
    return builtInThemeByName[themeName] ~= nil
end


function Database.GetThemeDescription(themeName)
    if themeName == DEFAULT_THEME_NAME then
        return "Editable built-in fallback theme. Its name is reserved."
    end
    local definition = builtInThemeByName[themeName]
    return definition and definition.description or "Custom theme."
end


function Database.GetProfileDisplayName(profileName)
    return profileName
end


function Database.GetProfileDescription(profileName)
    if profileName == DEFAULT_PROFILE_NAME then
        return "Editable built-in fallback profile. Its name is reserved."
    end

    return "Custom profile."
end


function Database.SetProfileTheme(profileName, themeName)
    local profile = Database.GetProfile(profileName)
    if type(profile) ~= "table" then
        return false, "That profile does not exist."
    end
    if not Database.GetTheme(themeName) then
        return false, "That theme does not exist."
    end

    CancelThemeColorEdit()
    profile.theme = themeName
    if profileName == Database.GetActiveProfileName() then
        RefreshThemeViews()
    else
        RefreshSettingsViews()
    end
    return true
end


function Database.CreateTheme(themeName, sourceSettings)
    local validName, errorMessage = ValidateNewThemeName(themeName)
    if not validName then return false, errorMessage end

    local settingsSource = type(sourceSettings) == "table"
        and sourceSettings or Database.GetThemeSettings()
    RPEmoteMenuDB.themes[validName] = {
        settings = CopyThemeSettings(settingsSource)
    }
    RefreshSettingsViews()
    return true, validName
end


function Database.CopyTheme(sourceThemeName, newThemeName)
    local source = Database.GetTheme(sourceThemeName)
    if not source then return false, "The source theme does not exist." end
    return Database.CreateTheme(newThemeName, source.settings)
end


function Database.RenameTheme(oldThemeName, newThemeName)
    if oldThemeName == DEFAULT_THEME_NAME then
        return false, "The Default theme cannot be renamed."
    end
    local theme = Database.GetTheme(oldThemeName)
    if not theme then return false, "That theme does not exist." end

    local validName, errorMessage = ValidateNewThemeName(newThemeName, oldThemeName)
    if not validName then return false, errorMessage end

    CancelThemeColorEdit()
    RPEmoteMenuDB.themes[validName] = theme
    RPEmoteMenuDB.themes[oldThemeName] = nil
    for _, profile in pairs(RPEmoteMenuDB.profiles) do
        if profile.theme == oldThemeName then
            profile.theme = validName
        end
    end
    if Database.GetActiveThemeName() == validName then
        RefreshThemeViews()
    else
        RefreshSettingsViews()
    end
    return true, validName
end


function Database.DeleteTheme(themeName, confirmedInUse)
    if themeName == DEFAULT_THEME_NAME then
        return false, "The Default theme cannot be deleted."
    end
    if not Database.GetTheme(themeName) then
        return false, "That theme does not exist."
    end

    local users = Database.GetProfilesUsingTheme(themeName)
    if #users > 0 and confirmedInUse ~= true then
        return false, "This theme is used by profiles.", users
    end

    CancelThemeColorEdit()
    for _, profileName in ipairs(users) do
        RPEmoteMenuDB.profiles[profileName].theme = DEFAULT_THEME_NAME
    end
    RPEmoteMenuDB.themes[themeName] = nil
    local activeProfileName = Database.GetActiveProfileName()
    local affected = false
    for _, profileName in ipairs(users) do
        if profileName == activeProfileName then affected = true end
    end
    if affected then
        RefreshThemeViews()
    else
        RefreshSettingsViews()
    end
    return true, users
end


-- Factory names obey the same case-insensitive uniqueness rule as CRUD/imports.
-- Preserve differently capitalized custom Themes rather than replacing them.
local function ValidateThemeRestoreName(themeName)
    for existingName in pairs(RPEmoteMenuDB.themes) do
        if existingName ~= themeName
            and string.lower(existingName) == string.lower(themeName) then
            return nil, 'Rename Theme "' .. existingName .. '" before restoring "' .. themeName .. '".'
        end
    end
    return true
end

function Database.RestoreTheme(themeName)
    local source
    if themeName == DEFAULT_THEME_NAME then
        source = themeDefaults
    else
        local definition = builtInThemeByName[themeName]
        source = definition and definition.settings
    end
    if not source then
        return false, "Only Default and bundled themes have factory settings."
    end

    local valid, errorMessage = ValidateThemeRestoreName(themeName)
    if not valid then return false, errorMessage end

    CancelThemeColorEdit()
    RPEmoteMenuDB.themes[themeName] = {settings = CopyThemeSettings(source)}
    if Database.GetActiveThemeName() == themeName then
        RefreshThemeViews()
    else
        RefreshSettingsViews()
    end
    return true
end


function Database.RestoreDefaultTheme()
    return Database.RestoreTheme(DEFAULT_THEME_NAME)
end


function Database.SetActiveProfile(profileName)
    if type(profileName) ~= "string"
        or type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        return false, "That profile does not exist."
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "The current character is not available yet."
    end

    CancelThemeColorEdit()
    RPEmoteMenuDB.activeProfiles[characterKey] = profileName
    RefreshProfileViews()
    return true
end


function Database.CreateProfile(profileName, sourceCategories, sourceSettings, sourceThemeName)
    local validName, errorMessage = ValidateNewProfileName(profileName)
    if not validName then
        return false, errorMessage
    end

    local characterKey = Database.GetCharacterKey()
    if not characterKey then
        return false, "The current character is not available yet."
    end
    if sourceThemeName ~= nil and not Database.GetTheme(sourceThemeName) then
        return false, "The source theme does not exist."
    end

    CancelThemeColorEdit()
    local settingsSource = type(sourceSettings) == "table"
        and sourceSettings
        or Database.GetProfileSettings()

    RPEmoteMenuDB.profiles[validName] = {
        theme = sourceThemeName or Database.GetActiveThemeName(),
        categories = type(sourceCategories) == "table"
            and CopyCategories(sourceCategories)
            or CopyDefaultCategories(),
        settings = CopyProfileSettings(settingsSource)
    }
    RPEmoteMenuDB.activeProfiles[characterKey] = validName

    RefreshProfileViews()
    return true, validName
end


function Database.CopyProfile(sourceProfileName, newProfileName)
    local source = RPEmoteMenuDB.profiles[sourceProfileName]
    if type(source) ~= "table" then
        return false, "The source profile does not exist."
    end

    return Database.CreateProfile(
        newProfileName, source.categories, source.settings, source.theme
    )
end


function Database.RenameProfile(oldProfileName, newProfileName)
    if oldProfileName == DEFAULT_PROFILE_NAME then
        return false, "The Default profile cannot be renamed."
    end

    local profile = RPEmoteMenuDB.profiles[oldProfileName]
    if type(profile) ~= "table" then
        return false, "That profile does not exist."
    end

    local validName, errorMessage = ValidateNewProfileName(newProfileName, oldProfileName)
    if not validName then
        return false, errorMessage
    end

    CancelThemeColorEdit()
    RPEmoteMenuDB.profiles[validName] = profile
    RPEmoteMenuDB.profiles[oldProfileName] = nil

    for characterKey, activeProfileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if activeProfileName == oldProfileName then
            RPEmoteMenuDB.activeProfiles[characterKey] = validName
        end
    end

    RefreshProfileViews()
    return true, validName
end


function Database.DeleteProfile(profileName)
    if profileName == DEFAULT_PROFILE_NAME then
        return false, "The Default profile cannot be deleted."
    end
    if type(RPEmoteMenuDB.profiles[profileName]) ~= "table" then
        return false, "That profile does not exist."
    end

    CancelThemeColorEdit()
    RPEmoteMenuDB.profiles[profileName] = nil

    for characterKey, activeProfileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if activeProfileName == profileName then
            RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
        end
    end

    RefreshProfileViews()
    return true
end


local function ImportedProfileName(sourceName)
    local baseName = strtrim(sourceName or "")
    if baseName == "" then
        baseName = "Imported Profile"
    end

    if string.lower(baseName) ~= string.lower(DEFAULT_PROFILE_NAME)
        and not FindProfileByName(baseName) then
        return baseName
    end

    local number = 1
    while true do
        local suffix = number == 1
            and " (Imported)"
            or " (Imported " .. number .. ")"
        local shortenedBase = strtrim(baseName:sub(1, MAX_PROFILE_NAME_LENGTH - #suffix))
        local candidate = shortenedBase .. suffix

        if not FindProfileByName(candidate) then
            return candidate
        end

        number = number + 1
    end
end


local function ImportedThemeName(sourceName)
    local baseName = strtrim(sourceName or "")
    if baseName == "" then baseName = "Imported Theme" end
    if string.lower(baseName) ~= string.lower(DEFAULT_THEME_NAME)
        and not FindThemeByName(baseName) then
        return baseName
    end

    local number = 1
    while true do
        local suffix = number == 1
            and " (Imported)" or " (Imported " .. number .. ")"
        local shortenedBase = strtrim(baseName:sub(1, MAX_THEME_NAME_LENGTH - #suffix))
        local candidate = shortenedBase .. suffix
        if not FindThemeByName(candidate) then return candidate end
        number = number + 1
    end
end


function Database.AddImportedThemes(importedThemes, deferRefresh)
    local createdNames, nameMap = {}, {}
    for _, imported in ipairs(importedThemes or {}) do
        local themeName = ImportedThemeName(imported.name)
        RPEmoteMenuDB.themes[themeName] = {
            settings = CopyThemeSettings(imported.settings)
        }
        nameMap[imported.name] = themeName
        createdNames[#createdNames + 1] = themeName
    end
    if not deferRefresh then RefreshSettingsViews() end
    return createdNames, nameMap
end


function Database.AddImportedProfiles(importedProfiles, themeNameMap, deferRefresh)
    local createdNames, missingThemes = {}, {}
    for _, imported in ipairs(importedProfiles or {}) do
        local profileName = ImportedProfileName(imported.name)
        local themeName = imported.theme
        if themeNameMap then
            themeName = themeNameMap[imported.theme]
        end
        if not Database.GetTheme(themeName) then
            missingThemes[#missingThemes + 1] = {
                profile = profileName, theme = imported.theme
            }
            themeName = DEFAULT_THEME_NAME
        end
        RPEmoteMenuDB.profiles[profileName] = {
            theme = themeName,
            categories = CopyCategories(imported.categories),
            settings = CopyProfileSettings(imported.settings)
        }
        createdNames[#createdNames + 1] = profileName
    end
    if not deferRefresh then RefreshSettingsViews() end
    return createdNames, missingThemes
end


function Database.AddImportedEverything(importedProfiles, importedThemes)
    local themeNames, themeNameMap = Database.AddImportedThemes(importedThemes, true)
    local profileNames, missingThemes = Database.AddImportedProfiles(
        importedProfiles, themeNameMap, true
    )
    RefreshSettingsViews()
    return profileNames, themeNames, missingThemes
end


function Database.InitializeDatabase()
    -- The former Global/Profile hybrid is intentionally not migrated.
    if type(RPEmoteMenuDB) ~= "table"
        or RPEmoteMenuDB.schemaVersion ~= SCHEMA_VERSION then
        RPEmoteMenuDB = {
            schemaVersion = SCHEMA_VERSION,
            globalSettings = NormalizeGlobalSettings(globalDefaults),
            profiles = {
                [DEFAULT_PROFILE_NAME] = {
                    theme = DEFAULT_THEME_NAME,
                    categories = CopyDefaultCategories(),
                    settings = CopyProfileSettings(profileDefaults)
                }
            },
            themes = {
                [DEFAULT_THEME_NAME] = {settings = CopyThemeSettings(themeDefaults)}
            },
            activeProfiles = {}
        }
        InstallBuiltInThemes()
    end

    RPEmoteMenuDB.globalSettings = NormalizeGlobalSettings(RPEmoteMenuDB.globalSettings)
    RPEmoteMenuDB.profiles = type(RPEmoteMenuDB.profiles) == "table"
        and RPEmoteMenuDB.profiles or {}
    RPEmoteMenuDB.themes = type(RPEmoteMenuDB.themes) == "table"
        and RPEmoteMenuDB.themes or {}
    RPEmoteMenuDB.activeProfiles = type(RPEmoteMenuDB.activeProfiles) == "table"
        and RPEmoteMenuDB.activeProfiles or {}

    for name, theme in pairs(RPEmoteMenuDB.themes) do
        if type(name) ~= "string" or name == "" or type(theme) ~= "table" then
            RPEmoteMenuDB.themes[name] = nil
        else
            theme.settings = CopyThemeSettings(theme.settings)
        end
    end
    if not RPEmoteMenuDB.themes[DEFAULT_THEME_NAME] then
        RPEmoteMenuDB.themes[DEFAULT_THEME_NAME] = {
            settings = CopyThemeSettings(themeDefaults)
        }
    end

    for name, profile in pairs(RPEmoteMenuDB.profiles) do
        if type(name) ~= "string" or name == "" or type(profile) ~= "table" then
            RPEmoteMenuDB.profiles[name] = nil
        else
            profile.categories = type(profile.categories) == "table"
                and NormalizeCategories(profile.categories) or CopyDefaultCategories()
            profile.settings = CopyProfileSettings(profile.settings)
            if type(profile.theme) ~= "string"
                or not RPEmoteMenuDB.themes[profile.theme] then
                profile.theme = DEFAULT_THEME_NAME
            end
        end
    end
    if not RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] then
        RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] = {
            theme = DEFAULT_THEME_NAME,
            categories = CopyDefaultCategories(),
            settings = CopyProfileSettings(profileDefaults)
        }
    end

    for characterKey, profileName in pairs(RPEmoteMenuDB.activeProfiles) do
        if type(characterKey) ~= "string" or characterKey == "" then
            RPEmoteMenuDB.activeProfiles[characterKey] = nil
        elseif type(profileName) ~= "string"
            or not RPEmoteMenuDB.profiles[profileName] then
            RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
        end
    end
    local characterKey = Database.GetCharacterKey()
    if characterKey and not RPEmoteMenuDB.activeProfiles[characterKey] then
        RPEmoteMenuDB.activeProfiles[characterKey] = DEFAULT_PROFILE_NAME
    end
end


function Database.RestoreBuiltInThemes()
    local valid, errorMessage = ValidateThemeRestoreName(DEFAULT_THEME_NAME)
    if not valid then return nil, errorMessage end
    -- Validate the entire batch before resetting any preset or cancelling previews.
    for _, definition in ipairs(builtInThemes) do
        local valid, errorMessage = ValidateThemeRestoreName(definition.name)
        if not valid then return nil, errorMessage end
    end
    CancelThemeColorEdit()
    RPEmoteMenuDB.themes[DEFAULT_THEME_NAME] = {settings = CopyThemeSettings(themeDefaults)}
    for _, definition in ipairs(builtInThemes) do
        RPEmoteMenuDB.themes[definition.name] = CopyBuiltInTheme(definition)
    end
    local activeTheme = Database.GetActiveThemeName()
    if activeTheme == DEFAULT_THEME_NAME or builtInThemeByName[activeTheme] then
        RefreshThemeViews()
    else
        RefreshSettingsViews()
    end
    return #builtInThemes + 1
end


function Database.RestoreProfile(profileName)
    if profileName ~= DEFAULT_PROFILE_NAME then
        return false, "Only the Default profile has factory settings."
    end
    CancelThemeColorEdit()
    RPEmoteMenuDB.profiles[DEFAULT_PROFILE_NAME] = {
        theme = DEFAULT_THEME_NAME,
        categories = CopyDefaultCategories(),
        settings = CopyProfileSettings(profileDefaults)
    }
    RefreshProfileViews()
    return true
end


function Database.RestoreDefaultProfile()
    return Database.RestoreProfile(DEFAULT_PROFILE_NAME)
end


function Database.ResetCategoryToDefaults(categoryIndex)
    if not Database.CanEditActiveProfile() then
        return false
    end

    Database.GetCategories()[categoryIndex] = CopyDefaultCategories()[categoryIndex]

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end

    addon.MainWindow.UpdateMenu()
    return true
end


function Database.ResetAllCategoriesToDefaults()
    if not Database.CanEditActiveProfile() then
        return false
    end

    Database.GetActiveProfile().categories = CopyDefaultCategories()

    if addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors()
    end

    addon.MainWindow.SetSelectedCategory(1)
    addon.MainWindow.UpdateMenu()
    return true
end


local function EmoteHasContent(emote)
    return type(emote) == "table" and (
        strtrim(NormalizeString(emote.label)) ~= ""
        or strtrim(NormalizeString(emote.defaultCommand)) ~= ""
        or strtrim(NormalizeString(emote.targetedCommand)) ~= ""
    )
end


function Database.DuplicateEmote(categoryIndex, emoteIndex)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile's emotes cannot be edited."
    end

    local category = Database.GetCategory(categoryIndex)
    local source = category and category.emotes and category.emotes[emoteIndex]
    if not EmoteHasContent(source) then
        return false, "That emote is empty."
    end

    for destinationIndex = 1, MAX_EMOTES do
        if not EmoteHasContent(category.emotes[destinationIndex]) then
            category.emotes[destinationIndex] = {
                label = NormalizeString(source.label),
                defaultCommand = NormalizeString(source.defaultCommand),
                targetedCommand = NormalizeString(source.targetedCommand)
            }
            return true, destinationIndex
        end
    end

    return false, "This category already has ten emotes."
end


function Database.DuplicateCategory(categoryIndex)
    if not Database.CanEditActiveProfile() then
        return false, "The Default profile's categories cannot be edited."
    end

    local categories = Database.GetCategories()
    local source = categories[categoryIndex]
    if type(source) ~= "table" then
        return false, "That category does not exist."
    end

    local destinationIndex
    for index = 1, MAX_CATEGORIES do
        local category = categories[index]
        local empty = index ~= categoryIndex
            and type(category) == "table"
            and strtrim(NormalizeString(category.name)) == ""

        for emoteIndex = 1, MAX_EMOTES do
            if empty and EmoteHasContent(category.emotes and category.emotes[emoteIndex]) then
                empty = false
            end
        end

        if empty then
            destinationIndex = index
            break
        end
    end

    if not destinationIndex then
        return false, "This profile already has ten categories."
    end

    local baseName = strtrim(NormalizeString(source.name))
    if baseName == "" then
        baseName = "Category " .. categoryIndex
    end
    local function CopyName(number)
        local suffix = number == 1 and " Copy" or " Copy " .. number
        local cut = math.min(#baseName, addon.ContentTextLimits.categoryName - #suffix)
        -- Do not split a UTF-8 character when shortening the generated copy name.
        while cut > 0 and baseName:byte(cut + 1)
            and baseName:byte(cut + 1) >= 128 and baseName:byte(cut + 1) < 192 do
            cut = cut - 1
        end
        return baseName:sub(1, cut) .. suffix
    end
    local copyName = CopyName(1)
    local suffix = 2
    local names = {}
    for _, category in ipairs(categories) do
        names[string.lower(strtrim(NormalizeString(category.name)))] = true
    end
    while names[string.lower(copyName)] do
        copyName = CopyName(suffix)
        suffix = suffix + 1
    end

    local copy = {name = copyName, emotes = {}}
    for emoteIndex = 1, MAX_EMOTES do
        local sourceEmote = source.emotes and source.emotes[emoteIndex]
        copy.emotes[emoteIndex] = {
            label = NormalizeString(sourceEmote and sourceEmote.label),
            defaultCommand = NormalizeString(sourceEmote and sourceEmote.defaultCommand),
            targetedCommand = NormalizeString(sourceEmote and sourceEmote.targetedCommand)
        }
    end

    categories[destinationIndex] = copy
    return true, destinationIndex
end

