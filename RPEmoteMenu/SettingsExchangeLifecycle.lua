-- Native event wiring and session cleanup; components own their own policy.
local _, addon = ...
local Lifecycle = {}
addon.ExchangeLifecycle = Lifecycle

function Lifecycle.Install(dialog, layout)
    local editBox, scrollFrame = dialog.editBox, dialog.scrollFrame
    editBox:SetScript("OnTextChanged", function(_, userInput)
        layout.ResetCaret()
        layout.Refresh()
        if userInput then dialog.SetStatus("") end
        dialog:UpdateActionState()
    end)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, height)
        layout.UpdateCaret(y, height)
    end)
    scrollFrame:HookScript("OnSizeChanged", function() layout.Refresh(true) end)
    editBox:HookScript("OnSizeChanged", function() layout.Refresh(true) end)
    dialog:HookScript("OnShow", function() layout.Refresh() end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        dialog:Hide()
    end)
    dialog:SetScript("OnHide", function()
        layout.ResetCaret()
        dialog.categoryTarget = nil
        editBox:ClearFocus()
    end)
end
