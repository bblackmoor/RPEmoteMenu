local _, addon = ...
local UI = addon.SettingsUI
local FIELD_GAP = UI.FIELD_GAP

-- Ordinary rows share one cursor. Each panel chooses its own starting point
-- and can add a deliberate gap before a new section.
function UI.CreateRows(parent, x, startY, rowHeight)
    local rows = {parent = parent, x = x, y = startY, rowHeight = rowHeight or 30}

    function rows:Next(height)
        local y = self.y
        self.y = y - (height or self.rowHeight)
        return y
    end

    function rows:Gap(height)
        self.y = self.y - height
    end

    function rows:Heading(label, after)
        local heading = self.parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x, self:Next(after))
        heading:SetText(label)
        return heading
    end

    return rows
end

local function CreateInfoLink(parent, anchor, dialogName)
    local link = CreateFrame("Button", nil, parent)
    link:SetPoint("LEFT", anchor, "RIGHT", FIELD_GAP, 0)
    local circle = link:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    circle:SetPoint("CENTER")
    circle:SetText("O")
    local letter = link:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letter:SetPoint("CENTER")
    letter:SetText("i")
    link:SetSize(
        math.ceil(math.max(circle:GetStringWidth(), letter:GetStringWidth()) + 6),
        math.ceil(math.max(circle:GetStringHeight(), letter:GetStringHeight()) + 4)
    )
    link:SetScript("OnClick", function()
        StaticPopup_Show(dialogName)
    end)
    return link
end

UI.CreateInfoLink = CreateInfoLink
