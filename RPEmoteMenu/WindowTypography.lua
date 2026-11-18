-- Font application, pane-wide fallback, text measurement and bounded retries.
-- MainWindow owns frame construction, content updates and window geometry.
local _, addon = ...
local L = addon.L
local Typography = {}
addon.WindowTypography = Typography
local themeDefaults = addon.DefaultThemeSettings
local minimumUsableWidth = 220
local minimumSidebarWidth = addon.MIN_SIDEBAR_WIDTH
local maximumSidebarWidth = addon.MAX_SIDEBAR_WIDTH
local minimumEmoteColumnWidth = addon.MIN_EMOTE_COLUMN_WIDTH
local maximumEmoteColumnWidth = addon.MAX_EMOTE_COLUMN_WIDTH

local function ClampColumnWidth(value, minimum, maximum)
    value = math.ceil(tonumber(value) or minimum)
    return math.max(minimum, math.min(maximum, value))
end

function Typography.MeasureText(measurementText, text, fontName, fontSize)
    if not measurementText or type(text) ~= "string" or text == "" then
        return 0
    end

    local fontPath = addon.GetFontPath(fontName)
    -- A display/UI-scale change can leave cached glyph metrics at the old
    -- scale. Changing size first makes SetFont rebuild them before measuring.
    measurementText:SetFont(fontPath, fontSize + 1, "")
    if not measurementText:SetFont(fontPath, fontSize, "") then
        measurementText:SetFont(STANDARD_TEXT_FONT, fontSize, "")
    end
    measurementText:SetText(text)

    local width = measurementText.GetUnboundedStringWidth
        and measurementText:GetUnboundedStringWidth()
        or measurementText:GetStringWidth()

    if width <= 0 and fontPath ~= STANDARD_TEXT_FONT then
        measurementText:SetFont(STANDARD_TEXT_FONT, fontSize, "")
        measurementText:SetText(text)
        width = measurementText.GetUnboundedStringWidth
            and measurementText:GetUnboundedStringWidth()
            or measurementText:GetStringWidth()
    end

    return math.max(width or 0, 0)
end

function Typography.MeasureColumns(measurementText, categories, themeSettings, chromeWidth)
    local sidebarWidth, emoteColumnWidth
    local widestCategory = 0
    local widestEmote = 0

    for _, category in ipairs(categories) do
        local categoryName = strtrim(category.name or "")
        if categoryName ~= "" then
            widestCategory = math.max(
                widestCategory,
                Typography.MeasureText(
                    measurementText,
                    categoryName,
                    themeSettings.categoryFont,
                    themeSettings.categoryFontSize
                )
            )
        end

        for _, emote in ipairs(category.emotes or {}) do
            local label = strtrim(emote.label or "")
            if label ~= "" then
                widestEmote = math.max(
                    widestEmote,
                    Typography.MeasureText(
                        measurementText, label,
                        themeSettings.emoteFont,
                        themeSettings.emoteFontSize
                    )
                )
            end
        end
    end

    if widestCategory == 0 then
        widestCategory = Typography.MeasureText(
            measurementText, L.MENU_ADD_CATEGORY,
            themeSettings.categoryFont,
            themeSettings.categoryFontSize
        )
    end

    -- Category text uses 11 pixels inside its button plus 7 pixels of sidebar
    -- chrome. Emotes reserve room for their edit button, text padding, and an
    -- eight-pixel gap between the label and gear.
    sidebarWidth = ClampColumnWidth(
        widestCategory + 18,
        minimumSidebarWidth,
        maximumSidebarWidth
    )
    emoteColumnWidth = ClampColumnWidth(
        widestEmote + 39,
        minimumEmoteColumnWidth,
        maximumEmoteColumnWidth
    )

    -- Keep the emote column the same width when categories are toggled.
    local width = sidebarWidth + emoteColumnWidth + chromeWidth
    if width < minimumUsableWidth then
        emoteColumnWidth = math.min(
            maximumEmoteColumnWidth,
            emoteColumnWidth + minimumUsableWidth - width
        )
    end

    return sidebarWidth, emoteColumnWidth
end

function Typography.ApplyFont(fontString, fontName, size, color, forceRefresh)
    local _, currentSize, fontFlags = fontString:GetFont()
    local fontFile = addon.GetFontPath(fontName)
    local currentText = forceRefresh and fontString:GetText()

    if forceRefresh and currentSize == size then
        local refreshSize = size < 24 and size + 1 or size - 1
        fontString:SetFont(fontFile, refreshSize, fontFlags or "")
    end

    local applied = fontString:SetFont(fontFile, size, fontFlags or "")

    if not applied then
        fontString:SetFont(STANDARD_TEXT_FONT, size, fontFlags or "")
    end

    if forceRefresh and currentText then
        fontString:SetText("")
        fontString:SetText(currentText)
    end

    if applied
        and currentText
        and currentText ~= ""
        and fontString:GetStringWidth() <= 0 then
        applied = false
        fontString:SetFont(STANDARD_TEXT_FONT, size, fontFlags or "")
        fontString:SetText("")
        fontString:SetText(currentText)
    end

    fontString:SetTextColor(color.r, color.g, color.b, 1)
    return applied
end

function Typography.GetRowHeights(theme)
    return math.max(24, theme.categoryFontSize + 10), math.max(20, theme.emoteFontSize + 8)
end

-- Template fonts keep their original font, size, flags and color.
function Typography.RefreshTemplateFont(text)
    if not text then return end
    local file, size, flags = text:GetFont()
    if not file or not size then return end
    text:SetFont(file, size + 1, flags or "")
    text:SetFont(file, size, flags or "")
end

function Typography.ApplyRows(categoryButtons, buttonsPool, themeSettings, selectedCategoryIndex)
    local categoryButtonHeight, emoteButtonHeight = Typography.GetRowHeights(themeSettings)
    local categoryApplied, emoteApplied = true, true
    for _, button in ipairs(categoryButtons) do
        button:SetHeight(categoryButtonHeight)
        local textColor = button.categoryIndex == selectedCategoryIndex
            and themeSettings.selectedCategoryTextColor
            or themeSettings.categoryTextColor

        if not Typography.ApplyFont(
            button.Text,
            themeSettings.categoryFont,
            themeSettings.categoryFontSize,
            textColor,
            true
        ) then
            categoryApplied = false
        end

        for _, outlineText in ipairs(button.TextOutline) do
            if not Typography.ApplyFont(
                outlineText,
                themeSettings.categoryFont,
                themeSettings.categoryFontSize,
                themeSettings.categoryHighlightColor,
                true
            ) then
                categoryApplied = false
            end
        end
    end

    if not categoryApplied then
        for _, button in ipairs(categoryButtons) do
            local textColor = button.categoryIndex == selectedCategoryIndex
                and themeSettings.selectedCategoryTextColor
                or themeSettings.categoryTextColor
            Typography.ApplyFont(
                button.Text,
                themeDefaults.categoryFont,
                themeSettings.categoryFontSize,
                textColor,
                true
            )
            for _, outlineText in ipairs(button.TextOutline) do
                Typography.ApplyFont(
                    outlineText,
                    themeDefaults.categoryFont,
                    themeSettings.categoryFontSize,
                    themeSettings.categoryHighlightColor,
                    true
                )
            end
        end
    end

    for _, button in ipairs(buttonsPool) do
        button:SetHeight(emoteButtonHeight)
        if not Typography.ApplyFont(
            button.Text,
            themeSettings.emoteFont,
            themeSettings.emoteFontSize,
            themeSettings.emoteTextColor,
            true
        ) then
            emoteApplied = false
        end
    end

    if not emoteApplied then
        for _, button in ipairs(buttonsPool) do
            Typography.ApplyFont(
                button.Text,
                themeDefaults.emoteFont,
                themeSettings.emoteFontSize,
                themeSettings.emoteTextColor,
                true
            )
        end
    end

    return categoryApplied and emoteApplied
end

-- Each owner gets a distinct key and generation. Callbacks resolve current
-- settings/frames at dispatch time; canceled work cannot refresh a replacement.
function Typography.CreateRefreshQueue(refresh)
    local key, generation = {}, 0
    local retryDelays = {0.25, 0.75, 2, 5, 10, 12} -- At most thirty seconds.
    local function Cancel()
        addon.Scheduling.Cancel(key)
        generation = generation + 1
    end
    local function Schedule(skipImmediateRefresh)
        Cancel()
        local requestedGeneration = generation
        local function Attempt(retry)
            if requestedGeneration ~= generation then return end
            if refresh() then return end
            local delay = retryDelays[retry]
            if delay then
                addon.Scheduling.Replace(key, delay, function() Attempt(retry + 1) end)
            end
        end
        if skipImmediateRefresh then
            addon.Scheduling.Replace(key, 0, function() Attempt(1) end)
        else
            Attempt(1)
        end
    end
    return {Cancel = Cancel, Schedule = Schedule}
end
