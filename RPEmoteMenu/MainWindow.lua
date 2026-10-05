local _, addon = ...
local definitions = addon.SettingDefinitions
local limits = definitions.limits

addon.MainWindow = {}

local MainWindow = addon.MainWindow
local scheduleKeys = {tooltip = {}, font = {}, scroll = {}, pin = {}}
local Database = addon.Database
local globalDefaults = addon.DefaultGlobalSettings
local profileDefaults = addon.DefaultProfileSettings
local themeDefaults = addon.DefaultThemeSettings
local globalSettings
local profileSettings
local themeSettings

local function BindSettings()
    globalSettings = Database.GetGlobalSettings()
    profileSettings = Database.GetProfileSettings()
    themeSettings = Database.GetThemeSettings()
end
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local selectedCategoryIndex = 1

local function Trim(value)
    return strtrim(value or "")
end

local titleBarThickness = 32
local leftTitleBarWidth = 32
local columnChromeWidth = addon.COLUMN_CHROME_WIDTH
local minimumUsableWidth = 220
local minimumHeight = limits.height.min
local maximumHeight = limits.height.max
local minimumSidebarWidth = addon.MIN_SIDEBAR_WIDTH
local maximumSidebarWidth = addon.MAX_SIDEBAR_WIDTH
local minimumEmoteColumnWidth = addon.MIN_EMOTE_COLUMN_WIDTH
local maximumEmoteColumnWidth = addon.MAX_EMOTE_COLUMN_WIDTH
local sidebarWidth = minimumSidebarWidth
local emoteColumnWidth = minimumEmoteColumnWidth
local categoryButtonHeight = 24
local emoteButtonHeight = 20

local MainFrame
local TitleBar
local TitleText
local MinimizedIconButton
local CategorySidebar
local EmoteBackgroundTop
local EmoteBackgroundBottom
local EmoteBackgroundLeft
local EmoteBackgroundRight
local CategoryScrollFrame
local CategoryScrollChild
local CategoryEmptyLabel
local CategoryEmptyButton
local ScrollFrame
local ScrollChild
local EmoteEmptyButton
local ScrollTopIndicator
local ScrollBottomIndicator
local PinBtn
local SettingsBtn
local ResizeGrip
local WidthMeasurementText
local categoryButtons = {}
local buttonsPool = {}
local categoryDropIndicator
local categoryDragState
local emoteDropIndicator
local emoteDragState
local isWindowAutoHidden = false
local SetWindowAutoHidden
local isApplyingColumnSize = false
local isUserResizing = false
local fontRefreshGeneration = 0
local windowDragState
local appliedTitleBarPosition
local tooltipGeneration = 0
local tooltipOwner

local function CancelTooltip(owner)
    if owner and tooltipOwner ~= owner then
        return
    end

    addon.Scheduling.Cancel(scheduleKeys.tooltip)
    tooltipGeneration = tooltipGeneration + 1
    tooltipOwner = nil
    GameTooltip:Hide()
end

local function ScheduleTooltip(owner, populateTooltip)
    addon.Scheduling.Cancel(scheduleKeys.tooltip)
    tooltipGeneration = tooltipGeneration + 1
    local generation = tooltipGeneration
    tooltipOwner = owner
    GameTooltip:Hide()

    local function ShowIfStillHovered()
        if generation ~= tooltipGeneration
            or tooltipOwner ~= owner
            or not owner:IsShown()
            or not owner:IsMouseOver() then
            return
        end

        if populateTooltip() ~= false then
            GameTooltip:Show()
        end
    end

    local delayMs = math.max(
        limits.tooltipDelayMs.min,
        math.min(limits.tooltipDelayMs.max, tonumber(globalSettings.tooltipDelayMs) or globalDefaults.tooltipDelayMs)
    )
    if delayMs == 0 then
        ShowIfStillHovered()
    else
        addon.Scheduling.Replace(scheduleKeys.tooltip, delayMs / 1000, ShowIfStillHovered)
    end
end

local function IsTitleBarOnLeft()
    return themeSettings and themeSettings.titleBarPosition == "LEFT"
end

local function GetMinimizeMode()
    return profileSettings and profileSettings.minimizeMode or "NONE"
end

local function IsMinimizedToIcon()
    return GetMinimizeMode() == "ICON"
end

local function UsesMinimizedDisplay()
    return GetMinimizeMode() ~= "NONE"
end

local windowFade
local function GetWindowFade()
    if not windowFade then
        windowFade = addon.WindowFade.Create({
            GetFrame = function() return MainFrame end,
            GetIcon = function() return MinimizedIconButton end,
            GetProfile = function() return profileSettings end,
            GetTheme = function() return themeSettings end,
            IsHidden = function() return isWindowAutoHidden end,
            UsesMinimizedDisplay = UsesMinimizedDisplay,
            IsMinimizedToIcon = IsMinimizedToIcon,
            SetHidden = function(hidden) SetWindowAutoHidden(hidden) end,
        })
    end
    return windowFade
end

local function ScheduleWindowAutoHide() GetWindowFade().ScheduleAutoHide() end

local function GetContentWidth()
    return sidebarWidth + emoteColumnWidth + columnChromeWidth
end

local function GetExpandedWidth()
    return GetContentWidth() + (IsTitleBarOnLeft() and leftTitleBarWidth or 0)
end

local function GetCurrentFrameSize(width, height)
    return addon.WindowGeometry.GetFrameSize(width or GetExpandedWidth(),
        height or profileSettings.height, {
            hidden = isWindowAutoHidden, minimizeMode = GetMinimizeMode(),
            titleBarOnLeft = IsTitleBarOnLeft(), leftTitleBarWidth = leftTitleBarWidth,
            titleBarThickness = titleBarThickness,
        })
end

local function SetInternalFrameSize(width, height)
    isApplyingColumnSize = true
    MainFrame:SetSize(width, height)
    isApplyingColumnSize = false
end

local function SetCompactResizeBounds()
    MainFrame:SetResizeBounds(1, 1, GetExpandedWidth(), maximumHeight)
end

local function SetNormalResizeBounds()
    local width = GetExpandedWidth()
    MainFrame:SetResizeBounds(
        width,
        minimumHeight,
        width,
        maximumHeight
    )
end

local function IsWindowBodyHidden()
    return isWindowAutoHidden
end

function MainWindow.GetMinimizedIconButton()
    return MinimizedIconButton
end

local function UpdatePinButton()
    if not PinBtn or not profileSettings then
        return
    end

    PinBtn.Icon:SetDesaturated(not profileSettings.locked)
    PinBtn.Icon:SetAlpha(profileSettings.locked and 1 or 0.45)
end

local function RefreshGeneralWindowFields()
    if addon.Settings and addon.Settings.RefreshGeneralWindowFields then
        addon.Settings.RefreshGeneralWindowFields()
    end
end

local function ClampColumnWidth(value, minimum, maximum)
    value = math.ceil(tonumber(value) or minimum)
    return math.max(minimum, math.min(maximum, value))
end

local function MeasureText(text, fontName, fontSize)
    if not WidthMeasurementText or type(text) ~= "string" or text == "" then
        return 0
    end

    local fontPath = addon.GetFontPath(fontName)
    if not WidthMeasurementText:SetFont(fontPath, fontSize, "") then
        WidthMeasurementText:SetFont(STANDARD_TEXT_FONT, fontSize, "")
    end
    WidthMeasurementText:SetText(text)

    local width = WidthMeasurementText.GetUnboundedStringWidth
        and WidthMeasurementText:GetUnboundedStringWidth()
        or WidthMeasurementText:GetStringWidth()

    if width <= 0 and fontPath ~= STANDARD_TEXT_FONT then
        WidthMeasurementText:SetFont(STANDARD_TEXT_FONT, fontSize, "")
        WidthMeasurementText:SetText(text)
        width = WidthMeasurementText.GetUnboundedStringWidth
            and WidthMeasurementText:GetUnboundedStringWidth()
            or WidthMeasurementText:GetStringWidth()
    end

    return math.max(width or 0, 0)
end

local ApplyColumnLayout
local ApplyAutomaticWidth
local ApplyTitleBarLayout

local function CalculateColumnWidths()
    local widestCategory = 0
    local widestEmote = 0

    for _, category in ipairs(Database.GetCategories()) do
        local categoryName = Trim(category.name)
        if categoryName ~= "" then
            widestCategory = math.max(
                widestCategory,
                MeasureText(
                    categoryName,
                    themeSettings.categoryFont,
                    themeSettings.categoryFontSize
                )
            )
        end

        for _, emote in ipairs(category.emotes or {}) do
            local label = Trim(emote.label)
            if label ~= "" then
                widestEmote = math.max(
                    widestEmote,
                    MeasureText(
                        label,
                        themeSettings.emoteFont,
                        themeSettings.emoteFontSize
                    )
                )
            end
        end
    end

    if widestCategory == 0 then
        widestCategory = MeasureText(
            "Add Category",
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

    local width = GetContentWidth()
    if width < minimumUsableWidth then
        emoteColumnWidth = math.min(
            maximumEmoteColumnWidth,
            emoteColumnWidth + minimumUsableWidth - width
        )
        width = GetContentWidth()
    end

    return width + (IsTitleBarOnLeft() and leftTitleBarWidth or 0)
end

local function ClampWindowGeometry(x, y, width, height, allowOffscreen)
    return addon.WindowGeometry.Clamp(x, y, width, height, allowOffscreen, {
        screenWidth = UIParent:GetWidth(), screenHeight = UIParent:GetHeight(),
        expandedWidth = GetExpandedWidth(), savedHeight = profileSettings.height,
        defaultHeight = profileDefaults.height, savedX = profileSettings.x,
        savedY = profileSettings.y, minimumHeight = minimumHeight,
        maximumHeight = maximumHeight,
    })
end

function MainWindow.ApplyWindowGeometry(
    x, y, width, height, preserveAnchor, preserveProfileGeometry
)
    width = CalculateColumnWidths()
    x, y, width, height = ClampWindowGeometry(
        x,
        y,
        width,
        height,
        preserveAnchor
    )

    if not preserveProfileGeometry then
        if not preserveAnchor then
            profileSettings.point = "TOPLEFT"
            profileSettings.relativePoint = "BOTTOMLEFT"
        end
        profileSettings.x = x
        profileSettings.y = y
        profileSettings.height = height
    end

    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        profileSettings.point,
        UIParent,
        profileSettings.relativePoint,
        x,
        y
    )

    local frameWidth, frameHeight = GetCurrentFrameSize(width, height)
    SetInternalFrameSize(frameWidth, frameHeight)
    if IsWindowBodyHidden() then
        SetCompactResizeBounds()
    else
        SetNormalResizeBounds()
    end
    ApplyColumnLayout()

    RefreshGeneralWindowFields()
end

local function SaveWindowPosition()
    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()

    if not left or not top then
        return
    end

    -- Always save the window relative to its upper-left corner.
    profileSettings.point = "TOPLEFT"
    profileSettings.relativePoint = "BOTTOMLEFT"

    local width = GetExpandedWidth()
    local x, y = ClampWindowGeometry(left, top, width, profileSettings.height)
    profileSettings.x = x
    profileSettings.y = y

    RefreshGeneralWindowFields()
end

local function RestoreWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        profileSettings.point,
        UIParent,
        profileSettings.relativePoint,
        profileSettings.x,
        profileSettings.y
    )
end

local function SaveWindowSize()
    if not IsWindowBodyHidden() then
        local width = GetExpandedWidth()
        local left = MainFrame:GetLeft()
        local top = MainFrame:GetTop()
        local x, y, _, height = ClampWindowGeometry(
            left,
            top,
            width,
            MainFrame:GetHeight()
        )

        profileSettings.point = "TOPLEFT"
        profileSettings.relativePoint = "BOTTOMLEFT"
        profileSettings.x = x
        profileSettings.y = y
        profileSettings.height = height

        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end

    ApplyTitleBarLayout()
    RefreshGeneralWindowFields()
end

local function RestoreWindowSize()
    local width = CalculateColumnWidths()
    local height = math.max(
        minimumHeight,
        math.min(
            maximumHeight,
            math.floor(UIParent:GetHeight() + 0.5),
            math.floor(tonumber(profileSettings.height) or profileDefaults.height)
        )
    )

    -- Saved x/y are signed anchor offsets, not physical TOPLEFT coordinates.
    -- Restore them verbatim; movement/reset operations own on-screen clamping.
    profileSettings.height = height
    local frameWidth, frameHeight = GetCurrentFrameSize(width, height)
    SetInternalFrameSize(frameWidth, frameHeight)
    if IsWindowBodyHidden() then
        SetCompactResizeBounds()
    else
        SetNormalResizeBounds()
    end
    ApplyColumnLayout()

    RefreshGeneralWindowFields()
end

function MainWindow.ResetWindowPosition()
    Database.ResetWindowLayout()
    local width = CalculateColumnWidths()

    -- Restore the full-size frame before applying its default anchor so the
    -- same saved geometry is used whether the body is visible or hidden.
    isApplyingColumnSize = true
    MainFrame:SetSize(width, profileDefaults.height)
    isApplyingColumnSize = false
    RestoreWindowPosition()

    if IsWindowBodyHidden() then
        local frameWidth, frameHeight = GetCurrentFrameSize(width, profileDefaults.height)
        SetInternalFrameSize(frameWidth, frameHeight)
    end

    if IsWindowBodyHidden() then
        SetCompactResizeBounds()
    else
        SetNormalResizeBounds()
    end
    ApplyColumnLayout()
    RefreshGeneralWindowFields()
end

function MainWindow.CenterWindow()
    if not MainFrame then
        return
    end

    profileSettings.point = "CENTER"
    profileSettings.relativePoint = "CENTER"
    profileSettings.x = 0
    profileSettings.y = 0
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    RefreshGeneralWindowFields()
end

ApplyTitleBarLayout = function()
    if not MainFrame or not TitleBar or not TitleText
        or not PinBtn or not SettingsBtn then
        return
    end

    local fullTitle = "RP Emote Menu " .. addon.VERSION
    local shortTitle = "RP Emote Menu"

    TitleBar:ClearAllPoints()
    TitleText:ClearAllPoints()
    PinBtn:ClearAllPoints()
    SettingsBtn:ClearAllPoints()
    TitleText:SetWordWrap(false)

    if IsTitleBarOnLeft() then
        TitleBar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT")
        TitleBar:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT")
        TitleBar:SetWidth(leftTitleBarWidth)

        -- The 20px pin with a 6px inset shares the icon's 16px center.
        -- Keep both controls inside the bar, stacked above the title.
        PinBtn:SetPoint("TOP", TitleBar, "TOP", 0, -6)
        SettingsBtn:SetPoint("TOP", PinBtn, "BOTTOM", 0, -4)

        -- Reserve the top 60 pixels for controls and a gap before the text.
        -- The remaining title region has a six-pixel bottom margin.
        local availableLength = math.max(MainFrame:GetHeight() - 66, 1)
        TitleText:SetRotation(math.rad(90))
        TitleText:SetSize(availableLength, 20)
        TitleText:SetPoint("CENTER", TitleBar, "CENTER", 0, -27)
        TitleText:SetText(fullTitle)

        local textWidth = TitleText.GetUnboundedStringWidth
            and TitleText:GetUnboundedStringWidth()
            or TitleText:GetStringWidth()
        TitleBar.titleTextShortened = textWidth > availableLength
        if TitleBar.titleTextShortened then
            TitleText:SetText(shortTitle)
        end
    else
        TitleBar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT")
        TitleBar:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT")
        TitleBar:SetHeight(titleBarThickness)

        PinBtn:SetPoint("TOPRIGHT", TitleBar, "TOPRIGHT", -5, -5)
        SettingsBtn:SetPoint("RIGHT", PinBtn, "LEFT", -4, 0)

        TitleText:SetRotation(0)
        TitleText:SetSize(math.max(MainFrame:GetWidth() - 80, 1), 20)
        TitleText:SetPoint("TOPLEFT", TitleBar, "TOPLEFT", 10, -7)
        TitleText:SetText(fullTitle)
        TitleBar.titleTextShortened = false
    end
end

ApplyColumnLayout = function()
    if not MainFrame or not CategorySidebar or not CategoryScrollChild
        or not ScrollFrame or not ScrollChild then
        return
    end

    CategorySidebar:SetWidth(sidebarWidth)
    CategoryScrollChild:SetWidth(sidebarWidth - 7)
    if CategoryEmptyButton then
        CategoryEmptyButton:SetWidth(math.max(sidebarWidth - 14, 1))
    end

    for _, button in ipairs(categoryButtons) do
        button:SetWidth(sidebarWidth - 7)
    end

    local leftInset = IsTitleBarOnLeft() and leftTitleBarWidth or 0
    local categoryTop = IsTitleBarOnLeft() and -6 or -36
    local emoteTop = IsTitleBarOnLeft() and -10 or -40

    CategorySidebar:ClearAllPoints()
    CategorySidebar:SetPoint(
        "TOPLEFT",
        MainFrame,
        "TOPLEFT",
        leftInset + 5,
        categoryTop
    )
    CategorySidebar:SetPoint(
        "BOTTOMLEFT",
        MainFrame,
        "BOTTOMLEFT",
        leftInset + 5,
        10
    )

    -- The category background fills the sidebar. Fill only the remaining
    -- space with the emote color so opacity is applied once at every point.
    EmoteBackgroundTop:ClearAllPoints()
    EmoteBackgroundTop:SetPoint("TOPLEFT", MainFrame, "TOPLEFT")
    EmoteBackgroundTop:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT")
    EmoteBackgroundTop:SetHeight(-categoryTop)

    EmoteBackgroundBottom:ClearAllPoints()
    EmoteBackgroundBottom:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT")
    EmoteBackgroundBottom:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT")
    EmoteBackgroundBottom:SetHeight(10)

    EmoteBackgroundLeft:ClearAllPoints()
    EmoteBackgroundLeft:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 0, categoryTop)
    EmoteBackgroundLeft:SetPoint("BOTTOMRIGHT", CategorySidebar, "BOTTOMLEFT")

    EmoteBackgroundRight:ClearAllPoints()
    EmoteBackgroundRight:SetPoint("TOPLEFT", CategorySidebar, "TOPRIGHT")
    EmoteBackgroundRight:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", 0, 10)

    ScrollFrame:ClearAllPoints()
    ScrollFrame:SetPoint(
        "TOPLEFT",
        MainFrame,
        "TOPLEFT",
        leftInset + sidebarWidth + 10,
        emoteTop
    )
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild:SetWidth(emoteColumnWidth)
    if EmoteEmptyButton then
        EmoteEmptyButton:SetWidth(math.max(emoteColumnWidth - 5, 1))
    end

    for _, button in ipairs(buttonsPool) do
        button:SetWidth(math.max(emoteColumnWidth - 5, 1))
    end

    ApplyTitleBarLayout()

    RefreshGeneralWindowFields()
end

ApplyAutomaticWidth = function()
    if not MainFrame then
        return
    end

    local width = CalculateColumnWidths()
    local frameWidth = GetCurrentFrameSize(width, profileSettings.height)
    isApplyingColumnSize = true
    MainFrame:SetWidth(frameWidth)
    isApplyingColumnSize = false

    if IsWindowBodyHidden() then
        SetCompactResizeBounds()
    else
        SetNormalResizeBounds()
    end

    ApplyColumnLayout()
end

function MainWindow.ApplyMovementLock()
    local unlocked = not profileSettings.locked

    MainFrame:SetMovable(unlocked)
    MainFrame:SetResizable(unlocked)
    UpdatePinButton()

    if ResizeGrip then
        if unlocked and not IsWindowBodyHidden() then
            ResizeGrip:Show()
        else
            ResizeGrip:Hide()
        end
    end
end

function MainWindow.ApplySettingsGearVisibility()
    if not SettingsBtn then
        return
    end

    if globalSettings.hideSettingsGear
        or (isWindowAutoHidden and IsMinimizedToIcon()) then
        SettingsBtn:Hide()
    else
        SettingsBtn:Show()
    end
end

local function ApplyFont(fontString, fontName, size, color, forceRefresh)
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


local function SetWindowOpacity(targetOpacity, duration, onFinished)
    GetWindowFade().SetOpacity(targetOpacity, duration, onFinished)
end
local function CancelWindowAutoHide() GetWindowFade().CancelAutoHide() end
local function RestoreActiveOpacity(animate) GetWindowFade().RestoreActiveOpacity(animate) end
local function ScheduleInactiveFade() GetWindowFade().ScheduleInactiveFade() end
function MainWindow.NotifyActivity() GetWindowFade().NotifyActivity() end
function MainWindow.ApplyFadeSettings() GetWindowFade().ApplySettings() end

function MainWindow.RefreshFontDisplays(updateLayout)
    if not MainFrame then
        return false
    end

    local categoryApplied = true
    local emoteApplied = true
    categoryButtonHeight = math.max(24, themeSettings.categoryFontSize + 10)
    emoteButtonHeight = math.max(20, themeSettings.emoteFontSize + 8)

    -- Build and position every required button before applying fonts. Otherwise
    -- a newly created final label can miss the pane-wide consistency pass.
    if updateLayout ~= false then
        MainWindow.UpdateMenu()
    end

    for _, button in ipairs(categoryButtons) do
        button:SetHeight(categoryButtonHeight)
        local textColor = button.categoryIndex == selectedCategoryIndex
            and themeSettings.selectedCategoryTextColor
            or themeSettings.categoryTextColor

        if not ApplyFont(
            button.Text,
            themeSettings.categoryFont,
            themeSettings.categoryFontSize,
            textColor,
            true
        ) then
            categoryApplied = false
        end

        for _, outlineText in ipairs(button.TextOutline) do
            if not ApplyFont(
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
            ApplyFont(
                button.Text,
                themeDefaults.categoryFont,
                themeSettings.categoryFontSize,
                textColor,
                true
            )
            for _, outlineText in ipairs(button.TextOutline) do
                ApplyFont(
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
        if not ApplyFont(
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
            ApplyFont(
                button.Text,
                themeDefaults.emoteFont,
                themeSettings.emoteFontSize,
                themeSettings.emoteTextColor,
                true
            )
        end
    end

    local emoteColor = themeSettings.emoteTextColor
    if ScrollTopIndicator then
        ScrollTopIndicator:SetColorTexture(
            emoteColor.r, emoteColor.g, emoteColor.b, 1
        )
    end
    if ScrollBottomIndicator then
        ScrollBottomIndicator:SetColorTexture(
            emoteColor.r, emoteColor.g, emoteColor.b, 1
        )
    end

    if addon.Settings and addon.Settings.RefreshFontControls then
        addon.Settings.RefreshFontControls()
    end

    ApplyAutomaticWidth()

    return categoryApplied and emoteApplied
end

function MainWindow.RefreshFont()
    return MainWindow.RefreshFontDisplays()
end

-- Registration handles late providers. Retry only when actual text rendering
-- fails, and stop on success or when a newer Theme/font request supersedes it.
function MainWindow.ScheduleFontRefreshes(skipImmediateRefresh)
    addon.Scheduling.Cancel(scheduleKeys.font)
    fontRefreshGeneration = fontRefreshGeneration + 1
    local requestedGeneration = fontRefreshGeneration
    local retryDelays = {0.25, 0.75, 2, 5, 10, 12} -- At most thirty seconds.
    local function Attempt(retry)
        if requestedGeneration ~= fontRefreshGeneration then return end
        if MainWindow.RefreshFontDisplays(false) then return end
        local delay = retryDelays[retry]
        if delay then addon.Scheduling.Replace(scheduleKeys.font, delay, function() Attempt(retry + 1) end) end
    end
    if skipImmediateRefresh then
        addon.Scheduling.Replace(scheduleKeys.font, 0, function() Attempt(1) end)
    else
        Attempt(1)
    end
end

local function ApplyMainFrameBackdrop()
    local emoteBackground = themeSettings.emoteBackgroundColor
    MainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    -- In compact title-bar mode there are no body backgrounds. In the
    -- expanded window the four adjoining regions paint around the sidebar.
    MainFrame:SetBackdropColor(
        emoteBackground.r, emoteBackground.g, emoteBackground.b,
        IsWindowBodyHidden() and 1 or 0
    )
end

function MainWindow.ApplyAppearance()
    if not MainFrame then
        return
    end

    local categoryBackground = themeSettings.categoryBackgroundColor

    if not (isWindowAutoHidden and IsMinimizedToIcon()) then
        ApplyMainFrameBackdrop()
    end

    CategorySidebar:SetBackdropColor(
        categoryBackground.r,
        categoryBackground.g,
        categoryBackground.b,
        1
    )

    local emoteBackground = themeSettings.emoteBackgroundColor
    for _, region in ipairs({
        EmoteBackgroundTop, EmoteBackgroundBottom,
        EmoteBackgroundLeft, EmoteBackgroundRight
    }) do
        region:SetColorTexture(
            emoteBackground.r, emoteBackground.g, emoteBackground.b, 1
        )
    end

    MainWindow.RefreshFontDisplays()
    MainWindow.ApplyFadeSettings()
end

-- MENU RENDERING
function MainWindow.OpenEmoteEditor(categoryIndex, emoteIndex, isNew)
    addon.EmoteEditor.Open(categoryIndex, emoteIndex, isNew)
end

local function ApplyEmoteHoverHighlight(button)
    if not button or not button.HoverHighlight then
        return
    end

    if not button.isHovered then
        button.HoverHighlight:Hide()
        return
    end

    -- Keep emote hover related to the category selection color, but quieter.
    -- Blending it toward the emote pane background reduces its saturation and
    -- contrast without introducing another profile setting.
    local highlight = themeSettings.categoryHighlightColor
    local background = themeSettings.emoteBackgroundColor
    local blend = 0.45

    button.HoverHighlight:SetColorTexture(
        background.r + (highlight.r - background.r) * blend,
        background.g + (highlight.g - background.g) * blend,
        background.b + (highlight.b - background.b) * blend,
        0.75
    )
    button.HoverHighlight:Show()
end

local function SetEmoteHovered(button, isHovered)
    button.isHovered = isHovered
    ApplyEmoteHoverHighlight(button)
end

local function RefreshEmoteHovered(button)
    if not button or not button:IsShown() then
        return
    end

    local isHovered = button:IsMouseOver()
        or (button.EditButton and button.EditButton:IsMouseOver())
    SetEmoteHovered(button, isHovered)
end

local function ScheduleEmoteHoverRefresh(button)
    addon.Scheduling.NextTick(button, function()
        RefreshEmoteHovered(button)
    end)
end

local function PopulateEmoteTooltip(button, owner, editHint)
    if not button.emoteLabel or not button.defaultCommand then
        return false
    end

    GameTooltip:SetOwner(owner or button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.emoteLabel)
    GameTooltip:AddLine(
        "Default: " .. button.defaultCommand,
        0.9,
        0.9,
        0.9,
        true
    )

    if button.targetedCommand and button.targetedCommand ~= "" then
        GameTooltip:AddLine(
            "Targeted: " .. button.targetedCommand,
            0.75,
            0.85,
            1,
            true
        )
    end

    if editHint then
        GameTooltip:AddLine(editHint, 1, 0.82, 0, false)
    end

end

local function ApplyEmoteGearVisibility(button)
    local showGear = not globalSettings.hideSettingsGear
    button.EditButton:SetShown(showGear)
    button.EditHoverIcon:SetShown(showGear)
    button.Text:ClearAllPoints()
    button.Text:SetPoint("LEFT", button, "LEFT", 7, 0)
    if showGear then
        button.Text:SetPoint("RIGHT", button.EditButton, "LEFT", -8, 0)
    else
        button.Text:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    end
end

local function GetContainerButton()
    for _, button in ipairs(buttonsPool) do
        if not button:IsShown() then
            return button
        end
    end

    local button = CreateFrame("Button", nil, ScrollChild)
    button:SetSize(math.max(ScrollChild:GetWidth() - 5, 1), emoteButtonHeight)

    button.HoverHighlight = button:CreateTexture(nil, "BACKGROUND")
    button.HoverHighlight:SetAllPoints(button)
    button.HoverHighlight:Hide()

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("LEFT", button, "LEFT", 7, 0)
    button.EditButton = CreateFrame("Button", nil, button)
    button.EditButton:SetSize(16, 16)
    button.EditButton:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    button.EditButton:SetFrameLevel(button:GetFrameLevel() + 2)
    button.EditButton:RegisterForClicks("LeftButtonUp")
    button.EditButton.Icon = button.EditButton:CreateTexture(nil, "ARTWORK")
    button.EditButton.Icon:SetAllPoints(button.EditButton)
    button.EditButton.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    button.EditButton.Icon:SetAlpha(0.25)

    -- Native HIGHLIGHT layers follow WoW's actual mouse focus and cannot be
    -- left bright by missed or reordered OnEnter/OnLeave callbacks.
    button.EditHoverIcon = button:CreateTexture(nil, "HIGHLIGHT")
    button.EditHoverIcon:SetSize(16, 16)
    button.EditHoverIcon:SetPoint("CENTER", button.EditButton, "CENTER")
    button.EditHoverIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    button.EditHoverIcon:SetBlendMode("BLEND")
    button.EditButton:SetHighlightTexture(
        "Interface\\Buttons\\UI-OptionsButton",
        "BLEND"
    )
    button.EditButton:SetScript("OnEnter", function(self)
        SetEmoteHovered(button, true)
        ScheduleTooltip(self, function()
            return PopulateEmoteTooltip(button, self, "Click to edit")
        end)
    end)
    button.EditButton:SetScript("OnLeave", function(self)
        ScheduleEmoteHoverRefresh(button)
        CancelTooltip(self)
    end)

    button:SetScript("OnEnter", function(self)
        SetEmoteHovered(button, true)
        ScheduleTooltip(self, function()
            return PopulateEmoteTooltip(button, self, "Right-click to edit")
        end)
    end)
    button:SetScript("OnLeave", function(self)
        ScheduleEmoteHoverRefresh(button)
        CancelTooltip(self)
    end)

    button.Text:SetPoint("RIGHT", button.EditButton, "LEFT", -8, 0)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetWordWrap(false)
    ApplyFont(
        button.Text,
        themeSettings.emoteFont,
        themeSettings.emoteFontSize,
        themeSettings.emoteTextColor
    )

    table.insert(buttonsPool, button)
    return button
end

local function GetCurrentCategory(categoryIndex)
    return Database.GetCategory(categoryIndex)
end

local function IsCategoryVisible(categoryIndex)
    local category = GetCurrentCategory(categoryIndex)
    return category and Trim(category.name) ~= ""
end

local function FindFirstVisibleCategory()
    for categoryIndex = 1, MAX_CATEGORIES do
        if IsCategoryVisible(categoryIndex) then
            return categoryIndex
        end
    end

    return nil
end

local function IsEmoteVisible(emote)
    return emote
        and Trim(emote.label) ~= ""
        and Trim(emote.defaultCommand) ~= ""
end

local function GetVisibleEmotes(category)
    local visibleEmotes = {}

    if not category then
        return visibleEmotes
    end

    for emoteIndex = 1, MAX_EMOTES do
        local emote = category.emotes and category.emotes[emoteIndex]

        if IsEmoteVisible(emote) then
            table.insert(visibleEmotes, {
                emote = emote,
                index = emoteIndex
            })
        end
    end

    return visibleEmotes
end

local function GetVisibleCategories()
    local visibleCategories = {}

    for categoryIndex = 1, MAX_CATEGORIES do
        local category = GetCurrentCategory(categoryIndex)

        if IsCategoryVisible(categoryIndex) then
            table.insert(visibleCategories, {
                category = category,
                index = categoryIndex
            })
        end
    end

    return visibleCategories
end

local function HideCategoryDropIndicator()
    if categoryDropIndicator then
        categoryDropIndicator:Hide()
    end
end

local function ShowCategoryDropIndicator(button, insertBefore)
    if not categoryDropIndicator then
        categoryDropIndicator = CategoryScrollChild:CreateTexture(nil, "OVERLAY")
        categoryDropIndicator:SetHeight(2)
    end

    local color = themeSettings.categoryHighlightColor
    categoryDropIndicator:SetColorTexture(color.r, color.g, color.b, 1)
    categoryDropIndicator:ClearAllPoints()
    categoryDropIndicator:SetPoint("LEFT", button, "LEFT", 2, 0)
    categoryDropIndicator:SetPoint("RIGHT", button, "RIGHT", -2, 0)

    if insertBefore then
        categoryDropIndicator:SetPoint("BOTTOM", button, "TOP", 0, 1)
    else
        categoryDropIndicator:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end

    categoryDropIndicator:Show()
end

local function UpdateCategoryDragTarget(_, elapsed)
    if not categoryDragState then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local scrollTop = CategoryScrollFrame:GetTop()
    local scrollBottom = CategoryScrollFrame:GetBottom()
    local maximumScroll = math.max(
        CategoryScrollChild:GetHeight() - CategoryScrollFrame:GetHeight(),
        0
    )
    local currentScroll = CategoryScrollFrame:GetVerticalScroll() or 0
    local scrollSpeed = 140 * (elapsed or 0)

    if scrollTop and cursorY > scrollTop - 14 and currentScroll > 0 then
        CategoryScrollFrame:SetVerticalScroll(
            math.max(0, currentScroll - scrollSpeed)
        )
    elseif scrollBottom
        and cursorY < scrollBottom + 14
        and currentScroll < maximumScroll then
        CategoryScrollFrame:SetVerticalScroll(
            math.min(maximumScroll, currentScroll + scrollSpeed)
        )
    end

    categoryDragState.targetButton = nil
    categoryDragState.insertBefore = nil

    for _, button in ipairs(categoryButtons) do
        if button:IsShown() and button.visiblePosition then
            local left, right = button:GetLeft(), button:GetRight()
            local top, bottom = button:GetTop(), button:GetBottom()

            if left and right and top and bottom
                and cursorX >= left and cursorX <= right
                and cursorY <= top and cursorY >= bottom then
                categoryDragState.targetButton = button
                categoryDragState.insertBefore = cursorY >= ((top + bottom) / 2)
                ShowCategoryDropIndicator(button, categoryDragState.insertBefore)
                return
            end
        end
    end

    HideCategoryDropIndicator()
end

local function ReorderVisibleCategories(sourcePosition, insertionPosition)
    local categories = Database.GetCategories()
    local visibleIndices = {}
    for position, entry in ipairs(GetVisibleCategories()) do
        visibleIndices[position] = entry.index
    end

    local selectedCategory = categories[selectedCategoryIndex]
    if not addon.VisibleSlotOrder.Move(
        categories, visibleIndices, sourcePosition, insertionPosition
    ) then
        return false
    end

    -- Selection follows the same category object to its new visible slot.
    for _, categoryIndex in ipairs(visibleIndices) do
        if categories[categoryIndex] == selectedCategory then
            selectedCategoryIndex = categoryIndex
            profileSettings.selectedCategory = categoryIndex
        end
    end
    return true
end

local function StartCategoryDrag(button)
    if not Database.CanEditActiveProfile() or not button.visiblePosition then
        return
    end

    categoryDragState = {
        sourceButton = button,
        sourcePosition = button.visiblePosition
    }
    CancelTooltip()
    button:SetAlpha(0.45)
    button:SetScript("OnUpdate", UpdateCategoryDragTarget)
    UpdateCategoryDragTarget(button, 0)
end

local function StopCategoryDrag(button)
    if not categoryDragState or categoryDragState.sourceButton ~= button then
        return
    end

    UpdateCategoryDragTarget(button, 0)
    button:SetScript("OnUpdate", nil)
    button:SetAlpha(1)

    local target = categoryDragState.targetButton
    local changed = false
    if target then
        local insertionPosition = target.visiblePosition
            + (categoryDragState.insertBefore and 0 or 1)
        changed = ReorderVisibleCategories(
            categoryDragState.sourcePosition,
            insertionPosition
        )
    end

    categoryDragState = nil
    HideCategoryDropIndicator()

    if changed then
        local previousScroll = CategoryScrollFrame:GetVerticalScroll() or 0
        MainWindow.UpdateMenu()
        local maximumScroll = math.max(
            CategoryScrollChild:GetHeight() - CategoryScrollFrame:GetHeight(),
            0
        )
        CategoryScrollFrame:SetVerticalScroll(
            math.min(previousScroll, maximumScroll)
        )
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors()
        end
    end
end

local function HideEmoteDropIndicator()
    if emoteDropIndicator then
        emoteDropIndicator:Hide()
    end
end

local function ShowEmoteDropIndicator(button, insertBefore)
    if not emoteDropIndicator then
        emoteDropIndicator = ScrollChild:CreateTexture(nil, "OVERLAY")
        emoteDropIndicator:SetHeight(2)
    end

    local color = themeSettings.categoryHighlightColor
    emoteDropIndicator:SetColorTexture(color.r, color.g, color.b, 1)
    emoteDropIndicator:ClearAllPoints()
    emoteDropIndicator:SetPoint("LEFT", button, "LEFT", 2, 0)
    emoteDropIndicator:SetPoint("RIGHT", button, "RIGHT", -2, 0)

    if insertBefore then
        emoteDropIndicator:SetPoint("BOTTOM", button, "TOP", 0, 1)
    else
        emoteDropIndicator:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end

    emoteDropIndicator:Show()
end

local function UpdateEmoteDragTarget(_, elapsed)
    if not emoteDragState then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    -- Keep all ten possible rows reachable in a short window.
    local scrollTop = ScrollFrame:GetTop()
    local scrollBottom = ScrollFrame:GetBottom()
    local maximumScroll = math.max(
        ScrollChild:GetHeight() - ScrollFrame:GetHeight(),
        0
    )
    local currentScroll = ScrollFrame:GetVerticalScroll() or 0
    local scrollSpeed = 140 * (elapsed or 0)

    if scrollTop and cursorY > scrollTop - 14 and currentScroll > 0 then
        ScrollFrame:SetVerticalScroll(math.max(0, currentScroll - scrollSpeed))
    elseif scrollBottom
        and cursorY < scrollBottom + 14
        and currentScroll < maximumScroll then
        ScrollFrame:SetVerticalScroll(math.min(maximumScroll, currentScroll + scrollSpeed))
    end

    emoteDragState.targetButton = nil
    emoteDragState.insertBefore = nil

    for _, button in ipairs(buttonsPool) do
        if button:IsShown() and button.visiblePosition then
            local left, right = button:GetLeft(), button:GetRight()
            local top, bottom = button:GetTop(), button:GetBottom()

            if left and right and top and bottom
                and cursorX >= left and cursorX <= right
                and cursorY <= top and cursorY >= bottom then
                emoteDragState.targetButton = button
                emoteDragState.insertBefore = cursorY >= ((top + bottom) / 2)
                ShowEmoteDropIndicator(button, emoteDragState.insertBefore)
                return
            end
        end
    end

    HideEmoteDropIndicator()
end

local function ReorderVisibleEmotes(categoryIndex, sourcePosition, insertionPosition)
    local category = Database.GetCategory(categoryIndex)
    if not category then return false end

    local visibleIndices = {}
    for position, entry in ipairs(GetVisibleEmotes(category)) do
        visibleIndices[position] = entry.index
    end
    return addon.VisibleSlotOrder.Move(
        category.emotes, visibleIndices, sourcePosition, insertionPosition
    )
end

local function StartEmoteDrag(button)
    if not Database.CanEditActiveProfile() or not button.visiblePosition then
        return
    end

    emoteDragState = {
        sourceButton = button,
        sourcePosition = button.visiblePosition,
        categoryIndex = selectedCategoryIndex
    }
    CancelTooltip()
    button:SetAlpha(0.45)
    button:SetScript("OnUpdate", UpdateEmoteDragTarget)
    UpdateEmoteDragTarget(button, 0)
end

local function StopEmoteDrag(button)
    if not emoteDragState or emoteDragState.sourceButton ~= button then
        return
    end

    UpdateEmoteDragTarget(button, 0)
    button:SetScript("OnUpdate", nil)
    button:SetAlpha(1)
    button.suppressClick = true
    addon.Scheduling.Defer(function()
        button.suppressClick = false
    end)

    local target = emoteDragState.targetButton
    local changed = false
    if target then
        local insertionPosition = target.visiblePosition
            + (emoteDragState.insertBefore and 0 or 1)
        changed = ReorderVisibleEmotes(
            emoteDragState.categoryIndex,
            emoteDragState.sourcePosition,
            insertionPosition
        )
    end

    emoteDragState = nil
    HideEmoteDropIndicator()

    if changed then
        local previousScroll = ScrollFrame:GetVerticalScroll() or 0
        MainWindow.UpdateMenu()
        local maximumScroll = math.max(
            ScrollChild:GetHeight() - ScrollFrame:GetHeight(),
            0
        )
        ScrollFrame:SetVerticalScroll(math.min(previousScroll, maximumScroll))
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors(selectedCategoryIndex)
        end
    end
end

function MainWindow.ApplyCategoryHighlight(button, isSelected)
    button.Selection:Hide()
    button.SelectionUnderline:Hide()

    for _, edge in pairs(button.SelectionOutline) do
        edge:Hide()
    end
    for _, outlineText in ipairs(button.TextOutline) do
        outlineText:Hide()
    end

    button.Text:SetShadowColor(
        button.defaultShadowR,
        button.defaultShadowG,
        button.defaultShadowB,
        button.defaultShadowA
    )
    button.Text:SetShadowOffset(button.defaultShadowX, button.defaultShadowY)

    local strength = isSelected and 1 or (button.isHovered and 0.5 or 0)

    if strength == 0 then
        return
    end

    local color = themeSettings.categoryHighlightColor
    local effect = not isSelected and button.isHovered
        and "background"
        or themeSettings.categoryHighlightEffect

    if effect == "background" then
        button.Selection:SetColorTexture(
            color.r,
            color.g,
            color.b,
            0.85 * strength
        )
        button.Selection:Show()
    elseif effect == "outline" then
        local thickness = themeSettings.categoryHighlightThickness
        for _, outlineText in ipairs(button.TextOutline) do
            outlineText:ClearAllPoints()
            outlineText:SetPoint(
                "LEFT",
                button.Text,
                "LEFT",
                outlineText.offsetX * thickness,
                outlineText.offsetY * thickness
            )
            outlineText:SetPoint(
                "RIGHT",
                button.Text,
                "RIGHT",
                outlineText.offsetX * thickness,
                outlineText.offsetY * thickness
            )
            outlineText:SetTextColor(color.r, color.g, color.b, strength)
            outlineText:Show()
        end
    elseif effect == "underline" then
        button.SelectionUnderline:SetHeight(themeSettings.categoryHighlightThickness)
        button.SelectionUnderline:SetColorTexture(
            color.r, color.g, color.b, strength
        )
        button.SelectionUnderline:Show()
    elseif effect == "shadow" then
        button.Text:SetShadowColor(color.r, color.g, color.b, strength)
        button.Text:SetShadowOffset(2, -2)
    elseif effect == "separator" then
        button.SelectionOutline.right:SetWidth(themeSettings.categoryHighlightThickness)
        button.SelectionOutline.right:SetColorTexture(
            color.r, color.g, color.b, strength
        )
        button.SelectionOutline.right:Show()
    end
end

local function UpdateCategorySidebar()
    if not CategoryScrollChild then
        return
    end

    local visibleCount = 0

    for categoryIndex = 1, MAX_CATEGORIES do
        local button = categoryButtons[categoryIndex]
        local category = GetCurrentCategory(categoryIndex)

        if button and IsCategoryVisible(categoryIndex) then
            button:ClearAllPoints()
            button:SetPoint(
                "TOPLEFT",
                CategoryScrollChild,
                "TOPLEFT",
                0,
                -visibleCount * categoryButtonHeight
            )
            button.Text:SetText(category.name)
            button.visiblePosition = visibleCount + 1
            for _, outlineText in ipairs(button.TextOutline) do
                outlineText:SetText(category.name)
            end

            local isSelected = categoryIndex == selectedCategoryIndex
            MainWindow.ApplyCategoryHighlight(button, isSelected)

            local textColor = isSelected
                and themeSettings.selectedCategoryTextColor
                or themeSettings.categoryTextColor

            button.Text:SetTextColor(
                textColor.r,
                textColor.g,
                textColor.b,
                1
            )

            button:Show()
            visibleCount = visibleCount + 1
        elseif button then
            button.visiblePosition = nil
            button:Hide()
        end
    end

    CategoryScrollChild:SetHeight(math.max(visibleCount * categoryButtonHeight, 1))

    if visibleCount == 0 then
        CategoryEmptyLabel:Show()
        CategoryEmptyButton:Show()
    else
        CategoryEmptyLabel:Hide()
        CategoryEmptyButton:Hide()
    end

    local maximumScroll = math.max(
        CategoryScrollChild:GetHeight() - CategoryScrollFrame:GetHeight(),
        0
    )
    CategoryScrollFrame:SetVerticalScroll(
        math.min(CategoryScrollFrame:GetVerticalScroll() or 0, maximumScroll)
    )
end

local function UpdateScrollIndicators()
    if not ScrollFrame or not ScrollChild
        or not ScrollTopIndicator or not ScrollBottomIndicator
        or IsWindowBodyHidden() then
        if ScrollTopIndicator then
            ScrollTopIndicator:Hide()
        end

        if ScrollBottomIndicator then
            ScrollBottomIndicator:Hide()
        end

        return
    end

    local viewportHeight = ScrollFrame:GetHeight() or 0
    local contentHeight = ScrollChild:GetHeight() or 0
    local scrollOffset = ScrollFrame:GetVerticalScroll() or 0
    local maxScroll = math.max(contentHeight - viewportHeight, 0)
    local epsilon = 1

    if maxScroll <= epsilon then
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        return
    end

    if scrollOffset > epsilon then
        ScrollTopIndicator:Show()
    else
        ScrollTopIndicator:Hide()
    end

    if scrollOffset < maxScroll - epsilon then
        ScrollBottomIndicator:Show()
    else
        ScrollBottomIndicator:Hide()
    end
end

function MainWindow.UpdateMenu()
    CancelTooltip()
    MainWindow.NotifyActivity()
    ApplyAutomaticWidth()

    for _, button in ipairs(categoryButtons) do
        button:SetScript("OnUpdate", nil)
        button:SetAlpha(1)
    end
    categoryDragState = nil
    HideCategoryDropIndicator()

    for _, button in ipairs(buttonsPool) do
        button:SetScript("OnUpdate", nil)
        button:SetAlpha(1)
        SetEmoteHovered(button, false)
        button:Hide()
        button:ClearAllPoints()
        button:SetScript("OnClick", nil)
        button:SetScript("OnDragStart", nil)
        button:SetScript("OnDragStop", nil)
        button.EditButton:SetScript("OnClick", nil)
        button.emoteLabel = nil
        button.defaultCommand = nil
        button.targetedCommand = nil
    end

    emoteDragState = nil
    HideEmoteDropIndicator()

    if not IsCategoryVisible(selectedCategoryIndex) then
        selectedCategoryIndex = FindFirstVisibleCategory()
    end

    profileSettings.selectedCategory = selectedCategoryIndex or profileDefaults.selectedCategory
    UpdateCategorySidebar()

    if not selectedCategoryIndex then
        EmoteEmptyButton:Hide()
        ScrollChild:SetHeight(1)
        ScrollFrame:SetVerticalScroll(0)
        UpdateScrollIndicators()
        ScheduleInactiveFade()
        return
    end

    local category = GetCurrentCategory(selectedCategoryIndex)

    local visibleEmotes = GetVisibleEmotes(category)
    EmoteEmptyButton:SetShown(#visibleEmotes == 0)
    local dynamicY = 0

    for visiblePosition, visible in ipairs(visibleEmotes) do
        local emote = visible.emote
        local emoteIndex = visible.index
        local label = emote.label
        local defaultCommand = emote.defaultCommand
        local targetedCommand = emote.targetedCommand
        local emoteButton = GetContainerButton()
        emoteButton.visiblePosition = visiblePosition
        emoteButton.emoteIndex = emoteIndex
        emoteButton.emoteLabel = label
        emoteButton.defaultCommand = defaultCommand
        emoteButton.targetedCommand = targetedCommand
        emoteButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        ApplyEmoteGearVisibility(emoteButton)

        emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -dynamicY)
        emoteButton.Text:SetText(label)
        emoteButton.Text:SetTextColor(
            themeSettings.emoteTextColor.r,
            themeSettings.emoteTextColor.g,
            themeSettings.emoteTextColor.b,
            1
        )
        emoteButton:SetScript("OnClick", function(_, mouseButton)
            if emoteButton.suppressClick then
                return
            end
            if mouseButton == "RightButton" then
                MainWindow.OpenEmoteEditor(selectedCategoryIndex, emoteIndex)
                return
            end
            addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
            if profileSettings.fadeEnabled and UsesMinimizedDisplay() then
                SetWindowAutoHidden(true)
            end
        end)
        emoteButton:RegisterForDrag("LeftButton")
        emoteButton:SetScript("OnDragStart", StartEmoteDrag)
        emoteButton:SetScript("OnDragStop", StopEmoteDrag)
        emoteButton.EditButton:SetScript("OnClick", function()
            MainWindow.OpenEmoteEditor(selectedCategoryIndex, emoteIndex)
        end)
        emoteButton:Show()

        dynamicY = dynamicY + emoteButtonHeight + 2
    end

    ScrollChild:SetHeight(math.max(dynamicY, #visibleEmotes == 0 and 26 or 1))
    ScrollFrame:SetVerticalScroll(0)

    addon.Scheduling.NextTick(scheduleKeys.scroll, UpdateScrollIndicators)

    ScheduleInactiveFade()
end

-- WINDOW AUTO-HIDE
local function AnchorFrameByTopLeft()
    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()

    if left and top then
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

local function ApplyMinimizedIconAnchor()
    if not MinimizedIconButton or not MainFrame then
        return
    end

    -- Both bars meet at the frame's upper-left corner. Centering the icon
    -- there keeps it fixed through an orientation change at any icon size.
    MinimizedIconButton:ClearAllPoints()
    MinimizedIconButton:SetPoint("CENTER", MainFrame, "TOPLEFT", 16, -16)
end

local function UpdateWindowBodyVisibility()
    -- Keep the upper-left corner fixed while the hidden frame collapses toward
    -- whichever edge owns the title bar.
    AnchorFrameByTopLeft()
    local width = GetExpandedWidth()
    local compactWidth, compactHeight = GetCurrentFrameSize(
        width,
        profileSettings.height
    )

    if IsWindowBodyHidden() then
        local hiddenOpacity = math.min(
            profileSettings.inactiveOpacity,
            themeSettings.windowOpacity
        )
        SetCompactResizeBounds()
        CategorySidebar:Hide()
        ScrollFrame:Hide()
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        EmoteBackgroundTop:Hide()
        EmoteBackgroundBottom:Hide()
        EmoteBackgroundLeft:Hide()
        EmoteBackgroundRight:Hide()
        if IsMinimizedToIcon() then
            TitleBar:Hide()
            TitleText:Hide()
            PinBtn:Hide()
            SettingsBtn:Hide()
            MainFrame:SetBackdrop(nil)
            MainFrame:EnableMouse(false)
            MinimizedIconButton:SetSize(
                profileSettings.minimizedIconSize,
                profileSettings.minimizedIconSize
            )
            ApplyMinimizedIconAnchor()
            MinimizedIconButton:SetAlpha(hiddenOpacity)
            MinimizedIconButton:SetShown(MainFrame:IsShown())
            SetInternalFrameSize(compactWidth, compactHeight)
        else
            TitleBar:Show()
            TitleText:Show()
            PinBtn:Show()
            MinimizedIconButton:Hide()
            MainFrame:EnableMouse(true)
            ApplyMainFrameBackdrop()
            MainWindow.ApplySettingsGearVisibility()
            SetInternalFrameSize(compactWidth, compactHeight)
            SetWindowOpacity(hiddenOpacity)
        end
    else
        -- Restore the saved height before raising the minimum resize bound.
        -- Applying the normal bounds while the frame is still collapsed to
        -- titleBarThickness makes WoW clamp it to minimumHeight. OnSizeChanged
        -- then persists that clamped value over the user's chosen height.
        SetInternalFrameSize(width, profileSettings.height)
        SetNormalResizeBounds()
        TitleBar:Show()
        TitleText:Show()
        PinBtn:Show()
        MinimizedIconButton:SetAlpha(1)
        MinimizedIconButton:Hide()
        MainFrame:EnableMouse(true)
        ApplyMainFrameBackdrop()
        MainWindow.ApplySettingsGearVisibility()
        CategorySidebar:Show()
        ScrollFrame:Show()
        EmoteBackgroundTop:Show()
        EmoteBackgroundBottom:Show()
        EmoteBackgroundLeft:Show()
        EmoteBackgroundRight:Show()
        MainWindow.UpdateMenu()
        addon.Scheduling.NextTick(scheduleKeys.scroll, UpdateScrollIndicators)
    end

    ApplyColumnLayout()
    MainWindow.ApplyMovementLock()
end

function MainWindow.ApplyMinimizeToIconSettings()
    if not definitions.enums.minimizeMode.allowed[profileSettings.minimizeMode] then
        profileSettings.minimizeMode = "NONE"
    end
    profileSettings.minimizedIconSize = math.max(
        limits.minimizedIconSize.min,
        math.min(
            limits.minimizedIconSize.max,
            math.floor(tonumber(profileSettings.minimizedIconSize)
                or profileDefaults.minimizedIconSize)
        )
    )
    CancelWindowAutoHide()
    if not UsesMinimizedDisplay() then
        SetWindowAutoHidden(false)
    end
    ApplyMinimizedIconAnchor()
    UpdateWindowBodyVisibility()
    MainWindow.ApplyFadeSettings()
    RefreshGeneralWindowFields()
end

function MainWindow.ApplyTitleBarPosition(
    preserveSavedPosition, preserveProfileGeometry
)
    themeSettings.titleBarPosition = themeSettings.titleBarPosition == "LEFT"
        and "LEFT"
        or "TOP"

    local x, y = profileSettings.x, profileSettings.y
    if not preserveSavedPosition and appliedTitleBarPosition
        and appliedTitleBarPosition ~= themeSettings.titleBarPosition then
        -- Keep the frame's upper-left corner fixed. Its content moves when
        -- the title bar changes sides, but the icon anchor stays in place.
        local top = MainFrame:GetTop()
        if top then
            local left = MainFrame:GetLeft()
            if left then
                local width = CalculateColumnWidths()
                local frameWidth, frameHeight = GetCurrentFrameSize(width, profileSettings.height)
                x, y = addon.WindowGeometry.GetAnchorOffsets(left, top, {
                    point = profileSettings.point, relativePoint = profileSettings.relativePoint,
                    width = frameWidth, height = frameHeight,
                    screenWidth = UIParent:GetWidth(), screenHeight = UIParent:GetHeight(),
                })
            end
        end
    end

    MainWindow.ApplyWindowGeometry(
        x, y, nil, profileSettings.height, true, preserveProfileGeometry
    )
    appliedTitleBarPosition = themeSettings.titleBarPosition
    ApplyMinimizedIconAnchor()
    UpdateWindowBodyVisibility()
end

SetWindowAutoHidden = function(hidden)
    hidden = not not hidden

    if not profileSettings.fadeEnabled or not UsesMinimizedDisplay() then
        hidden = false
    end
    if isWindowAutoHidden == hidden then
        return
    end

    isWindowAutoHidden = hidden
    UpdateWindowBodyVisibility()
end

-- MAIN WINDOW
local function StartWindowMoving()
    if profileSettings.locked then
        return
    end

    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()
    if not left or not top then
        return
    end

    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    windowDragState = {
        cursorX = cursorX / scale,
        cursorY = cursorY / scale,
        left = left,
        top = top,
    }
end

local function StopWindowMoving()
    windowDragState = nil

    local left = MainFrame:GetLeft()
    local top = MainFrame:GetTop()
    if left and top then
        -- Clamp using the expanded dimensions, even while the window is
        -- collapsed, so restoring the menu cannot place part of it off-screen.
        MainWindow.ApplyWindowGeometry(left, top, nil, profileSettings.height)
    else
        SaveWindowPosition()
    end
end

local function UpdateWindowDrag()
    if not windowDragState then
        return false
    end

    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local left = windowDragState.left
        + (cursorX / scale) - windowDragState.cursorX
    local top = windowDragState.top
        + (cursorY / scale) - windowDragState.cursorY

    -- Calculate every position from the initial mouse/frame coordinates. This
    -- avoids both Blizzard's sticky edge clamping and the anchor-dependent
    -- jump produced by StartMoving() with the vertical title bar.
    left, top = ClampWindowGeometry(
        left,
        top,
        GetExpandedWidth(),
        profileSettings.height
    )
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    return true
end

local function CreateMainFrame()
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(
        GetExpandedWidth(),
        profileDefaults.height
    )
    WidthMeasurementText = MainFrame:CreateFontString(nil, "OVERLAY")
    WidthMeasurementText:SetAlpha(0)
    SetNormalResizeBounds()
    MainFrame:SetClampedToScreen(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    MainFrame:SetScript("OnDragStart", StartWindowMoving)
    MainFrame:SetScript("OnDragStop", StopWindowMoving)

    MainFrame:SetScript("OnSizeChanged", function(self, width, height)
        if isApplyingColumnSize then return end
        local automaticWidth = GetCurrentFrameSize(
            GetExpandedWidth(),
            profileSettings.height
        )
        if isUserResizing and not IsWindowBodyHidden() then
            profileSettings.height = math.max(
                minimumHeight,
                math.min(maximumHeight, math.floor(height + 0.5))
            )
        end
        if math.abs(width - automaticWidth) > 0.5 then
            isApplyingColumnSize = true
            self:SetWidth(automaticWidth)
            isApplyingColumnSize = false
        end
    end)


end

local function CreateTitleBar()
    TitleBar = CreateFrame("Frame", nil, MainFrame)
    TitleBar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT")
    TitleBar:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT")
    TitleBar:SetHeight(titleBarThickness)
    TitleBar:SetFrameLevel(MainFrame:GetFrameLevel() + 1)
    TitleBar:EnableMouse(true)
    TitleBar:RegisterForDrag("LeftButton")
    TitleBar:SetScript("OnDragStart", StartWindowMoving)
    TitleBar:SetScript("OnDragStop", StopWindowMoving)
    TitleBar:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            addon.Settings.Open()
        end
    end)
    TitleBar:SetScript("OnEnter", function(self)
        if self.titleTextShortened
            or (IsTitleBarOnLeft() and TitleText:IsTruncated()) then
            ScheduleTooltip(self, function()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("RP Emote Menu " .. addon.VERSION)
            end)
        end
    end)
    TitleBar:SetScript("OnLeave", function(self)
        CancelTooltip(self)
    end)

    TitleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    TitleText:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    TitleText:SetText("RP Emote Menu " .. addon.VERSION)
    TitleText:SetTextColor(1, 1, 1, 1)


end

local function CreateMinimizedIcon()
    MinimizedIconButton = CreateFrame("Button", nil, UIParent)
    ApplyMinimizedIconAnchor()
    MinimizedIconButton:SetSize(
        profileDefaults.minimizedIconSize,
        profileDefaults.minimizedIconSize
    )
    MinimizedIconButton:SetFrameStrata(MainFrame:GetFrameStrata())
    MinimizedIconButton:SetFrameLevel(MainFrame:GetFrameLevel() + 5)
    MinimizedIconButton.Icon = MinimizedIconButton:CreateTexture(nil, "ARTWORK")
    MinimizedIconButton.Icon:SetAllPoints(MinimizedIconButton)
    MinimizedIconButton.Icon:SetTexture(
        "Interface\\AddOns\\RPEmoteMenu\\Media\\icon-minimized.tga"
    )
    MinimizedIconButton:RegisterForDrag("LeftButton")
    MinimizedIconButton:SetScript("OnEnter", function()
        SetWindowAutoHidden(false)
        MainWindow.NotifyActivity()
    end)
    MinimizedIconButton:SetScript("OnDragStart", StartWindowMoving)
    MinimizedIconButton:SetScript("OnDragStop", StopWindowMoving)
    MinimizedIconButton:Hide()


end

local function CreateCategorySidebar()
    EmoteBackgroundTop = MainFrame:CreateTexture(nil, "BACKGROUND")
    EmoteBackgroundBottom = MainFrame:CreateTexture(nil, "BACKGROUND")
    EmoteBackgroundLeft = MainFrame:CreateTexture(nil, "BACKGROUND")
    EmoteBackgroundRight = MainFrame:CreateTexture(nil, "BACKGROUND")

    CategorySidebar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    CategorySidebar:SetWidth(sidebarWidth)
    CategorySidebar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -36)
    CategorySidebar:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 5, 10)
    CategorySidebar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    CategoryScrollFrame = CreateFrame("ScrollFrame", nil, CategorySidebar)
    CategoryScrollFrame:SetPoint("TOPLEFT", CategorySidebar, "TOPLEFT", 3, -3)
    CategoryScrollFrame:SetPoint("BOTTOMRIGHT", CategorySidebar, "BOTTOMRIGHT", -4, 3)
    CategoryScrollFrame:EnableMouseWheel(true)

    CategoryScrollChild = CreateFrame("Frame", nil, CategoryScrollFrame)
    CategoryScrollChild:SetSize(sidebarWidth - 7, 1)
    CategoryScrollFrame:SetScrollChild(CategoryScrollChild)
    CategoryScrollFrame:SetScript("OnMouseWheel", function(self, direction)
        local maximumScroll = math.max(
            CategoryScrollChild:GetHeight() - self:GetHeight(),
            0
        )
        local scroll = (self:GetVerticalScroll() or 0)
            - (direction * categoryButtonHeight)

        self:SetVerticalScroll(math.max(0, math.min(maximumScroll, scroll)))
    end)

    CategoryEmptyLabel = CategorySidebar:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontDisableSmall"
    )
    CategoryEmptyLabel:SetPoint("TOPLEFT", CategorySidebar, "TOPLEFT", 7, -9)
    CategoryEmptyLabel:SetPoint("TOPRIGHT", CategorySidebar, "TOPRIGHT", -7, -9)
    CategoryEmptyLabel:SetJustifyH("LEFT")
    CategoryEmptyLabel:SetText("No categories")
    CategoryEmptyLabel:Hide()

    CategoryEmptyButton = CreateFrame(
        "Button",
        nil,
        CategorySidebar,
        "UIPanelButtonTemplate"
    )
    CategoryEmptyButton:SetSize(math.max(sidebarWidth - 14, 1), 22)
    CategoryEmptyButton:SetPoint("TOPLEFT", CategorySidebar, "TOPLEFT", 7, -28)
    CategoryEmptyButton:SetText("Add Category")
    CategoryEmptyButton:SetScript("OnClick", function()
        if addon.Settings and addon.Settings.OpenEmotes then
            addon.Settings.OpenEmotes()
        end
    end)
    CategoryEmptyButton:Hide()

    for categoryIndex = 1, MAX_CATEGORIES do
        local button = CreateFrame("Button", nil, CategoryScrollChild)
        button:SetSize(sidebarWidth - 7, categoryButtonHeight)
        button.categoryIndex = categoryIndex

        button.Selection = button:CreateTexture(nil, "BACKGROUND")
        button.Selection:SetAllPoints(button)
        button.Selection:Hide()

        button.SelectionOutline = {
            top = button:CreateTexture(nil, "ARTWORK"),
            bottom = button:CreateTexture(nil, "ARTWORK"),
            left = button:CreateTexture(nil, "ARTWORK"),
            right = button:CreateTexture(nil, "ARTWORK")
        }

        button.SelectionOutline.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.SelectionOutline.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button.SelectionOutline.bottom:SetPoint(
            "BOTTOMLEFT",
            button,
            "BOTTOMLEFT",
            0,
            0
        )
        button.SelectionOutline.bottom:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            0,
            0
        )
        button.SelectionOutline.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.SelectionOutline.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button.SelectionOutline.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button.SelectionOutline.right:SetPoint(
            "BOTTOMRIGHT",
            button,
            "BOTTOMRIGHT",
            0,
            0
        )

        for _, edge in pairs(button.SelectionOutline) do
            edge:Hide()
        end

        button.SelectionUnderline = button:CreateTexture(nil, "ARTWORK")
        button.SelectionUnderline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button.SelectionUnderline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button.SelectionUnderline:Hide()

        button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.Text:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.Text:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        button.Text:SetJustifyH("LEFT")
        button.Text:SetWordWrap(false)
        button.TextOutline = {}
        for _, offset in ipairs({
            {-1, -1}, {-1, 0}, {-1, 1}, {0, -1},
            {0, 1}, {1, -1}, {1, 0}, {1, 1}
        }) do
            local outlineText = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            outlineText:SetPoint("LEFT", button.Text, "LEFT", offset[1], offset[2])
            outlineText:SetPoint("RIGHT", button.Text, "RIGHT", offset[1], offset[2])
            outlineText:SetJustifyH("LEFT")
            outlineText:SetWordWrap(false)
            outlineText:SetTextColor(1, 1, 1, 1)
            outlineText.offsetX = offset[1]
            outlineText.offsetY = offset[2]
            outlineText:Hide()
            button.TextOutline[#button.TextOutline + 1] = outlineText
        end
        button.defaultShadowX, button.defaultShadowY = button.Text:GetShadowOffset()
        button.defaultShadowR,
            button.defaultShadowG,
            button.defaultShadowB,
            button.defaultShadowA = button.Text:GetShadowColor()
        ApplyFont(
            button.Text,
            themeSettings.categoryFont,
            themeSettings.categoryFontSize,
            themeSettings.categoryTextColor
        )

        button:SetScript("OnEnter", function(self)
            self.isHovered = true
            if categoryDragState then
                return
            elseif self.categoryIndex ~= selectedCategoryIndex then
                MainWindow.SetSelectedCategory(self.categoryIndex)
                MainWindow.UpdateMenu()
            else
                MainWindow.ApplyCategoryHighlight(self, true)
            end
            ScheduleTooltip(self, function()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.Text:GetText())
                GameTooltip:AddLine("Right-click to edit", 1, 0.82, 0, false)
            end)
        end)
        button:SetScript("OnLeave", function(self)
            self.isHovered = false
            MainWindow.ApplyCategoryHighlight(
                self,
                self.categoryIndex == selectedCategoryIndex
            )
            CancelTooltip(self)
        end)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton"
                and addon.Settings
                and addon.Settings.OpenEmotes then
                addon.Settings.OpenEmotes(self.categoryIndex)
            end
        end)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", StartCategoryDrag)
        button:SetScript("OnDragStop", StopCategoryDrag)
        button:Hide()

        categoryButtons[categoryIndex] = button
    end


end

local function CreateEmoteArea()
    ScrollFrame = CreateFrame("ScrollFrame", nil, MainFrame, "UIPanelScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollChild:SetSize(emoteColumnWidth, 1)
    ScrollFrame:SetScrollChild(ScrollChild)

    EmoteEmptyButton = CreateFrame(
        "Button",
        nil,
        ScrollChild,
        "UIPanelButtonTemplate"
    )
    EmoteEmptyButton:SetSize(math.max(emoteColumnWidth - 5, 1), 22)
    EmoteEmptyButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -2)
    EmoteEmptyButton:SetText("Add Emote")
    EmoteEmptyButton:SetScript("OnClick", function()
        if addon.Settings and addon.Settings.OpenEmotes then
            addon.Settings.OpenEmotes()
        end
    end)
    EmoteEmptyButton:Hide()

    ScrollTopIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollTopIndicator:SetHeight(1)
    ScrollTopIndicator:SetPoint("TOPLEFT", ScrollFrame, "TOPLEFT", 6, -1)
    ScrollTopIndicator:SetPoint("TOPRIGHT", ScrollFrame, "TOPRIGHT", -6, -1)
    ScrollTopIndicator:SetColorTexture(
        themeSettings.emoteTextColor.r,
        themeSettings.emoteTextColor.g,
        themeSettings.emoteTextColor.b,
        1
    )
    ScrollTopIndicator:Hide()

    ScrollBottomIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollBottomIndicator:SetHeight(1)
    ScrollBottomIndicator:SetPoint("BOTTOMLEFT", ScrollFrame, "BOTTOMLEFT", 6, 1)
    ScrollBottomIndicator:SetPoint("BOTTOMRIGHT", ScrollFrame, "BOTTOMRIGHT", -6, 1)
    ScrollBottomIndicator:SetColorTexture(
        themeSettings.emoteTextColor.r,
        themeSettings.emoteTextColor.g,
        themeSettings.emoteTextColor.b,
        1
    )
    ScrollBottomIndicator:Hide()

    ScrollFrame:HookScript("OnVerticalScroll", function()
        addon.Scheduling.NextTick(scheduleKeys.scroll, UpdateScrollIndicators)
    end)

    ScrollFrame:HookScript("OnMouseWheel", function()
        addon.Scheduling.NextTick(scheduleKeys.scroll, UpdateScrollIndicators)
    end)


end

local function CreateTitleBarControls()
    PinBtn = CreateFrame("Button", nil, MainFrame)
    PinBtn:SetSize(20, 20)
    PinBtn:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -5, -5)
    PinBtn:SetFrameLevel(MainFrame:GetFrameLevel() + 2)
    PinBtn:RegisterForClicks("LeftButtonUp")

    PinBtn.Icon = PinBtn:CreateTexture(nil, "ARTWORK")
    PinBtn.Icon:SetSize(18, 18)
    PinBtn.Icon:SetPoint("CENTER")
    PinBtn.Icon:SetAtlas("waypoint-mappin-minimap-tracked", false)
    PinBtn:SetHighlightTexture(
        "Interface\\Buttons\\ButtonHilight-Square",
        "ADD"
    )

    PinBtn:SetScript("OnClick", function()
        profileSettings.locked = not profileSettings.locked
        UpdatePinButton()
        MainWindow.ApplyMovementLock()
        RefreshGeneralWindowFields()
    end)

    PinBtn:SetScript("OnEnter", function(self)
        ScheduleTooltip(self, function()
            GameTooltip:SetOwner(
                self,
                IsTitleBarOnLeft() and "ANCHOR_RIGHT" or "ANCHOR_BOTTOM"
            )
            GameTooltip:SetText(profileSettings.locked and "Window locked" or "Window unlocked")
            GameTooltip:AddLine(
                profileSettings.locked
                    and "The window position and height are locked."
                    or "The window can be moved and resized vertically.",
                1,
                1,
                1,
                true
            )
        end)
    end)

    PinBtn:SetScript("OnLeave", function(self)
        CancelTooltip(self)
    end)

    SettingsBtn = CreateFrame("Button", nil, MainFrame)
    SettingsBtn:SetSize(20, 20)
    SettingsBtn:SetPoint("RIGHT", PinBtn, "LEFT", -4, 0)
    SettingsBtn:SetFrameLevel(MainFrame:GetFrameLevel() + 2)
    SettingsBtn:RegisterForClicks("LeftButtonUp")

    SettingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    local settingsTexture = SettingsBtn:GetNormalTexture()
    settingsTexture:ClearAllPoints()
    settingsTexture:SetSize(16, 16)
    settingsTexture:SetPoint("CENTER")
    SettingsBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    SettingsBtn:SetScript("OnClick", function()
        addon.Settings.Open()
    end)

    SettingsBtn:SetScript("OnEnter", function(self)
        ScheduleTooltip(self, function()
            GameTooltip:SetOwner(
                self,
                IsTitleBarOnLeft() and "ANCHOR_RIGHT" or "ANCHOR_BOTTOM"
            )
            GameTooltip:SetText("RP Emote Menu Settings")
        end)
    end)

    SettingsBtn:SetScript("OnLeave", function(self)
        CancelTooltip(self)
    end)


end

local function CreateResizeGrip()
    ResizeGrip = CreateFrame("Button", nil, MainFrame)
    ResizeGrip:SetSize(18, 18)
    ResizeGrip:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -2, 2)
    ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    ResizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not profileSettings.locked
            and not IsWindowBodyHidden() then
            isUserResizing = true
            MainFrame:StartSizing("BOTTOM")
        end
    end)
    ResizeGrip:SetScript("OnMouseUp", function()
        MainFrame:StopMovingOrSizing()
        if isUserResizing then
            SaveWindowSize()
            isUserResizing = false
        end
    end)


end

local function InstallWindowScripts()
    MainFrame:HookScript("OnEnter", function()
        if isWindowAutoHidden and not IsMinimizedToIcon() then
            SetWindowAutoHidden(false)
        end
        MainWindow.NotifyActivity()
    end)
    MainFrame:HookScript("OnLeave", function()
        ScheduleInactiveFade()
        ScheduleWindowAutoHide()
    end)
    MainFrame:HookScript("OnHide", function()
        CancelTooltip()
        MinimizedIconButton:Hide()
    end)
    MainFrame:HookScript("OnShow", function()
        if not globalSettings.active then MainFrame:Hide(); return end
        if isWindowAutoHidden and IsMinimizedToIcon() then
            MinimizedIconButton:Show()
        end
    end)
    local mouseCheckElapsed = 0
    MainFrame:SetScript("OnUpdate", function(self, elapsed)
        if UpdateWindowDrag() then
            return
        end

        mouseCheckElapsed = mouseCheckElapsed + elapsed
        if mouseCheckElapsed < 0.05 then
            return
        end
        mouseCheckElapsed = 0

        if not profileSettings.fadeEnabled
            or (isWindowAutoHidden and IsMinimizedToIcon()) then
            return
        end

        if self:IsMouseOver() then
            if isWindowAutoHidden then
                SetWindowAutoHidden(false)
            end
            if GetWindowFade().IsAutoHidePending() then
                MainWindow.NotifyActivity()
            end
        else
            ScheduleWindowAutoHide()
        end
    end)


end

local function FinishMainWindowCreation()
    MainWindow.ApplyProfileSettings()

    -- SetAtlas can finish applying after the button is created and overwrite
    -- its tint. Reapply the saved pin state on the next frame using the known
    -- button instead of trying to rediscover it by its not-yet-ready atlas.
    addon.Scheduling.NextTick(scheduleKeys.pin, UpdatePinButton)

    MainWindow.ApplyActivation()
end

function MainWindow.CreateMainWindow()
    BindSettings()
    selectedCategoryIndex = profileSettings.selectedCategory
    CreateMainFrame()
    CreateTitleBar()
    CreateMinimizedIcon()
    CreateCategorySidebar()
    CreateEmoteArea()
    CreateTitleBarControls()
    CreateResizeGrip()
    InstallWindowScripts()
    FinishMainWindowCreation()
end

function MainWindow.ApplyActivation()
    globalSettings = Database.GetGlobalSettings()
    if not MainFrame then return end
    CancelWindowAutoHide()
    GetWindowFade().InvalidateFade()
    if globalSettings.active then
        SetWindowAutoHidden(false)
        RestoreActiveOpacity()
        MainFrame:Show()
        if not MainFrame:IsMouseOver() then
            ScheduleInactiveFade()
            ScheduleWindowAutoHide()
        end
    else
        MainFrame:Hide()
        if MinimizedIconButton then MinimizedIconButton:Hide() end
    end
end

function MainWindow.ApplyThemeSettings()
    -- A Theme change keeps the current Profile and its selected category.
    themeSettings = Database.GetThemeSettings()
    if not MainFrame then return end

    local positionChanged = appliedTitleBarPosition
        and appliedTitleBarPosition ~= themeSettings.titleBarPosition
    MainWindow.ApplyTitleBarPosition(not positionChanged, not positionChanged)
    MainWindow.ApplyAppearance()
    MainWindow.UpdateMenu()
    MainWindow.ScheduleFontRefreshes(true)
end

function MainWindow.ApplyProfileSettings()
    BindSettings()
    selectedCategoryIndex = profileSettings.selectedCategory

    if not MainFrame then
        return
    end

    -- Stop delayed fades from the previous Profile before applying its
    -- replacement. Window geometry and minimize behavior belong to Profile.
    CancelWindowAutoHide()
    GetWindowFade().InvalidateFade()
    isWindowAutoHidden = profileSettings.fadeEnabled and UsesMinimizedDisplay()

    -- Apply Theme layout before restoring the saved Profile geometry.
    MainWindow.ApplyTitleBarPosition(true)
    RestoreWindowSize()
    RestoreWindowPosition()
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()
    MainWindow.ApplyAppearance()
    UpdatePinButton()

    UpdateWindowBodyVisibility()
    MainWindow.UpdateMenu()
    MainWindow.ScheduleFontRefreshes(true)
end

function MainWindow.SetSelectedCategory(categoryIndex)
    if type(categoryIndex) ~= "number"
        or categoryIndex % 1 ~= 0
        or categoryIndex < 1
        or categoryIndex > MAX_CATEGORIES then
        return
    end

    selectedCategoryIndex = categoryIndex

    if profileSettings then
        profileSettings.selectedCategory = categoryIndex
    end
end

function MainWindow.GetFrame()
    return MainFrame
end

