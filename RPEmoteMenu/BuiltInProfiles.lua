local _, addon = ...

-- Bundled profiles use the built-in emote categories. Settings intentionally
-- contain only each profile's visual design and dimensions; Database.lua fills
-- every omitted setting from the current defaults.
addon.BuiltInProfileVersion = 2

addon.BuiltInProfiles = {
    {
        name = "Gilded Shadow",
        description = "Black, gold, and cyan with a narrow, highly legible typeface.",
        settings = {
            backgroundOpacity = 0.6,
            borderColor = {r = 0, g = 0, b = 0},
            borderStyle = "blizzard",
            categoryBackgroundColor = {r = 0, g = 0, b = 0},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 18,
            categoryHighlightColor = {r = 0.2, g = 0.2, b = 0.2},
            categoryHighlightEffect = "separator",
            categoryHighlightThickness = 5,
            categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
            emoteBackgroundColor = {r = 0, g = 0, b = 0},
            emoteColumnWidth = 190,
            emoteFont = "Arial Narrow",
            emoteFontSize = 18,
            emoteTextColor = {r = 0.6, g = 0.9333334, b = 0.9333334},
            height = 310,
            selectedCategoryTextColor = {r = 0, g = 1, b = 1},
            sidebarWidth = 150,
            windowOpacity = 0.9
        }
    },
    {
        name = "Crimson Night",
        description = "A clean black-and-crimson design with strong contrast.",
        settings = {
            backgroundOpacity = 0.6,
            borderColor = {r = 0, g = 0, b = 0},
            borderStyle = "blizzard",
            categoryBackgroundColor = {r = 0, g = 0, b = 0},
            categoryFont = "Arial Narrow",
            categoryFontSize = 18,
            categoryHighlightColor = {r = 1, g = 0, b = 0},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
            emoteBackgroundColor = {r = 0, g = 0, b = 0},
            emoteColumnWidth = 200,
            emoteFont = "Arial Narrow",
            emoteFontSize = 18,
            emoteTextColor = {r = 1, g = 0, b = 0},
            height = 304,
            selectedCategoryTextColor = {r = 1, g = 1, b = 1},
            sidebarWidth = 145,
            windowOpacity = 0.9
        }
    },
    {
        name = "Teal",
        description = "Large teal text with a spacious, high-contrast layout.",
        settings = {
            backgroundOpacity = 1,
            borderColor = {r = 0.2, g = 0.2, b = 0.2},
            borderStyle = "thin",
            categoryBackgroundColor = {r = 0.12, g = 0.12, b = 0.12},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 21,
            categoryHighlightColor = {r = 0.4, g = 0.4, b = 0.4},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.8, g = 0.8, b = 0.8},
            emoteBackgroundColor = {r = 0.12, g = 0.12, b = 0.12},
            emoteColumnWidth = 239,
            emoteFont = "Arial Narrow",
            emoteFontSize = 21,
            emoteTextColor = {r = 0, g = 1, b = 1},
            height = 325,
            selectedCategoryTextColor = {r = 0, g = 1, b = 1},
            sidebarWidth = 175,
            windowOpacity = 1
        }
    },
    {
        name = "Joker",
        description = "An intentionally loud green-and-magenta fantasy theme.",
        settings = {
            backgroundOpacity = 0.6,
            borderColor = {r = 0.8, g = 0, b = 1},
            borderStyle = "none",
            categoryBackgroundColor = {r = 0.2, g = 1, b = 0.2},
            categoryFont = "Morpheus",
            categoryFontSize = 24,
            categoryHighlightColor = {r = 0.8, g = 0, b = 1},
            categoryHighlightEffect = "outline",
            categoryHighlightThickness = 1,
            categoryTextColor = {r = 0, g = 0, b = 0},
            emoteBackgroundColor = {r = 0, g = 1, b = 0},
            emoteColumnWidth = 310,
            emoteFont = "Arial Narrow",
            emoteFontSize = 24,
            emoteTextColor = {r = 1, g = 1, b = 1},
            height = 365,
            selectedCategoryTextColor = {r = 1, g = 1, b = 1},
            sidebarWidth = 175,
            windowOpacity = 0.9
        }
    },
    {
        name = "Moonlight",
        description = "A restrained blue-and-silver theme designed for easy reading.",
        settings = {
            backgroundOpacity = 0.9,
            borderColor = {r = 0.24, g = 0.35, b = 0.5},
            borderStyle = "thin",
            categoryBackgroundColor = {r = 0.04, g = 0.06, b = 0.12},
            categoryFont = "Friz Quadrata",
            categoryFontSize = 17,
            categoryHighlightColor = {r = 0.18, g = 0.32, b = 0.55},
            categoryHighlightEffect = "background",
            categoryHighlightThickness = 2,
            categoryTextColor = {r = 0.75, g = 0.82, b = 0.92},
            emoteBackgroundColor = {r = 0.03, g = 0.045, b = 0.09},
            emoteColumnWidth = 215,
            emoteFont = "Friz Quadrata",
            emoteFontSize = 17,
            emoteTextColor = {r = 0.78, g = 0.86, b = 1},
            height = 320,
            selectedCategoryTextColor = {r = 1, g = 1, b = 1},
            sidebarWidth = 150,
            windowOpacity = 1
        }
    }
}
