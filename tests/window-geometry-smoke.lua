-- Real database/window integration; only native rendering and coordinates stubbed.
local native = dofile('tests/details-framework-ui-stubs.lua')
dofile('tests/main-window-native.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
function strtrim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end
local addon = {VERSION='test', Settings={}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
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
-- Interrupted gestures finish against the old Profile before settings rebind.
frame:Show()
for _, position in ipairs({'TOP','LEFT'}) do
    theme=db.GetThemeSettings(); theme.titleBarPosition=position
    for _, gesture in ipairs({'drag','resize'}) do
        profile=db.GetProfileSettings()
        profile.fadeEnabled=false; profile.minimizeMode='NONE'; profile.locked=false
        main.ApplyProfileSettings()
        local originalProfile=profile
        if gesture=='drag' then
            frame:GetScript('OnDragStart')(frame)
            frame:ClearAllPoints(); frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',270,660)
        else
            grip:GetScript('OnMouseDown')(grip,'LeftButton')
            frame:SetHeight(310)
        end
        assert(db.CreateProfile('Interrupted '..position..' '..gesture,nil,addon.DefaultProfileSettings))
        profile=db.GetProfileSettings()
        assert(not frame.moving and not frame.sizing, 'Profile change retained native gesture')
        if gesture=='drag' then
            assert(originalProfile.x==270 and originalProfile.y==660,
                'interrupted drag was not saved to its original Profile')
        else
            assert(originalProfile.height==310, 'interrupted resize was not saved to its original Profile')
        end
        local x,y,height=profile.x,profile.y,profile.height
        frame:ClearAllPoints(); frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',290,680)
        frame:SetHeight(height+20)
        frame:GetScript('OnDragStop')(frame)
        grip:GetScript('OnMouseUp')(grip)
        assert(profile.x==x and profile.y==y and profile.height==height,
            'late gesture callbacks overwrote the new Profile')
    end
end
-- Hiding/reactivating retires resizing even when its mouse-up never arrives.
profile.fadeEnabled=false; profile.minimizeMode='NONE'; profile.locked=false
main.ApplyProfileSettings()
grip:GetScript('OnMouseDown')(grip,'LeftButton')
frame:SetHeight(325)
db.SetActive(false)
assert(not frame.moving and not frame.sizing and profile.height==325)
db.SetActive(true)
frame:SetHeight(350)
assert(profile.height==325, 'hidden resize left persistence active after reactivation')
grip:GetScript('OnMouseUp')(grip)
assert(profile.height==325, 'late hidden resize release persisted unrelated height')
-- Lock and Theme application use the same gesture cleanup.
main.ApplyProfileSettings()
frame:GetScript('OnDragStart')(frame)
profile.locked=true; main.ApplyMovementLock()
assert(not frame.moving)
profile.locked=false; main.ApplyMovementLock()
grip:GetScript('OnMouseDown')(grip,'LeftButton')
frame:SetHeight(335)
main.ApplyThemeSettings()
assert(not frame.sizing and profile.height==335)
frame:SetHeight(355)
assert(profile.height==335, 'Theme application left resizing persistence active')
-- Explicit layout actions supersede gestures and survive their stale callbacks.
for _, position in ipairs({'TOP','LEFT'}) do
    theme.titleBarPosition=position
    for _, gesture in ipairs({'drag','resize'}) do
        for _, action in ipairs({'center','reset','exact'}) do
            profile.fadeEnabled=false; profile.minimizeMode='NONE'; profile.locked=false
            profile.point,profile.relativePoint='TOPLEFT','BOTTOMLEFT'
            profile.x,profile.y,profile.height=250,650,300
            main.ApplyProfileSettings()
            if gesture=='drag' then
                frame:GetScript('OnDragStart')(frame)
                frame:ClearAllPoints(); frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',275,675)
            else
                grip:GetScript('OnMouseDown')(grip,'LeftButton')
                frame:SetHeight(320)
            end
            if action=='center' then
                main.CenterWindow()
                assert(profile.point=='CENTER' and profile.relativePoint=='CENTER'
                    and profile.x==0 and profile.y==0)
            elseif action=='reset' then
                main.ResetWindowPosition()
                assert(profile.point==addon.DefaultProfileSettings.point
                    and profile.relativePoint==addon.DefaultProfileSettings.relativePoint
                    and profile.x==addon.DefaultProfileSettings.x
                    and profile.y==addon.DefaultProfileSettings.y
                    and profile.height==addon.DefaultProfileSettings.height)
            else
                main.ApplyWindowGeometry(-75,-40,nil,285,true)
                assert(profile.x==-75 and profile.y==-40 and profile.height==285)
            end
            assert(not frame.moving and not frame.sizing, action..' retained '..gesture)
            local point,relative,x,y,height=profile.point,profile.relativePoint,
                profile.x,profile.y,profile.height
            frame:SetHeight(height+20)
            frame:GetScript('OnDragStop')(frame)
            grip:GetScript('OnMouseUp')(grip)
            assert(profile.point==point and profile.relativePoint==relative
                and profile.x==x and profile.y==y and profile.height==height,
                'stale '..gesture..' callbacks overwrote '..action..' layout')
        end
    end
end
-- Leaving while dragging/resizing cannot fade or collapse the window; activity
-- cancels preexisting timers, and inactivity resumes after the gesture finishes.
local originalAfter=C_Timer.After
for _, position in ipairs({'TOP','LEFT'}) do
    theme.titleBarPosition=position
    for _, mode in ipairs({'NONE','TITLE_BAR','ICON'}) do
        for _, gesture in ipairs({'drag','resize'}) do
            C_Timer.After=originalAfter
            profile.fadeEnabled=true; profile.minimizeMode=mode; profile.locked=false
            profile.height=300; frame.mouseover=true
            main.ApplyProfileSettings(); main.ApplyActivation()
            local width,height=frame:GetWidth(),frame:GetHeight()
            local timers={}
            C_Timer.After=function(delay,fn) timers[#timers+1]={delay=delay,fn=fn} end
            frame.mouseover=false; frame:GetScript('OnLeave')(frame)
            local pending=#timers
            assert(pending==1)
            frame.mouseover=true
            if gesture=='drag' then frame:GetScript('OnDragStart')(frame)
            else grip:GetScript('OnMouseDown')(grip,'LeftButton') end
            frame.mouseover=false
            frame:GetScript('OnLeave')(frame); frame:GetScript('OnUpdate')(frame,0.2)
            assert(#timers==pending, 'active '..gesture..' queued inactivity work')
            timers[1].fn()
            assert(frame:GetWidth()==width and frame:GetHeight()==height and grip:IsShown()
                and frame:GetAlpha()==theme.windowOpacity, 'pending timer changed active gesture presentation')
            if gesture=='drag' then frame:GetScript('OnDragStop')(frame)
            else grip:GetScript('OnMouseUp')(grip) end
            assert(#timers>pending, 'inactivity did not resume after '..gesture)
        end
    end
end
C_Timer.After=originalAfter
-- Model WoW's cached glyph scale: identical SetFont calls leave it stale.
-- Display changes must refresh even hidden/compact menus without saving geometry.
local methods=getmetatable(UIParent).__index
local oldSetFont,oldGetFont=methods.SetFont,methods.GetFont
local displayScale=1
function methods:SetFont(file,size,flags)
    local previous=self.testFont
    if not previous or previous[1]~=file or previous[2]~=size or previous[3]~=flags then
        self.glyphScale=displayScale
    end
    self.testFont={file,size,flags}
    return true
end
function methods:GetFont()
    return unpack(self.testFont or {STANDARD_TEXT_FONT,12,''})
end
local title
for _,object in ipairs(native.objects) do
    if object.kind=='FontString' and object.rotation~=nil then title=object end
end
assert(title, 'title font missing')
for _,position in ipairs({'TOP','LEFT'}) do
    for _,mode in ipairs({'NONE','TITLE','ICON'}) do
        theme.titleBarPosition=position
        profile.fadeEnabled=mode~='NONE'; profile.minimizeMode=mode
        main.ApplyProfileSettings()
        frame:Hide()
        local x,y,height=profile.x,profile.y,profile.height
        local timers={}
        C_Timer.After=function(delay,fn) timers[#timers+1]={delay=delay,fn=fn} end
        displayScale=displayScale+0.2
        local event=assert(frame:GetScript('OnEvent'))
        event(frame,'DISPLAY_SIZE_CHANGED'); event(frame,'UI_SCALE_CHANGED')
        assert(category.Text.glyphScale~=displayScale, 'font refresh was not deferred')
        local count=0
        while #timers>0 do
            count=count+1; assert(count<20, 'display refresh did not settle')
            table.remove(timers,1).fn()
        end
        assert(category.Text.glyphScale==displayScale and emote.Text.glyphScale==displayScale
            and title.glyphScale==displayScale, 'display scale left stale glyphs')
        for _,outline in ipairs(category.TextOutline) do assert(outline.glyphScale==displayScale) end
        assert(category.Text.testFont[2]==theme.categoryFontSize
            and emote.Text.testFont[2]==theme.emoteFontSize, 'display refresh changed saved font size')
        assert(profile.x==x and profile.y==y and profile.height==height
            and not frame:IsShown(), 'display refresh changed geometry or activation')
        C_Timer.After=originalAfter
    end
end
methods.SetFont,methods.GetFont=oldSetFont,oldGetFont
print('PASS real window geometry, native dragging, interrupted gesture ownership and layout actions, inactivity guards, events, signed offset reload and all 81 anchor pairs in expanded/compact modes')

