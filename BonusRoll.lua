-- BlingtronApp - Bonus-roll tracking and expected-value ranking

local SLOT_RANKS = { 100, 75, 50, 25 }
local DUAL_SLOTS = {
    finger = true,
    trinket = true,
}

local sourceList
local sourceByKey
local itemSources

local function chat(msg)
    print((BlingtronApp.logoIcon or "") .. " " .. msg)
end

local function normalizeSlot(slot)
    if slot == "trinkets" then
        return "trinket"
    end
    return slot
end

local function currentPlayerKey()
    local name, realm = UnitFullName("player")
    if not name or name == "" then
        return nil
    end
    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or ""
        realm = realm:gsub("%s+", "")
    end
    return BlingtronApp.Helpers.normalizeKey(name .. "-" .. realm)
end

local function currentSpecID()
    local specIndex
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        specIndex = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        specIndex = GetSpecialization()
    end
    if not specIndex or specIndex <= 0 then
        return nil
    end
    local specID
    if GetSpecializationInfo then
        specID = GetSpecializationInfo(specIndex)
    end
    if specID and specID > 0 then
        return specID
    end
    return nil
end

local function specDisplayName(specID)
    if not specID or not GetSpecializationInfoByID then
        return tostring(specID or "?")
    end
    local _, specName, _, _, _, _, className = GetSpecializationInfoByID(specID)
    if specName and className then
        return specName .. " " .. className
    end
    return specName or tostring(specID)
end

local function bisListLabel()
    local key = BlingtronApp.Helpers.getBisListSourceKey()
    if not key then
        return "none"
    end
    local source = BlingtronApp.BisListSources[key]
    if source and source.label then
        return source.label
    end
    return key
end

local function getCharDB()
    BlingtronAppDB = BlingtronAppDB or {}
    BlingtronAppDB.bonusRoll = BlingtronAppDB.bonusRoll or {}
    local playerKey = currentPlayerKey()
    if not playerKey then
        return nil
    end
    local charDB = BlingtronAppDB.bonusRoll[playerKey]
    if not charDB then
        charDB = { owned = {}, rolled = {} }
        BlingtronAppDB.bonusRoll[playerKey] = charDB
    end
    charDB.owned = charDB.owned or {}
    charDB.rolled = charDB.rolled or {}
    return charDB
end

local function isTracked(tbl, itemID)
    if not tbl then
        return nil
    end
    return tbl[itemID] or tbl[tostring(itemID)] or (tonumber(itemID) and tbl[tonumber(itemID)])
end

local function setTracked(tbl, itemID, value)
    itemID = tonumber(itemID) or itemID
    tbl[itemID] = value
    if type(itemID) == "number" then
        tbl[tostring(itemID)] = nil
    end
end

local function sortedItemIDs(tbl)
    local ids = {}
    local seen = {}
    for itemID in pairs(tbl or {}) do
        local numeric = tonumber(itemID)
        if numeric and not seen[numeric] then
            seen[numeric] = true
            ids[#ids + 1] = numeric
        end
    end
    table.sort(ids)
    return ids
end

local function sourceKey(kind, id)
    return kind .. ":" .. id
end

local function formatSourceToken(source)
    if source.kind == "mythic_plus" then
        return "mplus:" .. source.id
    end
    return "raid:" .. source.id
end

local function formatSourceLabel(source)
    if source.kind == "raid" then
        if source.raidName then
            return source.name .. "  (raid, " .. source.raidName .. ")"
        end
        return source.name .. "  (raid)"
    end
    return source.name .. "  (M+)"
end

local function parseSourceToken(text)
    if not text or text == "" then
        return nil
    end
    local kind, idText = text:match("^([%w_]+):(%d+)$")
    if not kind then
        return nil
    end
    kind = kind:lower()
    if kind == "mplus" or kind == "mythicplus" or kind == "mythic_plus" or kind == "dungeon" then
        kind = "mythic_plus"
    elseif kind == "raid" or kind == "boss" then
        kind = "raid"
    else
        return nil
    end
    return sourceKey(kind, tonumber(idText))
end

local function ensureIndex()
    if sourceList then
        return
    end
    sourceList = {}
    sourceByKey = {}
    itemSources = {}

    local pools = BlingtronApp.LootPools or {}
    for _, raid in ipairs(pools.raids or {}) do
        for _, encounter in ipairs(raid.encounters or {}) do
            local source = {
                key = sourceKey("raid", encounter.id),
                kind = "raid",
                id = encounter.id,
                name = encounter.name or ("encounter " .. tostring(encounter.id)),
                raidName = raid.name,
                items = encounter.items or {},
            }
            sourceList[#sourceList + 1] = source
            sourceByKey[source.key] = source
            for _, item in ipairs(source.items) do
                local list = itemSources[item.id]
                if not list then
                    list = {}
                    itemSources[item.id] = list
                end
                list[#list + 1] = source
            end
        end
    end

    for _, dungeon in ipairs(pools.dungeons or {}) do
        local source = {
            key = sourceKey("mythic_plus", dungeon.challengeModeId),
            kind = "mythic_plus",
            id = dungeon.challengeModeId,
            name = dungeon.name or ("dungeon " .. tostring(dungeon.challengeModeId)),
            items = dungeon.items or {},
        }
        sourceList[#sourceList + 1] = source
        sourceByKey[source.key] = source
        for _, item in ipairs(source.items) do
            local list = itemSources[item.id]
            if not list then
                list = {}
                itemSources[item.id] = list
            end
            list[#list + 1] = source
        end
    end
end

local function itemNameFromPools(itemID)
    ensureIndex()
    local sources = itemSources[itemID]
    if not sources then
        return nil
    end
    for _, source in ipairs(sources) do
        for _, item in ipairs(source.items) do
            if item.id == itemID and item.name then
                return item.name
            end
        end
    end
    return nil
end

local function itemDisplayName(itemID)
    local name
    if C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
    end
    if not name and GetItemInfo then
        name = GetItemInfo(itemID)
    end
    return name or itemNameFromPools(itemID) or ("item:" .. tostring(itemID))
end

local function itemLink(itemID)
    return string.format("|cffffffff|Hitem:%d::::::::|h[%s]|h|r", itemID, itemDisplayName(itemID))
end

local function parseItemAndRest(text)
    text = strtrim(text or "")
    if text == "" then
        return nil, ""
    end
    local itemID = tonumber(text:match("item:(%d+)"))
    if itemID then
        local rest = text:match("|h|r%s*(.-)%s*$")
        if rest == nil then
            local maybe = text:match("(%S+)$")
            if maybe and parseSourceToken(maybe) then
                rest = maybe
            else
                rest = ""
            end
        end
        return itemID, rest
    end
    local token, rest = text:match("^(%S+)%s*(.*)$")
    return tonumber(token), strtrim(rest or "")
end

local function specItemsFor(specID)
    local bisList = BlingtronApp.Helpers.getBisList()
    if type(bisList) ~= "table" then
        return nil
    end
    return bisList[specID] or bisList[tostring(specID)]
end

local function buildSlotWeights(specItems)
    local weights = {}
    if type(specItems) ~= "table" then
        return weights
    end

    local bySlot = {}
    for itemID, info in pairs(specItems) do
        local numericID = tonumber(itemID)
        if numericID and type(info) == "table" and type(info.pct) == "number" then
            local slot = normalizeSlot(info.slot) or "unknown"
            local list = bySlot[slot]
            if not list then
                list = {}
                bySlot[slot] = list
            end
            list[#list + 1] = { id = numericID, pct = info.pct }
        end
    end

    for slot, items in pairs(bySlot) do
        table.sort(items, function(a, b)
            if a.pct ~= b.pct then
                return a.pct > b.pct
            end
            return a.id < b.id
        end)

        local copies = DUAL_SLOTS[slot] and 2 or 1
        local rankIndex = 1
        local remainingCopies = copies
        for i = 1, #items do
            if not SLOT_RANKS[rankIndex] then
                break
            end
            weights[items[i].id] = SLOT_RANKS[rankIndex]
            remainingCopies = remainingCopies - 1
            if remainingCopies <= 0 then
                rankIndex = rankIndex + 1
                remainingCopies = copies
            end
        end
    end

    return weights
end

local function scoreSource(source, weights, charDB)
    local rolled = charDB.rolled[source.key] or {}
    local remaining = 0
    local valueSum = 0
    local wanted = {}

    for _, item in ipairs(source.items) do
        if not isTracked(rolled, item.id) then
            remaining = remaining + 1
            local weight = weights[item.id]
            if type(weight) == "number" and weight > 0 and not isTracked(charDB.owned, item.id) then
                valueSum = valueSum + weight
                wanted[#wanted + 1] = {
                    id = item.id,
                    name = item.name,
                    weight = weight,
                }
            end
        end
    end

    table.sort(wanted, function(a, b)
        if a.weight ~= b.weight then
            return a.weight > b.weight
        end
        return a.id < b.id
    end)

    local score = 0
    if remaining > 0 then
        score = valueSum / remaining
    end

    return {
        key = source.key,
        kind = source.kind,
        name = source.name,
        raidName = source.raidName,
        score = score,
        remaining = remaining,
        wantedRemaining = #wanted,
        wantedItems = wanted,
        source = source,
    }
end

local slotWeightCache = {}
local slotWeightCacheSource

local function GetSlotWeights(specID)
    specID = tonumber(specID) or specID
    if not specID then
        return {}
    end
    local sourceKey = BlingtronApp.Helpers.getBisListSourceKey()
    if slotWeightCacheSource ~= sourceKey then
        slotWeightCache = {}
        slotWeightCacheSource = sourceKey
    end
    local cached = slotWeightCache[specID]
    if cached then
        return cached
    end
    local weights = buildSlotWeights(specItemsFor(specID))
    slotWeightCache[specID] = weights
    return weights
end

local function emptyTracking()
    return { owned = {}, rolled = {} }
end

--- Resolve another player's have/rolled state.
--- Override later by setting BlingtronApp.BonusRoll.GetRemoteTracking = function(playerName) ... end
--- to pull addon-comm data. Until then this always returns empty tracking and never
--- uses the local /blingtron have|rolled SavedVariables (those are only known for self).
local function GetPlayerTracking(playerName)
    local api = BlingtronApp.BonusRoll
    local getter = api and api.GetRemoteTracking
    if type(getter) == "function" and playerName then
        local data = getter(playerName)
        if type(data) == "table" then
            return {
                owned = data.owned or {},
                rolled = data.rolled or {},
            }
        end
    end
    return emptyTracking()
end

--- Value of giving itemID as regular loot so they can avoid bonus-rolling an inefficient source.
--- Save = item weight / that source's bonus-roll EV. Low-EV (junk-heavy) sources score higher
--- because you would waste more rolls there to hit this item.
--- tracking.owned zeroes the item; tracking.rolled removes items from that source's pool.
--- @return table? { saving, weight, remaining, sourceScore, source }
local function GetSavingValue(specID, itemID, tracking)
    specID = tonumber(specID) or specID
    itemID = tonumber(itemID) or itemID
    if not specID or not itemID then
        return nil
    end
    tracking = tracking or emptyTracking()
    local owned = tracking.owned or {}
    local rolledBySource = tracking.rolled or {}
    if isTracked(owned, itemID) then
        return nil
    end

    ensureIndex()
    local sources = itemSources[itemID]
    if not sources or #sources == 0 then
        return nil
    end

    local weights = GetSlotWeights(specID)
    local weight = weights[itemID]
    if type(weight) ~= "number" or weight <= 0 then
        return nil
    end

    local charDB = { owned = owned, rolled = rolledBySource }
    local best
    for _, source in ipairs(sources) do
        local rolled = rolledBySource[source.key] or {}
        if not isTracked(rolled, itemID) then
            local scored = scoreSource(source, weights, charDB)
            if scored.score > 0 then
                local saving = weight / scored.score
                if not best or saving > best.saving then
                    best = {
                        saving = saving,
                        weight = weight,
                        remaining = scored.remaining,
                        sourceScore = scored.score,
                        source = source,
                    }
                end
            end
        end
    end
    return best
end

local SAVE_TIER_THRESHOLDS = {
    { min = 20, tier = "BiS" },
    { min = 14, tier = "S" },
    { min = 9,  tier = "A" },
    { min = 6,  tier = "B" },
    { min = 3,  tier = "C" },
    { min = 0,  tier = "D" },
}

local function SaveToTier(saving)
    if type(saving) ~= "number" then
        return nil
    end
    for _, row in ipairs(SAVE_TIER_THRESHOLDS) do
        if saving >= row.min then
            return row.tier
        end
    end
    return nil
end

local function FormatSaveText(saving)
    local tier = SaveToTier(saving)
    if not tier then
        return nil
    end
    return string.format("%s (%.1f)", tier, saving)
end

local function ScoreSources()
    ensureIndex()
    local specID = currentSpecID()
    if not specID then
        return nil, "Could not determine your specialization."
    end
    local charDB = getCharDB()
    if not charDB then
        return nil, "Could not determine the current character."
    end

    local weights = GetSlotWeights(specID)
    local results = {}
    for _, source in ipairs(sourceList) do
        results[#results + 1] = scoreSource(source, weights, charDB)
    end
    table.sort(results, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)
    return results, nil, specID
end

local function scoreToTier(score, maxScore)
    if type(score) ~= "number" or score <= 0 or type(maxScore) ~= "number" or maxScore <= 0 then
        return nil
    end
    if score >= maxScore - 0.0001 then
        return "BiS"
    end
    local pct = (score / maxScore) * 100
    local thresholds = BlingtronApp.BIS_TIER_THRESHOLDS
    if type(thresholds) == "table" then
        for _, row in ipairs(thresholds) do
            if type(row) == "table" and type(row.min) == "number" and pct >= row.min then
                return row.tier
            end
        end
    end
    return "D"
end

local function sourceDisplayName(source)
    if source.kind == "raid" then
        if source.raidName then
            return source.name, source.raidName
        end
        return source.name, "Raid"
    end
    return source.name, "Mythic+"
end

--- Rows for the bonus-roll window: every dungeon/boss, items, scores, and local have/rolled status.
local function GetBoardData()
    local results, err, specID = ScoreSources()
    if not results then
        return nil, err
    end
    local charDB = getCharDB() or emptyTracking()
    local weights = GetSlotWeights(specID)
    local maxScore = 0
    for _, scored in ipairs(results) do
        if scored.score > maxScore then
            maxScore = scored.score
        end
    end

    local rows = {}
    local maxItems = 0
    for _, scored in ipairs(results) do
        local rolled = charDB.rolled[scored.key] or {}
        local items = {}
        local bestSaving
        for _, item in ipairs(scored.source.items) do
            local weight = weights[item.id]
            if type(weight) ~= "number" then
                weight = 0
            end
            if weight > 0 then
                local isRolled = isTracked(rolled, item.id) and true or false
                local isOwned = isTracked(charDB.owned, item.id) and true or false
                local saving
                if not isOwned and not isRolled and scored.score > 0 then
                    saving = weight / scored.score
                    if not bestSaving or saving > bestSaving then
                        bestSaving = saving
                    end
                end
                local status = "open"
                if isRolled then
                    status = "rolled"
                elseif isOwned then
                    status = "loot"
                end
                items[#items + 1] = {
                    id = item.id,
                    name = item.name,
                    weight = weight,
                    saving = saving,
                    status = status,
                }
            end
        end
        table.sort(items, function(a, b)
            if a.weight ~= b.weight then
                return a.weight > b.weight
            end
            return a.id < b.id
        end)
        if #items > maxItems then
            maxItems = #items
        end

        local name, subName = sourceDisplayName(scored.source)
        local tier = scoreToTier(scored.score, maxScore)
        rows[#rows + 1] = {
            key = scored.key,
            kind = scored.kind,
            name = name,
            subName = subName,
            score = scored.score,
            tier = tier,
            saving = bestSaving,
            remaining = scored.remaining,
            wantedRemaining = scored.wantedRemaining,
            items = items,
        }
    end

    return {
        specID = specID,
        specName = specDisplayName(specID),
        bisLabel = bisListLabel(),
        maxScore = maxScore,
        maxItems = maxItems,
        rows = rows,
    }
end

local function PrintHelp()
    chat("Bonus-roll commands:")
    print("  /blingtron bonusroll (br)           open bonus-roll window")
    print("  /blingtron have <item>              mark owned from normal loot")
    print("  /blingtron unhave <item>            clear owned")
    print("  /blingtron rolled <item> [source]   mark bonus-rolled")
    print("  /blingtron unroll <item> [source]   undo a bonus-roll mark")
    print("  /blingtron bonusstatus (brstatus)   show tracked items")
    print("  /blingtron bonusclear               clear this character's tracking")
    print("  /blingtron help                     this list")
    print("  Item: numeric ID or shift-clicked link. Source: raid:197169 or mplus:588")
end

local function PrintRanking()
    ensureIndex()
    if #sourceList == 0 then
        chat("No loot pool data is loaded.")
        return
    end

    local results, err, specID = ScoreSources()
    if not results then
        chat(err)
        return
    end

    local shown = 0
    chat("Bonus-roll targets")
    for _, row in ipairs(results) do
        if row.score > 0 then
            shown = shown + 1
            print(string.format(
                "  |cffffd100%6.2f|r  %s  |cffaaaaaa%d wanted / %d remaining|r",
                row.score,
                formatSourceLabel(row.source),
                row.wantedRemaining,
                row.remaining
            ))
            for _, item in ipairs(row.wantedItems) do
                print(string.format("           |cff00ff00%3d|r  %s", item.weight, itemLink(item.id)))
            end
        end
    end

    if shown == 0 then
        print("  No remaining wanted items in any loot pool.")
    end
    print(string.format("  Spec: %s  |  BiS list: %s", specDisplayName(specID), bisListLabel()))
end

local function PrintStatus()
    local charDB = getCharDB()
    if not charDB then
        chat("Could not determine the current character.")
        return
    end
    ensureIndex()

    chat("Bonus-roll tracking")
    local ownedIDs = sortedItemIDs(charDB.owned)
    if #ownedIDs == 0 then
        print("  Owned (normal loot): none")
    else
        print("  Owned (normal loot):")
        for _, itemID in ipairs(ownedIDs) do
            print("    " .. itemLink(itemID))
        end
    end

    local anyRolled = false
    local keys = {}
    for key in pairs(charDB.rolled) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local ids = sortedItemIDs(charDB.rolled[key])
        if #ids > 0 then
            anyRolled = true
            local source = sourceByKey[key]
            local label = source and formatSourceLabel(source) or key
            print("  Bonus-rolled on " .. label .. ":")
            for _, itemID in ipairs(ids) do
                print("    " .. itemLink(itemID))
            end
        end
    end
    if not anyRolled then
        print("  Bonus-rolled: none")
    end
end

local function Have(itemID)
    local charDB = getCharDB()
    if not charDB then
        return false, "Could not determine the current character."
    end
    setTracked(charDB.owned, itemID, true)
    return true, "Marked " .. itemLink(itemID) .. " as owned from normal loot."
end

local function Unhave(itemID)
    local charDB = getCharDB()
    if not charDB then
        return false, "Could not determine the current character."
    end
    if not isTracked(charDB.owned, itemID) then
        return false, itemLink(itemID) .. " is not marked as owned."
    end
    setTracked(charDB.owned, itemID, nil)
    return true, "Cleared owned mark for " .. itemLink(itemID) .. "."
end

local function resolveRolledSource(itemID, sourceToken)
    ensureIndex()
    itemID = tonumber(itemID) or itemID
    if sourceToken and sourceToken ~= "" then
        local key = parseSourceToken(sourceToken)
        if not key then
            return nil, "Unknown source '" .. sourceToken .. "'. Use raid:197169 or mplus:588."
        end
        local source = sourceByKey[key]
        if not source then
            return nil, "Unknown source " .. sourceToken .. "."
        end
        local found = false
        for _, item in ipairs(source.items) do
            if tonumber(item.id) == itemID then
                found = true
                break
            end
        end
        if not found then
            return nil, itemLink(itemID) .. " is not in the loot pool for " .. formatSourceLabel(source) .. "."
        end
        return source
    end

    local sources = itemSources[itemID]
    if not sources or #sources == 0 then
        return nil, itemLink(itemID) .. " is not in any bundled loot pool. Pass a source like raid:197169."
    end
    if #sources == 1 then
        return sources[1]
    end

    local lines = { itemLink(itemID) .. " drops from multiple sources. Specify one:" }
    for _, source in ipairs(sources) do
        lines[#lines + 1] = "  " .. formatSourceToken(source) .. "  " .. formatSourceLabel(source)
    end
    return nil, table.concat(lines, "\n")
end

local function Rolled(itemID, sourceToken)
    local charDB = getCharDB()
    if not charDB then
        return false, "Could not determine the current character."
    end
    local source, err = resolveRolledSource(itemID, sourceToken)
    if not source then
        return false, err
    end
    local rolled = charDB.rolled[source.key]
    if not rolled then
        rolled = {}
        charDB.rolled[source.key] = rolled
    end
    setTracked(rolled, itemID, true)
    setTracked(charDB.owned, itemID, true)
    return true, "Marked " .. itemLink(itemID) .. " as bonus-rolled on " .. formatSourceLabel(source) .. "."
end

local function Unroll(itemID, sourceToken)
    local charDB = getCharDB()
    if not charDB then
        return false, "Could not determine the current character."
    end
    ensureIndex()

    local source
    if sourceToken and sourceToken ~= "" then
        local key = parseSourceToken(sourceToken)
        if not key then
            return false, "Unknown source '" .. sourceToken .. "'. Use raid:197169 or mplus:588."
        end
        source = sourceByKey[key]
        if not source then
            return false, "Unknown source " .. sourceToken .. "."
        end
    else
        local matches = {}
        for key, rolled in pairs(charDB.rolled) do
            if isTracked(rolled, itemID) then
                matches[#matches + 1] = sourceByKey[key] or {
                    key = key,
                    kind = key:match("^mythic_plus") and "mythic_plus" or "raid",
                    id = tonumber(key:match(":(%d+)$")) or 0,
                    name = key,
                    items = {},
                }
            end
        end
        if #matches == 0 then
            return false, itemLink(itemID) .. " is not marked as bonus-rolled."
        end
        if #matches > 1 then
            local lines = { itemLink(itemID) .. " is bonus-rolled on multiple sources. Specify one:" }
            for _, match in ipairs(matches) do
                lines[#lines + 1] = "  " .. formatSourceToken(match) .. "  " .. formatSourceLabel(match)
            end
            return false, table.concat(lines, "\n")
        end
        source = matches[1]
    end

    local rolled = charDB.rolled[source.key]
    if not rolled or not isTracked(rolled, itemID) then
        return false, itemLink(itemID) .. " is not marked as bonus-rolled on " .. formatSourceLabel(source) .. "."
    end
    setTracked(rolled, itemID, nil)
    if not next(rolled) then
        charDB.rolled[source.key] = nil
    end
    return true, "Cleared bonus-roll mark for " .. itemLink(itemID) .. " on " .. formatSourceLabel(source) .. "."
end

local function Clear()
    local playerKey = currentPlayerKey()
    if not playerKey then
        return false, "Could not determine the current character."
    end
    BlingtronAppDB = BlingtronAppDB or {}
    BlingtronAppDB.bonusRoll = BlingtronAppDB.bonusRoll or {}
    BlingtronAppDB.bonusRoll[playerKey] = { owned = {}, rolled = {} }
    return true, "Cleared bonus-roll tracking for this character."
end

local function printResult(ok, message)
    if not message then
        return
    end
    if message:find("\n", 1, true) then
        local first = true
        for line in string.gmatch(message, "[^\n]+") do
            if first then
                chat(line)
                first = false
            else
                print(line)
            end
        end
        return
    end
    chat(message)
end

local function requireItem(rest)
    local itemID, extra = parseItemAndRest(rest)
    if not itemID then
        return nil, extra, "Provide an item ID or shift-clicked item link."
    end
    return itemID, extra
end

local function HandleCommand(cmd, rest)
    if cmd == "bonusroll" or cmd == "br" then
        if BlingtronApp.ToggleBonusRollFrame then
            BlingtronApp:ToggleBonusRollFrame()
        else
            PrintRanking()
        end
        return true
    elseif cmd == "have" then
        local itemID, _, err = requireItem(rest)
        if not itemID then
            chat(err)
            return true
        end
        printResult(Have(itemID))
        return true
    elseif cmd == "unhave" then
        local itemID, _, err = requireItem(rest)
        if not itemID then
            chat(err)
            return true
        end
        printResult(Unhave(itemID))
        return true
    elseif cmd == "rolled" then
        local itemID, extra, err = requireItem(rest)
        if not itemID then
            chat(err)
            return true
        end
        printResult(Rolled(itemID, extra))
        return true
    elseif cmd == "unroll" then
        local itemID, extra, err = requireItem(rest)
        if not itemID then
            chat(err)
            return true
        end
        printResult(Unroll(itemID, extra))
        return true
    elseif cmd == "bonusstatus" or cmd == "brstatus" then
        PrintStatus()
        return true
    elseif cmd == "bonusclear" then
        printResult(Clear())
        return true
    elseif cmd == "help" then
        PrintHelp()
        return true
    end
    return false
end

-- Column-header explanations (RCLootCouncil + bonus-roll window).
local COLUMN_HEADER_TIPS = {
    tier = {
        "Tier",
        "This player's rank for the current item on the selected BiS list (or a custom player/spec list).",
        "BiS is best in that slot. S, A, B, C, and D are lower ranks. A percentage is the list's recommendation when available.",
    },
    brTier = {
        "BR Tier",
        "How good this boss or dungeon is as a bonus-roll target for your spec.",
        "Based on the expected value of remaining wanted loot. The best source is BiS; others are S–D relative to it. Higher means spend bonus rolls here.",
    },
    brSave = {
        "BR Save",
        "Value of giving this as regular loot so bonus rolls can be spent on better targets.",
        "Higher means this source is a worse bonus-roll farm (more junk), so handing the item out avoids wasting rolls there. Shown as a tier plus score: item weight divided by that source's bonus-roll EV.",
    },
}

--- Show a wrapped header tooltip. extraLines are appended after a blank line (e.g. sort hints).
local function ShowColumnHeaderTooltip(owner, key, extraLines)
    local lines = COLUMN_HEADER_TIPS[key]
    if not owner or not lines then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(lines[1], 1, 0.82, 0)
    for i = 2, #lines do
        GameTooltip:AddLine(lines[i], 1, 1, 1, true)
    end
    if extraLines then
        GameTooltip:AddLine(" ")
        for i = 1, #extraLines do
            GameTooltip:AddLine(extraLines[i], 0.8, 0.8, 0.8, true)
        end
    end
    GameTooltip:Show()
end

BlingtronApp.BonusRoll = {
    HandleCommand              = HandleCommand,
    PrintHelp                  = PrintHelp,
    PrintRanking               = PrintRanking,
    PrintStatus                = PrintStatus,
    Have                       = Have,
    Unhave                     = Unhave,
    Rolled                     = Rolled,
    Unroll                     = Unroll,
    Clear                      = Clear,
    ScoreSources               = ScoreSources,
    GetBoardData               = GetBoardData,
    GetSlotWeights             = GetSlotWeights,
    GetPlayerTracking          = GetPlayerTracking,
    GetSavingValue             = GetSavingValue,
    SaveToTier                 = SaveToTier,
    FormatSaveText             = FormatSaveText,
    COLUMN_HEADER_TIPS         = COLUMN_HEADER_TIPS,
    ShowColumnHeaderTooltip    = ShowColumnHeaderTooltip,
    --- Assign function(playerName) -> { owned, rolled } | nil when addon comms exist.
    GetRemoteTracking          = nil,
}
