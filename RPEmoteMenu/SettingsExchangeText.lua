-- Wrapped text sizing and caret visibility, independent of imports/dialog modes.
local _, addon = ...
local TextLayout = {}
addon.ExchangeTextLayout = TextLayout

function TextLayout.Create(options)
    local editBox, scrollFrame = options.editBox, options.scrollFrame
    local scrollContent, measurement = options.scrollContent, options.measurement
    measurement:SetWordWrap(true)
    measurement:SetNonSpaceWrap(true)
    measurement:Hide()
    local updatingLayout = false
    local caretTop, caretBottom, caretWidth
    local followCaret = false
    local function KeepCaretVisible()
        if not caretTop then return end
        local offset = scrollFrame:GetVerticalScroll()
        local viewportHeight = scrollFrame:GetHeight()
        if caretTop < offset + 4 then
            offset = caretTop - 4
        elseif caretBottom > offset + viewportHeight - 4 then
            offset = caretBottom - viewportHeight + 4
        end
        scrollFrame:SetVerticalScroll(math.max(0,
            math.min(offset, scrollFrame:GetVerticalScrollRange())))
    end
    local function RefreshTextLayout(keepCaret)
        if keepCaret then followCaret = true end
        if updatingLayout then return end
        updatingLayout = true
        local width = math.max(1, scrollFrame:GetWidth())
        -- Old y coordinates are invalid after rewrapping. Native cursor events
        -- supply fresh bounds when the editor's width changes.
        if caretWidth ~= width then caretTop, caretBottom, caretWidth = nil, nil, nil end
        editBox:SetWidth(width)
        scrollContent:SetWidth(width)
        measurement:SetFont(editBox:GetFont())
        measurement:SetWidth(math.max(1, width - 8))
        measurement:SetText((editBox:GetText() or "") .. " ")
        local height = math.max(scrollFrame:GetHeight(),
            measurement:GetStringHeight() + 8, followCaret and caretBottom and caretBottom + 4 or 0)
        editBox:SetHeight(height)
        scrollContent:SetHeight(height)
        scrollFrame:RefreshViewport()
        updatingLayout = false
        if followCaret then
            followCaret = false
            KeepCaretVisible()
        end
    end

    return {
        Refresh = RefreshTextLayout,
        ResetCaret = function() caretTop, caretBottom, caretWidth = nil, nil, nil end,
        UpdateCaret = function(y, height)
            -- Native cursor y is negative downward from the editor's top.
            caretTop = math.max(0, -y)
            caretBottom = caretTop + height
            caretWidth = editBox:GetWidth()
            RefreshTextLayout(true)
        end,
    }
end
