local _, addon = ...
local UI, Widgets = addon.SettingsUI, addon.SettingsWidgets
local SOURCE_URL = "https://github.com/bblackmoor/rpemotemenu"

function UI.CreateAboutPanel()
    local panel, content, layout = UI.CreateScrollablePanel("About")
    StaticPopupDialogs["RPEMOTEMENU_COPY_SOURCE"] = {
        text = "Press Ctrl+C to copy the source URL.",
        button1 = CLOSE or "Close",
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

    UI.AddTitle(content, layout, "About")
    UI.AddDescription(content, layout,
        "A customizable roleplaying emote menu with Profiles, targeted commands, Profile sharing, and shared Themes for appearance. Each character selects a Profile; Profiles assign a Theme.")
    UI.AddDescription(content, layout,
        "Version: " .. addon.VERSION .. "\nAuthor: Brandon Blackmoor\nCategory: Roleplay\nLicense: GPL-3.0")
    UI.AddDescription(content, layout, "Source:")
    local sourceLink = Widgets.CreateLink(content, SOURCE_URL, function()
        StaticPopup_Show("RPEMOTEMENU_COPY_SOURCE", nil, nil, SOURCE_URL)
    end)
    local sourceFrame = sourceLink:GetFrame()
    sourceFrame.LayoutFullWidth = true
    sourceFrame.text:SetWordWrap(true)
    sourceFrame.text:SetNonSpaceWrap(true)
    sourceFrame.LayoutText = sourceFrame.text
    layout:Add(sourceFrame, 24, 16, 8, true)
    UI.AddSection(content, layout, "Commands")
    UI.AddDescription(content, layout,
        "/rpem — Toggle RP Emote Menu Active or Inactive\n" ..
        "/rpem about — This page\n" ..
        "/rpem config, /rpem options or /rpem settings — Addon settings")
    UI.AddSection(content, layout, "Character-name tokens")
    UI.AddDescription(content, layout,
        "{target} — Target's name without the realm\n" ..
        "{player} — Current character's name without the realm")
    layout:Finish()
    return panel
end
