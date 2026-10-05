local _, addon = ...

-- Shared metadata only. Saved-data recovery, transfer validation and UI unit
-- conversion stay in their callers; these definitions do not prescribe policy.
local definitions = {
    limits = {
        tooltipDelayMs = {min = 0, max = 1000},
        height = {min = 150, max = 630},
        position = {min = -100000, max = 100000},
        minimizedIconSize = {min = addon.MIN_MINIMIZED_ICON_SIZE, max = addon.MAX_MINIMIZED_ICON_SIZE},
        selectedCategory = {min = 1, max = addon.MAX_CATEGORIES},
        fadeDelay = {min = 0, max = 60},
        opacity = {min = 0.1, max = 1},
        fontSize = {min = 8, max = 24},
        highlightThickness = {min = 1, max = 6}
    },
    -- Database/transfer callers count bytes; native popup maxLetters counts
    -- characters. Sharing the number must not change either caller's units.
    nameLengths = {profile = 64, theme = 64, font = 128},
    colorKeys = {
        "categoryTextColor", "selectedCategoryTextColor", "emoteTextColor",
        "categoryHighlightColor", "categoryBackgroundColor", "emoteBackgroundColor",
        "minimizedIconColor"
    },
    enums = {
        minimizeMode = {values = {"NONE", "TITLE_BAR", "ICON"}},
        titleBarPosition = {values = {"TOP", "LEFT"}},
        categoryHighlightEffect = {values = {"background", "outline", "separator", "underline", "shadow"}},
        anchorPoint = {values = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}}
    }
}

-- Ordered values drive controls; membership uses the same values for validation.
for _, enum in pairs(definitions.enums) do
    enum.allowed = {}
    for _, value in ipairs(enum.values) do enum.allowed[value] = true end
end

addon.SettingDefinitions = definitions
