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
-- Every accepted anchor pair restores signed offsets and preserves the window
-- corner across both orientations, including compact title/icon presentation.
local anchors=addon.SettingDefinitions.enums.anchorPoint.values
for _, mode in ipairs({'NONE','ICON','TITLE_BAR'}) do
    profile.fadeEnabled=mode~='NONE'; profile.minimizeMode=mode
    for _, point in ipairs(anchors) do
        for _, relative in ipairs(anchors) do
            profile.point,profile.relativePoint=point,relative
            profile.x,profile.y,profile.height=-75,-40,345
            theme.titleBarPosition='TOP'
            main.ApplyProfileSettings()
            assert(profile.x==-75 and profile.y==-40, 'restoration lost signed offsets')
            local left,top=frame:GetLeft(),frame:GetTop()
            for _, position in ipairs({'LEFT','TOP'}) do
                theme.titleBarPosition=position; main.ApplyThemeSettings()
                -- Stored integer offsets can round half-pixel center anchors.
                assert(math.abs(frame:GetLeft()-left)<=1 and math.abs(frame:GetTop()-top)<=1,
                    'anchor corner moved: '..point..'/'..relative..' '..mode..' '..position)
                assert(profile.point==point and profile.relativePoint==relative)
            end
            local x,y=profile.x,profile.y
            main.ApplyProfileSettings()
            assert(profile.x==x and profile.y==y, 'reapplication changed saved anchor offsets')
        end
    end
end
-- Database reload and a Profile switch must retain advanced signed offsets.
profile.fadeEnabled=false; profile.minimizeMode='NONE'
profile.point,profile.relativePoint='TOPLEFT','BOTTOMLEFT'
main.ApplyWindowGeometry(-75,-40,nil,345,true)
local originalName=db.GetActiveProfileName()
assert(db.CreateProfile('Position Regression'))
assert(db.SetActiveProfile(originalName))
profile=db.GetProfileSettings(); main.ApplyProfileSettings()
assert(profile.x==-75 and profile.y==-40)
db.InitializeDatabase(); profile=db.GetProfileSettings(); main.ApplyProfileSettings()
assert(profile.x==-75 and profile.y==-40)
-- Native dragging owns live movement; Lua must not reset its anchor on update.
profile.fadeEnabled=false; profile.minimizeMode='NONE'; profile.locked=false
for _, position in ipairs({'TOP','LEFT'}) do
    theme.titleBarPosition=position
    profile.point,profile.relativePoint='CENTER','CENTER'
    profile.x,profile.y,profile.height=0,0,200
    main.ApplyProfileSettings()
    local titleBar
    for _, object in ipairs(native.objects) do
        if object:GetParent()==frame and object.titleTextShortened~=nil then titleBar=object end
    end
    assert(titleBar)
    for _, handle in ipairs({frame,titleBar,icon}) do
        local left,top=frame:GetLeft(),frame:GetTop()
        handle:GetScript('OnDragStart')(handle)
        assert(frame.moving and frame.moveStart[1]==left and frame.moveStart[2]==top,
            'native movement changed the initial corner')
        frame:ClearAllPoints(); frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',250,650)
        local nativeAnchor=frame.point
        frame:GetScript('OnUpdate')(frame,0.2)
        assert(frame.point==nativeAnchor, 'Lua repositioned a natively dragged frame')
        handle:GetScript('OnDragStop')(handle)
        assert(not frame.moving and profile.x==250 and profile.y==650)
        assert(profile.point=='TOPLEFT' and profile.relativePoint=='BOTTOMLEFT')
        main.ApplyProfileSettings()
        assert(frame:GetLeft()==250 and frame:GetTop()==650, 'dragged position did not restore')
    end
end
profile.locked=true; main.ApplyMovementLock()
frame:GetScript('OnDragStart')(frame); assert(not frame.moving, 'locked window began native movement')
profile.locked=false; main.ApplyMovementLock()
frame:GetScript('OnDragStart')(frame); assert(frame.moving)
frame:Hide(); assert(not frame.moving, 'hidden window retained native movement')
print('PASS real window geometry, native dragging, events, signed offset reload and all 81 anchor pairs in expanded/compact modes')

