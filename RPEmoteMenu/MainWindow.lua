local _, addon = ...

addon.MainWindow = {}

local MainWindow = addon.MainWindow
local Database = addon.Database
local defaults = addon.DefaultSettings
local settings
local MAX_CATEGORIES = addon.MAX_CATEGORIES
local MAX_EMOTES = addon.MAX_EMOTES
local selectedCategoryIndex = 1

local function Trim(value)
    return strtrim(value or "")
end

local titleBarThickness = 30
-- The first category and emote labels are both centered about 50 pixels below
-- the top of the window. Keep the minimized icon on that same centerline.
local topTitleFirstRowCenterOffset = 50
local leftTitleFirstRowCenterOffset = 20
local columnChromeWidth = addon.COLUMN_CHROME_WIDTH
local minimumUsableWidth = 220
local minimumHeight = 150
local maximumHeight = 630
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
local CategoryScrollFrame
local CategoryScrollChild
local CategoryEmptyLabel
local CategoryEmptyButton
local SidebarDivider
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
local emoteEditorDialog
local emoteDropIndicator
local emoteDragState
local isWindowAutoHidden = false
local SetWindowAutoHidden
local ScheduleWindowAutoHide
local fadeGeneration = 0
local opacityAnimationGroup
local opacityAnimation
local opacityAnimationTarget
local fadeOutDuration = 1.0
local fadeInDuration = 0.2
local autoHideGeneration = 0
local autoHideScheduled = false
local autoHideFading = false
local isApplyingColumnSize = false
local isUserResizing = false
local fontRefreshGeneration = 0
local windowDragState

local function IsTitleBarOnLeft()
    return settings and settings.titleBarPosition == "LEFT"
end

local function GetMinimizeMode()
    return settings and settings.minimizeMode or "NONE"
end

local function IsMinimizedToIcon()
    return GetMinimizeMode() == "ICON"
end

local function UsesMinimizedDisplay()
    return GetMinimizeMode() ~= "NONE"
end

local function GetContentWidth()
    return sidebarWidth + emoteColumnWidth + columnChromeWidth
end

local function GetExpandedWidth()
    return GetContentWidth() + (IsTitleBarOnLeft() and titleBarThickness or 0)
end

local function GetCurrentFrameSize(width, height)
    width = width or GetExpandedWidth()
    height = height or settings.height

    if not isWindowAutoHidden then
        return width, height
    end

    if IsTitleBarOnLeft() then
        if IsMinimizedToIcon() or not UsesMinimizedDisplay() then
            return width, height
        end
        return titleBarThickness, height
    end

    if not UsesMinimizedDisplay() then
        return width, height
    end

    return width, titleBarThickness
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
    if not PinBtn or not settings then
        return
    end

    PinBtn.Icon:SetDesaturated(not settings.locked)
    PinBtn.Icon:SetAlpha(settings.locked and 1 or 0.45)
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
                    settings.categoryFont,
                    settings.categoryFontSize
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
                        settings.emoteFont,
                        settings.emoteFontSize
                    )
                )
            end
        end
    end

    if widestCategory == 0 then
        widestCategory = MeasureText(
            "Add Category",
            settings.categoryFont,
            settings.categoryFontSize
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

    return width + (IsTitleBarOnLeft() and titleBarThickness or 0)
end

local function ClampWindowGeometry(x, y, width, height, allowOffscreen)
    local screenWidth = math.floor(UIParent:GetWidth() + 0.5)
    local screenHeight = math.floor(UIParent:GetHeight() + 0.5)

    width = math.floor(tonumber(width)
        or GetExpandedWidth())
    height = math.floor(tonumber(height) or settings.height or defaults.height)

    width = math.min(screenWidth, width)
    height = math.max(minimumHeight, math.min(maximumHeight, screenHeight, height))

    x = math.floor(tonumber(x) or settings.x or 0)
    y = math.floor(tonumber(y) or settings.y or screenHeight)

    -- Normal movement supplies the window's TOPLEFT point relative to
    -- UIParent's BOTTOMLEFT and keeps the entire frame on-screen. Advanced
    -- position fields supply signed offsets for the saved anchor instead; the
    -- reset and center buttons provide recovery if an extreme value is used.
    if allowOffscreen then
        x = math.max(-100000, math.min(100000, x))
        y = math.max(-100000, math.min(100000, y))
    else
        x = math.max(0, math.min(screenWidth - width, x))
        y = math.max(height, math.min(screenHeight, y))
    end

    return x, y, width, height
end

function MainWindow.ApplyWindowGeometry(x, y, width, height, preserveAnchor)
    width = CalculateColumnWidths()
    x, y, width, height = ClampWindowGeometry(
        x,
        y,
        width,
        height,
        preserveAnchor
    )

    if not preserveAnchor then
        settings.point = "TOPLEFT"
        settings.relativePoint = "BOTTOMLEFT"
    end
    settings.x = x
    settings.y = y
    settings.height = height

    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        settings.point,
        UIParent,
        settings.relativePoint,
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
    settings.point = "TOPLEFT"
    settings.relativePoint = "BOTTOMLEFT"

    local width = GetExpandedWidth()
    local x, y = ClampWindowGeometry(left, top, width, settings.height)
    settings.x = x
    settings.y = y

    RefreshGeneralWindowFields()
end

local function RestoreWindowPosition()
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint(
        settings.point,
        UIParent,
        settings.relativePoint,
        settings.x,
        settings.y
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

        settings.point = "TOPLEFT"
        settings.relativePoint = "BOTTOMLEFT"
        settings.x = x
        settings.y = y
        settings.height = height

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
            math.floor(tonumber(settings.height) or defaults.height)
        )
    )

    if settings.point ~= "CENTER" or settings.relativePoint ~= "CENTER" then
        local x, y
        x, y, width, height = ClampWindowGeometry(
            settings.x,
            settings.y,
            width,
            height
        )
        settings.x = x
        settings.y = y
    end
    settings.height = height
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
    if Database.ResetProfileGeneralSettings(
        Database.GetActiveProfileName(),
        settings
    ) then
        -- Reset every option exposed on the General tab for restorable
        -- built-in profiles, while leaving appearance and emotes unchanged.
        MainWindow.ApplyFadeSettings()
        MainWindow.ApplyMinimizeToIconSettings()
        MainWindow.ApplyMovementLock()
        MainWindow.ApplySettingsGearVisibility()
    end

    settings.point = defaults.point
    settings.relativePoint = defaults.relativePoint
    settings.x = defaults.x
    settings.y = defaults.y
    settings.height = defaults.height
    local width = CalculateColumnWidths()

    -- Restore the full-size frame before applying its default anchor so the
    -- same saved geometry is used whether the body is visible or hidden.
    isApplyingColumnSize = true
    MainFrame:SetSize(width, defaults.height)
    isApplyingColumnSize = false
    RestoreWindowPosition()

    if IsWindowBodyHidden() then
        local frameWidth, frameHeight = GetCurrentFrameSize(width, defaults.height)
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

    settings.point = "CENTER"
    settings.relativePoint = "CENTER"
    settings.x = 0
    settings.y = 0
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
        TitleBar:SetWidth(titleBarThickness)

        PinBtn:SetPoint("TOP", TitleBar, "TOP", 0, -5)
        SettingsBtn:SetPoint("BOTTOM", TitleBar, "BOTTOM", 0, 5)

        local availableLength = math.max(MainFrame:GetHeight() - 62, 1)
        TitleText:SetRotation(math.rad(90))
        TitleText:SetSize(availableLength, 20)
        TitleText:SetPoint("CENTER", TitleBar, "CENTER", 0, 0)
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

    local leftInset = IsTitleBarOnLeft() and titleBarThickness or 0
    local categoryTop = IsTitleBarOnLeft() and -5 or -36
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
    local frameWidth = GetCurrentFrameSize(width, settings.height)
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
    local unlocked = not settings.locked

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

    if settings.hideSettingsGear
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

local opacityAnimationOnFinished

local function SetWindowOpacity(targetOpacity, duration, onFinished)
    if not MainFrame then
        return
    end

    local currentOpacity = MainFrame:GetAlpha()

    if opacityAnimationGroup and opacityAnimationGroup:IsPlaying() then
        opacityAnimationOnFinished = nil
        opacityAnimationGroup:Stop()
    end

    if not duration or math.abs(currentOpacity - targetOpacity) < 0.001 then
        MainFrame:SetAlpha(targetOpacity)
        if onFinished then
            onFinished()
        end
        return
    end

    if not opacityAnimationGroup then
        opacityAnimationGroup = MainFrame:CreateAnimationGroup()
        opacityAnimation = opacityAnimationGroup:CreateAnimation("Alpha")
        opacityAnimation:SetSmoothing("IN_OUT")
        opacityAnimationGroup:SetScript("OnFinished", function()
            MainFrame:SetAlpha(opacityAnimationTarget)
            local callback = opacityAnimationOnFinished
            opacityAnimationOnFinished = nil
            if callback then
                callback()
            end
        end)
    end

    MainFrame:SetAlpha(currentOpacity)
    opacityAnimationTarget = targetOpacity
    opacityAnimationOnFinished = onFinished
    opacityAnimation:SetFromAlpha(currentOpacity)
    opacityAnimation:SetToAlpha(targetOpacity)
    opacityAnimation:SetDuration(duration)
    opacityAnimationGroup:Play()
end

local function CancelWindowAutoHide()
    autoHideGeneration = autoHideGeneration + 1
    autoHideScheduled = false
    autoHideFading = false
end

local function RestoreActiveOpacity(animate)
    fadeGeneration = fadeGeneration + 1

    if MainFrame then
        SetWindowOpacity(
            settings.windowOpacity,
            animate and fadeInDuration or nil
        )
    end
end

local function ScheduleInactiveFade()
    fadeGeneration = fadeGeneration + 1
    local requestedGeneration = fadeGeneration

    -- Minimized modes use ScheduleWindowAutoHide for both their fade and
    -- collapse. None leaves the complete window visible at inactive opacity.
    if not settings.fadeEnabled or UsesMinimizedDisplay() or not MainFrame then
        return
    end

    C_Timer.After(settings.fadeDelay, function()
        if requestedGeneration ~= fadeGeneration
            or not settings.fadeEnabled
            or UsesMinimizedDisplay()
            or MainFrame:IsMouseOver() then
            return
        end

        SetWindowOpacity(
            math.min(settings.inactiveOpacity, settings.windowOpacity),
            fadeOutDuration
        )
    end)
end

function MainWindow.NotifyActivity()
    CancelWindowAutoHide()
    RestoreActiveOpacity(true)
end

function MainWindow.ApplyFadeSettings()
    RestoreActiveOpacity()

    if not settings.fadeEnabled then
        CancelWindowAutoHide()
        SetWindowAutoHidden(false)
    elseif not UsesMinimizedDisplay() then
        CancelWindowAutoHide()
        SetWindowAutoHidden(false)
        if MainFrame and not MainFrame:IsMouseOver() then
            ScheduleInactiveFade()
        end
    elseif isWindowAutoHidden then
        local hiddenOpacity = math.min(
            settings.inactiveOpacity,
            settings.windowOpacity
        )
        if IsMinimizedToIcon() then
            MinimizedIconButton:SetAlpha(hiddenOpacity)
        else
            SetWindowOpacity(hiddenOpacity)
        end
    elseif MainFrame and not MainFrame:IsMouseOver() then
        ScheduleInactiveFade()
        ScheduleWindowAutoHide()
    end
end

function MainWindow.RefreshFontDisplays(updateLayout)
    if not MainFrame then
        return false
    end

    local categoryApplied = true
    local emoteApplied = true
    categoryButtonHeight = math.max(24, settings.categoryFontSize + 10)
    emoteButtonHeight = math.max(20, settings.emoteFontSize + 8)

    -- Build and position every required button before applying fonts. Otherwise
    -- a newly created final label can miss the pane-wide consistency pass.
    if updateLayout ~= false then
        MainWindow.UpdateMenu()
    end

    for _, button in ipairs(categoryButtons) do
        button:SetHeight(categoryButtonHeight)
        local textColor = button.categoryIndex == selectedCategoryIndex
            and settings.selectedCategoryTextColor
            or settings.categoryTextColor

        if not ApplyFont(
            button.Text,
            settings.categoryFont,
            settings.categoryFontSize,
            textColor,
            true
        ) then
            categoryApplied = false
        end

        for _, outlineText in ipairs(button.TextOutline) do
            if not ApplyFont(
                outlineText,
                settings.categoryFont,
                settings.categoryFontSize,
                settings.categoryHighlightColor,
                true
            ) then
                categoryApplied = false
            end
        end
    end

    if not categoryApplied then
        for _, button in ipairs(categoryButtons) do
            local textColor = button.categoryIndex == selectedCategoryIndex
                and settings.selectedCategoryTextColor
                or settings.categoryTextColor
            ApplyFont(
                button.Text,
                defaults.categoryFont,
                settings.categoryFontSize,
                textColor,
                true
            )
            for _, outlineText in ipairs(button.TextOutline) do
                ApplyFont(
                    outlineText,
                    defaults.categoryFont,
                    settings.categoryFontSize,
                    settings.categoryHighlightColor,
                    true
                )
            end
        end
    end

    for _, button in ipairs(buttonsPool) do
        button:SetHeight(emoteButtonHeight)
        if not ApplyFont(
            button.Text,
            settings.emoteFont,
            settings.emoteFontSize,
            settings.emoteTextColor,
            true
        ) then
            emoteApplied = false
        end
    end

    if not emoteApplied then
        for _, button in ipairs(buttonsPool) do
            ApplyFont(
                button.Text,
                defaults.emoteFont,
                settings.emoteFontSize,
                settings.emoteTextColor,
                true
            )
        end
    end

    local emoteColor = settings.emoteTextColor
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

function MainWindow.ScheduleFontRefreshes(skipImmediateRefresh)
    fontRefreshGeneration = fontRefreshGeneration + 1
    local requestedGeneration = fontRefreshGeneration

    if not skipImmediateRefresh then
        MainWindow.RefreshFontDisplays()
    end

    for _, delay in ipairs({
        0, 0.25, 0.75, 1.5, 3, 5, 8, 12, 18, 24, 30
    }) do
        C_Timer.After(delay, function()
            if requestedGeneration == fontRefreshGeneration then
                MainWindow.RefreshFontDisplays(false)
            end
        end)
    end
end

local function ApplyMainFrameBackdrop()
    local emoteBackground = settings.emoteBackgroundColor
    local border = settings.borderColor
    local backdrop = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    }

    if settings.borderStyle == "thin" then
        backdrop.edgeFile = "Interface\\ChatFrame\\ChatFrameBackground"
        backdrop.edgeSize = 1
    elseif settings.borderStyle == "blizzard" then
        backdrop.edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border"
        backdrop.edgeSize = 12
        backdrop.insets = {left = 3, right = 3, top = 3, bottom = 3}
    end

    MainFrame:SetBackdrop(backdrop)
    MainFrame:SetBackdropColor(
        emoteBackground.r,
        emoteBackground.g,
        emoteBackground.b,
        settings.backgroundOpacity
    )
    MainFrame:SetBackdropBorderColor(border.r, border.g, border.b, 1)
end

function MainWindow.ApplyAppearance()
    if not MainFrame then
        return
    end

    local categoryBackground = settings.categoryBackgroundColor
    local border = settings.borderColor

    if not (isWindowAutoHidden and IsMinimizedToIcon()) then
        ApplyMainFrameBackdrop()
    end

    CategorySidebar:SetBackdropColor(
        categoryBackground.r,
        categoryBackground.g,
        categoryBackground.b,
        settings.backgroundOpacity
    )

    if settings.borderStyle == "none" then
        SidebarDivider:Hide()
    else
        SidebarDivider:SetColorTexture(border.r, border.g, border.b, 0.9)
        SidebarDivider:Show()
    end

    MainWindow.RefreshFontDisplays()
    MainWindow.ApplyFadeSettings()
end

-- MENU RENDERING
local function GetEmoteEditorDialog()
    if emoteEditorDialog then
        return emoteEditorDialog
    end

    local dialog = CreateFrame(
        "Frame",
        "RPEmoteMenuEmoteEditorDialog",
        UIParent,
        "BackdropTemplate"
    )
    dialog:SetSize(610, 330)
    dialog:SetPoint("CENTER", UIParent, "CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    dialog:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    dialog:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    dialog:Hide()

    if UISpecialFrames then
        table.insert(UISpecialFrames, "RPEmoteMenuEmoteEditorDialog")
    end

    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -16)
    title:SetText("Edit Emote")
    dialog.Title = title

    local closeIcon = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeIcon:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -4, -4)
    closeIcon:SetScript("OnClick", function() dialog:Hide() end)

    local helpText = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    helpText:SetWidth(570)
    helpText:SetJustifyH("LEFT")
    helpText:SetText(
        "{target} - Target's name without the realm.   " ..
        "{player} - Current character's name without the realm.\n" ..
        "Targeted Emote is used only when another unit is targeted. " ..
        "An emote appears only when it has both a name and a default emote."
    )
    helpText:SetTextColor(0.8, 0.8, 0.8, 1)

    local function CreateEditor(labelText, y)
        local label = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, y)
        label:SetWidth(170)
        label:SetJustifyH("LEFT")
        label:SetText(labelText)

        local editBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        editBox:SetSize(390, 24)
        editBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 188, y + 5)
        editBox:SetAutoFocus(false)
        editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
        editBox:SetTextColor(1, 1, 1, 1)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return editBox
    end

    dialog.NameBox = CreateEditor("Emote Name", -112)
    dialog.DefaultBox = CreateEditor("Default Emote", -152)
    dialog.TargetedBox = CreateEditor("Targeted Emote (optional)", -192)

    local status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", 18, 51)
    status:SetWidth(420)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.8, 0.8, 0.8, 1)
    dialog.Status = status

    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(110, 24)
    saveButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -138, 16)
    saveButton:SetText("Save")
    dialog.SaveButton = saveButton

    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(110, 24)
    cancelButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -18, 16)
    cancelButton:SetText(CANCEL or "Cancel")
    cancelButton:SetScript("OnClick", function() dialog:Hide() end)

    local function SaveEmote()
        if not Database.CanEditActiveProfile() then
            return
        end

        local category = Database.GetCategory(dialog.categoryIndex)
        local emote = category and category.emotes
            and category.emotes[dialog.emoteIndex]

        if not emote then
            return
        end

        emote.label = dialog.NameBox:GetText() or ""
        emote.defaultCommand = dialog.DefaultBox:GetText() or ""
        emote.targetedCommand = dialog.TargetedBox:GetText() or ""

        MainWindow.UpdateMenu()
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors(dialog.categoryIndex)
        end
        dialog:Hide()
    end

    saveButton:SetScript("OnClick", SaveEmote)
    for _, editBox in ipairs({dialog.NameBox, dialog.DefaultBox, dialog.TargetedBox}) do
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            SaveEmote()
        end)
    end

    function dialog:Open(categoryIndex, emoteIndex, isNew)
        local category = Database.GetCategory(categoryIndex)
        local emote = category and category.emotes and category.emotes[emoteIndex]
        if not emote then
            return
        end

        self.categoryIndex = categoryIndex
        self.emoteIndex = emoteIndex
        self.NameBox:SetText(emote.label or "")
        self.DefaultBox:SetText(emote.defaultCommand or "")
        self.TargetedBox:SetText(emote.targetedCommand or "")

        local editable = Database.CanEditActiveProfile()
        for _, editBox in ipairs({self.NameBox, self.DefaultBox, self.TargetedBox}) do
            if editable then
                editBox:Enable()
                editBox:SetTextColor(1, 1, 1, 1)
            else
                editBox:Disable()
                editBox:SetTextColor(0.65, 0.65, 0.65, 1)
            end
        end

        self.SaveButton:SetEnabled(editable)
        self.Status:SetText(editable
            and "Changes apply to the current profile."
            or "The Default profile's emotes cannot be edited. Copy it to a custom profile first.")
        self.Title:SetText(
            editable and (isNew and "Add Emote" or "Edit Emote") or "View Emote"
        )
        self:Show()
        self:Raise()
    end

    emoteEditorDialog = dialog
    return dialog
end

function MainWindow.OpenEmoteEditor(categoryIndex, emoteIndex, isNew)
    GetEmoteEditorDialog():Open(categoryIndex, emoteIndex, isNew)
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
    local highlight = settings.categoryHighlightColor
    local background = settings.emoteBackgroundColor
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
    C_Timer.After(0, function()
        RefreshEmoteHovered(button)
    end)
end

local function ShowEmoteTooltip(button, owner, editHint)
    if not button.emoteLabel or not button.defaultCommand then
        return
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

    GameTooltip:Show()
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
        ShowEmoteTooltip(button, self, "Click to edit")
    end)
    button.EditButton:SetScript("OnLeave", function()
        ScheduleEmoteHoverRefresh(button)
        GameTooltip:Hide()
    end)

    button:SetScript("OnEnter", function(self)
        SetEmoteHovered(button, true)
        ShowEmoteTooltip(button, self, "Right-click to edit")
    end)
    button:SetScript("OnLeave", function()
        ScheduleEmoteHoverRefresh(button)
        GameTooltip:Hide()
    end)

    button.Text:SetPoint("RIGHT", button.EditButton, "LEFT", -8, 0)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetWordWrap(false)
    ApplyFont(
        button.Text,
        settings.emoteFont,
        settings.emoteFontSize,
        settings.emoteTextColor
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

    local color = settings.categoryHighlightColor
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
    local visible = GetVisibleEmotes(category)
    local source = visible[sourcePosition]

    if not source or insertionPosition < 1 or insertionPosition > #visible + 1 then
        return false
    end

    if insertionPosition > sourcePosition then
        insertionPosition = insertionPosition - 1
    end

    if insertionPosition == sourcePosition then
        return false
    end

    local visibleIndices = {}
    local records = {}
    for position, entry in ipairs(visible) do
        visibleIndices[position] = entry.index
        records[position] = entry.emote
    end

    local moved = table.remove(records, sourcePosition)
    table.insert(records, insertionPosition, moved)

    for position, emoteIndex in ipairs(visibleIndices) do
        category.emotes[emoteIndex] = records[position]
    end

    return true
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
    GameTooltip:Hide()
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
    C_Timer.After(0, function()
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

    local color = settings.categoryHighlightColor
    local effect = not isSelected and button.isHovered
        and "background"
        or settings.categoryHighlightEffect

    if effect == "background" then
        button.Selection:SetColorTexture(
            color.r,
            color.g,
            color.b,
            0.85 * strength
        )
        button.Selection:Show()
    elseif effect == "outline" then
        local thickness = settings.categoryHighlightThickness
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
        button.SelectionUnderline:SetHeight(settings.categoryHighlightThickness)
        button.SelectionUnderline:SetColorTexture(
            color.r, color.g, color.b, strength
        )
        button.SelectionUnderline:Show()
    elseif effect == "shadow" then
        button.Text:SetShadowColor(color.r, color.g, color.b, strength)
        button.Text:SetShadowOffset(2, -2)
    elseif effect == "separator" then
        button.SelectionOutline.right:SetWidth(settings.categoryHighlightThickness)
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
            for _, outlineText in ipairs(button.TextOutline) do
                outlineText:SetText(category.name)
            end

            local isSelected = categoryIndex == selectedCategoryIndex
            MainWindow.ApplyCategoryHighlight(button, isSelected)

            local textColor = isSelected
                and settings.selectedCategoryTextColor
                or settings.categoryTextColor

            button.Text:SetTextColor(
                textColor.r,
                textColor.g,
                textColor.b,
                1
            )

            button:Show()
            visibleCount = visibleCount + 1
        elseif button then
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
    MainWindow.NotifyActivity()
    ApplyAutomaticWidth()

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

    settings.selectedCategory = selectedCategoryIndex or defaults.selectedCategory
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
        emoteButton.EditButton:SetShown(not settings.hideEmoteEditGears)
        emoteButton.Text:ClearAllPoints()
        emoteButton.Text:SetPoint("LEFT", emoteButton, "LEFT", 7, 0)
        if settings.hideEmoteEditGears then
            emoteButton.Text:SetPoint("RIGHT", emoteButton, "RIGHT", -3, 0)
        else
            emoteButton.Text:SetPoint("RIGHT", emoteButton.EditButton, "LEFT", -8, 0)
        end

        emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -dynamicY)
        emoteButton.Text:SetText(label)
        emoteButton.Text:SetTextColor(
            settings.emoteTextColor.r,
            settings.emoteTextColor.g,
            settings.emoteTextColor.b,
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
            if settings.fadeEnabled and UsesMinimizedDisplay() then
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

    C_Timer.After(0, function()
        UpdateScrollIndicators()
    end)

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

    local rightAligned = settings.minimizedIconCorner == "TOPRIGHT"
    local iconPoint = rightAligned and "RIGHT" or "LEFT"
    local windowPoint = rightAligned and "TOPRIGHT" or "TOPLEFT"

    MinimizedIconButton:ClearAllPoints()
    MinimizedIconButton:SetPoint(
        iconPoint,
        MainFrame,
        windowPoint,
        0,
        -(IsTitleBarOnLeft()
            and leftTitleFirstRowCenterOffset
            or topTitleFirstRowCenterOffset)
    )
end

local function UpdateWindowBodyVisibility()
    -- Keep the upper-left corner fixed while the hidden frame collapses toward
    -- whichever edge owns the title bar.
    AnchorFrameByTopLeft()
    local width = GetExpandedWidth()
    local compactWidth, compactHeight = GetCurrentFrameSize(
        width,
        settings.height
    )

    if IsWindowBodyHidden() then
        local hiddenOpacity = math.min(
            settings.inactiveOpacity,
            settings.windowOpacity
        )
        SetCompactResizeBounds()
        CategorySidebar:Hide()
        ScrollFrame:Hide()
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        if IsMinimizedToIcon() then
            TitleBar:Hide()
            TitleText:Hide()
            PinBtn:Hide()
            SettingsBtn:Hide()
            MainFrame:SetBackdrop(nil)
            MainFrame:EnableMouse(false)
            MinimizedIconButton:SetSize(
                settings.minimizedIconSize,
                settings.minimizedIconSize
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
        SetInternalFrameSize(width, settings.height)
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
        MainWindow.UpdateMenu()
        C_Timer.After(0, UpdateScrollIndicators)
    end

    ApplyColumnLayout()
    MainWindow.ApplyMovementLock()
end

function MainWindow.ApplyMinimizeToIconSettings()
    if settings.minimizeMode ~= "TITLE_BAR"
        and settings.minimizeMode ~= "ICON" then
        settings.minimizeMode = "NONE"
    end
    settings.minimizedIconSize = math.max(
        addon.MIN_MINIMIZED_ICON_SIZE,
        math.min(
            addon.MAX_MINIMIZED_ICON_SIZE,
            math.floor(tonumber(settings.minimizedIconSize)
                or defaults.minimizedIconSize)
        )
    )
    settings.minimizedIconCorner = settings.minimizedIconCorner == "TOPRIGHT"
        and "TOPRIGHT"
        or "TOPLEFT"
    CancelWindowAutoHide()
    if not UsesMinimizedDisplay() then
        SetWindowAutoHidden(false)
    end
    ApplyMinimizedIconAnchor()
    UpdateWindowBodyVisibility()
    MainWindow.ApplyFadeSettings()
    RefreshGeneralWindowFields()
end

function MainWindow.ApplyTitleBarPosition()
    settings.titleBarPosition = settings.titleBarPosition == "LEFT"
        and "LEFT"
        or "TOP"
    MainWindow.ApplyWindowGeometry(
        MainFrame:GetLeft() or settings.x,
        MainFrame:GetTop() or settings.y,
        nil,
        settings.height
    )
    ApplyMinimizedIconAnchor()
    UpdateWindowBodyVisibility()
end

SetWindowAutoHidden = function(hidden)
    hidden = not not hidden

    if not settings.fadeEnabled or not UsesMinimizedDisplay() then
        hidden = false
    end
    if isWindowAutoHidden == hidden then
        return
    end

    isWindowAutoHidden = hidden
    UpdateWindowBodyVisibility()
end

ScheduleWindowAutoHide = function()
    if not settings.fadeEnabled or not UsesMinimizedDisplay()
        or isWindowAutoHidden
        or autoHideScheduled or autoHideFading then
        return
    end

    autoHideGeneration = autoHideGeneration + 1
    local requestedGeneration = autoHideGeneration
    autoHideScheduled = true

    C_Timer.After(math.max(tonumber(settings.fadeDelay) or 0, 0), function()
        if requestedGeneration ~= autoHideGeneration then
            return
        end

        autoHideScheduled = false

        if not settings.fadeEnabled or not UsesMinimizedDisplay()
            or isWindowAutoHidden
            or not MainFrame or MainFrame:IsMouseOver() then
            return
        end

        autoHideFading = true
        fadeGeneration = fadeGeneration + 1
        local fadeTarget = 0

        SetWindowOpacity(fadeTarget, fadeOutDuration, function()
            if requestedGeneration ~= autoHideGeneration then
                return
            end

            autoHideFading = false

            if not settings.fadeEnabled or not UsesMinimizedDisplay()
                or MainFrame:IsMouseOver() then
                RestoreActiveOpacity(true)
                return
            end

            SetWindowAutoHidden(true)
            if IsMinimizedToIcon() then
                -- The icon is parented to UIParent, so MainFrame can remain
                -- ready at active opacity behind it.
                SetWindowOpacity(settings.windowOpacity)
            end
        end)
    end)
end

-- MAIN WINDOW
local function StartWindowMoving()
    if settings.locked then
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
        MainWindow.ApplyWindowGeometry(left, top, nil, settings.height)
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
        settings.height
    )
    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    return true
end

function MainWindow.CreateMainWindow()
    settings = Database.GetSettings()
    selectedCategoryIndex = settings.selectedCategory
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(
        GetExpandedWidth(),
        defaults.height
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
            settings.height
        )
        if isUserResizing and not IsWindowBodyHidden() then
            settings.height = math.max(
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
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("RP Emote Menu " .. addon.VERSION)
            GameTooltip:Show()
        end
    end)
    TitleBar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    TitleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    TitleText:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    TitleText:SetText("RP Emote Menu " .. addon.VERSION)
    TitleText:SetTextColor(1, 1, 1, 1)

    MinimizedIconButton = CreateFrame("Button", nil, UIParent)
    ApplyMinimizedIconAnchor()
    MinimizedIconButton:SetSize(
        defaults.minimizedIconSize,
        defaults.minimizedIconSize
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

    CategorySidebar = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    CategorySidebar:SetWidth(sidebarWidth)
    CategorySidebar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 5, -36)
    CategorySidebar:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 5, 10)
    CategorySidebar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground"
    })
    SidebarDivider = CategorySidebar:CreateTexture(nil, "OVERLAY")
    SidebarDivider:SetWidth(1)
    SidebarDivider:SetPoint("TOPRIGHT", CategorySidebar, "TOPRIGHT", 0, 0)
    SidebarDivider:SetPoint("BOTTOMRIGHT", CategorySidebar, "BOTTOMRIGHT", 0, 0)

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
            settings.categoryFont,
            settings.categoryFontSize,
            settings.categoryTextColor
        )

        button:SetScript("OnEnter", function(self)
            self.isHovered = true
            if self.categoryIndex ~= selectedCategoryIndex then
                MainWindow.SetSelectedCategory(self.categoryIndex)
                MainWindow.UpdateMenu()
            else
                MainWindow.ApplyCategoryHighlight(self, true)
            end
            if self.Text:IsTruncated() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.Text:GetText())
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function(self)
            self.isHovered = false
            MainWindow.ApplyCategoryHighlight(
                self,
                self.categoryIndex == selectedCategoryIndex
            )
            GameTooltip:Hide()
        end)
        button:Hide()

        categoryButtons[categoryIndex] = button
    end

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
        settings.emoteTextColor.r,
        settings.emoteTextColor.g,
        settings.emoteTextColor.b,
        1
    )
    ScrollTopIndicator:Hide()

    ScrollBottomIndicator = MainFrame:CreateTexture(nil, "OVERLAY")
    ScrollBottomIndicator:SetHeight(1)
    ScrollBottomIndicator:SetPoint("BOTTOMLEFT", ScrollFrame, "BOTTOMLEFT", 6, 1)
    ScrollBottomIndicator:SetPoint("BOTTOMRIGHT", ScrollFrame, "BOTTOMRIGHT", -6, 1)
    ScrollBottomIndicator:SetColorTexture(
        settings.emoteTextColor.r,
        settings.emoteTextColor.g,
        settings.emoteTextColor.b,
        1
    )
    ScrollBottomIndicator:Hide()

    ScrollFrame:HookScript("OnVerticalScroll", function()
        C_Timer.After(0, UpdateScrollIndicators)
    end)

    ScrollFrame:HookScript("OnMouseWheel", function()
        C_Timer.After(0, UpdateScrollIndicators)
    end)

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
        settings.locked = not settings.locked
        UpdatePinButton()
        MainWindow.ApplyMovementLock()
        RefreshGeneralWindowFields()
    end)

    PinBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(
            self,
            IsTitleBarOnLeft() and "ANCHOR_RIGHT" or "ANCHOR_BOTTOM"
        )
        GameTooltip:SetText(settings.locked and "Window locked" or "Window unlocked")
        GameTooltip:AddLine(
            settings.locked
                and "The window position and height are locked."
                or "The window can be moved and resized vertically.",
            1,
            1,
            1,
            true
        )
        GameTooltip:Show()
    end)

    PinBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
        GameTooltip:SetOwner(
            self,
            IsTitleBarOnLeft() and "ANCHOR_RIGHT" or "ANCHOR_BOTTOM"
        )
        GameTooltip:SetText("RP Emote Menu Settings")
        GameTooltip:Show()
    end)

    SettingsBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ResizeGrip = CreateFrame("Button", nil, MainFrame)
    ResizeGrip:SetSize(18, 18)
    ResizeGrip:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -2, 2)
    ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    ResizeGrip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not settings.locked
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
        MinimizedIconButton:Hide()
    end)
    MainFrame:HookScript("OnShow", function()
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

        if not settings.fadeEnabled
            or (isWindowAutoHidden and IsMinimizedToIcon()) then
            return
        end

        if self:IsMouseOver() then
            if isWindowAutoHidden then
                SetWindowAutoHidden(false)
            end
            if autoHideScheduled or autoHideFading then
                MainWindow.NotifyActivity()
            end
        else
            ScheduleWindowAutoHide()
        end
    end)

    MainWindow.ApplyProfileSettings()

    -- SetAtlas can finish applying after the button is created and overwrite
    -- its tint. Reapply the saved pin state on the next frame using the known
    -- button instead of trying to rediscover it by its not-yet-ready atlas.
    C_Timer.After(0, UpdatePinButton)

    if settings.showAtLogin then
        MainFrame:Show()
    else
        MainFrame:Hide()
    end
end

function MainWindow.ApplyProfileSettings()
    settings = Database.GetSettings()
    selectedCategoryIndex = settings.selectedCategory

    if not MainFrame then
        return
    end

    RestoreWindowSize()
    RestoreWindowPosition()
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()
    MainWindow.ApplyAppearance()
    UpdatePinButton()

    isWindowAutoHidden = settings.fadeEnabled and UsesMinimizedDisplay()
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

    if settings then
        settings.selectedCategory = categoryIndex
    end
end

function MainWindow.GetFrame()
    return MainFrame
end
