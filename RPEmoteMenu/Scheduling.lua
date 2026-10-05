-- Addon-owned queues and identities; DF supplies timer creation and dispatch.
local _, addon = ...
local Scheduling = {}
addon.Scheduling = Scheduling
local pending = {}

local function Scheduler()
    local framework = LibStub and LibStub:GetLibrary("DetailsFramework-1.0", true)
    local schedules = framework and framework.Schedules
    assert(schedules and type(schedules.NewTimer) == "function"
        and type(schedules.RunNextTick) == "function", "Details Framework scheduling is unavailable")
    return schedules
end

function Scheduling.Cancel(key)
    local request = pending[key]
    pending[key] = nil
    if request and request.timer then request.timer:Cancel() end
end

local function Enqueue(key, delay, callback)
    local schedules = Scheduler()
    local request = {}
    pending[key] = request
    request.timer = schedules.NewTimer(delay, function()
        if pending[key] ~= request then return end
        -- Clear before dispatch so a callback may queue another pass, even if
        -- it raises an error. A canceled/superseded callback cannot clear it.
        pending[key] = nil
        callback()
    end)
    return request.timer
end

-- First request keeps its deadline; callbacks must read current state.
function Scheduling.NextTick(key, callback)
    if pending[key] then return pending[key].timer end
    return Enqueue(key, 0, callback)
end

function Scheduling.Replace(key, delay, callback)
    Scheduling.Cancel(key)
    return Enqueue(key, delay, callback)
end

-- Independent one-shot callbacks retain their original ordering and guards.
function Scheduling.Defer(callback)
    return Scheduler().RunNextTick(callback)
end
