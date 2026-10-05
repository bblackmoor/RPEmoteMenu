local native = dofile("tests/details-framework-ui-stubs.lua")
local nativeMethods = dofile("tests/main-window-native.lua")
-- Real embedded media libraries, database/serialization, selector and rendering paths.
local addon={VERSION='test',SettingsUI={FIELD_GAP=12},Settings={}}
local function loadModule(n) assert(loadfile('RPEmoteMenu/'..n))('RPEmoteMenu',addon) end
strmatch=string.match
function getfenv() return _G end
bit={band=function(a,b) return a & b end}
function GetLocale() return 'enUS' end
function securecallfunction(fn,...) return fn(...) end
function strtrim(v) return (v:gsub('^%s+',''):gsub('%s+$','')) end
function UnitName() return 'Tester','Realm' end
STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
local timers={}
C_Timer={After=function(delay,fn) timers[#timers+1]={delay=delay,fn=fn} end,
 NewTimer=function(delay,fn)
  local timer={}; function timer:Cancel() self.cancelled=true end
  timers[#timers+1]={delay=delay,fn=function() if not timer.cancelled then fn(timer) end end}
  return timer
 end}
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
timers = {} -- Ignore framework bootstrap work; observe addon font schedules.
loadModule('Scheduling.lua')
local function nextTimer()
 local item=table.remove(timers,1); assert(item,'Timer missing'); item.fn(); return item.delay
end
local function drain() local n=0; while #timers>0 do nextTimer(); n=n+1; assert(n<30) end end
for _,n in ipairs({'Libs/LibStub/LibStub.lua','Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua','Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua','Defaults.lua','SettingDefinitions.lua','FontMedia.lua','BuiltInThemes.lua','JSON.lua','Database.lua','Serialization.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua','EmoteEditor.lua','MainWindow.lua'}) do loadModule(n) end
local db=addon.Database; db.InitializeDatabase()
local media=LibStub('LibSharedMedia-3.0')
local choices,textRefresh=0,0
addon.Settings.RefreshFontControls=function() choices=choices+1 end
local realSchedule=addon.MainWindow.ScheduleFontRefreshes
addon.MainWindow.ScheduleFontRefreshes=function() textRefresh=textRefresh+1 end
-- Registrations before startup must not access menu/selector state.
assert(media:Register('font','Early','Interface\\Fonts\\early.ttf')); assert(#timers==0)
addon.InitializeFontMedia()
local settings=db.GetThemeSettings(); settings.categoryFont='Late'; settings.emoteFont='Friz Quadrata'
assert(not addon.IsFontAvailable('Late')); assert(addon.GetFontPath('Late')==STANDARD_TEXT_FONT)
local entries=addon.GetAvailableFonts('Late'); assert(entries[#entries].unavailable and entries[#entries].name=='Late')
local count=0; for _,v in ipairs(entries) do if v.name=='Arial Narrow' then count=count+1 end end; assert(count==1)
local saved=assert(addon.Serialization.ExportTheme())
assert(media:Register('font','Late','Interface\\Fonts\\late.ttf'))
assert(media:Register('font','Unrelated','Interface\\Fonts\\other.ttf'))
assert(#timers==1,'Registration burst was not coalesced'); drain()
assert(choices==1 and textRefresh==1)
assert(settings.categoryFont=='Late' and addon.IsFontAvailable('Late'))
assert(addon.GetFontPath('Late')=='Interface\\Fonts\\late.ttf')
assert(addon.Serialization.ExportTheme()==saved,'Refresh changed exported settings')
media:Register('font','Another','Interface\\Fonts\\another.ttf'); drain()
assert(choices==2 and textRefresh==1,'Unselected font refreshed menu text')
media:Register('sound','Sound','Interface\\Sounds\\test.ogg'); assert(#timers==0)
-- Missing registrations stay missing even when Fetch has a global override.
media:SetGlobal('font','Unrelated'); drain()
assert(textRefresh==2 and addon.GetFontPath('Late')=='Interface\\Fonts\\other.ttf')
assert(not addon.IsFontAvailable('Missing') and addon.GetFontPath('Missing')==STANDARD_TEXT_FONT)
assert(addon.GetFontPath('Arial Narrow')=='Fonts\\ARIALN.TTF')
media:HashTable('font').Late=nil
assert(not addon.IsFontAvailable('Late')); assert(addon.GetFontPath('Late')==STANDARD_TEXT_FONT)
media:SetGlobal('font',nil); drain(); assert(settings.categoryFont=='Late')
media:Register('font','Late','Interface\\Fonts\\returned.ttf'); drain()
assert(addon.GetFontPath('Late')=='Interface\\Fonts\\returned.ttf')
-- A queued event follows the current Theme, without writing either Theme.
local pendingName=settings.categoryFont
media:SetGlobal('font','Unrelated')
assert(db.SetProfileTheme('Default','Teal'))
local teal=db.GetThemeSettings(); local tealFont=teal.categoryFont
drain(); assert(teal.categoryFont==tealFont and settings.categoryFont==pendingName)
media:SetGlobal('font',nil); drain()
-- The embedded copy must preserve a compatible newer instance and its registry.
local original=media; media.testMarker={}
LibStub.minors['LibSharedMedia-3.0']=LibStub.minors['LibSharedMedia-3.0']+1
loadModule('Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua')
assert(LibStub('LibSharedMedia-3.0')==original and original.testMarker)
-- Real DF selector choices/labels are covered in theme-smoke.lua.
teal.categoryFont='Absent'
media:Register('font','Absent','Interface\\Fonts\\absent.ttf'); drain()
-- Actual rendering retries stop on success, are bounded, and retire on a newer request.
addon.MainWindow.ScheduleFontRefreshes=realSchedule
local realRefresh=addon.MainWindow.RefreshFontDisplays
local attempts=0; local succeeds=false
addon.MainWindow.RefreshFontDisplays=function(layout)
 assert(layout==false); attempts=attempts+1; return succeeds
end
realSchedule(); assert(attempts==1 and #timers==1)
succeeds=true; assert(nextTimer()==0.25); assert(attempts==2 and #timers==0)
succeeds=false; attempts=0; realSchedule(); drain(); assert(attempts==7,'Retry count unbounded')
attempts=0; realSchedule(); succeeds=true; realSchedule(); local newAttempts=attempts
drain(); assert(attempts==newAttempts,'Superseded timer refreshed the new Theme')
attempts=0; realSchedule(true); assert(attempts==0); assert(nextTimer()==0); assert(attempts==1 and #timers==0)
-- Construct the actual window and control only native font results/measurement.
-- A single label failure must put every category label and outline on fallback.
function nativeMethods:SetFont(path,size,flags)
 self.fontPath,self.fontSize,self.fontFlags=path,size,flags
 return true
end
function nativeMethods:GetFont()
 return self.fontPath or STANDARD_TEXT_FONT,self.fontSize or 12,self.fontFlags or ''
end
function nativeMethods:GetStringWidth()
 return #(self:GetText())*(self.fontPath=='Interface\\Fonts\\absent.ttf' and 18 or 6)
end
for _, category in ipairs(db.GetCategories()) do category.name='' end
local first,second=db.GetCategory(1),db.GetCategory(2)
first.name,second.name='Category One','Category Two'
teal.categoryFont='Absent'
addon.MainWindow.RefreshFontDisplays=realRefresh
addon.MainWindow.CreateMainWindow()
drain()
local rows={}
for _, object in ipairs(native.objects) do
 if object.categoryIndex and object:IsShown() then rows[#rows+1]=object end
end
assert(#rows==2)
local text=rows[2].Text
local setFont=text.SetFont
local failing=true
function text:SetFont(path,size,flags)
 if failing and path=='Interface\\Fonts\\absent.ttf' then return false end
 return setFont(self,path,size,flags)
end
assert(not realRefresh(false))
for _, row in ipairs(rows) do
 assert(row.Text:GetFont()==STANDARD_TEXT_FONT)
 for _, outline in ipairs(row.TextOutline) do assert(outline:GetFont()==STANDARD_TEXT_FONT) end
end
failing=false; assert(realRefresh(false))
for _, row in ipairs(rows) do
 assert(row.Text:GetFont()=='Interface\\Fonts\\absent.ttf')
 for _, outline in ipairs(row.TextOutline) do assert(outline:GetFont()=='Interface\\Fonts\\absent.ttf') end
end
assert(teal.categoryFont=='Absent')
-- Width is observed on the rendered frame, using real content and font selection.
local frame=addon.MainWindow.GetFrame()
local availableWidth=frame:GetWidth()
media:HashTable('font').Absent=nil
realRefresh(false)
local fallbackWidth=frame:GetWidth()
assert(availableWidth>fallbackWidth,'Font return did not affect calculated width')
media:Register('font','Absent','Interface\\Fonts\\absent.ttf')
drain(); assert(frame:GetWidth()==availableWidth and teal.categoryFont=='Absent')

-- Every loaded TOC script exists and compiles, including bundled dependencies.
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
 if line:match('%.lua$') then assert(loadfile('RPEmoteMenu/'..line)) end
end
print('PASS real font libraries, late providers, missing choices, overrides, serialization and bounded rendering retries')

