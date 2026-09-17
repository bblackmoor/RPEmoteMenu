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

local titleBarHeight = 30
local columnChromeWidth = addon.COLUMN_CHROME_WIDTH
local minimumWidth = addon.MIN_SIDEBAR_WIDTH
    + addon.MIN_EMOTE_COLUMN_WIDTH + columnChromeWidth
local minimumHeight = 150
local maximumWidth = 600
local maximumHeight = 600
local sidebarWidth = defaults.sidebarWidth
local emoteColumnWidth = defaults.emoteColumnWidth
local minimumSidebarWidth = addon.MIN_SIDEBAR_WIDTH
local maximumSidebarWidth = addon.MAX_SIDEBAR_WIDTH
local minimumEmoteColumnWidth = addon.MIN_EMOTE_COLUMN_WIDTH
local maximumEmoteColumnWidth = addon.MAX_EMOTE_COLUMN_WIDTH
local categoryButtonHeight = 24
local emoteButtonHeight = 20

local MainFrame
local TitleText
local MinimizedIconButton
local CategorySidebar
local CategoryScrollFrame
local CategoryScrollChild
local CategoryEmptyLabel
local SidebarDivider
local ScrollFrame
local ScrollChild
local ScrollTopIndicator
local ScrollBottomIndicator
local PinBtn
local SettingsBtn
local ResizeGrip
local categoryButtons = {}
local buttonsPool = {}
local emoteEditorDialog
local emoteDropIndicator
local emoteDragState
local isWindowAutoHidden = false
local SetWindowAutoHidden
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
local fontRefreshGeneration = 0

local function SetInternalFrameSize(width, height)
    isApplyingColumnSize = true
    MainFrame:SetSize(width, height)
    isApplyingColumnSize = false
end

local function SetCompactResizeBounds()
    MainFrame:SetResizeBounds(1, 1, maximumWidth, maximumHeight)
end

local function SetNormalResizeBounds()
    MainFrame:SetResizeBounds(
        minimumWidth,
        minimumHeight,
        maximumWidth,
        maximumHeight
    )
end

local function IsWindowBodyHidden()
    return isWindowAutoHidden
end

local function UpdatePinButton()
    if not PinBtn or not settings then
        return
    end

    PinBtn.Icon:SetDesaturated(not settings.keepOpen)
    PinBtn.Icon:SetAlpha(settings.keepOpen and 1 or 0.45)
end

local function RefreshGeneralWindowFields()
    if addon.Settings and addon.Settings.RefreshGeneralWindowFields then
        addon.Settings.RefreshGeneralWindowFields()
    end
end

local function ClampColumnWidth(value, minimum, maximum, fallback)
    value = math.floor(tonumber(value) or fallback)
    return math.max(minimum, math.min(maximum, value))
end

local function DistributeWindowWidth(width)
    local target = math.max(minimumWidth, math.min(maximumWidth,
        math.floor(tonumber(width) or settings.width or defaults.width)))
    local left = ClampColumnWidth(
        sidebarWidth, minimumSidebarWidth, maximumSidebarWidth, defaults.sidebarWidth
    )
    local right = ClampColumnWidth(
        emoteColumnWidth,
        minimumEmoteColumnWidth,
        maximumEmoteColumnWidth,
        defaults.emoteColumnWidth
    )
    local delta = target - columnChromeWidth - left - right

    if delta > 0 then
        local rightChange = math.min(delta, maximumEmoteColumnWidth - right)
        right = right + rightChange
        left = left + math.min(delta - rightChange, maximumSidebarWidth - left)
    elseif delta < 0 then
        local remaining = -delta
        local rightChange = math.min(remaining, right - minimumEmoteColumnWidth)
        right = right - rightChange
        left = left - math.min(remaining - rightChange, left - minimumSidebarWidth)
    end

    return left, right, left + right + columnChromeWidth
end

local ApplyColumnLayout

local function ClampWindowGeometry(x, y, width, height)
    local screenWidth = math.floor(UIParent:GetWidth() + 0.5)
    local screenHeight = math.floor(UIParent:GetHeight() + 0.5)

    width = math.floor(tonumber(width) or settings.width or defaults.width)
    height = math.floor(tonumber(height) or settings.height or defaults.height)

    width = math.max(minimumWidth, math.min(maximumWidth, screenWidth, width))
    height = math.max(minimumHeight, math.min(maximumHeight, screenHeight, height))

    x = math.floor(tonumber(x) or settings.x or 0)
    y = math.floor(tonumber(y) or settings.y or screenHeight)

    -- x/y represent the window's TOPLEFT point relative to UIParent's BOTTOMLEFT.
    -- Keep the entire frame on-screen.
    x = math.max(0, math.min(screenWidth - width, x))
    y = math.max(height, math.min(screenHeight, y))

    return x, y, width, height
end

function MainWindow.ApplyWindowGeometry(x, y, width, height)
    x, y, width, height = ClampWindowGeometry(x, y, width, height)
    sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)

    settings.point = "TOPLEFT"
    settings.relativePoint = "BOTTOMLEFT"
    settings.x = x
    settings.y = y
    settings.width = width
    settings.height = height

    MainFrame:ClearAllPoints()
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

    isApplyingColumnSize = true
    if IsWindowBodyHidden() then
        MainFrame:SetSize(width, titleBarHeight)
    else
        MainFrame:SetSize(width, height)
    end
    isApplyingColumnSize = false
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

    local x, y = ClampWindowGeometry(left, top, settings.width, settings.height)
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
        local x, y, width, height = ClampWindowGeometry(
            settings.x,
            settings.y,
            MainFrame:GetWidth(),
            MainFrame:GetHeight()
        )

        settings.x = x
        settings.y = y
        settings.width = width
        settings.height = height
    end

    RefreshGeneralWindowFields()
end

local function RestoreWindowSize()
    local x, y, width, height = ClampWindowGeometry(
        settings.x,
        settings.y,
        settings.width,
        settings.height
    )

    settings.x = x
    settings.y = y
    sidebarWidth = settings.sidebarWidth
    emoteColumnWidth = settings.emoteColumnWidth
    sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)
    settings.sidebarWidth = sidebarWidth
    settings.emoteColumnWidth = emoteColumnWidth
    settings.width = width
    settings.height = height
    isApplyingColumnSize = true
    MainFrame:SetSize(width, height)
    isApplyingColumnSize = false

    RefreshGeneralWindowFields()
end

function MainWindow.ResetWindowPosition()
    settings.point = defaults.point
    settings.relativePoint = defaults.relativePoint
    settings.x = defaults.x
    settings.y = defaults.y
    settings.width = defaults.width
    settings.height = defaults.height
    settings.sidebarWidth = defaults.sidebarWidth
    settings.emoteColumnWidth = defaults.emoteColumnWidth
    sidebarWidth = defaults.sidebarWidth
    emoteColumnWidth = defaults.emoteColumnWidth

    -- Resolve the default CENTER anchor using the restored full-size window.
    -- Otherwise its previous dimensions shift the position until a second reset.
    isApplyingColumnSize = true
    MainFrame:SetSize(defaults.width, defaults.height)
    isApplyingColumnSize = false
    RestoreWindowPosition()

    if IsWindowBodyHidden() then
        SetInternalFrameSize(defaults.width, titleBarHeight)
    end

    MainWindow.ApplySidebarWidth(defaults.sidebarWidth)
    RefreshGeneralWindowFields()
end

ApplyColumnLayout = function()
    if not MainFrame or not CategorySidebar or not CategoryScrollChild
        or not ScrollFrame or not ScrollChild then
        return
    end

    settings.sidebarWidth = sidebarWidth
    settings.emoteColumnWidth = emoteColumnWidth
    settings.width = sidebarWidth + emoteColumnWidth + columnChromeWidth

    CategorySidebar:SetWidth(sidebarWidth)
    CategoryScrollChild:SetWidth(sidebarWidth - 7)

    for _, button in ipairs(categoryButtons) do
        button:SetWidth(sidebarWidth - 7)
    end

    ScrollFrame:ClearAllPoints()
    ScrollFrame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", sidebarWidth + 10, -40)
    ScrollFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -25, 10)

    ScrollChild:SetWidth(emoteColumnWidth)

    for _, button in ipairs(buttonsPool) do
        button:SetWidth(math.max(emoteColumnWidth - 5, 1))
    end

    RefreshGeneralWindowFields()
end

local function ApplyExplicitColumnWidths(left, right)
    sidebarWidth = ClampColumnWidth(
        left, minimumSidebarWidth, maximumSidebarWidth, defaults.sidebarWidth
    )
    emoteColumnWidth = ClampColumnWidth(
        right,
        minimumEmoteColumnWidth,
        maximumEmoteColumnWidth,
        defaults.emoteColumnWidth
    )
    local totalWidth = sidebarWidth + emoteColumnWidth + columnChromeWidth
    isApplyingColumnSize = true
    MainFrame:SetWidth(totalWidth)
    isApplyingColumnSize = false
    ApplyColumnLayout()
end

function MainWindow.ApplySidebarWidth(width)
    ApplyExplicitColumnWidths(width, emoteColumnWidth)
end

function MainWindow.ApplyEmoteColumnWidth(width)
    ApplyExplicitColumnWidths(sidebarWidth, width)
end

function MainWindow.ApplyMovementLock()
    local unlocked = not settings.locked

    MainFrame:SetMovable(unlocked and not settings.keepOpen)
    MainFrame:SetResizable(unlocked)

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
        or (isWindowAutoHidden and settings.minimizeToIcon) then
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

    if not settings.fadeEnabled or not MainFrame then
        return
    end

    C_Timer.After(settings.fadeDelay, function()
        if requestedGeneration ~= fadeGeneration
            or not settings.fadeEnabled
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

    if settings.fadeEnabled and MainFrame and not MainFrame:IsMouseOver() then
        ScheduleInactiveFade()
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

    if not (isWindowAutoHidden and settings.minimizeToIcon) then
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
        "{player} - Your character's name without the realm.\n" ..
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

    function dialog:Open(categoryIndex, emoteIndex)
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
        self.Title:SetText(editable and "Edit Emote" or "View Emote")
        self:Show()
        self:Raise()
    end

    emoteEditorDialog = dialog
    return dialog
end

function MainWindow.OpenEmoteEditor(categoryIndex, emoteIndex)
    GetEmoteEditorDialog():Open(categoryIndex, emoteIndex)
end

local function GetContainerButton()
    for _, button in ipairs(buttonsPool) do
        if not button:IsShown() then
            return button
        end
    end

    local button = CreateFrame("Button", nil, ScrollChild)
    button:SetSize(math.max(ScrollChild:GetWidth() - 5, 1), emoteButtonHeight)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("LEFT", button, "LEFT", 7, 0)
    button.EditButton = CreateFrame("Button", nil, button)
    button.EditButton:SetSize(16, 16)
    button.EditButton:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    button.EditButton:SetFrameLevel(button:GetFrameLevel() + 2)
    button.EditButton:RegisterForClicks("LeftButtonUp")
    button.EditButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    button.EditButton:SetHighlightTexture(
        "Interface\\Buttons\\ButtonHilight-Square",
        "ADD"
    )
    button.EditButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Edit emote")
        GameTooltip:Show()
    end)
    button.EditButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button.Text:SetPoint("RIGHT", button.EditButton, "LEFT", -4, 0)
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
    else
        CategoryEmptyLabel:Hide()
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

    for _, button in ipairs(buttonsPool) do
        button:SetScript("OnUpdate", nil)
        button:SetAlpha(1)
        button:Hide()
        button:ClearAllPoints()
        button:SetScript("OnClick", nil)
        button:SetScript("OnDragStart", nil)
        button:SetScript("OnDragStop", nil)
        button.EditButton:SetScript("OnClick", nil)
    end

    emoteDragState = nil
    HideEmoteDropIndicator()

    if not IsCategoryVisible(selectedCategoryIndex) then
        selectedCategoryIndex = FindFirstVisibleCategory()
    end

    settings.selectedCategory = selectedCategoryIndex or defaults.selectedCategory
    UpdateCategorySidebar()

    if not selectedCategoryIndex then
        ScrollChild:SetHeight(1)
        ScrollFrame:SetVerticalScroll(0)
        UpdateScrollIndicators()
        ScheduleInactiveFade()
        return
    end

    local category = GetCurrentCategory(selectedCategoryIndex)

    local visibleEmotes = GetVisibleEmotes(category)
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

        emoteButton:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, -dynamicY)
        emoteButton.Text:SetText(label)
        emoteButton.Text:SetTextColor(
            settings.emoteTextColor.r,
            settings.emoteTextColor.g,
            settings.emoteTextColor.b,
            1
        )
        emoteButton:SetScript("OnClick", function()
            if emoteButton.suppressClick then
                return
            end
            addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
            if not settings.keepOpen then
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

    ScrollChild:SetHeight(math.max(dynamicY, 1))
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

local function UpdateWindowBodyVisibility()
    -- Keep the title bar fixed while the bottom edge rises or falls.
    AnchorFrameByTopLeft()

    if IsWindowBodyHidden() then
        SetCompactResizeBounds()
        CategorySidebar:Hide()
        ScrollFrame:Hide()
        ScrollTopIndicator:Hide()
        ScrollBottomIndicator:Hide()
        if settings.minimizeToIcon then
            TitleText:Hide()
            PinBtn:Hide()
            SettingsBtn:Hide()
            MainFrame:SetBackdrop(nil)
            MainFrame:EnableMouse(false)
            MinimizedIconButton:SetSize(
                settings.minimizedIconSize,
                settings.minimizedIconSize
            )
            MinimizedIconButton:SetShown(MainFrame:IsShown())
            SetInternalFrameSize(settings.width, titleBarHeight)
        else
            TitleText:Show()
            PinBtn:Show()
            MinimizedIconButton:Hide()
            MainFrame:EnableMouse(true)
            ApplyMainFrameBackdrop()
            MainWindow.ApplySettingsGearVisibility()
            SetInternalFrameSize(settings.width, titleBarHeight)
        end
    else
        SetNormalResizeBounds()
        TitleText:Show()
        PinBtn:Show()
        MinimizedIconButton:Hide()
        MainFrame:EnableMouse(true)
        ApplyMainFrameBackdrop()
        MainWindow.ApplySettingsGearVisibility()
        SetInternalFrameSize(settings.width, settings.height)
        CategorySidebar:Show()
        ScrollFrame:Show()
        MainWindow.UpdateMenu()
        C_Timer.After(0, UpdateScrollIndicators)
    end

    MainWindow.ApplyMovementLock()
end

function MainWindow.ApplyMinimizeToIconSettings()
    settings.minimizedIconSize = math.max(
        addon.MIN_MINIMIZED_ICON_SIZE,
        math.min(
            addon.MAX_MINIMIZED_ICON_SIZE,
            math.floor(tonumber(settings.minimizedIconSize)
                or defaults.minimizedIconSize)
        )
    )
    UpdateWindowBodyVisibility()
    RefreshGeneralWindowFields()
end

SetWindowAutoHidden = function(hidden)
    hidden = not not hidden

    if settings.keepOpen then
        hidden = false
    end
    if isWindowAutoHidden == hidden then
        return
    end

    isWindowAutoHidden = hidden
    UpdateWindowBodyVisibility()
end

local function ScheduleWindowAutoHide()
    if settings.keepOpen or isWindowAutoHidden
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

        if settings.keepOpen or isWindowAutoHidden
            or not MainFrame or MainFrame:IsMouseOver() then
            return
        end

        autoHideFading = true
        fadeGeneration = fadeGeneration + 1
        SetWindowOpacity(0, fadeOutDuration, function()
            if requestedGeneration ~= autoHideGeneration then
                return
            end

            autoHideFading = false

            if settings.keepOpen or MainFrame:IsMouseOver() then
                RestoreActiveOpacity(true)
                return
            end

            SetWindowAutoHidden(true)
            SetWindowOpacity(
                settings.fadeEnabled
                    and math.min(settings.inactiveOpacity, settings.windowOpacity)
                    or settings.windowOpacity
            )
        end)
    end)
end

-- MAIN WINDOW
function MainWindow.CreateMainWindow()
    settings = Database.GetSettings()
    selectedCategoryIndex = settings.selectedCategory
    sidebarWidth = settings.sidebarWidth
    emoteColumnWidth = settings.emoteColumnWidth
    MainFrame = CreateFrame("Frame", "RPEmoteMenu", UIParent, "BackdropTemplate")
    MainFrame:SetSize(defaults.width, defaults.height)
    SetNormalResizeBounds()
    MainFrame:SetClampedToScreen(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    MainFrame:SetScript("OnDragStart", function(self)
        if not settings.locked and not settings.keepOpen then
            self:StartMoving()
        end
    end)

    MainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    MainFrame:SetScript("OnSizeChanged", function(self, width)
        if isApplyingColumnSize then return end
        sidebarWidth, emoteColumnWidth, width = DistributeWindowWidth(width)
        settings.sidebarWidth = sidebarWidth
        settings.emoteColumnWidth = emoteColumnWidth
        settings.width = width
        if math.abs(self:GetWidth() - width) > 0.5 then
            isApplyingColumnSize = true
            self:SetWidth(width)
            isApplyingColumnSize = false
        end
        if ApplyColumnLayout then ApplyColumnLayout() end
    end)

    TitleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    TitleText:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    TitleText:SetText("RP Emote Menu " .. addon.VERSION)
    TitleText:SetTextColor(1, 1, 1, 1)

    MinimizedIconButton = CreateFrame("Button", nil, UIParent)
    MinimizedIconButton:SetPoint("TOPLEFT", MainFrame, "TOPLEFT")
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
    MinimizedIconButton:SetScript("OnDragStart", function()
        if not settings.locked then
            MainFrame:StartMoving()
        end
    end)
    MinimizedIconButton:SetScript("OnDragStop", function()
        MainFrame:StopMovingOrSizing()
        SaveWindowPosition()
    end)
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
        settings.keepOpen = not settings.keepOpen
        UpdatePinButton()
        MainWindow.ApplyMovementLock()
        if settings.keepOpen then
            CancelWindowAutoHide()
            SetWindowAutoHidden(false)
        end
    end)

    PinBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(settings.keepOpen and "Window pinned" or "Window unpinned")
        GameTooltip:AddLine(
            settings.keepOpen
                and "The emote menu stays open."
                or "The menu opens on hover and hides when not in use.",
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
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
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
            MainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    ResizeGrip:SetScript("OnMouseUp", function()
        MainFrame:StopMovingOrSizing()
        SaveWindowSize()
    end)

    MainFrame:HookScript("OnEnter", function()
        if isWindowAutoHidden and not settings.minimizeToIcon then
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
        if isWindowAutoHidden and settings.minimizeToIcon then
            MinimizedIconButton:Show()
        end
    end)
    local mouseCheckElapsed = 0
    MainFrame:SetScript("OnUpdate", function(self, elapsed)
        mouseCheckElapsed = mouseCheckElapsed + elapsed
        if mouseCheckElapsed < 0.05 then
            return
        end
        mouseCheckElapsed = 0

        if settings.keepOpen or (isWindowAutoHidden and settings.minimizeToIcon) then
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
    sidebarWidth = settings.sidebarWidth
    emoteColumnWidth = settings.emoteColumnWidth

    if not MainFrame then
        return
    end

    RestoreWindowSize()
    RestoreWindowPosition()
    MainWindow.ApplySidebarWidth(settings.sidebarWidth)
    MainWindow.ApplyMovementLock()
    MainWindow.ApplySettingsGearVisibility()
    MainWindow.ApplyAppearance()
    UpdatePinButton()

    settings.minimized = false
    isWindowAutoHidden = not settings.keepOpen
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
