local addon = {}
assert(loadfile('RPEmoteMenu/MenuDrag.lua'))('RPEmoteMenu', addon)
local cursorX, cursorY, scale = 0, 0, 1
GetCursorPosition = function() return cursorX, cursorY end
UIParent = {GetEffectiveScale=function() return scale end}
local function Cursor(x, y) cursorX, cursorY = x * scale, y * scale end
local function Row(left, top, position)
    return {
        left=left, top=top, shown=true, visiblePosition=position,
        IsShown=function(self) return self.shown end,
        GetLeft=function(self) return self.left end,
        GetRight=function(self) return self.left and self.left+100 end,
        GetTop=function(self) return self.top end,
        GetBottom=function(self) return self.top and self.top-40 end,
    }
end
local function Pane(rows)
    local frame = {
        scroll=50, top=200, bottom=100, height=100,
        GetTop=function(self) return self.top end,
        GetBottom=function(self) return self.bottom end,
        GetHeight=function(self) return self.height end,
        GetVerticalScroll=function(self) return self.scroll end,
        SetVerticalScroll=function(self, value) self.scroll=value end,
    }
    local child = {height=300, textures={}}
    function child:GetHeight() return self.height end
    function child:CreateTexture()
        local texture = {
            SetHeight=function(self, height) self.height=height end,
            SetColorTexture=function(self, ...) self.color={...} end,
            ClearAllPoints=function(self) self.points={} end,
            SetPoint=function(self, ...) self.points[#self.points+1]={...} end,
            Show=function(self) self.shown=true end,
            Hide=function(self) self.shown=false end,
        }
        self.textures[#self.textures+1] = texture
        return texture
    end
    local color = {r=0.2,g=0.3,b=0.4}
    return addon.MenuDrag.Create(frame, child, rows, function() return color end), frame, child, color
end
local row = Row(20, 180, 1)
local controller, frame, child, color = Pane({row})
local state = {}
controller.Hide()
controller.Update(nil, 1)
assert(#child.textures == 0 and frame.scroll == 50)
-- Scaling, inclusive rectangle edges, and the midpoint's before/after boundary.
for _, factor in ipairs({0.5, 1, 2}) do
    scale = factor
    for _, point in ipairs({{20,180,true}, {120,160,true}, {70,159,false}, {120,140,false}}) do
        Cursor(point[1], point[2])
        controller.Update(state, 0)
        assert(state.targetButton == row and state.insertBefore == point[3])
        local indicator = child.textures[1]
        assert(indicator.shown and indicator.height == 2 and #indicator.points == 3)
        assert(indicator.points[3][1] == (point[3] and 'BOTTOM' or 'TOP'))
        assert(indicator.points[3][2] == row)
    end
end
assert(#child.textures == 1, 'indicator was recreated during updates')
color.r = 0.9
controller.Update(state)
assert(child.textures[1].color[1] == 0.9, 'indicator retained an old Theme color')
-- A miss clears both target fields and hides the existing indicator.
for _, point in ipairs({{19,160}, {121,160}, {70,181}, {70,139}}) do
    Cursor(point[1], point[2]); controller.Update(state, 0)
    assert(state.targetButton == nil and state.insertBefore == nil and not child.textures[1].shown)
end
Cursor(70,160)
row.shown=false; controller.Update(state, 0); assert(state.targetButton == nil)
row.shown=true; row.visiblePosition=nil; controller.Update(state, 0); assert(state.targetButton == nil)
row.visiblePosition=1; row.top=nil; controller.Update(state, 0); assert(state.targetButton == nil)
row.top=180
-- Scroll thresholds are strict; speed is time-based and clamped at both ends.
Cursor(70,186); controller.Update(state, 1); assert(frame.scroll == 50)
Cursor(70,187); controller.Update(state, 0.1); assert(frame.scroll == 36)
controller.Update(state, 1); assert(frame.scroll == 0)
Cursor(70,114); controller.Update(state, 1); assert(frame.scroll == 0)
Cursor(70,113); controller.Update(state, 0.5); assert(frame.scroll == 70)
controller.Update(state, 2); assert(frame.scroll == 200)
controller.Update(state); assert(frame.scroll == 200)
child.height=50; frame.scroll=0
controller.Update(state, 1); assert(frame.scroll == 0)
-- Hit testing must observe row geometry after the scroll setter runs.
child.height=300
function frame:SetVerticalScroll(value) self.scroll=value; row.top=140 end
Cursor(70,110); controller.Update(state, 0.1)
assert(state.targetButton == row and state.insertBefore == false)
-- Separate pane indicators and state do not affect one another.
local otherRow = Row(20, 180, 1)
local other, _, otherChild = Pane({otherRow})
local otherState = {}
Cursor(70,160); other.Update(otherState, 0)
controller.Hide()
assert(not child.textures[1].shown and otherChild.textures[1].shown)
assert(otherState.targetButton == otherRow)
-- Pools are retained by reference so newly allocated rows can be targeted.
local rows = {}
local growing = Pane(rows)
rows[1] = otherRow
local growingState = {}
growing.Update(growingState, 0)
assert(growingState.targetButton == otherRow)
print('PASS drag cursor scaling, hit boundaries, row eligibility, scroll thresholds/clamps/order and independent reusable indicators')
