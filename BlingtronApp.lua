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

-- Process CSV and set officer notes
function BlingtronApp:ProcessCSV()
    if not csvTextArea then
        return
    end
    
    local csvText = csvTextArea:GetText()
    if not csvText or csvText:match("^%s*$") then
        statusText:SetText("|cffff0000Error: No CSV data provided|r")
        return
    end
    
    -- Check if in a guild
    if not IsInGuild() then
        statusText:SetText("|cffff0000Error: You must be in a guild to use this addon|r")
        return
    end
    
    -- Check if at least one checkbox is checked
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
    
    -- Create lookup table from CSV entries (keyed by lowercased fullname)
    local csvLookup = {}
    for _, entry in ipairs(entries) do
        csvLookup[entry.fullname:lower()] = entry.note
    end
    
    local successCount = 0
    local failCount = 0
    local clearedCount = 0
    local processedNames = {}
    local clearMissing = clearMissingCheckbox and clearMissingCheckbox:GetChecked()
    
    -- Iterate over guild members and check for matching CSV entries
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, online, status, 
              classFileName, achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
        
        if name then
            local nameLower = name:lower()
            local csvNote = csvLookup[nameLower]
            
            if csvNote then
                local noteSet = false
                
                -- Set officer note if checkbox is checked
                if officerNoteCheckbox and officerNoteCheckbox:GetChecked() then
                    GuildRosterSetOfficerNote(i, csvNote)
                    noteSet = true
                end
                
                -- Set public note if checkbox is checked
                if publicNoteCheckbox and publicNoteCheckbox:GetChecked() then
                    GuildRosterSetPublicNote(i, csvNote)
                    noteSet = true
                end
                
                if noteSet then
                    successCount = successCount + 1
                    processedNames[nameLower] = true
                end
            else
                -- Guild member is not in CSV, clear their notes if "Clear missing" is checked
                if clearMissing then
                    if officerNoteCheckbox and officerNoteCheckbox:GetChecked() then
                        GuildRosterSetOfficerNote(i, "")
                    end
                    if publicNoteCheckbox and publicNoteCheckbox:GetChecked() then
                        GuildRosterSetPublicNote(i, "")
                    end
                    clearedCount = clearedCount + 1
                end
            end
        end
    end
    
    -- Count failed entries (CSV entries that weren't found in guild)
    local failMessages = {}
    for _, entry in ipairs(entries) do
        if not processedNames[entry.fullname:lower()] then
            failCount = failCount + 1
            table.insert(failMessages, entry.fullname)
        end
    end
    
    -- Update status
    local statusMsg = string.format("|cff00ff00Processed: %d successful|r", successCount)
    if clearedCount > 0 then
        statusMsg = statusMsg .. string.format(" |cff00ffff, %d cleared|r", clearedCount)
    end
    if failCount > 0 then
        statusMsg = statusMsg .. string.format(" |cffff0000, %d failed|r", failCount)
        if #failMessages <= 5 then
            statusMsg = statusMsg .. ": " .. table.concat(failMessages, ", ")
        end
    end
    statusText:SetText(statusMsg)
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
        mainFrame:Show()
        -- Request guild roster when opening
        if IsInGuild() then
            GuildRoster()
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

