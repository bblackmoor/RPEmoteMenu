-- Run from the repository root: texlua --luaonly tests/window-geometry-smoke.lua
-- Exercise MainWindow's actual anchor calculations with simulated screen coordinates.
local addon={Database={},DefaultGlobalSettings={},DefaultProfileSettings={},DefaultThemeSettings={},COLUMN_CHROME_WIDTH=0,MIN_SIDEBAR_WIDTH=0,MAX_SIDEBAR_WIDTH=0,MIN_EMOTE_COLUMN_WIDTH=0,MAX_EMOTE_COLUMN_WIDTH=0}
assert(loadfile('RPEmoteMenu/Scheduling.lua'))('RPEmoteMenu',addon)
for _, name in ipairs({'WindowGeometry.lua','WindowFade.lua','EmoteEditor.lua'}) do assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon) end
assert(loadfile('RPEmoteMenu/MainWindow.lua'))('RPEmoteMenu',addon)
local apply=addon.MainWindow.ApplyTitleBarPosition
local function getUpvalue(fn,name)
  for i=1,40 do
    local current,value=debug.getupvalue(fn,i)
    if current==name then return value end
    if not current then break end
  end
  error('Missing upvalue '..name)
end
local iconAnchor=getUpvalue(apply,'ApplyMinimizedIconAnchor')
local applyEmoteGearVisibility=getUpvalue(addon.MainWindow.UpdateMenu,'ApplyEmoteGearVisibility')
local backdrop=getUpvalue(addon.MainWindow.ApplyAppearance,'ApplyMainFrameBackdrop')
local function setUpvalue(fn,name,value)
  for i=1,40 do
    local current=debug.getupvalue(fn,i)
    if current==name then debug.setupvalue(fn,i,value); return end
    if not current then break end
  end
  error('Missing upvalue '..name)
end
local frame={left=300,top=600}
function frame:GetLeft() return self.left end
function frame:GetTop() return self.top end
local profile={point='TOPLEFT',relativePoint='BOTTOMLEFT',x=300,y=600,height=200}
local theme={titleBarPosition='LEFT'}
UIParent={GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
setUpvalue(apply,'MainFrame',frame)
setUpvalue(apply,'profileSettings',profile)
setUpvalue(apply,'themeSettings',theme)
setUpvalue(apply,'appliedTitleBarPosition','TOP')
setUpvalue(apply,'CalculateColumnWidths',function() return theme.titleBarPosition=='LEFT' and 432 or 400 end)
setUpvalue(apply,'GetCurrentFrameSize',function(width,height) return width,height end)
setUpvalue(apply,'ApplyMinimizedIconAnchor',function() end)
setUpvalue(apply,'UpdateWindowBodyVisibility',function() end)
addon.MainWindow.ApplyWindowGeometry=function(x,y)
  profile.x=x; profile.y=y
  if profile.point=='CENTER' then
    local width=theme.titleBarPosition=='LEFT' and 432 or 400
    frame.left=500+x-width/2; frame.top=400+y+100
  else
    frame.left=x; frame.top=y
  end
end
apply(false,false)
assert(profile.x==300 and profile.y==600)
assert(frame.left+32+5==337 and frame.top-6==594) -- Category moves with left bar.
assert(frame.left+32+100+10==442 and frame.top-10==590) -- Emotes move too.
theme.titleBarPosition='TOP'
apply(false,false)
assert(profile.x==300 and profile.y==600)
assert(frame.left+5==305 and frame.top-36==564)
assert(frame.left+100+10==410 and frame.top-40==560)
profile.point='CENTER';profile.relativePoint='CENTER';profile.x=0;profile.y=100
theme.titleBarPosition='LEFT'
apply(false,false)
assert(profile.x==16 and profile.y==100)
assert(frame.left==300 and frame.top==600)
theme.titleBarPosition='TOP'
apply(false,false)
assert(profile.x==0 and profile.y==100)

local icon={size=64}
function icon:ClearAllPoints() self.point=nil end
function icon:SetPoint(...) self.point={...} end
setUpvalue(iconAnchor,'MinimizedIconButton',icon)
setUpvalue(iconAnchor,'MainFrame',frame)
theme.titleBarPosition='LEFT'
iconAnchor()
assert(icon.point[1]=='CENTER' and icon.point[2]==frame
  and icon.point[3]=='TOPLEFT' and icon.point[4]==16 and icon.point[5]==-16)

local gearSettings={hideSettingsGear=true}
setUpvalue(applyEmoteGearVisibility,'globalSettings',gearSettings)
local emoteButton={EditButton={},EditHoverIcon={},Text={points={}}}
function emoteButton.EditButton:SetShown(shown) self.shown=shown end
function emoteButton.EditHoverIcon:SetShown(shown) self.shown=shown end
function emoteButton.Text:ClearAllPoints() self.points={} end
function emoteButton.Text:SetPoint(...) self.points[#self.points+1]={...} end
applyEmoteGearVisibility(emoteButton)
assert(not emoteButton.EditButton.shown and not emoteButton.EditHoverIcon.shown)
assert(emoteButton.Text.points[2][2]==emoteButton)
gearSettings.hideSettingsGear=false
applyEmoteGearVisibility(emoteButton)
assert(emoteButton.EditButton.shown and emoteButton.EditHoverIcon.shown)
assert(emoteButton.Text.points[2][2]==emoteButton.EditButton)
icon.size=16
iconAnchor()
assert(icon.point[4]==16 and icon.point[5]==-16)
theme.titleBarPosition='TOP'
iconAnchor()
assert(icon.point[1]=='CENTER' and icon.point[2]==frame
  and icon.point[3]=='TOPLEFT' and icon.point[4]==16 and icon.point[5]==-16)

-- The Theme refresh must request repositioning only when orientation changes.
local refresh=addon.MainWindow.ApplyThemeSettings
setUpvalue(refresh,'MainFrame',frame)
addon.Database.GetThemeSettings=function() return theme end
addon.MainWindow.ApplyAppearance=function() end
addon.MainWindow.UpdateMenu=function() end
addon.MainWindow.ScheduleFontRefreshes=function() end
local preservePosition,preserveGeometry
addon.MainWindow.ApplyTitleBarPosition=function(a,b)
  preservePosition,preserveGeometry=a,b
end
setUpvalue(refresh,'appliedTitleBarPosition','TOP')
theme.titleBarPosition='LEFT'
refresh()
assert(preservePosition==false and preserveGeometry==false)
setUpvalue(refresh,'appliedTitleBarPosition','LEFT')
refresh()
assert(preservePosition==true and preserveGeometry==true)

local borderlessFrame={}
function borderlessFrame:SetBackdrop(value) self.backdrop=value end
function borderlessFrame:SetBackdropColor(...) self.background={...} end
function borderlessFrame:SetBackdropBorderColor() error('Menu border should not be set') end
setUpvalue(backdrop,'MainFrame',borderlessFrame)
setUpvalue(backdrop,'themeSettings',{emoteBackgroundColor={r=0,g=0,b=0}})
setUpvalue(backdrop,'IsWindowBodyHidden',function() return false end)
backdrop()
assert(borderlessFrame.backdrop.bgFile and not borderlessFrame.backdrop.edgeFile)

-- Activation restores full visibility/opacity and starts the normal fade timers.
local activation = addon.MainWindow.ApplyActivation
local activeSettings = {active = false}
addon.Database.GetGlobalSettings = function() return activeSettings end
local activationFrame = {shown = true}
function activationFrame:Show() self.shown = true end
function activationFrame:Hide() self.shown = false end
function activationFrame:IsMouseOver() return self.mouseover end
local activationIcon = {shown = true}
function activationIcon:Hide() self.shown = false end
local minimized, opacityRestored, fadeScheduled, minimizeScheduled = true, 0, 0, 0
setUpvalue(activation, 'MainFrame', activationFrame)
setUpvalue(activation, 'MinimizedIconButton', activationIcon)
setUpvalue(activation, 'CancelWindowAutoHide', function() end)
setUpvalue(activation, 'SetWindowAutoHidden', function(hidden) minimized = hidden; activationIcon:Hide() end)
setUpvalue(activation, 'RestoreActiveOpacity', function() opacityRestored = opacityRestored + 1 end)
setUpvalue(activation, 'ScheduleInactiveFade', function() fadeScheduled = fadeScheduled + 1 end)
setUpvalue(activation, 'ScheduleWindowAutoHide', function() minimizeScheduled = minimizeScheduled + 1 end)
activation()
assert(not activationFrame.shown and not activationIcon.shown and opacityRestored == 0)
activeSettings.active = true; activation()
assert(activationFrame.shown and not minimized and opacityRestored == 1)
assert(fadeScheduled == 1 and minimizeScheduled == 1)
activationFrame.mouseover = true; activation()
assert(opacityRestored == 2 and fadeScheduled == 1 and minimizeScheduled == 1)
print('PASS fixed window corner, moving content, stationary icon, gear visibility, borderless backdrop')
