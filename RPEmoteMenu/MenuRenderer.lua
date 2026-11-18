local _, addon = ...
local L = addon.L
local Typography = addon.WindowTypography
local MAX_CATEGORIES = addon.MAX_CATEGORIES

-- Own row construction, bindings and rendering. The window supplies live
-- settings and interaction callbacks; geometry and drag state stay with it.
addon.MenuRenderer = {}
function addon.MenuRenderer.Create(context, view, categoryButtons, buttonsPool)
    local renderer = {}
    local MainWindow = context.window

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
        local highlight = context.GetTheme().categoryHighlightColor
        local background = context.GetTheme().emoteBackgroundColor
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
            string.format(L.MENU_DEFAULT_COMMAND, button.defaultCommand),
            0.9,
            0.9,
            0.9,
            true
        )

        if button.targetedCommand and button.targetedCommand ~= "" then
            GameTooltip:AddLine(
                string.format(L.MENU_TARGETED_COMMAND, button.targetedCommand),
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
        local showGear = not context.GetGlobalSettings().hideSettingsGear
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

        local button = CreateFrame("Button", nil, view.ScrollChild)
        button:SetSize(math.max(view.ScrollChild:GetWidth() - 5, 1), context.GetEmoteHeight())

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
            context.ScheduleTooltip(self, function()
                return PopulateEmoteTooltip(button, self, L.MENU_CLICK_TO_EDIT)
            end)
        end)
        button.EditButton:SetScript("OnLeave", function(self)
            ScheduleEmoteHoverRefresh(button)
            context.CancelTooltip(self)
        end)

        button:SetScript("OnEnter", function(self)
            SetEmoteHovered(button, true)
            context.ScheduleTooltip(self, function()
                return PopulateEmoteTooltip(button, self, L.MENU_RIGHT_CLICK_TO_EDIT)
            end)
        end)
        button:SetScript("OnLeave", function(self)
            ScheduleEmoteHoverRefresh(button)
            context.CancelTooltip(self)
        end)

        button.Text:SetPoint("RIGHT", button.EditButton, "LEFT", -8, 0)
        button.Text:SetJustifyH("LEFT")
        button.Text:SetWordWrap(false)
        Typography.ApplyFont(
            button.Text,
            context.GetTheme().emoteFont,
            context.GetTheme().emoteFontSize,
            context.GetTheme().emoteTextColor
        )

        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if not self.emoteIndex or self.suppressClick then
                return
            end
            if mouseButton == "RightButton" then
                MainWindow.OpenEmoteEditor(button.emoteCategoryIndex, button.emoteIndex)
                return
            end
            addon.Commands.ExecuteEmoteCommand(self.defaultCommand, self.targetedCommand, self.defaultSend, self.targetedSend)
            if context.GetProfile().fadeEnabled and context.UsesMinimizedDisplay() then
                context.SetWindowAutoHidden(true)
            end
        end)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", context.StartEmoteDrag)
        button:SetScript("OnDragStop", context.StopEmoteDrag)
        button.EditButton:SetScript("OnClick", function()
            if not button.emoteIndex then return end
            MainWindow.OpenEmoteEditor(button.emoteCategoryIndex, button.emoteIndex)
        end)

        table.insert(buttonsPool, button)
        return button
    end

    function renderer.ApplyCategoryHighlight(button, isSelected)
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

        local color = context.GetTheme().categoryHighlightColor
        local effect = not isSelected and button.isHovered
            and "background"
            or context.GetTheme().categoryHighlightEffect

        if effect == "background" then
            button.Selection:SetColorTexture(
                color.r,
                color.g,
                color.b,
                0.85 * strength
            )
            button.Selection:Show()
        elseif effect == "outline" then
            local thickness = context.GetTheme().categoryHighlightThickness
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
            button.SelectionUnderline:SetHeight(context.GetTheme().categoryHighlightThickness)
            button.SelectionUnderline:SetColorTexture(
                color.r, color.g, color.b, strength
            )
            button.SelectionUnderline:Show()
        elseif effect == "shadow" then
            button.Text:SetShadowColor(color.r, color.g, color.b, strength)
            button.Text:SetShadowOffset(2, -2)
        elseif effect == "separator" then
            button.SelectionOutline.right:SetWidth(context.GetTheme().categoryHighlightThickness)
            button.SelectionOutline.right:SetColorTexture(
                color.r, color.g, color.b, strength
            )
            button.SelectionOutline.right:Show()
        end
    end

    function renderer.UpdateCategories()
        if not view.CategoryScrollChild then
            return
        end

        local visibleCount = 0

        for categoryIndex = 1, MAX_CATEGORIES do
            local button = categoryButtons[categoryIndex]
            local category = context.GetCurrentCategory(categoryIndex)

            if button and context.IsCategoryVisible(categoryIndex) then
                button:ClearAllPoints()
                button:SetPoint(
                    "TOPLEFT",
                    view.CategoryScrollChild,
                    "TOPLEFT",
                    0,
                    -visibleCount * context.GetCategoryHeight()
                )
                button.Text:SetText(category.name)
                button.visiblePosition = visibleCount + 1
                for _, outlineText in ipairs(button.TextOutline) do
                    outlineText:SetText(category.name)
                end

                local isSelected = categoryIndex == context.GetSelectedCategory()
                MainWindow.ApplyCategoryHighlight(button, isSelected)

                local textColor = isSelected
                    and context.GetTheme().selectedCategoryTextColor
                    or context.GetTheme().categoryTextColor

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

        view.CategoryScrollChild:SetHeight(math.max(visibleCount * context.GetCategoryHeight(), 1))

        if visibleCount == 0 then
            view.CategoryEmptyLabel:Show()
            view.CategoryEmptyButton:Show()
        else
            view.CategoryEmptyLabel:Hide()
            view.CategoryEmptyButton:Hide()
        end

        local maximumScroll = math.max(
            view.CategoryScrollChild:GetHeight() - view.CategoryScrollFrame:GetHeight(),
            0
        )
        view.CategoryScrollFrame:SetVerticalScroll(
            math.min(view.CategoryScrollFrame:GetVerticalScroll() or 0, maximumScroll)
        )
    end

    function renderer.CreateCategories()
        for categoryIndex = 1, MAX_CATEGORIES do
            local button = CreateFrame("Button", nil, view.CategoryScrollChild)
            button:SetSize(context.GetSidebarWidth() - 7, context.GetCategoryHeight())
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
            Typography.ApplyFont(
                button.Text,
                context.GetTheme().categoryFont,
                context.GetTheme().categoryFontSize,
                context.GetTheme().categoryTextColor
            )

            button:SetScript("OnEnter", function(self)
                self.isHovered = true
                if context.IsCategoryDragging() then
                    return
                elseif self.categoryIndex ~= context.GetSelectedCategory() then
                    MainWindow.SetSelectedCategory(self.categoryIndex)
                    MainWindow.UpdateMenu()
                else
                    MainWindow.ApplyCategoryHighlight(self, true)
                end
                context.ScheduleTooltip(self, function()
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.Text:GetText())
                    GameTooltip:AddLine(L.MENU_RIGHT_CLICK_TO_EDIT, 1, 0.82, 0, false)
                end)
            end)
            button:SetScript("OnLeave", function(self)
                self.isHovered = false
                MainWindow.ApplyCategoryHighlight(
                    self,
                    self.categoryIndex == context.GetSelectedCategory()
                )
                context.CancelTooltip(self)
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
            button:SetScript("OnDragStart", context.StartCategoryDrag)
            button:SetScript("OnDragStop", context.StopCategoryDrag)
            button:Hide()

            categoryButtons[categoryIndex] = button
        end
    end

    function renderer.ResetEmotes()
        for _, button in ipairs(buttonsPool) do
            button:SetScript("OnUpdate", nil)
            button:SetAlpha(1)
            SetEmoteHovered(button, false)
            button:Hide()
            button:ClearAllPoints()
            button.emoteCategoryIndex = nil
            button.emoteIndex = nil
            button.visiblePosition = nil
            button.defaultSend = nil
            button.targetedSend = nil
            button.emoteLabel = nil
            button.defaultCommand = nil
            button.targetedCommand = nil
        end
    end

    function renderer.RenderEmotes()
        local category = context.GetCurrentCategory(context.GetSelectedCategory())

        local visibleEmotes = context.GetVisibleEmotes(category)
        view.EmoteEmptyButton:SetShown(#visibleEmotes == 0)
        local dynamicY = 0

        for visiblePosition, visible in ipairs(visibleEmotes) do
            local emote = visible.emote
            local emoteIndex = visible.index
            local label = emote.label
            local defaultCommand = emote.defaultCommand
            local targetedCommand = emote.targetedCommand
            local emoteButton = GetContainerButton()
            emoteButton.visiblePosition = visiblePosition
            emoteButton.emoteCategoryIndex = context.GetSelectedCategory()
            emoteButton.emoteIndex = emoteIndex
            emoteButton.defaultSend = emote.defaultSend
            emoteButton.targetedSend = emote.targetedSend
            emoteButton.emoteLabel = label
            emoteButton.defaultCommand = defaultCommand
            emoteButton.targetedCommand = targetedCommand
            ApplyEmoteGearVisibility(emoteButton)

            emoteButton:SetPoint("TOPLEFT", view.ScrollChild, "TOPLEFT", 0, -dynamicY)
            emoteButton.Text:SetText(label)
            emoteButton.Text:SetTextColor(
                context.GetTheme().emoteTextColor.r,
                context.GetTheme().emoteTextColor.g,
                context.GetTheme().emoteTextColor.b,
                1
            )
            emoteButton:Show()

            dynamicY = dynamicY + context.GetEmoteHeight() + 2
        end

        view.ScrollChild:SetHeight(math.max(dynamicY, #visibleEmotes == 0 and 26 or 1))
        view.ScrollFrame:SetVerticalScroll(0)

        addon.Scheduling.NextTick(context.scrollKey, context.UpdateScrollIndicators)

    end

    renderer.ApplyEmoteHoverHighlight = ApplyEmoteHoverHighlight
    return renderer
end
