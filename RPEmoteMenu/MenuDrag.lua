local _, addon = ...

addon.MenuDrag = {}
local MenuDrag = addon.MenuDrag

local function GetScaledCursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function ScrollAtEdge(frame, child, cursorY, elapsed)
    local top, bottom = frame:GetTop(), frame:GetBottom()
    local maximum = math.max(child:GetHeight() - frame:GetHeight(), 0)
    local current = frame:GetVerticalScroll() or 0
    local distance = 140 * (elapsed or 0)

    if top and cursorY > top - 14 and current > 0 then
        frame:SetVerticalScroll(math.max(0, current - distance))
    elseif bottom and cursorY < bottom + 14 and current < maximum then
        frame:SetVerticalScroll(math.min(maximum, current + distance))
    end
end

local function FindTarget(buttons, cursorX, cursorY)
    for _, button in ipairs(buttons) do
        if button:IsShown() and button.visiblePosition then
            local left, right = button:GetLeft(), button:GetRight()
            local top, bottom = button:GetTop(), button:GetBottom()
            if left and right and top and bottom
                and cursorX >= left and cursorX <= right
                and cursorY <= top and cursorY >= bottom then
                return button, cursorY >= ((top + bottom) / 2)
            end
        end
    end
    return nil, nil
end

-- Each pane owns its indicator. The caller owns drag lifetime, ordering,
-- selection and click suppression; the color getter follows Theme changes.
function MenuDrag.Create(scrollFrame, scrollChild, buttons, getColor)
    local controller = {}
    local indicator

    function controller.Hide()
        if indicator then indicator:Hide() end
    end

    local function ShowIndicator(button, insertBefore)
        if not indicator then
            indicator = scrollChild:CreateTexture(nil, "OVERLAY")
            indicator:SetHeight(2)
        end
        local color = getColor()
        indicator:SetColorTexture(color.r, color.g, color.b, 1)
        indicator:ClearAllPoints()
        indicator:SetPoint("LEFT", button, "LEFT", 2, 0)
        indicator:SetPoint("RIGHT", button, "RIGHT", -2, 0)
        if insertBefore then
            indicator:SetPoint("BOTTOM", button, "TOP", 0, 1)
        else
            indicator:SetPoint("TOP", button, "BOTTOM", 0, -1)
        end
        indicator:Show()
    end

    function controller.Update(state, elapsed)
        if not state then return end
        local cursorX, cursorY = GetScaledCursorPosition()
        -- Hit testing follows scrolling so rows use their updated positions.
        ScrollAtEdge(scrollFrame, scrollChild, cursorY, elapsed)
        state.targetButton, state.insertBefore = FindTarget(buttons, cursorX, cursorY)
        if state.targetButton then
            ShowIndicator(state.targetButton, state.insertBefore)
        else
            controller.Hide()
        end
    end

    return controller
end
