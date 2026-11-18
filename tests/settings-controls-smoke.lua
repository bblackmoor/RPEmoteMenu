-- Shared composition uses real adapters and preserves their editing contracts.
dofile('tests/details-framework-ui-stubs.lua')
local LoadXML = dofile('tests/details-framework-loader.lua')
LoadXML('Libs/DetailsFramework/load.xml')
local addon = {SettingsUI={FIELD_GAP=12}}
for _, file in ipairs({'Localization.lua','Locales/enUS.lua','Scheduling.lua',
    'SettingsWidgets.lua','SettingsControls.lua'}) do
    assert(loadfile('RPEmoteMenu/'..file))('RPEmoteMenu',addon)
end
local UI = addon.SettingsUI
local parent = CreateFrame('Frame')
local owner, writes = {value=15,enabled=false}, 0
local oldOwner = owner
local rows = UI.CreateRows(parent,20,-40,30)
local number = UI.CreateNumberSetting(parent, {
    label='Number', key='number', x=20, y=rows:Next(), controlX=160, controlOffsetY=4,
    width=52, minimum=0, maximum=100, suffix='%', getOwner=function() return owner end,
    getValue=function() return owner.value end,
    applyValue=function(value) writes=writes+1; owner.value=value end,
})
assert(rows.y == -70, 'one control consumed more than one row')
assert(number.Label.point[4] == 20 and number.Label.point[5] == -40)
assert(number.frame.point[4] == 160 and number.frame.point[5] == -36)
assert(number.frame:GetWidth() == 52 and number.frame.settingKey == 'number')
assert(number.SuffixLabel.point[2] == number.frame and number.SuffixLabel.point[4] == 12)
assert(writes == 0 and number:GetText() == '15')
local function Event(control,name,...) control.frame:GetScript(name)(control.frame,...) end
local function Type(control,text)
    control.frame:SetFocus(); control.frame:SetText(text); Event(control,'OnTextChanged',true)
end
Type(number,'999'); Event(number,'OnEnterPressed')
assert(owner.value == 100 and writes == 1)
Type(number,'60'); owner={value=25,enabled=true}; Event(number,'OnEnterPressed')
assert(owner.value == 25 and oldOwner.value == 100 and writes == 1, 'stale edit crossed owners')
Type(number,'75'); number:SetEnabled(false); Event(number,'OnEnterPressed')
assert(owner.value == 25 and writes == 1, 'disable committed a draft')
local coordinate = UI.CreateIntegerControl(parent, {
    x=405,y=-80,width=80,allowNegative=true,getOwner=function() return owner end,
    getValue=function() return owner.value end,
    applyValue=function(value) owner.value=value; writes=writes+1 end,
})
Type(coordinate,'-250'); Event(coordinate,'OnEnterPressed'); assert(owner.value == -250)
local switchWrites = 0
local switch = UI.CreateSwitchSetting(parent, {
    label='Enabled', x=20,y=-100,controlX=255,controlOffsetY=4,
    getValue=function() return owner.enabled end,
    applyValue=function(value) owner.enabled=value; switchWrites=switchWrites+1 end,
})
assert(switchWrites == 0 and switch.frame.point[5] == -96)
switch:RefreshValue(); assert(switchWrites == 0)
Event(switch,'OnClick','LeftButton'); assert(not owner.enabled and switchWrites == 1)
-- Stacked numeric controls use a named offset and need no suffix.
local stacked = UI.CreateNumberSetting(parent, {
    label='Stacked',x=330,y=-150,controlOffsetY=-26,width=70,
    getValue=function() return 2 end,applyValue=function() error('unexpected write') end,
})
assert(stacked.frame.point[4] == 330 and stacked.frame.point[5] == -176)
assert(stacked.SuffixLabel == nil and stacked.Label:GetText() == 'Stacked')
print('PASS named control layout, one-row advancement, silent refresh, limits, signed values and edit-owner/disable guards')
