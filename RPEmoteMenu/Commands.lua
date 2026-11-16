local _, addon = ...

addon.Commands = {}

local emoteAliases = addon.EmoteAliases

-- COMMAND EXECUTION
local function GetUnitDisplayName(unit)
    local name = UnitName(unit)
    return type(name) == "string" and name or ""
end

local function ReplaceCommandTokens(command)
    local replacements = {
        ["{target}"] = GetUnitDisplayName("target"),
        ["{player}"] = GetUnitDisplayName("player")
    }

    for token, value in pairs(replacements) do
        local pattern = string.gsub(token, "(%W)", "%%%1")
        command = string.gsub(command, pattern, function()
            return value
        end)
    end

    return command
end

local function HasOtherTarget()
    return UnitExists("target") and not UnitIsUnit("target", "player")
end

function addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand, defaultSend, targetedSend)
    local command = defaultCommand
    local send = addon.GetCommandSend(defaultSend, command)

    if HasOtherTarget() and targetedCommand and targetedCommand ~= "" then
        command = targetedCommand
        send = addon.GetCommandSend(targetedSend, command)
    end

    command = ReplaceCommandTokens(command)

    if not send then
        if ChatFrameUtil and ChatFrameUtil.OpenChat then
            ChatFrameUtil.OpenChat(command, DEFAULT_CHAT_FRAME)
        else
            ChatFrame_OpenChat(command, DEFAULT_CHAT_FRAME)
        end
        return
    end

    local customText = string.match(command, "^/e%s+(.+)$")
    if customText then
        C_ChatInfo.SendChatMessage(customText, "EMOTE")
        return
    end

    local slashCommand = string.match(command, "^/(%S+)$")
    if slashCommand then
        local token = emoteAliases[string.lower(slashCommand)] or string.upper(slashCommand)
        DoEmote(token)
        return
    end

    -- Use Blizzard's chat parser for other slash commands and plain chat text.
    if ChatFrameUtil and ChatFrameUtil.OpenChat then
        local editBox = ChatFrameUtil.OpenChat(command, DEFAULT_CHAT_FRAME)
        if editBox then
            editBox:SendText(1)
            editBox:ClearChat()
        end
    else
        ChatFrame_OpenChat(command, DEFAULT_CHAT_FRAME)
        local editBox = ChatEdit_GetActiveWindow()
        if editBox then
            ChatEdit_SendText(editBox, 1)
            ChatEdit_DeactivateChat(editBox)
        end
    end
end
