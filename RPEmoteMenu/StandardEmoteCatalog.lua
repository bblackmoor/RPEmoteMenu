-- Reference choices only. This module never edits saved data or executes commands.
local _, addon = ...
local Catalog = {Verification = {}}
addon.StandardEmoteCatalog = Catalog

local function Copy(entry)
    local result = {}
    for key, value in pairs(entry) do result[key] = value end
    return result
end

local function DenseArray(value, expected)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    if expected and count ~= expected then return false end
    for index = 1, count do if value[index] == nil then return false end end
    return true, count
end

-- Evidence is scoped to a locale, exact client build and resolved token.
-- Shape/alias-map presence alone never marks a command as verified.
local function SupportStatus(review, locale, token, clientBuild)
    if type(review) ~= "table" or review.locale ~= locale
        or type(clientBuild) ~= "string" or clientBuild == ""
        or review.clientBuild ~= clientBuild or review.token ~= token
        or type(review.evidence) ~= "string" or not review.evidence:find("%S") then
        return "unverified"
    end
    if review.status == "unsupported" then return "unsupported", review.evidence end
    if review.status == "verified" and review.targetingChecked == true then
        return "verified", review.evidence
    end
    return "unverified"
end

function Catalog.Build(locale, rows, options)
    if type(locale) ~= "string" or not locale:match("^[a-z][a-z][A-Z][A-Z]$") then
        return nil, "Invalid catalog locale"
    end
    local valid, count = DenseArray(rows)
    if not valid then return nil, "Catalog must be a dense array" end
    options = options or {}
    local aliases = options.aliases or addon.EmoteAliases or {}
    local reviews = options.reviews or {}
    local entries, byValue, seen = {}, {}, {}
    for index = 1, count do
        local row = rows[index]
        if not DenseArray(row, 3) or type(row[1]) ~= "string"
            or not row[1]:match("^[a-z][a-z0-9]*$")
            or type(row[2]) ~= "string" or type(row[3]) ~= "string" then
            return nil, "Invalid catalog row " .. index
        end
        local alias = row[1]
        if seen[alias] then return nil, "Duplicate catalog alias: " .. alias end
        seen[alias] = true
        local token = aliases[alias] or string.upper(alias)
        if type(token) ~= "string" or not token:match("^[A-Z][A-Z0-9_]*$") then
            return nil, "Invalid execution token for alias: " .. alias
        end
        local status, evidence = SupportStatus(reviews[alias], locale, token, options.clientBuild)
        local entry = {
            locale = locale, alias = alias, value = locale .. ":" .. alias,
            command = "/" .. alias, token = token,
            defaultPreview = row[2], targetedPreview = row[3],
            supportStatus = status, selectable = status ~= "unsupported", evidence = evidence,
        }
        entries[#entries + 1] = entry
        byValue[entry.value] = entry
    end
    table.sort(entries, function(first, second) return first.alias < second.alias end)
    local model = {locale = locale, count = count}

    -- Callers receive copies, so a UI cannot alter the catalog or this snapshot.
    function model:GetChoices(verifiedOnly)
        local result = {}
        for _, entry in ipairs(entries) do
            if not verifiedOnly or entry.supportStatus == "verified" then
                result[#result + 1] = Copy(entry)
            end
        end
        return result
    end

    function model:Resolve(value)
        local entry = byValue[value]
        return entry and Copy(entry) or nil
    end

    return model
end

-- No English command-catalog fallback on another client locale.
-- clientBuild is supplied by a caller; no client API discovery is performed here.
function Catalog.GetForClient(options)
    local localization = addon.Localization
    local locale = localization and localization.locale
    local rows = localization and localization.StandardEmotes
        and localization.StandardEmotes[locale]
    if rows == nil then return nil, "unavailable" end
    options = options or {}
    local model, reason = Catalog.Build(locale, rows, {
        clientBuild = options.clientBuild,
        reviews = Catalog.Verification[locale],
        aliases = addon.EmoteAliases,
    })
    if not model then return nil, "invalid", reason end
    return model, "available"
end
