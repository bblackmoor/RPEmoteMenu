-- Pure catalog behavior; all reference rows are unverified until native review.
local function Load(locale)
    GetLocale = function() return locale end
    local addon = {}
    for _, path in ipairs({'Localization.lua', 'Locales/enUS.lua', 'Defaults.lua', 'StandardEmoteCatalog.lua'}) do
        assert(loadfile('RPEmoteMenu/' .. path))('RPEmoteMenu', addon)
    end
    return addon
end
local addon = Load('enUS')
local catalog = addon.StandardEmoteCatalog
local source = addon.Localization.StandardEmotes.enUS
local snapshot = {}
for i, row in ipairs(source) do snapshot[i] = {row[1], row[2], row[3]} end
local dispatched = 0
DoEmote = function() dispatched = dispatched + 1 end
ChatFrame_OpenChat = function() dispatched = dispatched + 1 end
C_ChatInfo = {SendChatMessage = function() dispatched = dispatched + 1 end}
local model, state = catalog.GetForClient()
assert(model and state == 'available' and model.count == 299)
local choices = model:GetChoices()
assert(#choices == 299 and #model:GetChoices(true) == 0)
for index, entry in ipairs(choices) do
    assert(entry.supportStatus == 'unverified' and entry.selectable)
    assert(entry.value == 'enUS:' .. entry.alias and entry.command == '/' .. entry.alias)
    if index > 1 then assert(choices[index-1].alias < entry.alias) end
end
assert(model:Resolve('enUS:lol').token == 'LAUGH')
assert(model:Resolve('enUS:ty').token == 'THANK')
assert(model:Resolve('enUS:wave').token == 'WAVE')
assert(model:Resolve('frFR:wave') == nil and model:Resolve(1) == nil)
local wave = model:Resolve('enUS:wave')
wave.alias, wave.defaultPreview = 'modified', 'modified'
choices[1].value = 'modified'
assert(model:Resolve('enUS:wave').alias == 'wave')
assert(model:GetChoices()[1].value ~= 'modified')
assert(model:Resolve('enUS:belch') and model:Resolve('enUS:burp'), 'Alias variants must remain distinct')
-- Deliberately unsorted input and duplicate preview wording.
local rows = {{'wave','Same','Same <target>'},{'agree','Same','Same <target>'}}
local small = assert(catalog.Build('enUS', rows))
assert(small:GetChoices()[1].alias == 'agree' and rows[1][1] == 'wave')
rows[1][2] = 'Later source mutation'
assert(small:Resolve('enUS:wave').defaultPreview == 'Same')
assert(assert(catalog.Build('enUS', {})).count == 0)
local invalid = {
    false, {[2]={'wave','',''}}, {extra=true},
    {{'wave',''}}, {{'wave','','','extra'}}, {{'wave',false,''}},
    {{'','',''}}, {{'/wave','',''}}, {{'WaVe','',''}}, {{'wave x','',''}},
    {{'wave\n','',''}}, {{'wave;','',''}}, {{'wave','',''},{'wave','',''}},
}
for _, rows in ipairs(invalid) do local result, errorMessage = catalog.Build('enUS', rows); assert(not result and errorMessage) end
assert(not catalog.Build('EN-US', {}))
assert(not catalog.Build('enUS', {{'wave','',''}}, {aliases={wave='bad token'}}))
-- Native evidence must match locale/build/token and cover targeting before claiming verification.
local review = {locale='enUS', clientBuild='test-build', token='WAVE', status='verified', targetingChecked=true, evidence='Native acceptance fixture'}
local function Reviewed(record, build)
    return assert(catalog.Build('enUS', {{'wave','',''}}, {reviews={wave=record}, clientBuild=build or 'test-build'})):Resolve('enUS:wave')
end
assert(Reviewed(review).selectable and Reviewed(review).supportStatus == 'verified')
assert(Reviewed(review, 'different-build').selectable and Reviewed(review, 'different-build').supportStatus == 'unverified')
for _, field in ipairs({'locale','clientBuild','token','evidence','targetingChecked'}) do
    local bad = {}; for k,v in pairs(review) do bad[k]=v end; bad[field]=nil
    assert(Reviewed(bad).supportStatus == 'unverified', field)
end
review.status = 'unsupported'
assert(Reviewed(review).supportStatus == 'unsupported' and not Reviewed(review).selectable)
review.status = 'invented'
assert(Reviewed(review).supportStatus == 'unverified')
review.status = 'verified'
catalog.Verification.enUS = {wave=review}
local reviewed = assert(catalog.GetForClient({clientBuild='test-build'}))
assert(#reviewed:GetChoices(true) == 1 and reviewed:GetChoices(true)[1].value == 'enUS:wave')
assert(model:Resolve('enUS:wave').supportStatus == 'unverified', 'An existing snapshot must not change after later reviews')
local foreign = Load('deDE')
local result, reason = foreign.StandardEmoteCatalog.GetForClient()
assert(not result and reason == 'unavailable')
foreign.Localization.Register('deDE', {}, {{'wave','German preview','German target'}})
local foreignModel = assert(foreign.StandardEmoteCatalog.GetForClient())
assert(foreignModel.count == 1 and foreignModel:Resolve('deDE:wave'))
foreign.Localization.StandardEmotes.deDE = {{'bad slash/','',''}}
local result, reason, detail = foreign.StandardEmoteCatalog.GetForClient()
assert(not result and reason == 'invalid' and detail)
for i,row in ipairs(source) do for j=1,3 do assert(row[j] == snapshot[i][j], 'Source catalog changed') end end
assert(dispatched == 0 and RPEmoteMenuDB == nil, 'Catalog reads must not execute or create saved data')
print('PASS catalog validation, sorting, identity/isolation, locale availability and build-scoped verification')
