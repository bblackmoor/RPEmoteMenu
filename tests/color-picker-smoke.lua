-- Real database mutations, DF swatches and the shared picker manager.
local addon={SettingsUI={FIELD_GAP=12},Settings={},MainWindow={}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
local function loadModule(n) assert(loadfile('RPEmoteMenu/'..n))('RPEmoteMenu',addon) end
function strtrim(v) return (v:gsub('^%s+',''):gsub('%s+$','')) end
function UnitName() return 'Tester','Realm' end
local native = dofile('tests/details-framework-ui-stubs.lua')
local frames = native.objects
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
ColorPickerFrame=CreateFrame('Frame')
function ColorPickerFrame:GetExtraInfo() return self.info and self.info.extraInfo end
function ColorPickerFrame:GetColorRGB() return self.r,self.g,self.b end
function ColorPickerFrame:SetupColorPickerAndShow(info)
 self.info=info; self.shown=true; self.r,self.g,self.b=info.r,info.g,info.b
 info.swatchFunc()
end
addon.MinimizedIconColor={Apply=function() end}
loadModule('Defaults.lua'); loadModule('SettingDefinitions.lua'); loadModule('BuiltInThemes.lua'); loadModule('Database.lua')
local db=addon.Database; db.InitializeDatabase()
local module=io.open('RPEmoteMenu/SettingsColorPicker.lua')
if module then module:close(); loadModule('SettingsColorPicker.lua') end
loadModule('SettingsWidgets.lua'); loadModule('SettingsControls.lua'); loadModule('SettingsThemeIcon.lua')
local parent=CreateFrame('Frame'); local writes=0
local function color() return db.GetThemeSettings().categoryTextColor end
local swatch=addon.SettingsWidgets.CreateColorPicker(parent,color,
 function(v) writes=writes+1; db.GetThemeSettings().categoryTextColor=v end)
local function open()
 local f=swatch:GetFrame(); f.scripts.OnMouseDown(f,'LeftButton'); f.scripts.OnMouseUp(f,'LeftButton'); return ColorPickerFrame.info
end
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
preview(replacement,0.6,0.7,0.8); swatch:GetFrame():Hide(); same(color(),accepted)
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
 if w.scripts.OnMouseUp then
  if w.MyObject and w.MyObject.__iscolorpicker then icon=w else reset=w end
 end
end
assert(icon and reset)
icon.scripts.OnMouseDown(icon,'LeftButton'); icon.scripts.OnMouseUp(icon,'LeftButton'); info=ColorPickerFrame.info
preview(info,0,0,1); reset.scripts.OnMouseDown(reset,'LeftButton'); reset.scripts.OnMouseUp(reset,'LeftButton')
local yellow=copy(db.GetThemeSettings().minimizedIconColor)
info.cancelFunc(); preview(info,0,1,0); same(db.GetThemeSettings().minimizedIconColor,yellow)
icon.scripts.OnMouseDown(icon,'LeftButton'); icon.scripts.OnMouseUp(icon,'LeftButton'); info=ColorPickerFrame.info
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


info = open()
assert(info.extraInfo.owner and info.extraInfo.target.name == db.GetActiveThemeName())
assert(info.extraInfo.target.object == db.GetThemeSettings())
addon.SettingsUI.CancelColorEdit()

-- Theme creation and copying must clone accepted colors, not a live preview.
local function cloneTheme(name, action)
 local sourceName=db.GetActiveThemeName()
 local source=db.GetThemeSettings()
 local opening=copy(color())
 local stale=open(); preview(stale,0.01,0.02,0.03)
 same(color(),{r=0.01,g=0.02,b=0.03})
 assert(action(sourceName,name))
 same(source.categoryTextColor,opening)
 same(db.GetThemeSettings(name).categoryTextColor,opening)
 assert(not ColorPickerFrame.shown)
 assert(db.SetProfileTheme(db.GetActiveProfileName(),name))
 stale.cancelFunc(); preview(stale,1,0,0)
 same(source.categoryTextColor,opening); same(color(),opening)
end
cloneTheme('Created Without Preview',function(_,name) return db.CreateTheme(name) end)
cloneTheme('Copied Without Preview',db.CopyTheme)

-- Failed validation leaves the current preview open and cancelable.
info=open(); original=copy(info.extraInfo.original); preview(info,0.02,0.03,0.04)
assert(not db.CreateTheme(db.GetActiveThemeName()))
assert(not db.CopyTheme('Missing Theme','Unused Copy'))
assert(not db.CopyTheme(db.GetActiveThemeName(),db.GetActiveThemeName()))
same(color(),{r=0.02,g=0.03,b=0.04}); assert(ColorPickerFrame.shown)
info.cancelFunc(); same(color(),original); ColorPickerFrame:Hide()
print('color-picker smoke passed')

