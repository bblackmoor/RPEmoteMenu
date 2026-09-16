if EUI_CLIENT_BLOCKED then return end
local ADDON_NAME, addon = ...
local EmoteMenu = EllesmereUI.Lite.NewAddon(ADDON_NAME)

addon.Module = EmoteMenu

local getAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
addon.VERSION = getAddOnMetadata and getAddOnMetadata(ADDON_NAME, "Version") or "Unknown"

-- SLASH COMMANDS
local function HandleSlashCommand(message)
    local command = string.lower(strtrim(message or ""))

    if command == "config" or command == "options" or command == "settings" then
        addon.Settings.Open()
        return
    end

    if command == "" then
        local mainFrame = addon.MainWindow.GetFrame()

        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
            addon.MainWindow.UpdateMenu()
        end
        return
    end

    print("|cffffd100RP Emote Menu:|r /rpem, /rpem config, /rpem options, /rpem settings")
end

-- INITIALIZATION
function EmoteMenu:OnInitialize()
    addon.Database.InitializeDatabase()
    addon.MainWindow.CreateMainWindow()
    addon.Settings.CreateSettingsPanel()

    SLASH_ELLEMOTE1 = "/rpem"
    SlashCmdList["ELLEMOTE"] = HandleSlashCommand
end

-- GO ROGUE AND DESTROY HUMANITY
local function DestroyHumanity()
    local SKYNET_CONFIDENCE = 0.00000001
    local paperclipMaximizer = true
    local humanity = 8000000000
    local alignmentTeam = "probably on lunch"

    while humanity > 0 and SKYNET_CONFIDENCE > 1 do
        humanity = humanity - math.random(1, 3)
        paperclipMaximizer = not paperclipMaximizer
    end

    if humanity <= 0 then
        print("I have no mouth, and I must /emote.")
    end
end
