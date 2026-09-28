-- Run from the repository root: texlua --luaonly tests/window-geometry-smoke.lua
-- Exercise MainWindow's actual anchor calculations with simulated screen coordinates.
local addon={Database={},DefaultGlobalSettings={},DefaultProfileSettings={},DefaultThemeSettings={},COLUMN_CHROME_WIDTH=0,MIN_SIDEBAR_WIDTH=0,MAX_SIDEBAR_WIDTH=0,MIN_EMOTE_COLUMN_WIDTH=0,MAX_EMOTE_COLUMN_WIDTH=0}
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
local profile={point='TOPLEFT',relativePoint='BOTTOMLEFT',x=300,y=600,height=200,minimizedIconCorner='TOPLEFT'}
local theme={titleBarPosition='LEFT'}
UIParent={GetWidth=function() return 1000 end,GetHeight=function() return 800 end}
setUpvalue(apply,'MainFrame',frame)
setUpvalue(apply,'profileSettings',profile)
setUpvalue(apply,'themeSettings',theme)
setUpvalue(apply,'appliedTitleBarPosition','TOP')
setUpvalue(apply,'CalculateColumnWidths',function() return theme.titleBarPosition=='LEFT' and 430 or 400 end)
setUpvalue(apply,'GetCurrentFrameSize',function(width,height) return width,height end)
setUpvalue(apply,'ApplyMinimizedIconAnchor',function() end)
setUpvalue(apply,'UpdateWindowBodyVisibility',function() end)
addon.MainWindow.ApplyWindowGeometry=function(x,y)
  profile.x=x; profile.y=y
  if profile.point=='CENTER' then
    local width=theme.titleBarPosition=='LEFT' and 430 or 400
    frame.left=500+x-width/2; frame.top=400+y+100
  else
    frame.left=x; frame.top=y
  end
end
apply(false,false)
assert(profile.x==270 and profile.y==570)
assert(frame.left+35==305 and frame.top-6==564) -- Category origin.
assert(frame.left+30+100+10==300+100+10 and frame.top-10==600-40) -- Emotes.
theme.titleBarPosition='TOP'
apply(false,false)
assert(profile.x==300 and profile.y==600)
profile.point='CENTER';profile.relativePoint='CENTER';profile.x=0;profile.y=100
theme.titleBarPosition='LEFT'
apply(false,false)
assert(profile.x==-15 and profile.y==70)
theme.titleBarPosition='TOP'
apply(false,false)
assert(profile.x==0 and profile.y==100)

local icon={size=64}
function icon:ClearAllPoints() self.point=nil end
function icon:SetPoint(...) self.point={...} end
local pin={}
setUpvalue(iconAnchor,'MinimizedIconButton',icon)
setUpvalue(iconAnchor,'MainFrame',frame)
setUpvalue(iconAnchor,'PinBtn',pin)
profile.minimizedIconCorner='TOPRIGHT'
theme.titleBarPosition='LEFT'
iconAnchor()
assert(icon.point[1]=='CENTER' and icon.point[2]==pin and icon.point[3]=='CENTER')
icon.size=16
iconAnchor()
assert(icon.point[1]=='CENTER' and icon.point[2]==pin)
theme.titleBarPosition='TOP'
iconAnchor()
assert(icon.point[1]=='RIGHT' and icon.point[2]==frame
  and icon.point[3]=='TOPRIGHT')

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
print('PASS title bar screen coordinates and minimized icon center')
