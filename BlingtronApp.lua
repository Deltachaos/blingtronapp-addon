-- BlingtronApp - Set guild officer notes from CSV
local BlingtronApp = CreateFrame("Frame")
BlingtronApp.name = "BlingtronApp"

-- Saved variables
BlingtronAppDB = BlingtronAppDB or {}

-- Main frame
local mainFrame = nil
local csvTextArea = nil
local processButton = nil
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
local diffRows = {}  -- pool of row frames, reused each UpdateDiffList
local copyDialogFrame = nil
local copyDialogEditBox = nil
local copyDialogTitle = nil

-- Create the main UI window
local function CreateUI()
    if mainFrame then
        return
    end
    
    -- Main frame
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
    
    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -5)
    title:SetText("Blingtron.app")
    
    -- Instructions
    local instructions = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -15)
    instructions:SetText("Paste CSV with format: char-realmname,note")
    instructions:SetTextColor(0.8, 0.8, 0.8)
    
    -- CSV Text Area (ScrollFrame with EditBox)
    local scrollFrame = CreateFrame("ScrollFrame", "BlingtronAppScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 60)
    
    csvTextArea = CreateFrame("EditBox", "BlingtronAppEditBox", scrollFrame)
    csvTextArea:SetMultiLine(true)
    csvTextArea:SetFontObject("GameFontHighlight")
    csvTextArea:SetAutoFocus(false)
    csvTextArea:SetTextInsets(5, 5, 5, 5)
    
    -- Add background to make it visible
    local bg = csvTextArea:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(csvTextArea)
    bg:SetColorTexture(0, 0, 0, 0.5)
    
    csvTextArea:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    -- Function to update EditBox size based on scrollFrame
    local function UpdateEditBoxSize()
        local scrollWidth = scrollFrame:GetWidth()
        local scrollHeight = scrollFrame:GetHeight()
        csvTextArea:SetWidth(scrollWidth)
        csvTextArea:SetHeight(scrollHeight)
    end
    
    -- Update size when frame is shown or scrollFrame is resized
    scrollFrame:SetScript("OnShow", UpdateEditBoxSize)
    scrollFrame:SetScript("OnSizeChanged", UpdateEditBoxSize)
    mainFrame:SetScript("OnShow", UpdateEditBoxSize)
    
    scrollFrame:SetScrollChild(csvTextArea)
    
    -- Process Button
    processButton = CreateFrame("Button", "BlingtronAppProcessButton", mainFrame, "UIPanelButtonTemplate")
    processButton:SetSize(120, 30)
    processButton:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, 30)
    processButton:SetText("Process CSV")
    processButton:SetScript("OnClick", function()
        BlingtronApp:ProcessCSV()
    end)
    
    -- Checkboxes
    officerNoteCheckbox = CreateFrame("CheckButton", "BlingtronAppOfficerNoteCheckbox", mainFrame, "UICheckButtonTemplate")
    officerNoteCheckbox:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, 30)
    officerNoteCheckbox:SetChecked(true) -- Default to checked
    local officerNoteLabel = officerNoteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    officerNoteLabel:SetPoint("LEFT", officerNoteCheckbox, "RIGHT", 5, 0)
    officerNoteLabel:SetText("Set officer note")
    
    publicNoteCheckbox = CreateFrame("CheckButton", "BlingtronAppPublicNoteCheckbox", mainFrame, "UICheckButtonTemplate")
    publicNoteCheckbox:SetPoint("LEFT", officerNoteLabel, "RIGHT", 30, 0)
    publicNoteCheckbox:SetChecked(false) -- Default to unchecked
    local publicNoteLabel = publicNoteCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    publicNoteLabel:SetPoint("LEFT", publicNoteCheckbox, "RIGHT", 5, 0)
    publicNoteLabel:SetText("Set public note")
    
    clearMissingCheckbox = CreateFrame("CheckButton", "BlingtronAppClearMissingCheckbox", mainFrame, "UICheckButtonTemplate")
    clearMissingCheckbox:SetPoint("TOPLEFT", officerNoteCheckbox, "BOTTOMLEFT", 0, 5)
    clearMissingCheckbox:SetChecked(false) -- Default to unchecked
    local clearMissingLabel = clearMissingCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clearMissingLabel:SetPoint("LEFT", clearMissingCheckbox, "RIGHT", 5, 0)
    clearMissingLabel:SetText("Clear missing")
    
    -- Status Text
    statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, 15)
    statusText:SetWidth(mainFrame:GetWidth() - 40)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
end

-- Helper function to trim whitespace
local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

-- Helpers for note-setting APIs (call only if they exist, for when they are re-added)
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

-- Request guild roster update (call only if API exists)
local function RequestGuildRoster()
    if GuildRoster then
        GuildRoster()
        return true
    end
    return false
end

-- Parse CSV text
local function ParseCSV(csvText)
    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local entries = {}
    for i, line in ipairs(lines) do
        -- Skip empty lines
        if not line:match("^%s*$") then
            -- Split only on the first comma (note can contain commas)
            local firstComma = line:find(",")
            if firstComma then
                local fullname = trim(line:sub(1, firstComma - 1))
                local note = trim(line:sub(firstComma + 1))
                -- Guild note fields are limited to 32 characters (count UTF-8 chars, not bytes)
                if string.utf8len(note) > 31 then
                    note = string.utf8sub(note, 1, 31)
                end

                if fullname and note and fullname ~= "" then
                    table.insert(entries, {
                        fullname = fullname,  -- Format: "char-realmname"
                        note = note
                    })
                end
            end
        end
    end
    
    return entries
end

-- Build sorted list of differences between CSV desired notes and current guild notes
local function GetNoteDifferences(csvEntries, officerChecked, publicChecked, clearMissing)
    local csvLookup = {}
    for _, entry in ipairs(csvEntries) do
        csvLookup[entry.fullname:lower()] = entry.note
    end

    local diffs = {}
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status,
              classFileName, achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
        if name then
            local nameLower = name:lower()
            local csvNote = csvLookup[nameLower]
            local desiredOfficer = (officerChecked and csvNote ~= nil) and csvNote or (clearMissing and officerChecked and not csvNote) and "" or nil
            local desiredPublic  = (publicChecked and csvNote ~= nil) and csvNote or (clearMissing and publicChecked and not csvNote) and "" or nil
            local currentOfficer = officernote or ""
            local currentPublic  = note or ""

            local officerDiff = (desiredOfficer ~= nil and desiredOfficer ~= currentOfficer)
            local publicDiff  = (desiredPublic ~= nil and desiredPublic ~= currentPublic)
            if officerDiff or publicDiff then
                table.insert(diffs, {
                    fullname = name,
                    officerDesired = desiredOfficer or currentOfficer,
                    officerCurrent = currentOfficer,
                    publicDesired  = desiredPublic or currentPublic,
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

-- Forward declaration so RefreshDiffList can call it (UpdateDiffList is defined later)
local UpdateDiffList

-- Refresh the diff list from current CSV, checkboxes, and guild roster (used on GUILD_ROSTER_UPDATE)
local function RefreshDiffList()
    if not diffContent or not diffHeaderRow then return end
    local csvText = csvTextArea and csvTextArea:GetText() or ""
    local entries = ParseCSV(csvText)
    local officerChecked = officerNoteCheckbox and officerNoteCheckbox:GetChecked()
    local publicChecked = publicNoteCheckbox and publicNoteCheckbox:GetChecked()
    local clearMissing = clearMissingCheckbox and clearMissingCheckbox:GetChecked()
    local diffs = GetNoteDifferences(entries, officerChecked, publicChecked, clearMissing)
    UpdateDiffList(diffs)
end

-- Create and show the differences window
local function CreateDiffWindow()
    if diffFrame then
        return
    end
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

    -- Update list on every GUILD_ROSTER_UPDATE while window is open
    diffFrame:SetScript("OnEvent", function(_, ev)
        if ev == "GUILD_ROSTER_UPDATE" then
            RefreshDiffList()
        end
    end)
    diffFrame:SetScript("OnShow", function()
        diffFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    end)
    diffFrame:SetScript("OnHide", function()
        diffFrame:UnregisterEvent("GUILD_ROSTER_UPDATE")
    end)

    local title = diffFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", diffFrame, "TOP", 0, -5)
    title:SetText("Note differences (red = current, green = desired)")

    diffScrollFrame = CreateFrame("ScrollFrame", "BlingtronAppDiffScrollFrame", diffFrame, "UIPanelScrollFrameTemplate")
    diffScrollFrame:SetPoint("TOPLEFT", diffFrame, "TOPLEFT", 15, -35)
    diffScrollFrame:SetPoint("BOTTOMRIGHT", diffFrame, "BOTTOMRIGHT", -30, 50)

    diffContent = CreateFrame("Frame", "BlingtronAppDiffContent", diffScrollFrame)
    diffContent:SetSize(diffScrollFrame:GetWidth(), 1)
    diffScrollFrame:SetScrollChild(diffContent)

    -- Table header row
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
    diffRecheckBtn:SetScript("OnClick", function()
        RequestGuildRoster()
    end)
end

-- Show a dialog with an EditBox containing text so the user can Ctrl+C to copy
local function ShowCopyDialog(titleSuffix, textToCopy)
    if not copyDialogFrame then
        copyDialogFrame = CreateFrame("Frame", "BlingtronAppCopyDialog", UIParent, "BasicFrameTemplateWithInset")
        copyDialogFrame:SetSize(480, 120)
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
        hintText:SetText("Closes automatically on CTRL-C")
        hintText:SetTextColor(0.7, 0.7, 0.7)

        local closeBtn = CreateFrame("Button", nil, copyDialogFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", copyDialogFrame, "BOTTOM", 0, 12)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function()
            copyDialogFrame:Hide()
        end)
    end
    copyDialogTitle:SetText("Copy note" .. (titleSuffix and (" - " .. titleSuffix) or ""))
    copyDialogEditBox:SetText(textToCopy or "")
    copyDialogEditBox:SetFocus()
    copyDialogEditBox:HighlightText(0, #(textToCopy or ""))
    copyDialogFrame:Show()
end

-- Column layout constants for diff table
local COL_NAME_LEFT = 4
local COL_NAME_W = 110
local COL_OFFICER_LEFT = 120
local COL_OFFICER_W = 262
local COL_PUBLIC_LEFT = 390
local COL_PUBLIC_W = 262
local ROW_MIN_H = 36

-- Update the diff list display as a table with Copy button per row
UpdateDiffList = function(diffs)
    if not diffContent or not diffHeaderRow then
        return
    end
    local officerChecked = officerNoteCheckbox and officerNoteCheckbox:GetChecked()
    local publicChecked = publicNoteCheckbox and publicNoteCheckbox:GetChecked()

    -- Show/hide header columns based on checkbox state
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

    -- Column positions: first note column always at 120; second (if both) at 390. Single column uses full width.
    local noteColLeft = 120
    local noteColW = contentW - noteColLeft - 60  -- space for Copy button
    local officerLeft = noteColLeft
    local publicLeft = publicChecked and officerChecked and 390 or noteColLeft
    local officerW = (officerChecked and publicChecked) and COL_OFFICER_W or noteColW
    local publicW = (officerChecked and publicChecked) and COL_PUBLIC_W or noteColW

    -- Clear previous data rows (header stays)
    for _, row in ipairs(diffRows) do
        row:SetParent(nil)
        row:Hide()
    end
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

            -- Officer column: only when officer note should be set
            if officerChecked then
                local officerCurrentFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                officerCurrentFS:SetPoint("TOPLEFT", row, "TOPLEFT", officerLeft, 0)
                officerCurrentFS:SetWidth(officerW)
                officerCurrentFS:SetWordWrap(true)
                officerCurrentFS:SetNonSpaceWrap(true)
                local officerDesiredFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                officerDesiredFS:SetPoint("TOPLEFT", officerCurrentFS, "BOTTOMLEFT", 0, -2)
                officerDesiredFS:SetWidth(officerW)
                officerDesiredFS:SetWordWrap(true)
                officerDesiredFS:SetNonSpaceWrap(true)
                if d.officerDesired ~= d.officerCurrent then
                    officerCurrentFS:SetText("|cffff0000" .. (d.officerCurrent or "(empty)") .. "|r")
                    officerDesiredFS:SetText("|cff00ff00" .. (d.officerDesired or "(empty)") .. "|r")
                else
                    officerCurrentFS:SetText("")
                    officerDesiredFS:SetText("")
                end
                rowH = math.max(rowH, officerCurrentFS:GetStringHeight() + 2 + officerDesiredFS:GetStringHeight() + 6)
            end

            -- Public column: only when public note should be set
            if publicChecked then
                local publicCurrentFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                publicCurrentFS:SetPoint("TOPLEFT", row, "TOPLEFT", publicLeft, 0)
                publicCurrentFS:SetWidth(publicW)
                publicCurrentFS:SetWordWrap(true)
                publicCurrentFS:SetNonSpaceWrap(true)
                local publicDesiredFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                publicDesiredFS:SetPoint("TOPLEFT", publicCurrentFS, "BOTTOMLEFT", 0, -2)
                publicDesiredFS:SetWidth(publicW)
                publicDesiredFS:SetWordWrap(true)
                publicDesiredFS:SetNonSpaceWrap(true)
                if d.publicDesired ~= d.publicCurrent then
                    publicCurrentFS:SetText("|cffff0000" .. (d.publicCurrent or "(empty)") .. "|r")
                    publicDesiredFS:SetText("|cff00ff00" .. (d.publicDesired or "(empty)") .. "|r")
                else
                    publicCurrentFS:SetText("")
                    publicDesiredFS:SetText("")
                end
                rowH = math.max(rowH, publicCurrentFS:GetStringHeight() + 2 + publicDesiredFS:GetStringHeight() + 6)
            end

            row:SetHeight(rowH)

            -- Copy button: copy the desired note(s) for this row (for Ctrl+C in dialog)
            local copyNoteParts = {}
            if d.officerChecked and (d.officerDesired ~= d.officerCurrent) then
                table.insert(copyNoteParts, (d.officerDesired or ""))
            end
            if d.publicChecked and (d.publicDesired ~= d.publicCurrent) then
                table.insert(copyNoteParts, (d.publicDesired or ""))
            end
            -- Same note for officer/public; show plain text only
            local textToCopy = (copyNoteParts[1] or copyNoteParts[2] or d.officerDesired or d.publicDesired or "")

            local copyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            copyBtn:SetSize(50, 22)
            copyBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, 0)
            copyBtn:SetText("Copy")
            copyBtn:SetScript("OnClick", function()
                ShowCopyDialog(d.fullname, textToCopy)
            end)

            table.insert(diffRows, row)
            y = y - rowH
        end
    end

    local totalH = math.abs(y) + 22
    diffContent:SetHeight(math.max(totalH, 1))
end

-- Process CSV and show differences window
function BlingtronApp:ProcessCSV()
    if not csvTextArea then
        return
    end

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
    local publicChecked = publicNoteCheckbox and publicNoteCheckbox:GetChecked()
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
    if mainFrame and mainFrame:IsShown() then
        mainFrame:Hide()
    end
    diffFrame:Show()
    statusText:SetText(string.format("|cff00ff00%d difference(s) – see list above|r", #diffs))
end

-- Slash command handler
SLASH_BLINGTRONAPP1 = "/blingtron"
SLASH_BLINGTRONAPP2 = "/blingtronapp"
SlashCmdList["BLINGTRONAPP"] = function(msg)
    -- Clear chat input
    local chatFrame = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    if chatFrame and chatFrame.editBox then
        chatFrame.editBox:SetText("")
        chatFrame.editBox:ClearFocus()
    end
    
    CreateUI()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        if diffFrame and diffFrame:IsShown() then
            diffFrame:Hide()
        end
        mainFrame:Show()
        -- Request guild roster when opening (if API exists)
        if IsInGuild() then
            RequestGuildRoster()
        end
    end
end

-- Initialize
BlingtronApp:RegisterEvent("ADDON_LOADED")
BlingtronApp:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BlingtronApp" then
        CreateUI()
        print("Blingtron.app loaded! Type /blingtron to open.")
    end
end)

