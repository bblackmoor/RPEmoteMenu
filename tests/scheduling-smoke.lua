-- Real DF scheduler with deterministic native timers, including forced stale delivery.
local native = dofile('tests/details-framework-ui-stubs.lua')
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
local addon = {}
for _, name in ipairs({'Defaults.lua','Scheduling.lua','MainWindow.lua'}) do
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
-- Exercise actual tooltip ownership and timer cancellation without building UI.
local seen={}
local function Find(fn, target)
    if seen[fn] then return end; seen[fn]=true
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i); if not name then break end
        if name==target then return value end
        if type(value)=='function' then local found=Find(value,target); if found then return found end end
    end
end
local function FindInWindow(target)
    seen={}
    for _,fn in pairs(addon.MainWindow) do
        if type(fn)=='function' then local found=Find(fn,target); if found then return found end end
    end
    error('Missing '..target)
end
local scheduleTooltip=FindInWindow('ScheduleTooltip')
local cancelTooltip=FindInWindow('CancelTooltip')
for i=1,30 do
    if debug.getupvalue(scheduleTooltip,i)=='globalSettings' then
        debug.setupvalue(scheduleTooltip,i,{tooltipDelayMs=350}); break
    end
end
local owner=CreateFrame('Button'); owner:Show(); function owner:IsMouseOver() return true end
local populated=0
scheduleTooltip(owner,function() populated=populated+1 end)
local tooltipTimer=timers[#timers]; assert(tooltipTimer.delay==0.35)
cancelTooltip(owner); assert(tooltipTimer.cancelled)
Fire(tooltipTimer); assert(populated==0)
scheduleTooltip(owner,function() populated=populated+1 end)
local previous=timers[#timers]
scheduleTooltip(owner,function() populated=populated+10 end)
assert(previous.cancelled); Fire(previous); Fire(timers[#timers]); assert(populated==10)
assert(#errors==1, 'no unexpected callback errors')
print('PASS real DF scheduling: coalescing, cancellation, stale delivery, reentrancy, errors, independent callbacks and tooltip ownership')
