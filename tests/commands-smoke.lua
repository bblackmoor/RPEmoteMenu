-- Run from the repository root: texlua tests/commands-smoke.lua
-- Load the real command module; stub only WoW's unit and chat APIs.
local addon = {}
assert(loadfile('RPEmoteMenu/Defaults.lua'))('RPEmoteMenu', addon)
local targetExists, selfTarget = false, false
local names = {player = 'Tester', target = 'Friend'}
function UnitName(unit) return names[unit], 'ExampleRealm' end
function UnitExists(unit) assert(unit == 'target'); return targetExists end
function UnitIsUnit(first, second)
    assert(first == 'target' and second == 'player')
    return selfTarget
end

local calls = {}
DEFAULT_CHAT_FRAME = {}
function DoEmote(token) calls[#calls + 1] = {kind = 'emote', text = token} end
C_ChatInfo = {SendChatMessage = function(text, channel)
    calls[#calls + 1] = {kind = 'send', text = text, channel = channel}
end}
function ChatFrame_OpenChat(text, frame)
    calls[#calls + 1] = {kind = 'chat', text = text, frame = frame}
end
assert(loadfile('RPEmoteMenu/Commands.lua'))('RPEmoteMenu', addon)

local function expect(defaultCommand, targetedCommand, kind, text)
    calls = {}
    addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand)
    assert(#calls == 1, 'A click must dispatch exactly one action')
    local call = calls[1]
    assert(call.kind == kind, 'Wrong command route: ' .. call.kind)
    assert(call.text == text, 'Wrong command text: ' .. call.text)
    if kind == 'send' then assert(call.channel == 'EMOTE') end
    if kind == 'chat' then assert(call.frame == DEFAULT_CHAT_FRAME) end
end

-- Native emotes and aliases use DoEmote, with case-insensitive alias lookup.
for _, case in ipairs({{'/wave', 'WAVE'}, {'/WaVe', 'WAVE'},
    {'/lol', 'LAUGH'}, {'/LoL', 'LAUGH'}, {'/ty', 'THANK'}, {'/TY', 'THANK'}}) do
    expect(case[1], nil, 'emote', case[2])
end

-- Only another existing target selects the targeted command.
local default = '/e {player} waits.'
local targeted = '/e watches {target}.'
expect(default, targeted, 'send', 'Tester waits.')
targetExists = true
expect(default, targeted, 'send', 'watches Friend.')
selfTarget = true
names.target = names.player
expect(default, targeted, 'send', 'Tester waits.')
selfTarget = false
names.target = 'Friend'
expect(default, nil, 'send', 'Tester waits.')
expect(default, '', 'send', 'Tester waits.')
expect('/wave', '/lol', 'emote', 'LAUGH')

-- Expand repeated tokens without realm suffixes or Lua replacement escapes.
names.player, names.target = 'Mélacanthe', '50% Friend'
expect('/e {player} greets {target}; {player} thanks {target}.', nil, 'send',
    'Mélacanthe greets 50% Friend; Mélacanthe thanks 50% Friend.')
targetExists = false
names.target = nil
expect('/e {player} waits for {target}.', nil, 'send', 'Mélacanthe waits for .')
names.player, names.target = false, 42
expect('/e [{player}] [{target}]', nil, 'send', '[] []')
names.player, names.target = 'Tester', 'Friend'

-- Open-ended speech and other chat commands stay editable and are not sent.
expect('/e {player} says, "', nil, 'chat', '/e Tester says, "')
targetExists = true
expect('/e waits.', '/e asks {target}, "', 'chat', '/e asks Friend, "')
expect('/say Hello, {target}.', nil, 'chat', '/say Hello, Friend.')
expect('/whisper {target} Hello', nil, 'chat', '/whisper Friend Hello')
expect('A draft for {player}', nil, 'chat', 'A draft for Tester')

-- Preserve custom emote content while removing its slash-command separator.
expect('/e watches quietly.', nil, 'send', 'watches quietly.')
expect('/e  watches quietly.', nil, 'send', 'watches quietly.')
expect('/e watches "quietly".', nil, 'send', 'watches "quietly".')
expect('/e watches quietly.  ', nil, 'send', 'watches quietly.  ')
print('PASS real command routing, aliases, target selection, tokens and editable chat drafts')
