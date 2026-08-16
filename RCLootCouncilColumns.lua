--[[
    BlingtronApp - RCLootCouncil column definitions
    Contains the abstract base class BlingtronApp.Column and all concrete column subclasses.

    To add a new column, create a subclass of BlingtronApp.Column:
        local MyCol = BlingtronApp.Column:Extend("blingtron_mycol", "Header", 50, "gear1", "before", "CENTER")
        function MyCol:GetValue(name, itemID, specID) return "hello" end
        function MyCol:GetColor(value) return 1, 1, 0 end
        function MyCol:GetTooltip(value) return "Title", "Body" end
]]

-- BlingtronApp.RC is always initialized as {} in Constants.lua; only load
-- columns when RCLootCouncil.lua successfully wired up the integration.
if not BlingtronApp or not BlingtronApp.RC or not BlingtronApp.RC.addon then return end

local RC                  = BlingtronApp.RC
local addon               = RC.addon
local Player              = addon.Require "Data.Player"
local RCVotingFrame       = RC.RCVotingFrame
local lookupByName        = BlingtronApp.Helpers.lookupByName
local normalizeKey        = BlingtronApp.Helpers.normalizeKey
local logo                = BlingtronApp.logoIconSmall

-- WoW item-quality colors: gold, orange, purple, blue, green, white, gray
local QUALITY_FALLBACK = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
}

local TIER_QUALITY = {
    BiS = 6,
    S   = 5,
    A   = 4,
    B   = 3,
    C   = 2,
    D   = 1,
}

local SAVE_QUALITY_THRESHOLDS = {
    { min = 20, quality = 6 },
    { min = 14, quality = 5 },
    { min = 9,  quality = 4 },
    { min = 6,  quality = 3 },
    { min = 3,  quality = 2 },
    { min = 0,  quality = 1 },
}

local function qualityColor(quality)
    quality = quality or 0
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r then
            return r, g, b
        end
    end
    local colors = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if colors then
        return colors.r, colors.g, colors.b
    end
    local fb = QUALITY_FALLBACK[quality] or QUALITY_FALLBACK[0]
    return fb[1], fb[2], fb[3]
end

local function parseTierName(value)
    if type(value) ~= "string" then
        return nil
    end
    if value:find("^BiS") or value:lower() == "bis" then
        return "BiS"
    end
    return value:match("^([SABCD])$")
        or value:match("^([SABCD])%s")
        or value:match("^([SABCD])%(")
end

local function saveQuality(score)
    if type(score) ~= "number" then
        return 0
    end
    for _, row in ipairs(SAVE_QUALITY_THRESHOLDS) do
        if score >= row.min then
            return row.quality
        end
    end
    return 0
end

-- =============================================================================
-- ABSTRACT BASE CLASS: BlingtronApp.Column
-- =============================================================================

local Column = {}
Column.__index = Column
BlingtronApp.Column = Column

--- Create a new column subclass. The header is automatically prefixed with the logo.
--- Placement is passed through to RCVotingFrame:AddColumn(spec, target, position).
--- @param colName  string  Unique internal name (e.g. "blingtron_bis")
--- @param header   string  Column header text shown in the table
--- @param width    number  Column width in pixels
--- @param target   string|number? Column name or index to place relative to. nil = append.
--- @param position "before"|"after"? Relative placement when target is a column name.
--- @param align    string? Text alignment: "LEFT" (default), "CENTER", "RIGHT"
--- @return table           New column class (override GetValue, GetColor, GetTooltip)
function Column:Extend(colName, header, width, target, position, align)
    local cls = setmetatable({}, { __index = self })
    cls.__index = cls
    cls.colName  = colName
    cls.header   = logo .. " " .. header
    cls.width    = width
    cls.target   = target
    cls.position = position
    cls.align    = align
    tinsert(BlingtronApp.RCColumns, cls)
    return cls
end

--- Override: return display text for a cell, or nil for "-".
--- Optional second return is the sort value (defaults to the display text).
--- @param name   string  Candidate name (e.g. "Player-Realm")
--- @param itemID number? Current loot item ID
--- @param specID number? Candidate's specialization ID
--- @return string?, any?
function Column:GetValue(name, itemID, specID)
    return nil
end

--- Override: return r, g, b color for the cell text.
--- Only called when GetValue returned a non-nil value.
--- @param value string  The value returned by GetValue
--- @return number, number, number
function Column:GetColor(value)
    return qualityColor(0)
end

--- Override: return tooltip title and body text.
--- Only called when GetValue returned a non-nil value. Return nil to skip tooltip.
--- @param value string
--- @param name string?
--- @param itemID number?
--- @param specID number?
--- @return string?, string?
function Column:GetTooltip(value, name, itemID, specID)
    return nil, nil
end

--- Build the DoCellUpdate callback for this column instance.
function Column:MakeCellUpdate()
    local col = self
    return function(_, frame, data, cols, row, realrow, column, fShow, table, ...)
        local name = data[realrow].name
        frame.text:SetText("-")
        data[realrow].cols[column].value = "-"
        frame.text:SetTextColor(qualityColor(0))
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)

        if not name then return end

        local lootTable = addon:GetLootTable()
        local session = RCVotingFrame:GetCurrentSession()
        local sessionEntry = lootTable and lootTable[session]
        local itemID = sessionEntry and sessionEntry.itemID
        local player = Player:Get(name)
        local specID = player and player.specID
        if specID and specID <= 0 then
            specID = nil
        end
        local value, sortValue = col:GetValue(name, itemID, specID)
        if not value then return end

        frame.text:SetText(value)
        data[realrow].cols[column].value = sortValue ~= nil and sortValue or value
        frame.text:SetTextColor(col:GetColor(value))

        local tipTitle, tipBody = col:GetTooltip(value, name, itemID, specID)
        if tipTitle then
            frame:SetScript("OnEnter", function()
                addon:CreateTooltip(tipTitle, tipBody)
            end)
            frame:SetScript("OnLeave", function()
                addon:HideTooltip()
            end)
        end
    end
end

-- =============================================================================
-- COLUMN: BiS
-- =============================================================================

local function itemMapGet(map, itemID)
    if not map or not itemID then return nil end
    return map[itemID] or map[tostring(itemID)]
end

local function playerHasAnyCustomPlayerBis(playerEntry)
    if not playerEntry or type(playerEntry) ~= "table" then return false end
    if playerEntry.all and next(playerEntry.all) ~= nil then return true end
    if playerEntry.specs then
        for _, specMap in pairs(playerEntry.specs) do
            if type(specMap) == "table" and next(specMap) ~= nil then
                return true
            end
        end
    end
    return false
end

local function getCustomSpecBisMap(specID)
    if not specID or not BlingtronAppDB or not BlingtronAppDB.customSpecBis then return nil end
    local db = BlingtronAppDB.customSpecBis
    local t = db[specID] or db[tostring(specID)]
    if type(t) ~= "table" or next(t) == nil then return nil end
    return t
end

local function formatBisColumnText(tier, pct)
    if not tier then
        return nil
    end
    if type(pct) == "number" then
        return string.format("%s (%d%%)", tier, math.floor(pct + 0.5))
    end
    return tier
end

local BisColumn = Column:Extend("blingtron_bis", "Tier", 80, "gear1", "before")

--- Resolution order (mutually exclusive tiers):
--- 1) Custom player BIS — if this player has any CSV rows, ONLY that list applies (no spec/source lists).
--- 2) Custom spec BIS — if this spec has any saved rows, ONLY that list applies (not the selected source).
--- 3) Selected BiS list source (e.g. Wowhead). Wishlist rows always include recommendation %.
function BisColumn:GetValue(name, itemID, specID)
    if not itemID then return nil end

    local customPlayerBis = BlingtronAppDB and BlingtronAppDB.customPlayerBis
    local playerEntry = nil
    if customPlayerBis and name then
        local playerKey = normalizeKey(name)
        playerEntry = playerKey and customPlayerBis[playerKey]
    end

    if playerHasAnyCustomPlayerBis(playerEntry) then
        if specID and playerEntry.specs then
            local specMap = playerEntry.specs[specID] or playerEntry.specs[tostring(specID)]
            local v = itemMapGet(specMap, itemID)
            if v then return v end
        end
        local v = itemMapGet(playerEntry.all, itemID)
        if v then return v end
        return nil
    end

    if specID then
        local customSpecMap = getCustomSpecBisMap(specID)
        if customSpecMap then
            local v = itemMapGet(customSpecMap, itemID)
            if v then return v end
            return nil
        end
    end

    if not specID then return nil end

    local tier, pct = BlingtronApp.Helpers.getBisTier(specID, itemID)
    return formatBisColumnText(tier, pct)
end

function BisColumn:GetColor(value)
    local tier = parseTierName(value)
    return qualityColor(TIER_QUALITY[tier] or 0)
end

function BisColumn:GetTooltip(value)
    if type(value) == "string" and value:find("^BiS") then
        return "BiS / Trinket tier", "Best in slot for this spec."
    end
    -- Tier letters (A/B/…) or custom CSV note text
    return "BiS / Trinket tier", value
end

-- =============================================================================
-- COLUMN: Bonus-roll save
-- =============================================================================

local SavingColumn = Column:Extend("blingtron_brsave", "BR Save", 58, "blingtron_bis", "after", "CENTER")

function SavingColumn:GetValue(name, itemID, specID)
    if not itemID or not specID or not BlingtronApp.BonusRoll then
        return nil
    end
    local tracking = BlingtronApp.BonusRoll.GetPlayerTracking(name)
    local result = BlingtronApp.BonusRoll.GetSavingValue(specID, itemID, tracking)
    if not result then
        return nil
    end
    return string.format("%.1f", result.saving), result.saving
end

function SavingColumn:GetColor(value)
    return qualityColor(saveQuality(tonumber(value)))
end

function SavingColumn:GetTooltip(value, name, itemID, specID)
    local result
    if itemID and specID and BlingtronApp.BonusRoll then
        local tracking = BlingtronApp.BonusRoll.GetPlayerTracking(name)
        result = BlingtronApp.BonusRoll.GetSavingValue(specID, itemID, tracking)
    end
    if not result then
        return "Bonus-roll save", "Value of giving this as regular loot so they can spend bonus rolls on higher-value targets."
    end
    local source = result.source
    local where = source.name
    if source.raidName then
        where = source.name .. " (" .. source.raidName .. ")"
    elseif source.kind == "mythic_plus" then
        where = source.name .. " (M+)"
    end
    local body = string.format(
        "Weight %d on %s (bonus-roll EV %.1f, %d remaining). Save %.1f = weight / source EV. Higher means this source is a worse bonus-roll target, so getting the item as regular loot avoids wasting rolls on junk.",
        result.weight,
        where,
        result.sourceScore,
        result.remaining,
        result.saving
    )
    return "Bonus-roll save", body
end

-- =============================================================================
-- COLUMN: Performance
-- =============================================================================

-- local PerfColumn = Column:Extend("blingtron_perf", "Perf", 40, "blingtron_bis", "after", "CENTER")

-- function PerfColumn:GetValue(name)
--     return lookupByName(BlingtronApp.Performance, name)
-- end

-- function PerfColumn:GetColor(value)
--     if value == "A" then return 0.0, 1.0, 0.3 end
--     if value == "B" then return 0.3, 0.9, 0.2 end
--     if value == "C" then return 1.0, 1.0, 0.0 end
--     if value == "D" then return 1.0, 0.6, 0.0 end
--     if value == "F" then return 1.0, 0.2, 0.2 end
--     return 0.8, 0.8, 0.8
-- end

-- function PerfColumn:GetTooltip(value)
--     return "Performance", "Raider performance rating: " .. value
-- end
