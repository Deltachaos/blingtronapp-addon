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

local function sourceSortTuple(key)
    local source = BlingtronApp.BisListSources[key]
    local order = 1000
    local label = key
    if source then
        if type(source.order) == "number" then
            order = source.order
        end
        if source.label then
            label = source.label
        end
    end
    return order, label
end

local function getSortedBisListSourceKeys()
    local keys = {}
    for k in pairs(BlingtronApp.BisListSources) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local oa, la = sourceSortTuple(a)
        local ob, lb = sourceSortTuple(b)
        if oa ~= ob then
            return oa < ob
        end
        return la < lb
    end)
    return keys
end

local function getBisListSourceKey()
    local dbKey = BlingtronAppDB.bisListSource
    if dbKey and bisListSourceKeyHasItems(dbKey) then
        return dbKey
    end

    local preferred = { "blingtron_overall" }
    for _, k in ipairs(preferred) do
        if bisListSourceKeyHasItems(k) then
            return k
        end
    end

    local keys = getSortedBisListSourceKeys()
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

local DUAL_SLOTS = {
    finger = true,
    trinket = true,
}

local computedTierCache = {}

local function normalizeSlot(slot)
    if slot == "trinkets" then
        return "trinket"
    end
    return slot
end

local function pctToTier(pct)
    local thresholds = BlingtronApp.BIS_TIER_THRESHOLDS
    if type(thresholds) ~= "table" or type(pct) ~= "number" then
        return nil
    end
    for _, row in ipairs(thresholds) do
        if type(row) == "table" and type(row.min) == "number" and pct >= row.min then
            return row.tier
        end
    end
    return nil
end

local function computeSpecTiers(specItems)
    local bySlot = {}
    local result = {}

    for itemID, info in pairs(specItems) do
        local numericID = tonumber(itemID)
        if type(info) == "string" then
            if numericID then
                result[numericID] = info
            end
        elseif type(info) == "table" and type(info.pct) == "number" then
            local slot = normalizeSlot(info.slot) or "unknown"
            local list = bySlot[slot]
            if not list then
                list = {}
                bySlot[slot] = list
            end
            list[#list + 1] = { id = numericID or itemID, pct = info.pct }
        end
    end

    for slot, items in pairs(bySlot) do
        table.sort(items, function(a, b)
            if a.pct ~= b.pct then
                return a.pct > b.pct
            end
            return tostring(a.id) < tostring(b.id)
        end)

        local bisCount = 0
        local lastBisPct = nil
        local minBis = DUAL_SLOTS[slot] and 2 or 1

        for _, item in ipairs(items) do
            local isBis = bisCount < minBis or (lastBisPct and item.pct == lastBisPct)
            if isBis then
                result[item.id] = "BiS"
                bisCount = bisCount + 1
                lastBisPct = item.pct
            else
                result[item.id] = pctToTier(item.pct)
            end
        end
    end

    return result
end

local function getComputedTiers(specItems)
    local cached = computedTierCache[specItems]
    if cached then
        return cached
    end
    cached = computeSpecTiers(specItems)
    computedTierCache[specItems] = cached
    return cached
end

local function getBisTier(specID, itemID)
    if not specID or not itemID then
        return nil
    end
    local bisList = getBisList()
    local specItems = bisList[specID] or bisList[tostring(specID)]
    if type(specItems) ~= "table" then
        return nil
    end

    local raw = specItems[itemID] or specItems[tostring(itemID)]
    if type(raw) == "string" then
        return raw
    end

    local computed = getComputedTiers(specItems)
    local tier = computed[itemID] or computed[tonumber(itemID)]
    if not tier then
        return nil
    end
    local pct = type(raw) == "table" and raw.pct or nil
    if type(pct) ~= "number" then
        pct = nil
    end
    return tier, pct
end

BlingtronApp.Helpers = {
    normalizeKey                 = normalizeKey,
    lookupByName                 = lookupByName,
    getSortedBisListSourceKeys   = getSortedBisListSourceKeys,
    getBisListSourceKey          = getBisListSourceKey,
    getBisList                   = getBisList,
    getBisTier                   = getBisTier,
}
