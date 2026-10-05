local native = dofile("tests/details-framework-ui-stubs.lua")
-- Real embedded media libraries, database/serialization, selector and rendering paths.
local addon={SettingsUI={FIELD_GAP=12},Settings={}}
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
for _,n in ipairs({'Libs/LibStub/LibStub.lua','Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua','Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua','Defaults.lua','SettingDefinitions.lua','FontMedia.lua','BuiltInThemes.lua','JSON.lua','Database.lua','Serialization.lua','WindowGeometry.lua','WindowFade.lua','EmoteEditor.lua','MainWindow.lua'}) do loadModule(n) end
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
-- Exercise actual pane-wide fallback and the automatic-width update boundary.
local function upvalue(fn,name,value,replace)
 for i=1,60 do
  local k,v=debug.getupvalue(fn,i); if k==name then if replace then debug.setupvalue(fn,i,value) end; return v end
  if not k then break end
 end
 error('Missing upvalue '..name)
end
local failing=true
local function fontString()
 local w={text='Label',size=12}
 function w:GetFont() return self.path,self.size,'' end
 function w:GetText() return self.text end
 function w:SetText(v) self.text=v end
 function w:SetTextColor() end
 function w:GetStringWidth() return #self.text*8 end
 function w:SetFont(path,size)
  if failing and path=='Interface\\Fonts\\absent.ttf' then return false end
  self.path,self.size=path,size; return true
 end
 return w
end
local text=fontString(); local outline=fontString()
local button={Text=text,TextOutline={outline},categoryIndex=1,SetHeight=function() end}
local widthUpdates=0
upvalue(realRefresh,'MainFrame',{},true)
upvalue(realRefresh,'themeSettings',teal,true)
upvalue(realRefresh,'categoryButtons',{button},true)
upvalue(realRefresh,'buttonsPool',{},true)
upvalue(realRefresh,'selectedCategoryIndex',1,true)
local automaticWidth=upvalue(realRefresh,'ApplyAutomaticWidth')
upvalue(realRefresh,'ApplyAutomaticWidth',function() widthUpdates=widthUpdates+1 end,true)
addon.MainWindow.RefreshFontDisplays=realRefresh
assert(not realRefresh(false)); assert(text.path==STANDARD_TEXT_FONT and outline.path==STANDARD_TEXT_FONT)
failing=false; assert(realRefresh(false)); assert(text.path=='Interface\\Fonts\\absent.ttf')
assert(widthUpdates==2 and teal.categoryFont=='Absent')
-- Actual font measurement changes calculated menu width when a font returns.
local calculate=upvalue(automaticWidth,'CalculateColumnWidths')
local measure=upvalue(calculate,'MeasureText')
local measurement=fontString()
function measurement:GetStringWidth()
 return #self.text*(self.path=='Interface\\Fonts\\absent.ttf' and 18 or 6)
end
upvalue(measure,'WidthMeasurementText',measurement,true)
local availableWidth=calculate()
media:HashTable('font').Absent=nil
local fallbackWidth=calculate()
assert(availableWidth>fallbackWidth,'Font return did not affect calculated width')
media:Register('font','Absent','Interface\\Fonts\\absent.ttf')
drain(); assert(calculate()==availableWidth and teal.categoryFont=='Absent')

-- Every loaded TOC script exists and compiles, including bundled dependencies.
for line in io.lines('RPEmoteMenu/RPEmoteMenu.toc') do
 if line:match('%.lua$') then assert(loadfile('RPEmoteMenu/'..line)) end
end
print('PASS real font libraries, late providers, missing choices, overrides, serialization and bounded rendering retries')
