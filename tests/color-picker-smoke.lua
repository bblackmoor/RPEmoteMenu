-- Real database mutations and both native color-picker owners.
local addon={SettingsUI={FIELD_GAP=12},Settings={},MainWindow={}}
local function loadModule(n) assert(loadfile('RPEmoteMenu/'..n))('RPEmoteMenu',addon) end
function strtrim(v) return (v:gsub('^%s+',''):gsub('%s+$','')) end
function UnitName() return 'Tester','Realm' end
STANDARD_TEXT_FONT='font'
local Widget={}
Widget.__index=function(_,k) return Widget[k] or function() end end
function Widget:SetScript(k,fn) self.scripts[k]=fn end
function Widget:HookScript(k,fn)
 local old=self.scripts[k]
 self.scripts[k]=function(...) if old then old(...) end; fn(...) end
end
function Widget:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Widget:CreateFontString() return CreateFrame('FontString',nil,self) end
function Widget:CreateTexture() return CreateFrame('Texture',nil,self) end
local frames={}
function CreateFrame(kind,_,parent)
 local w=setmetatable({scripts={},parent=parent,shown=true},Widget)
 frames[#frames+1]=w; return w
end
ColorPickerFrame=CreateFrame('Frame')
function ColorPickerFrame:GetExtraInfo() return self.info and self.info.extraInfo end
function ColorPickerFrame:GetColorRGB() return self.r,self.g,self.b end
function ColorPickerFrame:SetupColorPickerAndShow(info)
 self.info=info; self.shown=true; self.r,self.g,self.b=info.r,info.g,info.b
 info.swatchFunc()
end
addon.MinimizedIconColor={Apply=function() end}
loadModule('Defaults.lua'); loadModule('BuiltInThemes.lua'); loadModule('Database.lua')
local db=addon.Database; db.InitializeDatabase()
local module=io.open('RPEmoteMenu/SettingsColorPicker.lua')
if module then module:close(); loadModule('SettingsColorPicker.lua') end
loadModule('SettingsControls.lua'); loadModule('SettingsThemeIcon.lua')
local parent=CreateFrame('Frame'); local writes=0
local function color() return db.GetThemeSettings().categoryTextColor end
local swatch=addon.SettingsUI.CreateColorSetting(parent,'Text','categoryTextColor',0,0,color,
 function(v) writes=writes+1; db.GetThemeSettings().categoryTextColor=v end)
local function open() swatch.scripts.OnClick(swatch); return ColorPickerFrame.info end
local function preview(info,r,g,b)
 ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=r,g,b; info.swatchFunc()
end
local function same(c,e) assert(c.r==e.r and c.g==e.g and c.b==e.b,'Color changed unexpectedly') end
local function copy(c) return {r=c.r,g=c.g,b=c.b} end
local original=copy(color()); local oldSettings=db.GetThemeSettings()
local before=writes; local info=open(); local setupWrites=writes-before
preview(info,0.1,0.2,0.3); assert(db.SetProfileTheme('Default','Teal'))
local tealOriginal=copy(color()); info.cancelFunc({r=1,g=0,b=0}); preview(info,1,0,0)
same(color(),tealOriginal); same(oldSettings.categoryTextColor,original)
assert(not ColorPickerFrame.shown)
assert(setupWrites==0,'Setup wrote settings')
db.SetProfileTheme('Default','Default')
info=open(); preview(info,0.1,0.2,0.3); info.cancelFunc({r=1,g=0,b=0}); same(color(),original)
ColorPickerFrame:Hide(); preview(info,1,0,0); same(color(),original)
info=open(); preview(info,0.2,0.3,0.4); ColorPickerFrame:Hide()
local accepted=copy(color()); info.cancelFunc(); preview(info,1,0,0); same(color(),accepted)
info=open(); preview(info,0.5,0.6,0.7); local replacement=open(); same(color(),accepted)
info.cancelFunc(); preview(info,1,0,0); same(color(),accepted)
preview(replacement,0.6,0.7,0.8); swatch:Hide(); same(color(),accepted)
info=open(); preview(info,0.1,0.2,0.3); db.RestoreDefaultTheme()
local restored=copy(color()); info.cancelFunc(); preview(info,1,0,0); same(color(),restored)
local previous=db.GetThemeSettings()
info=open(); preview(info,0.1,0.2,0.3); db.CreateProfile('Other')
same(previous.categoryTextColor,restored); info.cancelFunc(); same(color(),restored)
info=open(); preview(info,0.2,0.3,0.4); db.SetActiveProfile('Default')
same(color(),restored); info.cancelFunc(); same(color(),restored)
-- Do not close or roll back another addon's replacement picker.
info=open(); preview(info,0.3,0.4,0.5)
ColorPickerFrame.info={extraInfo={}}; ColorPickerFrame.shown=true
addon.SettingsUI.CancelColorEdit(); assert(ColorPickerFrame.shown)
info.cancelFunc(); preview(info,1,0,0); same(color(),{r=0.3,g=0.4,b=0.5})
-- Icon Restore Yellow and Theme changes retire the same shared lifecycle.
local start=#frames
addon.SettingsUI.CreateThemeIconColorControls(parent,0,0,true,db.GetActiveThemeName)
local icon,reset
for i=start+1,#frames do
 local w=frames[i]
 if w.scripts.OnClick then if rawget(w,"Swatch") then icon=w else reset=w end end
end
assert(icon and reset)
icon.scripts.OnClick(icon); info=ColorPickerFrame.info
preview(info,0,0,1); reset.scripts.OnClick(reset)
local yellow=copy(db.GetThemeSettings().minimizedIconColor)
info.cancelFunc(); preview(info,0,1,0); same(db.GetThemeSettings().minimizedIconColor,yellow)
icon.scripts.OnClick(icon); info=ColorPickerFrame.info
preview(info,0,0,1); db.SetProfileTheme('Default','Teal')
local tealIcon=copy(db.GetThemeSettings().minimizedIconColor)
info.cancelFunc(); preview(info,0,1,0); same(db.GetThemeSettings().minimizedIconColor,tealIcon)
info=open(); preview(info,0.1,0.2,0.3); db.RestoreBuiltInThemes()
restored=copy(color()); info.cancelFunc(); preview(info,1,0,0); same(color(),restored)
-- Selection-affecting CRUD and factory Profile restore also close previews.
local function mutation(action)
 local settings=db.GetThemeSettings(); local opening=copy(color())
 local stale=open(); preview(stale,0.01,0.02,0.03)
 assert(action())
 same(settings.categoryTextColor,opening)
 local current=copy(color()); stale.cancelFunc(); preview(stale,1,0,0)
 same(color(),current); assert(not ColorPickerFrame.shown)
end
assert(db.CreateTheme('Custom'))
assert(db.SetProfileTheme(db.GetActiveProfileName(),'Custom'))
mutation(function() return db.RenameTheme('Custom','Renamed') end)
mutation(function() return db.DeleteTheme('Renamed',true) end)
assert(db.CreateProfile('Disposable'))
mutation(function() return db.RenameProfile('Disposable','Renamed Profile') end)
mutation(function() return db.DeleteProfile('Renamed Profile') end)
assert(db.SetProfileTheme('Default','Teal'))
mutation(function() return db.RestoreDefaultProfile() end)
-- A retired editor never becomes valid again after returning to its old Theme.
info=open(); preview(info,0.1,0.2,0.3)
db.SetProfileTheme('Default','Teal'); db.SetProfileTheme('Default','Default')
restored=copy(color()); info.cancelFunc(); preview(info,1,0,0); same(color(),restored)
print('color-picker smoke passed')
