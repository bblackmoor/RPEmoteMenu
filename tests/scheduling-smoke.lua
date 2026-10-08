-- Real DF scheduler with deterministic native timers, including forced stale delivery.
local native = dofile('tests/details-framework-ui-stubs.lua')
dofile('tests/main-window-native.lua')
local timers, errors = {}, {}
C_Timer.NewTimer = function(delay, callback)
    local timer = {delay=delay, nativeCallback=callback}
    function timer:Cancel() self.cancelled=true end
    timers[#timers+1]=timer
    return timer
end
C_Timer.After = function(delay, callback)
    timers[#timers+1]={delay=delay, callback=function() callback() end}
end
function geterrorhandler() return function(message) errors[#errors+1]=message end end
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
timers = {}
function strtrim(v) return (v:gsub('^%s+',''):gsub('%s+$','')) end
local addon = {VERSION='test',Settings={}}
assert(loadfile("RPEmoteMenu/Localization.lua"))("RPEmoteMenu", addon)
assert(loadfile("RPEmoteMenu/Locales/enUS.lua"))("RPEmoteMenu", addon)
for _, name in ipairs({'Defaults.lua','SettingDefinitions.lua','BuiltInThemes.lua','Database.lua','FontMedia.lua','Scheduling.lua','VisibleSlotOrder.lua','WindowGeometry.lua','WindowFade.lua','EmoteEditor.lua','MainWindow.lua'}) do
    assert(loadfile('RPEmoteMenu/'..name))('RPEmoteMenu', addon)
end
local queue = addon.Scheduling
local function Fire(timer) (timer.nativeCallback or timer.callback)(timer) end
local key, another = {}, {}
local calls = 0
local first = queue.NextTick(key, function() calls=calls+1 end)
assert(first.delay==0 and queue.NextTick(key, function() error('duplicate') end)==first)
assert(#timers==1)
local separate=queue.NextTick(another,function() calls=calls+10 end)
Fire(first); Fire(separate); assert(calls==11)
local canceled=queue.Replace(key, 3, function() error('canceled') end)
queue.Cancel(key); assert(canceled.cancelled)
local old=queue.Replace(key, 4, function() error('superseded') end)
local current=queue.Replace(key, 5, function() calls=calls+1 end)
assert(old.cancelled and current.delay==5)
Fire(canceled); Fire(old); assert(calls==11)
assert(queue.NextTick(key,function() error('wrong') end)==current)
Fire(current); assert(calls==12)
-- A pass queued inside a callback survives that callback's completion/error.
local nextPass
local reentrant=queue.NextTick(key,function()
    nextPass=queue.NextTick(key,function() calls=calls+1 end)
    error('expected callback error')
end)
Fire(reentrant); assert(#errors==1 and nextPass~=reentrant)
Fire(reentrant); assert(#errors==1, 'stale delivery cannot dispatch twice')
Fire(nextPass); assert(calls==13)
local independent=0
queue.Defer(function() independent=independent+1 end)
queue.Defer(function() independent=independent+1 end)
Fire(timers[#timers-1]); Fire(timers[#timers]); assert(independent==2)
-- Resolution follows the current shared library and rejects missing APIs.
local df=LibStub('DetailsFramework-1.0'); local saved=df.Schedules.NewTimer
df.Schedules.NewTimer=nil
assert(not pcall(queue.NextTick, {}, function() end))
df.Schedules.NewTimer=saved
-- Exercise real tooltip owners through their installed native hover events.
addon.Database.InitializeDatabase()
addon.Database.GetGlobalSettings().tooltipDelayMs=350
addon.Database.GetCategory(2).name='Second'
addon.MainWindow.CreateMainWindow()
local owners={}
for _, object in ipairs(native.objects) do
    if object.categoryIndex and object:IsShown() and object:GetScript('OnEnter') then owners[#owners+1]=object end
end
assert(#owners>=2)
local owner, second=owners[1],owners[2]
local function Enter(object) object:GetScript('OnEnter')(object) end
local function Leave(object) object:GetScript('OnLeave')(object) end
Enter(owner)
local tooltipTimer=timers[#timers]; assert(tooltipTimer.delay==0.35)
Leave(owner); assert(tooltipTimer.cancelled)
Fire(tooltipTimer); assert(not GameTooltip:IsShown())
Enter(owner); local previous=timers[#timers]
Enter(second); local currentTooltip=timers[#timers]
assert(previous.cancelled)
Fire(previous); assert(not GameTooltip:IsShown())
Fire(currentTooltip); assert(GameTooltip:IsShown() and GameTooltip:IsOwned(second))
-- Leaving an obsolete owner cannot cancel its replacement's timer.
Enter(second); local replacement=timers[#timers]
Leave(owner); assert(not replacement.cancelled)
Fire(replacement); assert(GameTooltip:IsOwned(second))
Leave(second)
Enter(owner); local hidden=timers[#timers]; owner:Hide()
Fire(hidden); assert(not GameTooltip:IsShown())
owner:Show(); Enter(owner); owner.mouseover=false
Fire(timers[#timers]); assert(not GameTooltip:IsShown())
owner.mouseover=true
addon.Database.GetGlobalSettings().tooltipDelayMs=0
local before=#timers
Enter(owner); assert(#timers==before and GameTooltip:IsOwned(owner) and GameTooltip:IsShown())
Leave(owner)
assert(#errors==1, 'no unexpected callback errors')
print('PASS real DF scheduling: coalescing, cancellation, stale delivery, reentrancy, errors, independent callbacks and tooltip ownership')


