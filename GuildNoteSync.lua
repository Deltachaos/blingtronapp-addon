-- BlingtronApp - Guild Note Sync

local mainFrame = nil
local csvTextArea = nil
local statusText = nil
local officerNoteCheckbox = nil
local publicNoteCheckbox = nil
local clearMissingCheckbox = nil
local diffFrame = nil
local diffScrollFrame = nil
local diffContent = nil
local diffRecheckBtn = nil
local diffHeaderRow = nil
local diffHeaderOfficer = nil
local diffHeaderPublic = nil
local diffRows = {}
local copyDialogFrame = nil
local copyDialogEditBox = nil
local copyDialogTitle = nil

-- =============================================================================
-- HELPERS
-- =============================================================================

local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function SetGuildOfficerNote(memberIndex, note)
    if GuildRosterSetOfficerNote then
        GuildRosterSetOfficerNote(memberIndex, note)
        return true
    end
    return false
end

local function SetGuildPublicNote(memberIndex, note)
    if GuildRosterSetPublicNote then
        GuildRosterSetPublicNote(memberIndex, note)
        return true
    end
    return false
end

local function RequestGuildRoster()
    if GuildRoster then
        GuildRoster()
        return true
    end
    return false
end

-- =============================================================================
-- CSV PARSING
-- =============================================================================

local function ParseCSV(csvText)
    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local entries = {}
    for i, line in ipairs(lines) do
        if not line:match("^%s*$") then
            local firstComma = line:find(",")
            if firstComma then
                local fullname = trim(line:sub(1, firstComma - 1))
                local note = trim(line:sub(firstComma + 1))
                if string.utf8len(note) > 31 then
                    note = string.utf8sub(note, 1, 31)
                end
                if fullname and note and fullname ~= "" then
                    table.insert(entries, { fullname = fullname, note = note })
                end
            end
        end
    end

    return entries
end

-- =============================================================================
-- DIFF LOGIC
-- =============================================================================

local function GetNoteDifferences(csvEntries, officerChecked, publicChecked, clearMissing)
    local csvLookup = {}
    for _, entry in ipairs(csvEntries) do
        csvLookup[entry.fullname:lower()] = entry.note
    end

    local diffs = {}
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote = GetGuildRosterInfo(i)
        if name then
            local nameLower = name:lower()
            local csvNote = csvLookup[nameLower]
            local desiredOfficer = (officerChecked and csvNote ~= nil) and csvNote or (clearMissing and officerChecked and not csvNote) and "" or nil
            local desiredPublic  = (publicChecked  and csvNote ~= nil) and csvNote or (clearMissing and publicChecked  and not csvNote) and "" or nil
            local currentOfficer = officernote or ""
            local currentPublic  = note or ""

            local officerDiff = (desiredOfficer ~= nil and desiredOfficer ~= currentOfficer)
            local publicDiff  = (desiredPublic  ~= nil and desiredPublic  ~= currentPublic)
            if officerDiff or publicDiff then
                table.insert(diffs, {
                    fullname       = name,
                    officerDesired = desiredOfficer or currentOfficer,
                    officerCurrent = currentOfficer,
                    publicDesired  = desiredPublic  or currentPublic,
                    publicCurrent  = currentPublic,
                    officerChecked = officerChecked,
                    publicChecked  = publicChecked,
                })
            end
        end
    end

    table.sort(diffs, function(a, b) return a.fullname:lower() < b.fullname:lower() end)
    return diffs
end

-- =============================================================================
-- COPY DIALOG
-- =============================================================================

-- Do not touch CommunitiesFrame / memberInfo / OpenGuildMemberDetailFrame /
-- Button:Click() from addon code. Reading Blizzard's roster memberInfo taints
-- the GUID used by SET_GUILD_COMMUNITIY_NOTE, so Accept → SetNote() is blocked
-- (ADDON_ACTION_FORBIDDEN) even when the player clicks Accept themselves.
-- The player must open the guild roster and click the member with a real mouse
-- click, then paste into Blizzard's note box.

local function ShowCopyDialog(titleSuffix, textToCopy)
    if not copyDialogFrame then
        copyDialogFrame = CreateFrame("Frame", "BlingtronAppCopyDialog", UIParent, "BasicFrameTemplateWithInset")
        copyDialogFrame:SetSize(480, 135)
        copyDialogFrame:SetPoint("CENTER")
        copyDialogFrame:SetMovable(true)
        copyDialogFrame:EnableMouse(true)
        copyDialogFrame:RegisterForDrag("LeftButton")
        copyDialogFrame:SetScript("OnDragStart", copyDialogFrame.StartMoving)
        copyDialogFrame:SetScript("OnDragStop", copyDialogFrame.StopMovingOrSizing)
        copyDialogFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        copyDialogFrame:Hide()

        copyDialogTitle = copyDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyDialogTitle:SetPoint("TOP", copyDialogFrame, "TOP", 0, -5)
        copyDialogTitle:SetText("Copy note")

        copyDialogEditBox = CreateFrame("EditBox", nil, copyDialogFrame)
        copyDialogEditBox:SetMultiLine(true)
        copyDialogEditBox:SetFontObject("GameFontHighlight")
        copyDialogEditBox:SetAutoFocus(true)
        copyDialogEditBox:SetWidth(440)
        copyDialogEditBox:SetHeight(20)
        copyDialogEditBox:SetTextInsets(8, 8, 8, 8)
        copyDialogEditBox:SetPoint("TOP", copyDialogFrame, "TOP", 0, -28)
        copyDialogEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            copyDialogFrame:Hide()
        end)
        copyDialogEditBox:SetScript("OnKeyDown", function(self, key)
            if key == "C" and IsControlKeyDown() then
                copyDialogFrame:Hide()
            end
        end)
        local bg = copyDialogEditBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(copyDialogEditBox)
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

        local hintText = copyDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hintText:SetPoint("BOTTOM", copyDialogFrame, "BOTTOM", 0, 42)
        hintText:SetWidth(440)
        hintText:SetWordWrap(true)
        hintText:SetText("CTRL-C copies & closes. Open the guild roster yourself, click the member, then paste into Blizzard's note box.")
        hintText:SetTextColor(0.7, 0.7, 0.7)

        local closeBtn = CreateFrame("Button", nil, copyDialogFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", copyDialogFrame, "BOTTOM", 0, 12)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() copyDialogFrame:Hide() end)
    end
    copyDialogTitle:SetText("Copy note" .. (titleSuffix and (" - " .. titleSuffix) or ""))
    copyDialogEditBox:SetText(textToCopy or "")
    copyDialogEditBox:SetFocus()
    copyDialogEditBox:HighlightText(0, #(textToCopy or ""))
    copyDialogFrame:Show()
end

-- =============================================================================
-- DIFF LIST UI
-- =============================================================================

local COL_NAME_LEFT  = 4
local COL_NAME_W     = 110
local COL_OFFICER_W  = 262
local COL_PUBLIC_W   = 262
local ROW_MIN_H      = 36

local UpdateDiffList

local function RefreshDiffList()
    if not diffContent or not diffHeaderRow then return end
    local csvText = csvTextArea and csvTextArea:GetText() or ""
    local entries = ParseCSV(csvText)
    local officerChecked = officerNoteCheckbox and officerNoteCheckbox:GetChecked()
    local publicChecked  = publicNoteCheckbox  and publicNoteCheckbox:GetChecked()
    local clearMissing   = clearMissingCheckbox and clearMissingCheckbox:GetChecked()
    UpdateDiffList(GetNoteDifferences(entries, officerChecked, publicChecked, clearMissing))
end

local function CreateDiffWindow()
    if diffFrame then return end

    diffFrame = CreateFrame("Frame", "BlingtronAppDiffFrame", UIParent, "BasicFrameTemplateWithInset")
    diffFrame:SetSize(780, 520)
    diffFrame:SetPoint("CENTER")
    diffFrame:SetMovable(true)
    diffFrame:EnableMouse(true)
    diffFrame:RegisterForDrag("LeftButton")
    diffFrame:SetScript("OnDragStart", diffFrame.StartMoving)
    diffFrame:SetScript("OnDragStop", diffFrame.StopMovingOrSizing)
    diffFrame:SetFrameStrata("DIALOG")
    diffFrame:Hide()

    diffFrame:SetScript("OnEvent", function(_, ev)
        if ev == "GUILD_ROSTER_UPDATE" then RefreshDiffList() end
    end)
    diffFrame:SetScript("OnShow", function() diffFrame:RegisterEvent("GUILD_ROSTER_UPDATE") end)
    diffFrame:SetScript("OnHide", function() diffFrame:UnregisterEvent("GUILD_ROSTER_UPDATE") end)

    local title = diffFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", diffFrame, "TOP", 0, -5)
    title:SetText("Note differences (red = current, green = desired)")

    diffScrollFrame = CreateFrame("ScrollFrame", "BlingtronAppDiffScrollFrame", diffFrame, "UIPanelScrollFrameTemplate")
    diffScrollFrame:SetPoint("TOPLEFT", diffFrame, "TOPLEFT", 15, -35)
    diffScrollFrame:SetPoint("BOTTOMRIGHT", diffFrame, "BOTTOMRIGHT", -30, 50)

    diffContent = CreateFrame("Frame", "BlingtronAppDiffContent", diffScrollFrame)
    diffContent:SetSize(diffScrollFrame:GetWidth(), 1)
    diffScrollFrame:SetScrollChild(diffContent)

    diffHeaderRow = CreateFrame("Frame", nil, diffContent)
    diffHeaderRow:SetPoint("TOPLEFT", diffContent, "TOPLEFT", 0, 0)
    diffHeaderRow:SetHeight(22)
    diffHeaderRow:SetWidth(diffContent:GetWidth() or 400)
    local hName = diffHeaderRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hName:SetPoint("LEFT", diffHeaderRow, "LEFT", 4, 0)
    hName:SetText("|cffaaaaaaName|r")
    diffHeaderOfficer = diffHeaderRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffHeaderOfficer:SetPoint("LEFT", diffHeaderRow, "LEFT", 120, 0)
    diffHeaderOfficer:SetText("|cffaaaaaaOfficer|r")
    diffHeaderPublic = diffHeaderRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    diffHeaderPublic:SetPoint("LEFT", diffHeaderRow, "LEFT", 390, 0)
    diffHeaderPublic:SetText("|cffaaaaaaPublic|r")

    diffRecheckBtn = CreateFrame("Button", "BlingtronAppDiffRecheck", diffFrame, "UIPanelButtonTemplate")
    diffRecheckBtn:SetSize(100, 28)
    diffRecheckBtn:SetPoint("BOTTOMRIGHT", diffFrame, "BOTTOMRIGHT", -20, 15)
    diffRecheckBtn:SetText("Recheck")
    diffRecheckBtn:SetScript("OnClick", function() RequestGuildRoster() end)
end

UpdateDiffList = function(diffs)
    if not diffContent or not diffHeaderRow then return end
    local officerChecked = officerNoteCheckbox and officerNoteCheckbox:GetChecked()
    local publicChecked  = publicNoteCheckbox  and publicNoteCheckbox:GetChecked()

    if diffHeaderOfficer then
        if officerChecked then diffHeaderOfficer:Show() else diffHeaderOfficer:Hide() end
    end
    if diffHeaderPublic then
        if publicChecked then diffHeaderPublic:Show() else diffHeaderPublic:Hide() end
    end

    local contentW = diffScrollFrame:GetWidth() - 25
    if contentW <= 0 then contentW = 720 end
    diffHeaderRow:SetWidth(contentW)
    diffContent:SetWidth(contentW)

    local noteColLeft = 120
    local noteColW    = contentW - noteColLeft - 60
    local officerLeft = noteColLeft
    local publicLeft  = (publicChecked and officerChecked) and 390 or noteColLeft
    local officerW    = (officerChecked and publicChecked) and COL_OFFICER_W or noteColW
    local publicW     = (officerChecked and publicChecked) and COL_PUBLIC_W  or noteColW

    for _, row in ipairs(diffRows) do row:SetParent(nil) row:Hide() end
    wipe(diffRows)

    local y = -22

    if #diffs == 0 then
        local emptyRow = CreateFrame("Frame", nil, diffContent)
        emptyRow:SetPoint("TOPLEFT", diffContent, "TOPLEFT", 0, y)
        emptyRow:SetSize(contentW, 22)
        local lbl = emptyRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", emptyRow, "LEFT", COL_NAME_LEFT, 0)
        lbl:SetText("No differences – all notes match.")
        table.insert(diffRows, emptyRow)
        y = y - 22
    else
        for _, d in ipairs(diffs) do
            local row = CreateFrame("Frame", nil, diffContent)
            row:SetPoint("TOPLEFT", diffContent, "TOPLEFT", 0, y)
            row:SetSize(contentW, ROW_MIN_H)

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", COL_NAME_LEFT, 0)
            nameFS:SetWidth(COL_NAME_W)
            nameFS:SetWordWrap(false)
            nameFS:SetText(d.fullname)

            local rowH = ROW_MIN_H

            if officerChecked then
                local curFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                curFS:SetPoint("TOPLEFT", row, "TOPLEFT", officerLeft, 0)
                curFS:SetWidth(officerW) curFS:SetWordWrap(true) curFS:SetNonSpaceWrap(true)
                local desFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                desFS:SetPoint("TOPLEFT", curFS, "BOTTOMLEFT", 0, -2)
                desFS:SetWidth(officerW) desFS:SetWordWrap(true) desFS:SetNonSpaceWrap(true)
                if d.officerDesired ~= d.officerCurrent then
                    curFS:SetText("|cffff0000" .. (d.officerCurrent or "(empty)") .. "|r")
                    desFS:SetText("|cff00ff00" .. (d.officerDesired or "(empty)") .. "|r")
                else
                    curFS:SetText("") desFS:SetText("")
                end
                rowH = math.max(rowH, curFS:GetStringHeight() + 2 + desFS:GetStringHeight() + 6)
            end

            if publicChecked then
                local curFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                curFS:SetPoint("TOPLEFT", row, "TOPLEFT", publicLeft, 0)
                curFS:SetWidth(publicW) curFS:SetWordWrap(true) curFS:SetNonSpaceWrap(true)
                local desFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                desFS:SetPoint("TOPLEFT", curFS, "BOTTOMLEFT", 0, -2)
                desFS:SetWidth(publicW) desFS:SetWordWrap(true) desFS:SetNonSpaceWrap(true)
                if d.publicDesired ~= d.publicCurrent then
                    curFS:SetText("|cffff0000" .. (d.publicCurrent or "(empty)") .. "|r")
                    desFS:SetText("|cff00ff00" .. (d.publicDesired or "(empty)") .. "|r")
                else
                    curFS:SetText("") desFS:SetText("")
                end
                rowH = math.max(rowH, curFS:GetStringHeight() + 2 + desFS:GetStringHeight() + 6)
            end

            row:SetHeight(rowH)

            local textToCopy
            if officerChecked and d.officerDesired ~= d.officerCurrent then
                textToCopy = d.officerDesired or ""
            elseif publicChecked and d.publicDesired ~= d.publicCurrent then
                textToCopy = d.publicDesired or ""
            else
                textToCopy = (officerChecked and d.officerDesired)
                    or (publicChecked and d.publicDesired)
                    or ""
            end
            local copyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            copyBtn:SetSize(50, 22)
            copyBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, 0)
            copyBtn:SetText("Copy")
            copyBtn:SetScript("OnClick", function() ShowCopyDialog(d.fullname, textToCopy) end)

            table.insert(diffRows, row)
            y = y - rowH
        end
    end

    diffContent:SetHeight(math.max(math.abs(y) + 22, 1))
end

-- =============================================================================
-- CSV INPUT WINDOW
-- =============================================================================

local function CreateUI()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "BlingtronAppFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(600, 500)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:Hide()

    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -5)
    title:SetText(BlingtronApp.logoIcon .. " Guild Note Sync")

    local instructions = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -15)
    instructions:SetText("Paste the CSV from blingtron.app from the Members page. Format: char-realmname,note")
    instructions:SetTextColor(0.8, 0.8, 0.8)

    local infoText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOP", instructions, "BOTTOM", 0, -6)
    infoText:SetWidth(mainFrame:GetWidth() - 40)
    infoText:SetWordWrap(true)
    infoText:SetJustifyH("CENTER")
    infoText:SetText("You have to set the note manually now because of blizzards addon api changes :(")
    infoText:SetTextColor(0.6, 0.6, 0.6)

    local scrollFrame = CreateFrame("ScrollFrame", "BlingtronAppScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -72)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 60)

    csvTextArea = CreateFrame("EditBox", "BlingtronAppEditBox", scrollFrame)
    csvTextArea:SetMultiLine(true)
    csvTextArea:SetFontObject("GameFontHighlight")
    csvTextArea:SetAutoFocus(false)
    csvTextArea:SetTextInsets(5, 5, 5, 5)
    local bg = csvTextArea:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(csvTextArea)
    bg:SetColorTexture(0, 0, 0, 0.5)
    csvTextArea:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function UpdateEditBoxSize()
        csvTextArea:SetWidth(scrollFrame:GetWidth())
        csvTextArea:SetHeight(scrollFrame:GetHeight())
    end
    scrollFrame:SetScript("OnShow", UpdateEditBoxSize)
    scrollFrame:SetScript("OnSizeChanged", UpdateEditBoxSize)
    mainFrame:SetScript("OnShow", UpdateEditBoxSize)
    scrollFrame:SetScrollChild(csvTextArea)

    local processButton = CreateFrame("Button", "BlingtronAppProcessButton", mainFrame, "UIPanelButtonTemplate")
    processButton:SetSize(120, 30)
    processButton:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, 30)
    processButton:SetText("Process CSV")
    processButton:SetScript("OnClick", function() BlingtronApp:ProcessCSV() end)

    officerNoteCheckbox = CreateFrame("CheckButton", "BlingtronAppOfficerNoteCheckbox", mainFrame, "UICheckButtonTemplate")
    officerNoteCheckbox:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 30)
    officerNoteCheckbox:SetChecked(true)
    local officerNoteLabel = officerNoteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    officerNoteLabel:SetPoint("LEFT", officerNoteCheckbox, "RIGHT", 5, 0)
    officerNoteLabel:SetText("Set officer note")

    publicNoteCheckbox = CreateFrame("CheckButton", "BlingtronAppPublicNoteCheckbox", mainFrame, "UICheckButtonTemplate")
    publicNoteCheckbox:SetPoint("LEFT", officerNoteLabel, "RIGHT", 30, 0)
    publicNoteCheckbox:SetChecked(false)
    local publicNoteLabel = publicNoteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    publicNoteLabel:SetPoint("LEFT", publicNoteCheckbox, "RIGHT", 5, 0)
    publicNoteLabel:SetText("Set public note")

    clearMissingCheckbox = CreateFrame("CheckButton", "BlingtronAppClearMissingCheckbox", mainFrame, "UICheckButtonTemplate")
    clearMissingCheckbox:SetPoint("TOPLEFT", officerNoteCheckbox, "BOTTOMLEFT", 0, 5)
    clearMissingCheckbox:SetChecked(false)
    local clearMissingLabel = clearMissingCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clearMissingLabel:SetPoint("LEFT", clearMissingCheckbox, "RIGHT", 5, 0)
    clearMissingLabel:SetText("Clear missing")

    statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 15)
    statusText:SetWidth(mainFrame:GetWidth() - 40)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function BlingtronApp:ProcessCSV()
    if not csvTextArea then return end

    local csvText = csvTextArea:GetText()
    if not csvText or csvText:match("^%s*$") then
        statusText:SetText("|cffff0000Error: No CSV data provided|r")
        return
    end
    if not IsInGuild() then
        statusText:SetText("|cffff0000Error: You must be in a guild to use this addon|r")
        return
    end

    local officerChecked = officerNoteCheckbox and officerNoteCheckbox:GetChecked()
    local publicChecked  = publicNoteCheckbox  and publicNoteCheckbox:GetChecked()
    if not officerChecked and not publicChecked then
        statusText:SetText("|cffff0000Error: Please select at least one note type to set|r")
        return
    end

    local entries = ParseCSV(csvText)
    if #entries == 0 then
        statusText:SetText("|cffff0000Error: No valid entries found in CSV|r")
        return
    end

    local clearMissing = clearMissingCheckbox and clearMissingCheckbox:GetChecked()
    local diffs = GetNoteDifferences(entries, officerChecked, publicChecked, clearMissing)

    CreateDiffWindow()
    UpdateDiffList(diffs)
    if mainFrame and mainFrame:IsShown() then mainFrame:Hide() end
    diffFrame:Show()
    statusText:SetText(string.format("|cff00ff00%d difference(s) – see list above|r", #diffs))
end

function BlingtronApp:ToggleGuildNoteSync()
    CreateUI()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        if diffFrame and diffFrame:IsShown() then diffFrame:Hide() end
        mainFrame:Show()
        if IsInGuild() then RequestGuildRoster() end
    end
end
