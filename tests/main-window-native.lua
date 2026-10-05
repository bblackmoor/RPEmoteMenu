-- Native rendering support for real MainWindow integration tests. Call after
-- details-framework-ui-stubs.lua; no addon private state is exposed or replaced.
local methods = getmetatable(UIParent).__index
-- Deliver main-window events synchronously to exercise the coordinator's reentrancy
-- guards. Real client rendering/event timing still requires in-game acceptance.
function methods:SetSize(width,height)
    local changed=width~=self.width or height~=self.height
    self.width,self.height=width,height
    if changed and self.name=='RPEmoteMenu' and self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self,width,height)
    end
end
function methods:SetWidth(width) self:SetSize(width,self.height) end
function methods:SetHeight(height) self:SetSize(self.width,height) end
function methods:SetResizeBounds(...)
    self.resizeBounds={...}
end
function methods:Show()
    local wasShown=self:IsShown()
    self.shown=true
    if not wasShown and self.name=='RPEmoteMenu' and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:StartSizing(direction) self.sizing=direction end
function methods:StopMovingOrSizing() self.sizing=nil end
function methods:GetShadowOffset() return 0, 0 end
function methods:GetShadowColor() return 0, 0, 0, 1 end
function methods:SetRotation(value) self.rotation = value end
function methods:IsPlaying() return not not self.playing end
function methods:Play() self.playing=true end
function methods:Stop() self.playing=false end
function methods:GetAlpha() return self.alpha or 1 end
function methods:IsMouseOver() return self.mouseover ~= false end
function methods:GetLeft()
    if self.left then return self.left end
    local p = self.point
    if not p then return 0 end
    local relative = p[2] or UIParent
    local left = relative == self and 0 or relative:GetLeft()
    if p[3] == 'CENTER' then left = left + relative:GetWidth() / 2 end
    if p[1] == 'CENTER' then left = left - self:GetWidth() / 2 end
    return left + (p[4] or 0)
end
function methods:GetTop()
    if self.top then return self.top end
    local p = self.point
    if not p then return self == UIParent and self:GetHeight() or 600 end
    local relative = p[2] or UIParent
    local top = relative == self and 0 or relative:GetTop()
    if p[3] == 'BOTTOMLEFT' then top = top - relative:GetHeight()
    elseif p[3] == 'CENTER' then top = top - relative:GetHeight() / 2 end
    if p[1] == 'CENTER' then top = top + self:GetHeight() / 2 end
    return top + (p[5] or 0)
end
function methods:GetRight() return self:GetLeft() + self:GetWidth() end
function methods:GetBottom() return self:GetTop() - self:GetHeight() end
function methods:AddLine(text)
    self.lines=self.lines or {}; self.lines[#self.lines+1]=text
end
return methods
