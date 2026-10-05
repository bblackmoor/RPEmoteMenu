-- Component contracts use explicit inputs/context rather than private upvalues.
local addon = {}
for _, file in ipairs({'SettingDefinitions.lua','WindowGeometry.lua','WindowFade.lua'}) do
    assert(loadfile('RPEmoteMenu/'..file))('RPEmoteMenu',addon)
end
local geometry=addon.WindowGeometry
local bounds={screenWidth=1000,screenHeight=800,expandedWidth=400,
    savedHeight=300,defaultHeight=200,savedX=20,savedY=600,minimumHeight=150,maximumHeight=630}
local x,y,w,h=geometry.Clamp(-50,100,400,900,false,bounds)
assert(x==0 and y==630 and w==400 and h==630)
x,y,w,h=geometry.Clamp(-100001,100001,nil,nil,true,bounds)
assert(x==-100000 and y==100000 and w==400 and h==300)
for _, mode in ipairs({'NONE','TITLE_BAR','ICON'}) do
    for _, left in ipairs({false,true}) do
        for _, hidden in ipairs({false,true}) do
            local width,height=geometry.GetFrameSize(400,300,{hidden=hidden,
                minimizeMode=mode,titleBarOnLeft=left,leftTitleBarWidth=32,titleBarThickness=32})
            local expectedWidth,expectedHeight=400,300
            if hidden and mode~='NONE' then
                if not left then expectedHeight=32 elseif mode~='ICON' then expectedWidth=32 end
            end
            assert(width==expectedWidth and height==expectedHeight)
        end
    end
end
local timers={}
C_Timer={After=function(delay,callback) timers[#timers+1]={delay=delay,callback=callback} end}
local profile={fadeEnabled=true,fadeDelay=5,inactiveOpacity=0.3,minimizeMode='NONE'}
local theme={windowOpacity=0.8}
local hidden=false
local frame={alpha=0.8,hover=false}
function frame:GetAlpha() return self.alpha end
function frame:SetAlpha(alpha) self.alpha=alpha end
function frame:IsMouseOver() return self.hover end
local group
function frame:CreateAnimationGroup()
    group={playing=false,scripts={}}
    function group:IsPlaying() return self.playing end
    function group:Stop() self.playing=false end
    function group:Play() self.playing=true end
    function group:SetScript(name,fn) self.scripts[name]=fn end
    function group:Finish() self.playing=false; self.scripts.OnFinished() end
    function group:CreateAnimation()
        local animation={}
        function animation:SetSmoothing() end
        function animation:SetFromAlpha(value) self.from=value end
        function animation:SetToAlpha(value) self.to=value end
        function animation:SetDuration(value) self.duration=value end
        self.animation=animation; return animation
    end
    return group
end
local icon={}; function icon:SetAlpha(alpha) self.alpha=alpha end
local interacting=false
local fade=addon.WindowFade.Create({GetFrame=function() return frame end,
    GetIcon=function() return icon end,GetProfile=function() return profile end,
    GetTheme=function() return theme end,IsHidden=function() return hidden end,
    IsInteracting=function() return interacting end,
    SetHidden=function(value) hidden=value end,
    UsesMinimizedDisplay=function() return profile.minimizeMode~='NONE' end,
    IsMinimizedToIcon=function() return profile.minimizeMode=='ICON' end})
fade.ScheduleInactiveFade(); assert(#timers==1 and timers[1].delay==5)
fade.RestoreActiveOpacity(); timers[1].callback(); assert(not group,'superseded fade must not animate')
fade.ScheduleInactiveFade(); timers[2].callback()
assert(group.animation.to==0.3 and group.animation.duration==1)
group:Finish(); assert(frame.alpha==0.3)
fade.NotifyActivity(); assert(group.animation.to==0.8 and group.animation.duration==0.2)
group:Finish(); assert(frame.alpha==0.8)
profile.minimizeMode='ICON'; timers={}
fade.ScheduleAutoHide(); fade.ScheduleAutoHide()
assert(#timers==1 and fade.IsAutoHidePending(),'auto-hide must keep first deadline')
fade.CancelAutoHide(); timers[1].callback(); assert(not fade.IsAutoHidePending() and not hidden)
fade.ScheduleAutoHide(); timers[2].callback(); assert(fade.IsAutoHidePending())
group:Finish(); assert(hidden and frame.alpha==0.8 and not fade.IsAutoHidePending())
fade.ApplySettings(); assert(icon.alpha==0.3)
hidden=false; profile.minimizeMode='TITLE_BAR'; timers={}
fade.ScheduleAutoHide(); timers[1].callback()
frame.hover=true; group:Finish(); assert(not hidden,'hover must reject collapse at animation completion')
group:Finish(); assert(frame.alpha==0.8)
frame.hover=false; profile.fadeEnabled=false; hidden=true
fade.ApplySettings(); assert(not hidden and not fade.IsAutoHidePending())
-- Replacing settings must be visible to delayed callbacks without stale binding.
profile={fadeEnabled=true,fadeDelay=2,inactiveOpacity=0.2,minimizeMode='NONE'}
theme={windowOpacity=0.6}; timers={}
fade.ScheduleInactiveFade(); theme={windowOpacity=0.1}; timers[1].callback()
assert(group.animation.to==0.1); group:Finish(); assert(frame.alpha==0.1)
local oldFinished=0
fade.SetOpacity(0.5,1,function() oldFinished=oldFinished+1 end)
fade.SetOpacity(0.4)
assert(frame.alpha==0.4 and oldFinished==0 and not group.playing)
-- Appearance refresh during a collapse must retire its pending state and
-- schedule a replacement without requiring the pointer to enter the menu.
for _, mode in ipairs({'ICON','TITLE_BAR'}) do
    for _, hover in ipairs({false,true}) do
        frame.hover=false; profile.fadeEnabled=true; profile.minimizeMode=mode; hidden=false
        fade.CancelAutoHide(); fade.RestoreActiveOpacity(); timers={}
        fade.ScheduleAutoHide(); timers[1].callback()
        assert(group.playing and fade.IsAutoHidePending())
        frame.hover=hover
        fade.ApplySettings()
        assert(not group.playing and not hidden)
        if hover then
            assert(not fade.IsAutoHidePending() and #timers==1)
            frame.hover=false; fade.ScheduleAutoHide()
        end
        assert(#timers==2 and fade.IsAutoHidePending(), 'interrupted collapse blocked replacement')
        timers[2].callback(); group:Finish()
        assert(hidden and not fade.IsAutoHidePending())
    end
end
-- An appearance refresh before the timer fires preserves the first deadline.
frame.hover=false; hidden=false; fade.CancelAutoHide(); fade.RestoreActiveOpacity(); timers={}
fade.ScheduleAutoHide(); fade.ApplySettings()
assert(#timers==1 and fade.IsAutoHidePending())
timers[1].callback(); group:Finish(); assert(hidden and not fade.IsAutoHidePending())
-- Busy gestures reject new requests, pending timers and final collapse callbacks.
for _, mode in ipairs({'NONE','TITLE_BAR','ICON'}) do
    profile.minimizeMode=mode; profile.fadeEnabled=true; frame.hover=false; hidden=false
    fade.CancelAutoHide(); fade.RestoreActiveOpacity(); timers={}
    interacting=true
    fade.ScheduleInactiveFade(); fade.ScheduleAutoHide()
    assert(#timers==0 and not fade.IsAutoHidePending(), 'gesture scheduled inactivity work')
    interacting=false
    if mode=='NONE' then fade.ScheduleInactiveFade() else fade.ScheduleAutoHide() end
    assert(#timers==1)
    interacting=true; timers[1].callback()
    assert(not group.playing and not hidden and not fade.IsAutoHidePending(),
        'pending inactivity timer ran during a gesture')
    interacting=false; timers={}
    if mode~='NONE' then
        fade.ScheduleAutoHide(); timers[1].callback(); assert(group.playing)
        interacting=true; group:Finish()
        assert(not hidden and not fade.IsAutoHidePending(), 'animation collapsed during a gesture')
        group:Finish(); assert(frame.alpha==theme.windowOpacity)
    end
    interacting=false
end
print('PASS explicit geometry and fade component contracts, gesture guards, mode combinations, cancellation, animation, hover and current settings')

