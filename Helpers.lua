-- BlingtronApp - Shared helper functions

local function normalizeKey(name)
    if not name or name == "" then return nil end
    return name:gsub("%s+", ""):lower()
end

local function lookupByName(tbl, name)
    if not tbl or not name then return nil end
    return tbl[name] or tbl[normalizeKey(name)]
end

local function getSpecForCandidate(name)
    if not name then return nil end
    local playerName = UnitName("player")
    local playerFullName = playerName and (playerName .. "-" .. GetRealmName())
    if name == playerName or name == playerFullName then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID then return specID end
        end
    end
    return nil
end

local function getBisList()
    local sourceKey = BlingtronAppDB.bisListSource
    if not sourceKey then
        -- fall back to first registered source
        for k in pairs(BlingtronApp.BisListSources) do
            sourceKey = k
            break
        end
    end

    if not sourceKey then return {} end
    local source = BlingtronApp.BisListSources[sourceKey]
    if not source then return {} end
    return BlingtronApp.BisList[source.id] or {}
end

BlingtronApp.Helpers = {
    normalizeKey        = normalizeKey,
    lookupByName        = lookupByName,
    getSpecForCandidate = getSpecForCandidate,
    getBisList          = getBisList,
}
