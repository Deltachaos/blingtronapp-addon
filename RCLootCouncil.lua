--[[
    BlingtronApp - RCLootCouncil integration
    Registers custom columns on the RCLootCouncil voting frame via RCVotingFrame:AddColumn.
    Column definitions live in RCLootCouncilColumns.lua.
]]

if not LibStub or not LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil", true) then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
local RCVotingFrame = addon:GetModule("RCVotingFrame")

local RCBlingtronApp = addon:NewModule("RCBlingtronApp", "AceHook-3.0", "AceTimer-3.0")
local votingFrameModule = RCBlingtronApp:NewModule("BlingtronVotingFrame", "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- =============================================================================
-- SHARED STATE (consumed by RCLootCouncilColumns.lua)
-- =============================================================================

BlingtronApp.RC = {
    addon               = addon,
    RCVotingFrame       = RCVotingFrame,
}

-- =============================================================================
-- VOTING FRAME MODULE
-- =============================================================================

function votingFrameModule:OnInitialize()
    if not RCVotingFrame.scrollCols then
        return self:ScheduleTimer("OnInitialize", 0.5)
    end
    if not RCVotingFrame.AddColumn then
        return
    end

    self:RegisterMessage("RCSessionChangedPre", "OnSessionChanged")

    for _, col in ipairs(BlingtronApp.RCColumns) do
        if not RCVotingFrame:GetColumn(col.colName) then
            RCVotingFrame:AddColumn({
                name         = col.header,
                DoCellUpdate = col:MakeCellUpdate(),
                colName      = col.colName,
                width        = col.width,
                align        = col.align,
                sortnext     = col.sortnext,
            }, col.target, col.position)
        end
    end
end

function votingFrameModule:OnSessionChanged(msg, newSession)
    if msg == "RCSessionChangedPre" then
        self.session = newSession
    end
end

function RCBlingtronApp:OnInitialize()
    self:EnableModule("BlingtronVotingFrame")
end

addon:EnableModule("RCBlingtronApp")
