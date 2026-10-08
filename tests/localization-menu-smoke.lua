-- Translated menu/editor with real data, framework and width calculation.
local native = dofile("tests/details-framework-ui-stubs.lua")
dofile("tests/main-window-native.lua")
local methods = getmetatable(UIParent).__index
function methods:SetEnabled(value) if value then self:Enable() else self:Disable() end end
local measured = {}
function methods:GetStringWidth()
    measured[self:GetText() or ""] = true
    return #(self:GetText() or "") * 5
end
local LoadXML = dofile("tests/details-framework-loader.lua")
LoadXML("Libs/DetailsFramework/load.xml")
function strtrim(value) return (value:gsub("^%s+", ""):gsub("%s+$", "")) end
GetLocale = function() return "deDE" end
local executed
local addon = {VERSION = "test", Settings = {}, SettingsUI = {FIELD_GAP = 12}, Commands = {
    ExecuteEmoteCommand = function(default, targeted) executed = {default, targeted} end,
}}
local function Load(name) assert(loadfile("RPEmoteMenu/" .. name))("RPEmoteMenu", addon) end
Load("Localization.lua"); Load("Locales/enUS.lua")
local translated = {
    MENU_ADD_CATEGORY = "Neue Kategorie hinzufügen",
    MENU_NO_CATEGORIES = "Keine Kategorien", UI_ADD_EMOTE = "Emote hinzufügen",
    MENU_DEFAULT_COMMAND = "Standard: %s", MENU_TARGETED_COMMAND = "Ziel: %s",
    MENU_RIGHT_CLICK_TO_EDIT = "Rechtsklick zum Bearbeiten",
    EDITOR_EDIT_EMOTE = "Emote bearbeiten", EDITOR_SAVE = "Speichern",
    EDITOR_EMOTE_NAME_FIELD = "Emote-Name", EDITOR_TARGET_CHANGED = "Editor erneut öffnen.",
}
addon.Localization.Register("deDE", translated)
for _, name in ipairs({"Defaults.lua", "SettingDefinitions.lua", "BuiltInThemes.lua",
    "Database.lua", "Scheduling.lua", "FontMedia.lua", "VisibleSlotOrder.lua",
    "WindowGeometry.lua", "WindowFade.lua", "EmoteEditor.lua", "MainWindow.lua",
    "SettingsWidgets.lua", "SettingsControls.lua"}) do Load(name) end
local db, main = addon.Database, addon.MainWindow
db.InitializeDatabase()
UIParent:SetSize(1000, 800)
local categories = db.GetCategories()
for _, category in ipairs(categories) do
    category.name = ""
    for _, emote in ipairs(category.emotes) do
        emote.label, emote.defaultCommand, emote.targetedCommand = "", "", ""
    end
end
main.CreateMainWindow()
local emptyLabel, emptyButton
for _, object in ipairs(native.objects) do
    if object:GetText() == translated.MENU_NO_CATEGORIES then emptyLabel = object end
    if object:GetText() == translated.MENU_ADD_CATEGORY then emptyButton = object end
end
assert(emptyLabel and emptyButton)
assert(measured[translated.MENU_ADD_CATEGORY] and not measured["Add Category"],
    "empty-sidebar sizing must measure the translated caption")
local expectedWidth = math.min(addon.MAX_SIDEBAR_WIDTH,
    math.max(addon.MIN_SIDEBAR_WIDTH, #translated.MENU_ADD_CATEGORY * 5 + 18))
assert(emptyLabel:GetParent():GetWidth() == expectedWidth)

categories[1].name = "User category %s"
local emote = categories[1].emotes[1]
emote.label, emote.defaultCommand, emote.targetedCommand = "User label %s", " /e {player} %s ", " /e {target} "
db.GetGlobalSettings().tooltipDelayMs = 0
main.UpdateMenu()
local button
for _, object in ipairs(native.objects) do
    if object.emoteLabel == emote.label then button = object end
end
assert(button and button.Text:GetText() == emote.label)
local lines = {}
function GameTooltip:AddLine(text) lines[#lines + 1] = text end
button.scripts.OnEnter(button)
assert(GameTooltip:GetText() == emote.label)
assert(lines[1] == "Standard: " .. emote.defaultCommand)
assert(lines[2] == "Ziel: " .. emote.targetedCommand)
assert(lines[3] == translated.MENU_RIGHT_CLICK_TO_EDIT)
button.scripts.OnClick(button, "LeftButton")
assert(executed[1] == emote.defaultCommand and executed[2] == emote.targetedCommand)

addon.EmoteEditor.Open(1, 1, false)
local dialog
for _, object in ipairs(native.objects) do if object.NameBox then dialog = object end end
assert(dialog.Title:GetText() == translated.EDITOR_EDIT_EMOTE)
assert(dialog.SaveButton:GetText() == translated.EDITOR_SAVE)
assert(dialog.DefaultBox:GetText() == emote.defaultCommand)
dialog.NameBox:SetText(string.rep("x", addon.ContentTextLimits.emoteLabel + 1))
dialog.SaveButton.scripts.OnClick()
assert(dialog.Status:GetText() == "Emote-Name cannot exceed " .. addon.ContentTextLimits.emoteLabel .. " bytes.")
assert(emote.label == "User label %s", "invalid translated editor input must not save")
dialog.NameBox:SetText("Saved label %s")
dialog.DefaultBox:SetText(" /e {player} says %s ")
dialog.SaveButton.scripts.OnClick()
assert(emote.label == "Saved label %s" and emote.defaultCommand == " /e {player} says %s ")
addon.EmoteEditor.Open(1, 1, false)
categories[1].emotes[1] = {label = "Replacement", defaultCommand = "/wave", targetedCommand = ""}
dialog.SaveButton.scripts.OnClick()
assert(dialog.Status:GetText() == translated.EDITOR_TARGET_CHANGED and not dialog.SaveButton:IsEnabled())
print("PASS translated menu sizing/tooltips/editor and unchanged user content, command routing and stale-target guards")
