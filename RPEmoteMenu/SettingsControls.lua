local _, addon = ...
local UI = addon.SettingsUI
local FIELD_GAP = UI.FIELD_GAP
addon.SettingsPanels = addon.SettingsPanels or {}

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


local function CreateScrollablePanel(name)
    local panel = CreateFrame("Frame")
    panel.name = name
    local scroll, content = addon.SettingsWidgets.CreateCanvasScrollBox(panel, {step = 40})
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 0)
    content:SetSize(640, 1)

    local desiredHeight, finished = 1, false
    local layout = { parent = content, offset = 18, items = {} }
    local function Reflow()
        local offset = 18
        for _, item in ipairs(layout.items) do
            local height = item.height
            if item.region and item.region.LayoutFullWidth then
                item.region:SetWidth(math.max(1, content:GetWidth() - item.x - 24))
            end
            if item.autoHeight then
                local text = item.region.LayoutText or item.region
                if item.region.LayoutText then
                    text:SetWidth(item.region:GetWidth())
                    text:SetJustifyH("LEFT")
                end
                text:SetHeight(0) -- Measure wrapped text without its previous height cap.
                height = math.max(16, text:GetStringHeight() + 2)
            end
            if item.region then
                item.region:SetHeight(height)
                item.region:SetPoint("TOPLEFT", content, "TOPLEFT", item.x, -offset)
            end
            offset = offset + height + item.gap
        end
        layout.offset = offset
        desiredHeight = offset + 20
    end
    local function UpdateContentSize(_, width, height)
        width = width or scroll:GetWidth()
        height = height or scroll:GetHeight()
        if width and width > 4 then content:SetWidth(width - 4) end
        if finished then Reflow() end
        content:SetHeight(math.max(desiredHeight, height or 1, 1))
    end
    scroll:HookScript("OnSizeChanged", UpdateContentSize)
    scroll:HookScript("OnShow", function(self)
        UpdateContentSize(self, self:GetWidth(), self:GetHeight())
    end)
    function layout:Add(region, x, height, gap, autoHeight)
        self.items[#self.items + 1] = {region = region, x = x or 24,
            height = height or 20, gap = gap or 0, autoHeight = autoHeight}
        if region.LayoutFullWidth then region:SetWidth(math.max(1, content:GetWidth() - (x or 24) - 24)) end
        region:SetHeight(height or 20)
        region:SetPoint("TOPLEFT", content, "TOPLEFT", x or 24, -self.offset)
        self.offset = self.offset + (height or 20) + (gap or 0)
        return region
    end
    function layout:Space(height)
        self.items[#self.items + 1] = {height = height, gap = 0}
        self.offset = self.offset + height
    end
    function layout:Finish()
        finished = true
        local onShow = panel:GetScript("OnShow")
        panel:SetScript("OnShow", function(self, ...)
            if onShow then onShow(self, ...) end
            UpdateContentSize(scroll, scroll:GetWidth(), scroll:GetHeight())
        end)
        UpdateContentSize(scroll, scroll:GetWidth(), scroll:GetHeight())
    end
    return panel, content, layout
end

local function AddTitle(content, layout, text)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetText(text)
    return layout:Add(title, 24, 24, 8)
end

local function AddDescription(content, layout, text)
    local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description.LayoutFullWidth = true
    description:SetTextColor(0.72, 0.72, 0.72, 1)
    description:SetJustifyH("LEFT")
    description:SetText(text)
    return layout:Add(description, 24, 16, 8, true)
end

local function AddSection(content, layout, text)
    layout:Space(14)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(text)
    return layout:Add(label, 24, 20, 6)
end


UI.CreateScrollablePanel = CreateScrollablePanel
UI.AddTitle = AddTitle
UI.AddDescription = AddDescription
UI.AddSection = AddSection
