-- Real database/window integration; only native rendering and coordinates stubbed.
local native = dofile('tests/details-framework-ui-stubs.lua')
dofile('tests/main-window-native.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local addon = {VERSION='test', Settings={}}
for _, name in ipairs({'Defaults.lua','SettingDefinitions.lua','BuiltInThemes.lua','Database.lua',
    'Scheduling.lua','FontMedia.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua',
    'EmoteEditor.lua','MainWindow.lua'}) do
    assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu',addon)
end
local db, main = addon.Database, addon.MainWindow
db.InitializeDatabase()
UIParent:SetSize(1000,800)
local profile, theme = db.GetProfileSettings(), db.GetThemeSettings()
profile.point, profile.relativePoint, profile.x, profile.y = 'TOPLEFT','BOTTOMLEFT',300,600
profile.height = 200
main.CreateMainWindow()
local frame, icon = main.GetFrame(), main.GetMinimizedIconButton()
local category, emote
for _, object in ipairs(native.objects) do
    if object.categoryIndex == 1 then category = object end
    if object.emoteIndex == 1 then emote = object end
end
assert(category and emote)
local sidebar = category:GetParent():GetParent():GetParent()
local emoteScroll = emote:GetParent():GetParent()
local function Orientation(position)
    local left, top = frame:GetLeft(), frame:GetTop()
    theme.titleBarPosition = position
    main.ApplyThemeSettings()
    assert(frame:GetLeft()==left and frame:GetTop()==top, 'window corner moved')
    assert(icon.point[1]=='CENTER' and icon.point[2]==frame and icon.point[3]=='TOPLEFT'
        and icon.point[4]==16 and icon.point[5]==-16, 'icon anchor moved')
end
Orientation('LEFT')
assert(sidebar.points.TOPLEFT[5]==-6 and emoteScroll.points.TOPLEFT[5]==-10)
local leftSidebarX, leftEmoteX = sidebar.points.TOPLEFT[4], emoteScroll.points.TOPLEFT[4]
Orientation('TOP')
assert(sidebar.points.TOPLEFT[5]==-36 and emoteScroll.points.TOPLEFT[5]==-40)
assert(leftSidebarX-sidebar.points.TOPLEFT[4]==32 and leftEmoteX-emoteScroll.points.TOPLEFT[4]==32)
profile.point,profile.relativePoint,profile.x,profile.y='CENTER','CENTER',0,100
main.ApplyProfileSettings()
Orientation('LEFT'); assert(profile.x==16 and profile.y==100)
Orientation('TOP'); assert(profile.x==0 and profile.y==100)
-- Same orientation preserves stored geometry; switching sides requests repositioning.
local apply = main.ApplyTitleBarPosition
local preservePosition, preserveGeometry
main.ApplyTitleBarPosition=function(a,b)
    preservePosition,preserveGeometry=a,b
    return apply(a,b)
end
Orientation('LEFT'); assert(preservePosition==false and preserveGeometry==false)
Orientation('LEFT'); assert(preservePosition==true and preserveGeometry==true)
main.ApplyTitleBarPosition=apply
profile.fadeEnabled=true; profile.minimizeMode='ICON'
main.ApplyProfileSettings()
for _, size in ipairs({16,64}) do
    profile.minimizedIconSize=size
    main.ApplyMinimizeToIconSettings()
    Orientation('TOP'); Orientation('LEFT')
    assert(icon:GetWidth()==size and icon:GetHeight()==size)
end
profile.fadeEnabled=false; profile.minimizeMode='NONE'
main.ApplyProfileSettings()
-- Gear presentation is observed on a real rendered emote row.
local global=db.GetGlobalSettings()
global.hideSettingsGear=true; main.UpdateMenu()
assert(not emote.EditButton:IsShown() and not emote.EditHoverIcon:IsShown())
assert(emote.Text.points.RIGHT[2]==emote)
global.hideSettingsGear=false; main.UpdateMenu()
assert(emote.EditButton:IsShown() and emote.EditHoverIcon:IsShown())
assert(emote.Text.points.RIGHT[2]==emote.EditButton)
main.ApplyAppearance()
assert(frame.backdrop.bgFile and not frame.backdrop.edgeFile, 'menu gained border')
-- Activation hides both presentations and restores the expanded window/opacity.
profile.fadeEnabled=true; profile.minimizeMode='ICON'
main.ApplyProfileSettings()
assert(icon:IsShown() and not frame.mouseEnabled)
global.active=false; main.ApplyActivation()
assert(not frame:IsShown() and not icon:IsShown())
frame.mouseover=true
global.active=true; main.ApplyActivation()
assert(frame:IsShown() and frame.mouseEnabled and not icon:IsShown())
assert(frame:GetAlpha()==theme.windowOpacity)
-- Show dispatch must enforce Active and restore a hidden minimized icon.
local showEvents, sizeEvents=0,0
frame:HookScript('OnShow',function() showEvents=showEvents+1 end)
frame:HookScript('OnSizeChanged',function() sizeEvents=sizeEvents+1 end)
global.active=false; main.ApplyActivation()
frame:Show(); assert(not frame:IsShown() and not icon:IsShown() and showEvents==1)
global.active=true; main.ApplyActivation()
assert(frame:IsShown() and showEvents==2)
main.ApplyProfileSettings() -- Starts collapsed in Icon mode.
frame:Hide(); assert(not icon:IsShown())
frame:Show(); assert(icon:IsShown() and showEvents==3)
-- Internal collapse/expand sizes must not overwrite the saved expanded height.
profile.height=310
for _, mode in ipairs({'ICON','TITLE_BAR'}) do
    profile.minimizeMode=mode
    for _, position in ipairs({'TOP','LEFT'}) do
        theme.titleBarPosition=position
        main.ApplyProfileSettings()
        assert(profile.height==310)
        main.ApplyActivation()
        assert(frame:GetHeight()==310 and profile.height==310)
    end
end
-- Native resize events persist user height, correct width, and respect Lock.
profile.fadeEnabled=false; profile.minimizeMode='NONE'; profile.locked=false
main.ApplyProfileSettings()
local grip
for _, object in ipairs(native.objects) do
    if object:GetParent()==frame and object:GetScript('OnMouseDown')
        and object:GetScript('OnMouseUp') and object:GetWidth()==18 then grip=object end
end
assert(grip)
local width=frame:GetWidth()
local beforeSizeEvents=sizeEvents
grip:GetScript('OnMouseDown')(grip,'LeftButton'); assert(frame.sizing=='BOTTOM')
frame:SetSize(width+50,345)
assert(sizeEvents>beforeSizeEvents and profile.height==345 and frame:GetWidth()==width)
grip:GetScript('OnMouseUp')(grip); assert(not frame.sizing and profile.height==345)
profile.locked=true; main.ApplyMovementLock()
grip:GetScript('OnMouseDown')(grip,'LeftButton'); assert(not frame.sizing)
frame:SetHeight(370); assert(profile.height==345, 'locked/programmatic resize persisted height')
main.ApplyProfileSettings(); assert(frame:GetHeight()==345)
assert(sizeEvents>0)
-- Delayed animation/cancellation and hover policy use explicit WindowFade context
-- in window-components-smoke.lua; the integration here checks real presentation.
print('PASS real window fixed corner, moving content, stationary icon, gear visibility, borderless backdrop and activation')
