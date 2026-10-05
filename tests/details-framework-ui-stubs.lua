-- Minimal native UI stand-ins for loading the real embedded library.
-- No external addon/library stand-ins: LibStub must resolve actual dependencies.
-- Rendering, security and native client event timing remain in-game checks.
strbyte=string.byte; strchar=string.char; strlen=string.len; strupper=string.upper; strgsub=string.gsub
function Saturate(x) return math.max(0,math.min(1,x)) end; function Clamp(x,a,b) return math.max(a,math.min(b,x)) end
UISpecialFrames = {}
C_GuildInfo = {}
LOCALIZED_CLASS_NAMES_MALE = {}; LOCALIZED_CLASS_NAMES_FEMALE = {}
function debugstack() return "Interface/AddOns/RPEmoteMenu/Libs/DetailsFramework/fw.lua" end
bit = {band=function() return 0 end}; function securecallfunction(f, ...) return f(...) end
function getfenv() return _G end
unpack = unpack or table.unpack
loadstring = loadstring or load
floor, ceil, abs, min, max = math.floor, math.ceil, math.abs, math.min, math.max
strmatch, strfind, strsub, strlower, format = string.match, string.find, string.sub, string.lower, string.format
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function Mixin(t, ...) for i=1,select('#',...) do for k,v in pairs(select(i,...)) do t[k]=v end end return t end
function CreateFromMixins(...) return Mixin({}, ...) end
function GetBuildInfo() return '12.1.0','70000','Oct 4 2026',120100 end
function GetLocale() return 'enUS' end
function GetCursorPosition() return 0,0 end
function GetTime() return 0 end
function UnitClass() return 'Mage','MAGE',8 end
function UnitName() return 'Tester' end
function UnitFactionGroup() return 'Alliance' end
function GetPhysicalScreenSize() return 1920,1080 end
function issecretvalue() return false end
function geterrorhandler() return error end
function hooksecurefunc() end
function GetCVar() return '1' end
function GetCVarBool() return false end
function InCombatLockdown() return false end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 1,'Mage' end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1,1
WOW_PROJECT_CLASSIC, WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_WRATH_CLASSIC = 2,5,11
Enum = {SpellBookItemType={Spell=1,None=0,Flyout=2,FutureSpell=3,PetAction=4}, SpellBookSpellBank={Player=0,Pet=1},PowerType={Mana=0}}
C_Spell, C_SpellBook, C_SpecializationInfo = {},{},{}
C_Timer = {After=function() end,NewTimer=function(delay, callback)
    local timer = {Cancel=function(self) self.cancelled=true end}
    C_Timer.After(delay, function() if not timer.cancelled then callback(timer) end end)
    return timer
end,NewTicker=function() return {Cancel=function() end} end}
C_AddOns = {IsAddOnLoaded=function() return false end,GetAddOnMetadata=function() return nil end}
C_Texture = {GetAtlasInfo=function() return nil end}
C_ClassTalents = {}
C_UnitAuras = {}
C_CVar = {GetCVar=GetCVar,GetCVarBool=GetCVarBool}
RAID_CLASS_COLORS = {MAGE={r=1,g=1,b=1,colorStr='ffffffff'}}
CLASS_ICON_TCOORDS = {}
STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
SOUNDKIT = {}
BackdropTemplateMixin = {}
local objects = {}
local methods = {}
local focused
local objectMT = {__index=methods}
local function object(name,parent,kind)
 if name and parent then name=name:gsub("%$[pP]arent",parent.name or "") end
 local t=setmetatable({name=name,parent=parent,kind=kind or 'Frame',scripts={},width=100,height=20},objectMT)
 objects[#objects + 1] = t
 if name then _G[name]=t end
 return t
end
function CreateFrame(kind,name,parent) return object(name,parent,kind) end
function methods:GetName() return self.name end
function methods:GetParent() return self.parent end
function methods:SetOwner(owner) self.owner=owner end
function methods:IsOwned(owner) return self.owner==owner end
function methods:GetObjectType() return self.kind end
function methods:IsObjectType(kind) return self.kind==kind end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetSize() return self.width,self.height end
function methods:GetEffectiveScale() return 1 end
function methods:GetScale() return 1 end
function methods:GetFont() return STANDARD_TEXT_FONT,12,'' end
function methods:GetText() return self.text or '' end
function methods:GetValue() return self.value or 0 end
function methods:SetValue(v) local changed=v~=self.value; self.value=v; if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function methods:SetText(v)
    self.text = v
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:SetFocus()
    local old = focused
    focused = self
    if old and old ~= self and old.scripts.OnEditFocusLost then old.scripts.OnEditFocusLost(old) end
    if old ~= self and self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:HighlightText() end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k,v) local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end v(...) end end
function methods:CreateTexture(name) return object(name,self,'Texture') end
function methods:CreateMaskTexture(name) return object(name,self,"MaskTexture") end
function methods:AddMaskTexture() end
function methods:SetGradient() end
function methods:RemoveMaskTexture() end
function methods:CreateFontString(name) return object(name,self,'FontString') end
function methods:CreateAnimationGroup() return object(nil,self,'AnimationGroup') end
function methods:CreateAnimation() return object(nil,self,'Animation') end
function methods:GetStringWidth() return 20 end
function methods:GetStringHeight() return 12 end
function methods:IsMovable() return false end
function methods:IsMouseOver() return true end
function methods:IsEnabled() return self.enabled ~= false end
function methods:IsShown() return self.shown ~= false end
function methods:GetFrameLevel() return 1 end
function methods:SetIndentedWordWrap() end
function methods:SetWordWrap() end
function methods:GetPushedTexture() return self.normalTexture end
function methods:GetHighlightTexture() return self.normalTexture end
function methods:GetDisabledTexture() return self.normalTexture end
function methods:GetNormalTexture() return self.normalTexture end
function methods:SetNormalTexture(path) self.normalTexture=object(nil,self,"Texture"); self.normalTexture.texture=path end
function methods:GetThumbTexture() return self.thumbTexture end
function methods:SetThumbTexture(texture) self.thumbTexture=texture end
function methods:SetScrollChild(child) self.scrollChild=child end
function methods:GetScrollChild() return self.scrollChild end
function methods:SetPushedTextOffset() end
function methods:GetDrawLayer() return "ARTWORK",1 end
function methods:ClearFocus()
    if focused == self then
        focused = nil
        if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetVertexColor() return unpack(self.color or {1,1,1,1}) end
function methods:GetNumPoints() return 0 end
for _,k in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetAlpha','SetTexture','SetColorTexture','SetVertexColor','SetTexCoord','SetDrawLayer','SetFont','SetFontObject','SetTextColor','SetJustifyH','SetJustifyV','SetShadowColor','SetShadowOffset','RegisterEvent','RegisterUnitEvent','UnregisterEvent','Hide','Show','SetFrameStrata','SetFrameLevel','SetParent','SetScale','Enable','Disable','EnableMouse','SetClampedToScreen','SetMovable','SetResizable','RegisterForDrag','RegisterForClicks','SetNormalTexture','SetPushedTexture','SetHighlightTexture','SetDisabledTexture','SetAutoFocus','SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetThumbTexture','SetBlendMode','SetAtlas','SetHitRectInsets','SetLooping','SetDuration','SetOrder','SetSmoothing','SetFromAlpha','SetToAlpha','SetTarget','SetChildKey','SetOffset','SetStartDelay','SetEndDelay','SetSpeed','SetDegrees','SetOrigin','SetScript','SetMaxLetters','SetWordWrap','SetNonSpaceWrap','SetNumeric','SetMultiLine','SetTextInsets','SetFontString','SetToplevel','SetIgnoreParentAlpha','Stop','Play','SetDesaturated'}) do
 if not methods[k] then methods[k]=function() end end
end
function methods:SetPoint(...)
    self.point = {...}
    self.points = self.points or {}
    self.points[self.point[1]] = self.point
end
function methods:GetBackdropColor() return unpack(self.backdropColor or {0,0,0,1}) end
function methods:GetBackdropBorderColor() return unpack(self.backdropBorderColor or {0,0,0,0}) end
function methods:GetTextColor() return unpack(self.textColor or {1,1,1,1}) end
function methods:SetBackdrop(value) self.backdrop=value end
function methods:SetBackdropColor(...) self.backdropColor={...} end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor={...} end
function methods:SetTexture(value) self.texture=value end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetTextColor(...) self.textColor={...} end
function methods:EnableMouse(enabled) self.mouseEnabled=enabled end
function methods:Show() self.shown=true end
function methods:Hide()
    local wasShown = self:IsShown(); self.shown=false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
function methods:SetCursorPosition(value) self.cursor = value end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetMinMaxValues(minimum,maximum) self.minimum,self.maximum=minimum,maximum end
function methods:GetMinMaxValues() return self.minimum,self.maximum end
function methods:SetValueStep(step) self.step = step end
function methods:SetParent(parent) self.parent = parent end
function methods:EnableMouseWheel(enabled) self.mouseWheel = enabled end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetVerticalScrollRange()
    return math.max(0, (self.scrollChild and self.scrollChild:GetHeight() or 0) - self:GetHeight())
end
function methods:UpdateScrollChildRect()
    if self.scripts.OnScrollRangeChanged then
        self.scripts.OnScrollRangeChanged(self, 0, self:GetVerticalScrollRange())
    end
end
function methods:GetRegions()
    local regions = {}
    for _, region in ipairs(objects) do
        if region.parent == self and (region.kind == "FontString" or region.kind == "Texture") then
            regions[#regions + 1] = region
        end
    end
    return unpack(regions)
end
UIParent=object('UIParent'); GameTooltip=object('GameTooltip'); ColorPickerFrame=object('ColorPickerFrame')
for _,k in ipairs({'GameFontNormal','GameFontHighlight','GameFontNormalSmall','GameFontHighlightSmall','GameFontNormalLarge','GameFontHighlightLarge','NumberFontNormal','NumberFontNormalSmall'}) do _G[k]=object(k,nil,'Font') end
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self.info, self.extraInfo = info, info.extraInfo
    self:Show()
    info.swatchFunc() -- Native setup may synchronously set the initial selection.
end
function ColorPickerFrame:GetExtraInfo() return self.extraInfo end
function ColorPickerFrame:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
PixelUtil={SetSize=function(o,...)o:SetSize(...)end,SetPoint=function(o,...)o:SetPoint(...)end,SetWidth=function(o,...)o:SetWidth(...)end,SetHeight=function(o,...)o:SetHeight(...)end,GetPixelToUIUnitFactor=function()return 1 end}

function methods:SetMaxLetters(n) self.maxLetters=n end
function methods:Raise() end
function methods:SetMaxBytes(n) self.maxBytes=n end

return {objects = objects}
