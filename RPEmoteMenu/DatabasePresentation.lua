local _, addon = ...

-- Resolve views at dispatch time: database operations also work before frames
-- exist, and refresh callbacks may be installed or replaced after module load.
addon.DatabasePresentation = {}
local Presentation = addon.DatabasePresentation

-- Retire Theme previews before changing selection or replacing saved data.
function Presentation.CancelThemeColorEdit()
    if addon.SettingsUI and addon.SettingsUI.CancelColorEdit then
        addon.SettingsUI.CancelColorEdit()
    end
end

function Presentation.RefreshSettingsViews()
    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    else
        if addon.Settings and addon.Settings.RefreshEditors then
            addon.Settings.RefreshEditors()
        end
        if addon.Settings and addon.Settings.RefreshProfiles then
            addon.Settings.RefreshProfiles()
        end
    end
end


function Presentation.RefreshProfileViews()
    if addon.MainWindow and addon.MainWindow.ApplyProfileSettings then
        addon.MainWindow.ApplyProfileSettings()
    elseif addon.MainWindow and addon.MainWindow.UpdateMenu then
        addon.MainWindow.UpdateMenu()
    end
    Presentation.RefreshSettingsViews()
end


function Presentation.RefreshThemeViews()
    if addon.MainWindow and addon.MainWindow.ApplyThemeSettings then
        addon.MainWindow.ApplyThemeSettings()
    end
    Presentation.RefreshSettingsViews()
end


function Presentation.RefreshActivation()
    if addon.MainWindow and addon.MainWindow.ApplyActivation then
        addon.MainWindow.ApplyActivation()
    end
    if addon.Settings and addon.Settings.RefreshSettingsPanels then
        addon.Settings.RefreshSettingsPanels()
    end
end

function Presentation.RefreshCategories(categoryIndex, resetSelection)
    if addon.Settings and addon.Settings.RefreshEditors then
        addon.Settings.RefreshEditors(categoryIndex)
    end
    local window = addon.MainWindow
    if window then
        if resetSelection and window.SetSelectedCategory then window.SetSelectedCategory(1) end
        if window.UpdateMenu then window.UpdateMenu() end
    end
end
