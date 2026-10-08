local _, addon = ...
local L = addon.L

-- Bundled Themes contain visual settings only. Database.lua fills omitted
-- values from the Default Theme without changing their factory definitions.
addon.BuiltInThemes = {
    {
        name = "Gilded Shadow",
        description = L.UI_BLACK_GOLD_AND_CYAN_WITH_A_NARROW_HIGHLY_LEGIBLE_TYPEFACE,
        settings = {
            categoryBackgroundColor = {r = 0, g = 0, b = 0},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 18,
            categoryHighlightColor = {r = 0.2, g = 0.2, b = 0.2},
            categoryHighlightEffect = "separator",
            categoryHighlightThickness = 5,
            categoryTextColor = {r = 1.8, g = 1.0, b = 0},
            emoteBackgroundColor = {r = 0, g = 0, b = 0},
            emoteFont = "Arial Narrow",
            emoteFontSize = 18,
            emoteTextColor = {r = 1.8, g = 1.0, b = 0},
            selectedCategoryTextColor = {r = 0, g = 1, b = 1},
            windowOpacity = 0.9
        }
    },
    {
        name = "Crimson Night",
        description = L.UI_A_CLEAN_BLACK_AND_CRIMSON_DESIGN_WITH_STRONG_CONTRAST,
        settings = {
            categoryBackgroundColor = {r = 0, g = 0, b = 0},
            categoryFont = "Arial Narrow",
            categoryFontSize = 18,
            categoryHighlightColor = {r = 1, g = 0, b = 0},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
            emoteBackgroundColor = {r = 0, g = 0, b = 0},
            emoteFont = "Arial Narrow",
            emoteFontSize = 18,
            emoteTextColor = {r = 1, g = 0, b = 0},
            selectedCategoryTextColor = {r = 1, g = 1, b = 1},
            titleBarPosition = "LEFT",
            windowOpacity = 0.9
        }
    },
    {
        name = "Teal",
        description = L.UI_LARGE_TEAL_TEXT_WITH_A_SPACIOUS_HIGH_CONTRAST_LAYOUT,
        settings = {
            categoryBackgroundColor = {r = 0.12, g = 0.12, b = 0.12},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 21,
            categoryHighlightColor = {r = 0.4, g = 0.4, b = 0.4},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
            emoteBackgroundColor = {r = 0.12, g = 0.12, b = 0.12},
            emoteFont = "Arial Narrow",
            emoteFontSize = 21,
            emoteTextColor = {r = 0, g = 1, b = 1},
            selectedCategoryTextColor = {r = 0, g = 1, b = 1},
            windowOpacity = 1
        }
    },
    {
        name = "High Contrast",
        description = L.UI_A_COLORBLIND_FRIENDLY_THEME_WITH_BRIGHT_TEXT_AND_A_BOLD,
        settings = {
            categoryBackgroundColor = {r = 0.0627451, g = 0.0941176, b = 0.1254902},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 21,
            categoryHighlightColor = {r = 0.9411765, g = 0.8941177, b = 0.2588235},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 1, g = 1, b = 1},
            emoteBackgroundColor = {r = 0.0627451, g = 0.0941176, b = 0.1254902},
            emoteFont = "Arial Narrow",
            emoteFontSize = 21,
            emoteTextColor = {r = 0.95, g = 0.95, b = 0.95},
            selectedCategoryTextColor = {r = 0.03, g = 0.03, b = 0.03},
            windowOpacity = 1
        }
    },
    {
        name = "Moonlight",
        description = L.UI_A_RESTRAINED_BLUE_AND_SILVER_THEME_DESIGNED_FOR_EASY_READING,
        settings = {
            categoryBackgroundColor = {r = 0.04, g = 0.06, b = 0.12},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 17,
            categoryHighlightColor = {r = 0.18, g = 0.32, b = 0.55},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.75, g = 0.82, b = 0.92},
            emoteBackgroundColor = {r = 0.03, g = 0.045, b = 0.09},
            emoteFont = "Friz Quadrata",
            emoteFontSize = 17,
            emoteTextColor = {r = 0.78, g = 0.86, b = 1},
            selectedCategoryTextColor = {r = 1, g = 1, b = 1},
            windowOpacity = 1
        }
    }
}

