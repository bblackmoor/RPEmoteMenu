local _, addon = ...
local L = addon.L
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local SOURCE_URL = "https://github.com/bblackmoor/rpemotemenu"

local function CreateAboutPanel()
    local panel, content, layout = UI.CreateScrollablePanel("About")
    StaticPopupDialogs["RPEMOTEMENU_COPY_SOURCE"] = {
        text = L.COPY_SOURCE_PROMPT,
        button1 = CLOSE or L.CLOSE,
        hasEditBox = true,
        maxLetters = 255,
        editBoxWidth = 340,
        OnShow = function(self, url)
            local editBox = self.GetEditBox and self:GetEditBox() or self.editBox

            editBox:SetText(url or self.data or SOURCE_URL)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self)
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3
    }

    UI.AddTitle(content, layout, L.TAB_ABOUT)
    UI.AddDescription(content, layout,
        L.ABOUT_DESCRIPTION)
    UI.AddDescription(content, layout,
        string.format(L.ABOUT_METADATA, addon.VERSION))
    UI.AddDescription(content, layout, L.SOURCE_LABEL)
    local sourceLink = Widgets.CreateLink(content, SOURCE_URL, function()
        StaticPopup_Show("RPEMOTEMENU_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)
    local sourceFrame = sourceLink:GetFrame()
    sourceFrame.LayoutFullWidth = true
    sourceFrame.text:SetWordWrap(true)
    sourceFrame.text:SetNonSpaceWrap(true)
    sourceFrame.LayoutText = sourceFrame.text
    layout:Add(sourceFrame, 24, 16, 8, true)
    UI.AddSection(content, layout, L.COMMANDS_HEADING)
    UI.AddDescription(content, layout,
        L.ABOUT_COMMANDS)
    UI.AddSection(content, layout, L.TOKENS_HEADING)
    UI.AddDescription(content, layout,
        L.ABOUT_TOKENS)
    layout:Finish()
    return panel
end

addon.SettingsPanels.About = CreateAboutPanel

