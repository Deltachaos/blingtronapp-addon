-- BlingtronApp - Shared helper functions

local function normalizeKey(name)
    if not name or name == "" then return nil end
    return name:gsub("%s+", ""):lower()
end

local function lookupByName(tbl, name)
    if not tbl or not name then return nil end
    return tbl[name] or tbl[normalizeKey(name)]
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
    getBisListSourceKey    = getBisListSourceKey,
    getBisList             = getBisList,
}
