-- Run from repository root; optionally pass the other addon's picker module.
local contracts = dofile("tests/settings-contracts.lua")
local own = {name = "RPEmoteMenu", kind = "theme", path = "RPEmoteMenu/SettingsColorPicker.lua"}
contracts.PickerLifecycle(own)
if arg and arg[1] then
    local peer = {name = "SimpleNameplates", kind = "profile", path = arg[1]}
    contracts.PickerLifecycle(peer)
    contracts.PickerCoexistence(own, peer)
    contracts.PickerCoexistence(peer, own)
    print("PASS actual addon picker coexistence in both directions")
end
print("PASS shared settings picker lifecycle contracts")
