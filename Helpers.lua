-- BlingtronApp - Shared helper functions

local function normalizeKey(name)
    if not name or name == "" then return nil end
    return name:gsub("%s+", ""):lower()
end

local function lookupByName(tbl, name)
    if not tbl or not name then return nil end
    return tbl[name] or tbl[normalizeKey(name)]
end

-- Resolve a full candidate name ("Name-Realm") to a unit token ("player"/"raidN"/"partyN").
-- If no match, returns the character name only (no realm) for use as a unit token.
local function resolveUnitIdForCandidate(fullName)
    if not fullName or fullName == "" then return nil end

    local function nameOnly(s)
        local short = s:match("^([^-]+)-")
        if short and short ~= "" then return short end
        return s
    end

    local targetLower = fullName:lower()
    local function candidateNameMatchesUnit(unit)
        if not UnitExists(unit) then return false end

        local name, realm = UnitFullName(unit)
        if not name or name == "" then return false end

        -- For party/raid units on the same realm, UnitFullName returns realm = nil.
        -- The candidate string we receive always includes "-Realm", so synthesize it.
        if not realm or realm == "" then
            realm = GetRealmName()
        end

        local fullLower = (name .. "-" .. realm):lower()
        return fullLower == targetLower
    end

    if candidateNameMatchesUnit("player") then
        return "player"
    end

    if IsInRaid() then
        -- GetNumGroupMembers includes the player, but raid unit tokens are 1..N
        -- and some may not exist. `UnitExists` guards this.
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if candidateNameMatchesUnit(unit) then
                return unit
            end
        end
    elseif IsInGroup() then
        -- partyN is 1..4 (other members; self handled via "player" above).
        for i = 1, 4 do
            local unit = "party" .. i
            if candidateNameMatchesUnit(unit) then
                return unit
            end
        end
    end

    return nameOnly(fullName)
end

local function getSpecForCandidate(name)
    if not name or name == "" then return nil end
    BlingtronAppDB.candidateSpecCache = BlingtronAppDB.candidateSpecCache or {}
    local cache = BlingtronAppDB.candidateSpecCache

    local key = normalizeKey(name)
    if not key then return nil end

    -- Resolve Name-Realm -> raid/party unit, or short name fallback for GetInspectSpecialization.
    local unit = resolveUnitIdForCandidate(name)
    local specID
    if unit then
        specID = GetInspectSpecialization(unit)
        if specID and specID > 0 then
            cache[key] = specID
            return specID
        end
    end

    -- Fallback: if inspect returned 0 (or we couldn't resolve a unit), try cached value.
    local cached = cache[key] or cache[name] -- backward compatibility with older cached keys
    if cached and type(cached) == "number" and cached > 0 then
        return cached
    end

    return nil
end

local function bisListSourceKeyHasItems(sourceKey)
    local source = BlingtronApp.BisListSources[sourceKey]
    if not source then return false end
    local list = BlingtronApp.BisList[source.id]
    return type(list) == "table" and next(list) ~= nil
end

local function getBisListSourceKey()
    local dbKey = BlingtronAppDB.bisListSource
    if dbKey and bisListSourceKeyHasItems(dbKey) then
        return dbKey
    end

    local keys = {}
    for k in pairs(BlingtronApp.BisListSources) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        if bisListSourceKeyHasItems(k) then
            return k
        end
    end

    if dbKey and BlingtronApp.BisListSources[dbKey] then
        return dbKey
    end
    return keys[1]
end

local function getBisList()
    local sourceKey = getBisListSourceKey()
    if not sourceKey then return {} end
    local source = BlingtronApp.BisListSources[sourceKey]
    if not source then return {} end
    return BlingtronApp.BisList[source.id] or {}
end

BlingtronApp.Helpers = {
    normalizeKey           = normalizeKey,
    lookupByName           = lookupByName,
    getSpecForCandidate    = getSpecForCandidate,
    getBisListSourceKey    = getBisListSourceKey,
    getBisList             = getBisList,
}
