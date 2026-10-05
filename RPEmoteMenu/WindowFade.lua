-- Owns opacity animation and delayed fade/collapse state. Current settings and
-- frame bindings are supplied by MainWindow through this small context.
local _, addon = ...
local WindowFade = {}
addon.WindowFade = WindowFade

function WindowFade.Create(context)
    local fadeGeneration, autoHideGeneration = 0, 0
    local autoHideScheduled, autoHideFading = false, false
    local opacityAnimationGroup, opacityAnimation, opacityAnimationTarget
    local opacityAnimationOnFinished
    local fadeOutDuration, fadeInDuration = 1.0, 0.2
    local ScheduleWindowAutoHide
    local function IsInteracting()
        return context.IsInteracting and context.IsInteracting()
    end
    local function SetWindowOpacity(targetOpacity, duration, onFinished)
        if not context.GetFrame() then
            return
        end

        local currentOpacity = context.GetFrame():GetAlpha()

        if opacityAnimationGroup and opacityAnimationGroup:IsPlaying() then
            opacityAnimationOnFinished = nil
            opacityAnimationGroup:Stop()
        end

        if not duration or math.abs(currentOpacity - targetOpacity) < 0.001 then
            context.GetFrame():SetAlpha(targetOpacity)
            if onFinished then
                onFinished()
            end
            return
        end

        if not opacityAnimationGroup then
            opacityAnimationGroup = context.GetFrame():CreateAnimationGroup()
            opacityAnimation = opacityAnimationGroup:CreateAnimation("Alpha")
            opacityAnimation:SetSmoothing("IN_OUT")
            opacityAnimationGroup:SetScript("OnFinished", function()
                context.GetFrame():SetAlpha(opacityAnimationTarget)
                local callback = opacityAnimationOnFinished
                opacityAnimationOnFinished = nil
                if callback then
                    callback()
                end
            end)
        end

        context.GetFrame():SetAlpha(currentOpacity)
        opacityAnimationTarget = targetOpacity
        opacityAnimationOnFinished = onFinished
        opacityAnimation:SetFromAlpha(currentOpacity)
        opacityAnimation:SetToAlpha(targetOpacity)
        opacityAnimation:SetDuration(duration)
        opacityAnimationGroup:Play()
    end

    local function CancelWindowAutoHide()
        autoHideGeneration = autoHideGeneration + 1
        autoHideScheduled = false
        autoHideFading = false
    end

    local function RestoreActiveOpacity(animate)
        fadeGeneration = fadeGeneration + 1

        if context.GetFrame() then
            SetWindowOpacity(
                context.GetTheme().windowOpacity,
                animate and fadeInDuration or nil
            )
        end
    end

    local function ScheduleInactiveFade()
        fadeGeneration = fadeGeneration + 1
        local requestedGeneration = fadeGeneration

        -- Minimized modes use ScheduleWindowAutoHide for both their fade and
        -- collapse. None leaves the complete window visible at inactive opacity.
        if IsInteracting() or not context.GetProfile().fadeEnabled
            or context.UsesMinimizedDisplay() or not context.GetFrame() then
            return
        end

        C_Timer.After(context.GetProfile().fadeDelay, function()
            if requestedGeneration ~= fadeGeneration
                or IsInteracting()
                or not context.GetProfile().fadeEnabled
                or context.UsesMinimizedDisplay()
                or context.GetFrame():IsMouseOver() then
                return
            end

            SetWindowOpacity(
                math.min(context.GetProfile().inactiveOpacity, context.GetTheme().windowOpacity),
                fadeOutDuration
            )
        end)
    end

    local function NotifyActivity()
        CancelWindowAutoHide()
        RestoreActiveOpacity(true)
    end

    local function ApplySettings()
        -- Restoring opacity stops the animation and retires its completion
        -- callback. Release an interrupted collapse so it can be scheduled
        -- again; an unstarted timer keeps its existing deadline.
        if autoHideFading then CancelWindowAutoHide() end
        RestoreActiveOpacity()

        if not context.GetProfile().fadeEnabled then
            CancelWindowAutoHide()
            context.SetHidden(false)
        elseif not context.UsesMinimizedDisplay() then
            CancelWindowAutoHide()
            context.SetHidden(false)
            if context.GetFrame() and not context.GetFrame():IsMouseOver() then
                ScheduleInactiveFade()
            end
        elseif context.IsHidden() then
            local hiddenOpacity = math.min(
                context.GetProfile().inactiveOpacity,
                context.GetTheme().windowOpacity
            )
            if context.IsMinimizedToIcon() then
                context.GetIcon():SetAlpha(hiddenOpacity)
            else
                SetWindowOpacity(hiddenOpacity)
            end
        elseif context.GetFrame() and not context.GetFrame():IsMouseOver() then
            ScheduleInactiveFade()
            ScheduleWindowAutoHide()
        end
    end

    ScheduleWindowAutoHide = function()
        if IsInteracting() or not context.GetProfile().fadeEnabled or not context.UsesMinimizedDisplay()
            or context.IsHidden()
            or autoHideScheduled or autoHideFading then
            return
        end

        autoHideGeneration = autoHideGeneration + 1
        local requestedGeneration = autoHideGeneration
        autoHideScheduled = true

        C_Timer.After(math.max(tonumber(context.GetProfile().fadeDelay) or 0, 0), function()
            if requestedGeneration ~= autoHideGeneration then
                return
            end

            autoHideScheduled = false

            if not context.GetProfile().fadeEnabled or not context.UsesMinimizedDisplay()
                or IsInteracting()
                or context.IsHidden()
                or not context.GetFrame() or context.GetFrame():IsMouseOver() then
                return
            end

            autoHideFading = true
            fadeGeneration = fadeGeneration + 1
            local fadeTarget = 0

            SetWindowOpacity(fadeTarget, fadeOutDuration, function()
                if requestedGeneration ~= autoHideGeneration then
                    return
                end

                autoHideFading = false

                if not context.GetProfile().fadeEnabled or not context.UsesMinimizedDisplay()
                    or IsInteracting()
                    or context.GetFrame():IsMouseOver() then
                    RestoreActiveOpacity(true)
                    return
                end

                context.SetHidden(true)
                if context.IsMinimizedToIcon() then
                    -- The icon is parented to UIParent, so the window can remain
                    -- ready at active opacity behind it.
                    SetWindowOpacity(context.GetTheme().windowOpacity)
                end
            end)
        end)
    end

    return {
        SetOpacity = SetWindowOpacity,
        CancelAutoHide = CancelWindowAutoHide,
        RestoreActiveOpacity = RestoreActiveOpacity,
        ScheduleInactiveFade = ScheduleInactiveFade,
        ScheduleAutoHide = ScheduleWindowAutoHide,
        NotifyActivity = NotifyActivity,
        ApplySettings = ApplySettings,
        InvalidateFade = function() fadeGeneration = fadeGeneration + 1 end,
        IsAutoHidePending = function() return autoHideScheduled or autoHideFading end,
    }
end

