local ADDON_NAME, addon = ...

local getAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
addon.VERSION = getAddOnMetadata and getAddOnMetadata(ADDON_NAME, "Version") or "Unknown"

-- SLASH COMMANDS
local function HandleSlashCommand(message)
    local command = string.lower(strtrim(message or ""))

    if command == "config" or command == "options" or command == "settings" then
        addon.Settings.Open()
        return
    end

    if command == "about" then
        addon.Settings.OpenAbout()
        return
    end

    if command == "" then
        addon.Database.SetActive(not addon.Database.GetGlobalSettings().active)
        return
    end

    print(
        "|cffffd100RP Emote Menu:|r /rpem, /rpem about, /rpem config, " ..
        "/rpem options, /rpem settings"
    )
end

-- INITIALIZATION
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then
        return
    end

    addon.Database.InitializeDatabase()
    addon.MainWindow.CreateMainWindow()
    addon.Settings.RegisterSettingsPanels()
    if addon.InitializeFontMedia then addon.InitializeFontMedia() end

    SLASH_ELLEMOTE1 = "/rpem"
    SlashCmdList["ELLEMOTE"] = HandleSlashCommand

    eventFrame:UnregisterEvent("ADDON_LOADED")
end)

