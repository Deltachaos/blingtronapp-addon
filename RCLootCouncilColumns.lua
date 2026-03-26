--[[
    BlingtronApp - RCLootCouncil column definitions
    Contains the abstract base class BlingtronApp.Column and all concrete column subclasses.

    To add a new column, create a subclass of BlingtronApp.Column:
        local MyCol = BlingtronApp.Column:Extend("blingtron_mycol", "Header", 50, "CENTER")
        function MyCol:GetValue(name, itemID, specID) return "hello" end
        function MyCol:GetColor(value) return 1, 1, 0 end
        function MyCol:GetTooltip(value) return "Title", "Body" end
]]

if not BlingtronApp or not BlingtronApp.RC then return end

local Player              = RCLootCouncil.Require "Data.Player"
local RC                  = BlingtronApp.RC
local addon               = RC.addon
local RCVotingFrame       = RC.RCVotingFrame
local lookupByName        = BlingtronApp.Helpers.lookupByName
local logo                = BlingtronApp.logoIconSmall

-- =============================================================================
-- ABSTRACT BASE CLASS: BlingtronApp.Column
-- =============================================================================

local Column = {}
Column.__index = Column
BlingtronApp.Column = Column

--- Create a new column subclass. The header is automatically prefixed with the logo.
--- @param colName  string  Unique internal name (e.g. "blingtron_bis")
--- @param header   string  Column header text shown in the table
--- @param width    number  Column width in pixels
--- @param insertAt number? Position to insert at (1-based). nil = append at end.
--- @param align    string? Text alignment: "LEFT" (default), "CENTER", "RIGHT"
--- @return table           New column class (override GetValue, GetColor, GetTooltip)
function Column:Extend(colName, header, width, insertAt, align)
    local cls = setmetatable({}, { __index = self })
    cls.__index = cls
    cls.colName  = colName
    cls.header   = logo .. " " .. header
    cls.width    = width
    cls.insertAt = insertAt
    cls.align    = align
    tinsert(BlingtronApp.RCColumns, cls)
    return cls
end

--- Override: return display text for a cell, or nil for "-".
--- @param name   string  Candidate name (e.g. "Player-Realm")
--- @param itemID number? Current loot item ID
--- @param specID number? Candidate's specialization ID
--- @return string?
function Column:GetValue(name, itemID, specID)
    return nil
end

--- Override: return r, g, b color for the cell text.
--- Only called when GetValue returned a non-nil value.
--- @param value string  The value returned by GetValue
--- @return number, number, number
function Column:GetColor(value)
    return 0.8, 0.8, 0.8
end

--- Override: return tooltip title and body text.
--- Only called when GetValue returned a non-nil value. Return nil to skip tooltip.
--- @param value string
--- @return string?, string?
function Column:GetTooltip(value)
    return nil, nil
end

--- Build the DoCellUpdate callback for this column instance.
function Column:MakeCellUpdate()
    local col = self
    return function(_, frame, data, cols, row, realrow, column, fShow, table, ...)
        local name = data[realrow].name
        frame.text:SetText("-")
        data[realrow].cols[column].value = "-"
        frame.text:SetTextColor(0.8, 0.8, 0.8)
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
        local value = col:GetValue(name, itemID, specID)
        if not value then return end

        frame.text:SetText(value)
        data[realrow].cols[column].value = value
        frame.text:SetTextColor(col:GetColor(value))

        local tipTitle, tipBody = col:GetTooltip(value)
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

local BisColumn = Column:Extend("blingtron_bis", "BiS", 50, 8)

function BisColumn:GetValue(name, itemID, specID)
    if not itemID or not specID then return nil end
    local bisList = BlingtronApp.Helpers.getBisList()
    local entry = bisList[specID]

    if not entry then return nil end
    return entry[itemID]
end

function BisColumn:GetTooltip(value)
    if value == "BiS" then
        return "BiS / Trinket tier", "Best in slot for this spec."
    end
    return "BiS / Trinket tier", "Trinket tier: " .. value
end

-- =============================================================================
-- COLUMN: Performance
-- =============================================================================

-- local PerfColumn = Column:Extend("blingtron_perf", "Perf", 40, 9, "CENTER")

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
