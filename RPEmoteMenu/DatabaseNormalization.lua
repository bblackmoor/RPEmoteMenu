local _, addon = ...
local definitions = addon.SettingDefinitions
local limits = definitions.limits
local defaultSections = addon.DefaultSections
local globalDefaults = addon.DefaultGlobalSettings
local profileDefaults = addon.DefaultProfileSettings
local themeDefaults = addon.DefaultThemeSettings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local VALID_CATEGORY_HIGHLIGHT_EFFECTS = definitions.enums.categoryHighlightEffect.allowed
local VALID_MINIMIZE_MODES = definitions.enums.minimizeMode.allowed
local VALID_TITLE_BAR_POSITIONS = definitions.enums.titleBarPosition.allowed
local VALID_ANCHOR_POINTS = definitions.enums.anchorPoint.allowed
local COLOR_SETTING_KEYS = definitions.colorKeys

-- No SavedVariables or presentation access. Normalization repairs records in
-- place; copies allocate independent records and preserve explicit Send flags.
local function NormalizeString(value)
    return type(value) == "string" and value or ""
end

-- Generated names have byte limits, but must end on a UTF-8 boundary.
local function TruncateUTF8(value, maximumBytes)
    local cut = math.min(#value, maximumBytes)
    while cut > 0 and value:byte(cut + 1)
        and value:byte(cut + 1) >= 128 and value:byte(cut + 1) < 192 do
        cut = cut - 1
    end
    return value:sub(1, cut)
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
                targetedCommand = NormalizeString(source and source[3]),
                defaultSend = addon.GetDefaultCommandSend(source and source[2]),
                targetedSend = addon.GetDefaultCommandSend(source and source[3])
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
            emote.defaultSend = addon.GetCommandSend(emote.defaultSend, emote.defaultCommand)
            emote.targetedSend = addon.GetCommandSend(emote.targetedSend, emote.targetedCommand)
        end
    end

    return categories
end


local function CopyEmote(source)
    return {
        label = NormalizeString(source and source.label),
        defaultCommand = NormalizeString(source and source.defaultCommand),
        targetedCommand = NormalizeString(source and source.targetedCommand),
        defaultSend = addon.GetCommandSend(source and source.defaultSend, source and source.defaultCommand),
        targetedSend = addon.GetCommandSend(source and source.targetedSend, source and source.targetedCommand)
    }
end

local function CopyCategory(sourceCategory)
    local category = {name = NormalizeString(sourceCategory and sourceCategory.name), emotes = {}}
    for emoteIndex = 1, MAX_EMOTES do
        local source = sourceCategory and sourceCategory.emotes and sourceCategory.emotes[emoteIndex]
        category.emotes[emoteIndex] = CopyEmote(source)
    end
    return category
end

local function CopyCategories(sourceCategories)
    local categories = {}
    sourceCategories = type(sourceCategories) == "table" and sourceCategories or {}
    for categoryIndex = 1, MAX_CATEGORIES do
        categories[categoryIndex] = CopyCategory(sourceCategories[categoryIndex])
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
        source.tooltipDelayMs, limits.tooltipDelayMs.min, limits.tooltipDelayMs.max, globalDefaults.tooltipDelayMs
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

    result.height = math.floor(ClampNumber(
        source.height, limits.height.min, limits.height.max, profileDefaults.height
    ))
    result.minimizedIconSize = math.floor(ClampNumber(
        source.minimizedIconSize,
        limits.minimizedIconSize.min,
        limits.minimizedIconSize.max,
        profileDefaults.minimizedIconSize
    ))
    result.x = math.floor(ClampNumber(
        source.x, limits.position.min, limits.position.max, profileDefaults.x
    ))
    result.y = math.floor(ClampNumber(
        source.y, limits.position.min, limits.position.max, profileDefaults.y
    ))

    if not VALID_ANCHOR_POINTS[result.point] then
        result.point = profileDefaults.point
    end
    if not VALID_ANCHOR_POINTS[result.relativePoint] then
        result.relativePoint = profileDefaults.relativePoint
    end
    if result.selectedCategory % 1 ~= 0
        or result.selectedCategory < limits.selectedCategory.min
        or result.selectedCategory > limits.selectedCategory.max then
        result.selectedCategory = profileDefaults.selectedCategory
    end

    result.fadeDelay = math.floor(ClampNumber(
        source.fadeDelay, limits.fadeDelay.min, limits.fadeDelay.max, profileDefaults.fadeDelay
    ))
    result.inactiveOpacity = ClampNumber(
        source.inactiveOpacity, limits.opacity.min, limits.opacity.max, profileDefaults.inactiveOpacity
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
        source.categoryFontSize, limits.fontSize.min, limits.fontSize.max, themeDefaults.categoryFontSize
    ))
    result.emoteFontSize = math.floor(ClampNumber(
        source.emoteFontSize, limits.fontSize.min, limits.fontSize.max, themeDefaults.emoteFontSize
    ))
    result.categoryHighlightThickness = math.floor(ClampNumber(
        source.categoryHighlightThickness,
        limits.highlightThickness.min,
        limits.highlightThickness.max,
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
        source.windowOpacity, limits.opacity.min, limits.opacity.max, themeDefaults.windowOpacity
    )

    return result
end


local function CopyProfileSettings(source)
    return NormalizeProfileSettings(source)
end


local function CopyThemeSettings(source)
    return NormalizeThemeSettings(source)
end


addon.DatabaseNormalization = {
    NormalizeString = NormalizeString,
    TruncateUTF8 = TruncateUTF8,
    CopyDefaultCategories = CopyDefaultCategories,
    NormalizeCategories = NormalizeCategories,
    CopyEmote = CopyEmote,
    CopyCategory = CopyCategory,
    CopyCategories = CopyCategories,
    NormalizeGlobalSettings = NormalizeGlobalSettings,
    CopyProfileSettings = CopyProfileSettings,
    CopyThemeSettings = CopyThemeSettings,
}
