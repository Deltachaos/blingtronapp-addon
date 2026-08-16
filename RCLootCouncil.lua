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

function votingFrameModule:AttachColumnHeaderTooltips()
    local st = RCVotingFrame.frame and RCVotingFrame.frame.st
    if not st or not st.head or not st.head.cols then
        return
    end
    for _, btn in ipairs(st.head.cols) do
        if not btn.blingtronHeaderTipHooked then
            btn.blingtronHeaderTipHooked = true
            btn:HookScript("OnEnter", function(self)
                local stNow = RCVotingFrame.frame and RCVotingFrame.frame.st
                if not stNow or not stNow.head or not stNow.cols then
                    return
                end
                local colIndex
                for j, colBtn in ipairs(stNow.head.cols) do
                    if colBtn == self then
                        colIndex = j
                        break
                    end
                end
                local spec = colIndex and stNow.cols[colIndex]
                local key = spec and spec.headerTipKey
                if key and BlingtronApp.BonusRoll and BlingtronApp.BonusRoll.ShowColumnHeaderTooltip then
                    BlingtronApp.BonusRoll.ShowColumnHeaderTooltip(self, key)
                end
            end)
            btn:HookScript("OnLeave", function()
                addon:HideTooltip()
            end)
        end
    end
end

function votingFrameModule:OnInitialize()
    if not RCVotingFrame.scrollCols then
        return self:ScheduleTimer("OnInitialize", 0.5)
    end
    if not RCVotingFrame.AddColumn then
        return
    end

    self:RegisterMessage("RCSessionChangedPre", "OnSessionChanged")
    self:SecureHook(RCVotingFrame, "GetFrame", "AttachColumnHeaderTooltips")
    self:SecureHook(RCVotingFrame, "RefreshColumnLayout", "AttachColumnHeaderTooltips")

    for _, col in ipairs(BlingtronApp.RCColumns) do
        if not RCVotingFrame:GetColumn(col.colName) then
            RCVotingFrame:AddColumn({
                name         = col.header,
                DoCellUpdate = col:MakeCellUpdate(),
                colName      = col.colName,
                width        = col.width,
                align        = col.align,
                sortnext     = col.sortnext,
                headerTipKey = col.headerTipKey,
            }, col.target, col.position)
        end
    end

    self:AttachColumnHeaderTooltips()
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
