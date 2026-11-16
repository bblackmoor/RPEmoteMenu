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

local function expect(defaultCommand, targetedCommand, kind, text, defaultSend, targetedSend)
    calls = {}
    addon.Commands.ExecuteEmoteCommand(defaultCommand, targetedCommand, defaultSend, targetedSend)
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

-- Explicit flags override routing, including the trailing-quote draft heuristic.
targetExists, selfTarget = false, false
expect('/wave', nil, 'chat', '/wave', false)
expect('/e waves.', nil, 'chat', '/e waves.', false)
expect('/e says, "', nil, 'send', 'says, "', true)
targetExists = true
expect('/wave', '/e asks {target}, "', 'chat', '/e asks Friend, "', true, false)
expect('/e waits.', '/wave', 'emote', 'WAVE', false, true)
selfTarget = true
expect('/wave', '/e waves.', 'chat', '/wave', false, true)
selfTarget, targetExists = false, false
-- Model Blizzard's deferred OpenChat text, rather than assuming it is ready.
local parsed, cleared, opened, sent = 0, 0, nil, {}
local editBox = {value = ''}
function editBox:SetText(text) self.value = text end
function editBox:OnUpdate()
    if self.setText == 1 then
        self:SetText(self.text)
        self.setText = 0
    end
end
function editBox:SendText(history)
    assert(history == 1)
    parsed = parsed + 1
    sent[#sent + 1] = self.value
end
function editBox:ClearChat()
    cleared = cleared + 1
    self.value = ''
end
local function DeferredOpen(text, frame)
    assert(frame == DEFAULT_CHAT_FRAME)
    opened = text
    editBox.text, editBox.setText = text, 1
    return editBox
end
ChatFrameUtil = {OpenChat = DeferredOpen}
local example = '/s says, "Oh, there you are."'
addon.Commands.ExecuteEmoteCommand(example, nil, true)
assert(sent[1] == example and parsed == 1 and cleared == 1)
editBox:OnUpdate()
assert(editBox.value == '' and editBox.setText == 0, 'Sent text must not return as a draft')
-- Off retains the normal next-update draft and sends nothing.
addon.Commands.ExecuteEmoteCommand('/say Draft', nil, false)
assert(opened == '/say Draft' and parsed == 1 and cleared == 1)
editBox:OnUpdate(); assert(editBox.value == '/say Draft')
-- On must replace a previously open draft, without submitting that draft.
addon.Commands.ExecuteEmoteCommand('/say Hello, {player}.', nil, true)
assert(sent[2] == '/say Hello, Tester.' and parsed == 2 and cleared == 2)
editBox:OnUpdate(); assert(editBox.value == '')
addon.Commands.ExecuteEmoteCommand('A complete message', nil, true)
assert(sent[3] == 'A complete message' and parsed == 3 and cleared == 3)
editBox:OnUpdate(); assert(editBox.value == '')
-- The independently enabled targeted command follows the same submission path.
targetExists = true
addon.Commands.ExecuteEmoteCommand('/e waits.', '/s Hello, {target}.', false, true)
assert(sent[4] == '/s Hello, Friend.' and parsed == 4 and cleared == 4)
editBox:OnUpdate(); assert(editBox.value == '')
targetExists = false
-- Legacy OpenChat also defers text; flush it before its global send API.
ChatFrameUtil = nil
ChatFrame_OpenChat = DeferredOpen
function ChatEdit_GetActiveWindow() return editBox end
function ChatEdit_SendText(box, history) assert(box == editBox); box:SendText(history) end
function ChatEdit_DeactivateChat(box) assert(box == editBox); box:ClearChat() end
addon.Commands.ExecuteEmoteCommand(example, nil, true)
assert(sent[5] == example and parsed == 5 and cleared == 5)
editBox:OnUpdate(); assert(editBox.value == '' and editBox.setText == 0)
print('PASS independent Send overrides and deferred chat text in Retail/legacy APIs')
