-- Font names remain the saved/imported Theme values; availability is runtime state.
local _, addon = ...
local media = LibStub("LibSharedMedia-3.0")
local builtins = {}
for _, font in ipairs(addon.BuiltInFonts) do builtins[font.name] = font.path end
local ready, refreshText = false, false
local mediaRefreshKey = {}

local function SharedPath(name)
    if type(name) ~= "string" then return end
    local registered = media:HashTable("font")[name]
    -- Fetch respects global overrides, even for missing keys. Validate the
    -- requested registration first so missing fonts retain their fallback.
    if type(registered) ~= "string" or registered == "" then return end
    local path = media:Fetch("font", name, true)
    if type(path) == "string" and path ~= "" then return path end
end

function addon.IsFontAvailable(name)
    return builtins[name] ~= nil or SharedPath(name) ~= nil
end

function addon.GetFontPath(name)
    return builtins[name] or SharedPath(name) or addon.BuiltInFonts[1].path
end

function addon.GetAvailableFonts(selected)
    local fonts, included, shared = {}, {}, {}
    for _, font in ipairs(addon.BuiltInFonts) do
        fonts[#fonts + 1] = font
        included[font.name] = true
    end
    for _, name in ipairs(media:List("font") or {}) do
        if not included[name] and SharedPath(name) then
            shared[#shared + 1] = {name = name, path = SharedPath(name)}
            included[name] = true
        end
    end
    table.sort(shared, function(a, b)
        local first, second = a.name:lower(), b.name:lower()
        return first == second and a.name < b.name or first < second
    end)
    for _, font in ipairs(shared) do fonts[#fonts + 1] = font end
    if type(selected) == "string" and selected ~= "" and not included[selected] then
        fonts[#fonts + 1] = {name = selected, unavailable = true}
    end
    return fonts
end

local function FlushMediaChanges()
    local updateText = refreshText
    refreshText = false
    if addon.Settings and addon.Settings.RefreshFontControls then
        addon.Settings.RefreshFontControls()
    end
    if updateText and addon.MainWindow and addon.MainWindow.ScheduleFontRefreshes then
        addon.MainWindow.ScheduleFontRefreshes()
    end
end

local function MediaChanged(event, kind, name)
    if kind ~= "font" or not ready then return end
    local settings = addon.Database.GetThemeSettings()
    for _, selected in ipairs({settings.categoryFont, settings.emoteFont}) do
        if not builtins[selected] and (event == "LibSharedMedia_SetGlobal" or selected == name) then
            refreshText = true
        end
    end
    addon.Scheduling.NextTick(mediaRefreshKey, FlushMediaChanges)
end

-- Initialization creates the menu and its selectors before late providers
-- may request refreshes. Startup rendering is owned by ApplyProfileSettings.
function addon.InitializeFontMedia() ready = true end
media.RegisterCallback(addon, "LibSharedMedia_Registered", MediaChanged)
media.RegisterCallback(addon, "LibSharedMedia_SetGlobal", MediaChanged)
