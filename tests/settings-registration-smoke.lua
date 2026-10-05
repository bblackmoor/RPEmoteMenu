-- Registration preflight, retry, routing and duplicate protection.
local addon = {MAX_CATEGORIES = 8, Database = {GetSettings = function() return {selectedCategory = 2} end}}
assert(loadfile("RPEmoteMenu/Settings.lua"))("RPEmoteMenu", addon)
local keys = {"About","Behavior","Profiles","Themes","Emotes","ImportExport"}
local register = addon.Settings.RegisterSettingsPanels
local created, registered, refreshes, selected, editors = 0, {}, {}, nil, nil
addon.SettingsPanels = {}
for _, key in ipairs(keys) do
    addon.SettingsPanels[key] = function()
        created = created + 1
        return {key = key,
            Refresh = function() refreshes[key] = (refreshes[key] or 0) + 1 end,
            SelectCategory = function(index) selected = index end,
            RefreshEditors = function(index) editors = index end}
    end
end
Settings = nil
register()
assert(created == 0, "missing Settings API does not construct pages")
Settings = {
    RegisterCanvasLayoutCategory = function(panel, label)
        local category = {panel = panel, label = label, id = #registered + 1}
        function category:GetID() return self.id end
        registered[#registered + 1] = category
        return category
    end,
    RegisterAddOnCategory = function() end,
}
Settings.RegisterCanvasLayoutSubcategory = function(_, panel, label)
    return Settings.RegisterCanvasLayoutCategory(panel, label)
end
local factory = addon.SettingsPanels[keys[#keys]]
addon.SettingsPanels[keys[#keys]] = nil
register()
assert(created == 0 and #registered == 0, "missing factory cannot partially register")
addon.SettingsPanels[keys[#keys]] = factory
local addOn = Settings.RegisterAddOnCategory
Settings.RegisterAddOnCategory = nil
register()
assert(created == 0, "missing AddOn registration API is recoverable")
Settings.RegisterAddOnCategory = addOn
SlashCmdList = {}
function strtrim(text) return text:match("^%s*(.-)%s*$") end
register()
assert(created == #keys and #registered == #keys)
for index, key in ipairs(keys) do assert(registered[index].panel.key == key, "page order") end
local firstRoot = registered[1]
register()
assert(created == #keys and #registered == #keys and registered[1] == firstRoot, "registration is idempotent")
local opened
Settings.OpenToCategory = function(id) opened = id end
addon.Settings.OpenAbout(); assert(opened == 1)
addon.Settings.Open(); assert(opened == 2)
addon.Settings.OpenEmotes(3); assert(opened == 5 and selected == 3)
addon.Settings.OpenEmotes(0); assert(selected == 3, "invalid editor category ignored")
addon.SettingsUI.RefreshExchangeDialog = function() end
addon.Settings.RefreshSettingsPanels()
assert(refreshes.Behavior == 1 and refreshes.Themes == 1 and refreshes.Profiles == 1 and selected == 2)
assert(editors == nil, "ordinary page refresh does not invoke targeted editor refresh")
addon.Settings.RefreshEditors(4); assert(editors == 4)
print("PASS settings registration preflight, retry, order, routing and duplicate protection")
