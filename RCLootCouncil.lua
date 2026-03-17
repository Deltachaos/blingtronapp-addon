--[[
    BlingtronApp - RCLootCouncil integration
    Adds custom columns to the RCLootCouncil voting frame.
    Column definitions live in RCLootCouncilColumns.lua.
]]

if not LibStub or not LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil", true) then
    return
end

local addon = LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil")
local RCVotingFrame = addon:GetModule("RCVotingFrame")

local RCBlingtronApp = addon:NewModule("RCBlingtronApp", "AceHook-3.0", "AceTimer-3.0")
local votingFrameModule = RCBlingtronApp:NewModule("BlingtronVotingFrame", "AceHook-3.0", "AceEvent-3.0")

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

    self:RegisterMessage("RCSessionChangedPre", "OnSessionChanged")

    self.sortnext = {}
    for _, v in ipairs(RCVotingFrame.scrollCols) do
        if v.sortnext then
            self.sortnext[v.colName] = RCVotingFrame.scrollCols[v.sortnext].colName
        end
    end

    for _, col in ipairs(BlingtronApp.RCColumns) do
        local colDef = {
            name         = col.header,
            DoCellUpdate = col:MakeCellUpdate(),
            colName      = col.colName,
            width        = col.width,
            align        = col.align,
        }
        if col.insertAt then
            tinsert(RCVotingFrame.scrollCols, col.insertAt, colDef)
        else
            tinsert(RCVotingFrame.scrollCols, colDef)
        end
    end

    self:UpdateSortNext()
end

function votingFrameModule:OnSessionChanged(msg, newSession)
    if msg == "RCSessionChangedPre" then
        self.session = newSession
    end
end

function votingFrameModule:UpdateSortNext()
    for index in ipairs(RCVotingFrame.scrollCols) do
        if RCVotingFrame.scrollCols[index].sortnext then
            local colName = RCVotingFrame.scrollCols[index].colName
            local nextName = self.sortnext[colName]
            if nextName and RCVotingFrame.GetColumnIndexFromName then
                local exists = RCVotingFrame:GetColumnIndexFromName(nextName)
                if exists then
                    RCVotingFrame.scrollCols[index].sortnext = exists
                end
            end
        end
    end

    local frame = RCVotingFrame:GetFrame()
    if frame and frame.st and frame.st.SetDisplayCols then
        frame.st:SetDisplayCols(RCVotingFrame.scrollCols)
        if frame.SetWidth and frame.st.frame then
            frame:SetWidth(frame.st.frame:GetWidth() + 20)
        end
    end
end

function RCBlingtronApp:OnInitialize()
    self:EnableModule("BlingtronVotingFrame")
end

addon:EnableModule("RCBlingtronApp")
