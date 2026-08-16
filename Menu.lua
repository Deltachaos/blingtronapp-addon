-- BlingtronApp - Main menu and minimap icon

local ADDON_NAME = "BlingtronApp"
local logo = BlingtronApp.logoIcon

-- =============================================================================
-- MINIMAP BUTTON
-- =============================================================================

local minimapButton = CreateFrame("Button", "BlingtronAppMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:SetMovable(true)
minimapButton:RegisterForClicks("AnyUp")

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetTexture("Interface\\AddOns\\BlingtronApp\\Media\\logo_minimap")
icon:SetPoint("CENTER", 1, 0)

local function UpdateMinimapPosition(angle)
    local rad = math.rad(angle)
    local x = math.cos(rad) * 105
    local y = math.sin(rad) * 105
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapButton:SetScript("OnDragStart", function(self)
    self.dragging = true
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        BlingtronAppDB.minimapAngle = angle
        UpdateMinimapPosition(angle)
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

minimapButton:RegisterForDrag("LeftButton")

minimapButton:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
        BlingtronApp:ToggleBonusRollFrame()
    elseif button == "RightButton" then
        BlingtronApp:ToggleMainMenu()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(logo .. " Blingtron.app")
    GameTooltip:AddLine("|cffffffffLeft-click|r to open bonus rolls", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffRight-click|r to open main menu", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- =============================================================================
-- MAIN MENU FRAME
-- =============================================================================

local mainMenuFrame = nil
local sourceDropdown = nil

local function BuildSortedSources()
    return BlingtronApp.Helpers.getSortedBisListSourceKeys()
end

local function trim(str)
    return str and str:match("^%s*(.-)%s*$") or nil
end

local function isIntegerString(s)
    if not s or s == "" then return false end
    return s:match("^%-?%d+$") ~= nil
end

--- Parse one line: name-realm,itemid,specid(optional),note(optional)
--- When specid and note are omitted (2 columns), entry applies to all specs; note defaults to "BiS".
--- 3 columns: if third is an integer spec id -> spec-specific, note "BiS"; else third is note for all specs.
--- 4 columns: spec-specific with note (note may be empty -> "BiS").
local function ParseCustomPlayerBisLine(line)
    line = trim(line)
    if not line or line == "" then return nil end

    -- Four fields: name,itemid,specid,note — specid may be empty (,,) for all-specs + note (e.g. numeric notes).
    local name, itemIdStr, third, fourth = line:match("^([^,]+),([^,]+),([^,]*),(.*)$")
    if name and itemIdStr and fourth ~= nil then
        local itemID = tonumber(trim(itemIdStr))
        local t3 = third and trim(third) or ""
        local note = trim(fourth)
        if note == "" then note = "BiS" end
        if itemID then
            if t3 == "" then
                return trim(name), itemID, nil, note
            end
            local specID = tonumber(t3)
            if specID then
                return trim(name), itemID, specID, note
            end
        end
        return nil
    end

    name, itemIdStr, third = line:match("^([^,]+),([^,]+),([^,]+)$")
    if name and itemIdStr and third then
        local itemID = tonumber(trim(itemIdStr))
        if not itemID then return nil end
        local t3 = trim(third)
        if t3 == "" then return nil end
        if isIntegerString(t3) then
            local specID = tonumber(t3)
            if specID then
                return trim(name), itemID, specID, "BiS"
            end
        else
            return trim(name), itemID, nil, t3
        end
    end

    name, itemIdStr = line:match("^([^,]+),([^,]+)$")
    if name and itemIdStr then
        local itemID = tonumber(trim(itemIdStr))
        if itemID then
            return trim(name), itemID, nil, "BiS"
        end
    end

    return nil
end

local function ParseCustomPlayerBisCSV(csvText)
    -- Stored per player: all[itemID]=note, specs[specID][itemID]=note
    local out = {}
    if not csvText or csvText:match("^%s*$") then return out end

    for line in csvText:gmatch("[^\r\n]+") do
        local name, itemID, specID, note = ParseCustomPlayerBisLine(line)
        if name and itemID and note then
            local nameKey = BlingtronApp.Helpers.normalizeKey(name)
            if nameKey then
                local playerEntry = out[nameKey]
                if not playerEntry then
                    playerEntry = { all = {}, specs = {} }
                    out[nameKey] = playerEntry
                end

                if specID then
                    local specEntry = playerEntry.specs[specID]
                    if not specEntry then
                        specEntry = {}
                        playerEntry.specs[specID] = specEntry
                    end
                    specEntry[itemID] = note
                else
                    playerEntry.all[itemID] = note
                end
            end
        end
    end

    return out
end

--- Serialize saved custom player BIS for the editor (round-trips with ParseCustomPlayerBisCSV).
local function CustomPlayerBisTableToCSV(customPlayerBis)
    if not customPlayerBis or next(customPlayerBis) == nil then return "" end
    local lines = {}
    local playerKeys = {}
    for k in pairs(customPlayerBis) do
        tinsert(playerKeys, k)
    end
    table.sort(playerKeys)

    for _, nameKey in ipairs(playerKeys) do
        local entry = customPlayerBis[nameKey]
        if not entry then
            -- skip
        else
            if entry.all then
                local rows = {}
                for itemIDMaybe, note in pairs(entry.all) do
                    local itemID = tonumber(itemIDMaybe)
                    if itemID and note then
                        tinsert(rows, { itemID, tostring(note) })
                    end
                end
                table.sort(rows, function(a, b) return a[1] < b[1] end)
                for _, r in ipairs(rows) do
                    local itemID, note = r[1], r[2]
                    if note == "BiS" then
                        tinsert(lines, string.format("%s,%d", nameKey, itemID))
                    elseif isIntegerString(note) then
                        tinsert(lines, string.format("%s,%d,,%s", nameKey, itemID, note))
                    else
                        tinsert(lines, string.format("%s,%d,%s", nameKey, itemID, note))
                    end
                end
            end
            if entry.specs then
                local specIDs = {}
                for sid in pairs(entry.specs) do
                    tinsert(specIDs, tonumber(sid) or sid)
                end
                table.sort(specIDs)
                for _, specID in ipairs(specIDs) do
                    local specMap = entry.specs[specID]
                    if specMap then
                        local rows = {}
                        for itemIDMaybe, note in pairs(specMap) do
                            local itemID = tonumber(itemIDMaybe)
                            if itemID and note then
                                tinsert(rows, { itemID, tostring(note) })
                            end
                        end
                        table.sort(rows, function(a, b) return a[1] < b[1] end)
                        for _, r in ipairs(rows) do
                            local itemID, note = r[1], r[2]
                            if note == "BiS" then
                                tinsert(lines, string.format("%s,%d,%d", nameKey, itemID, specID))
                            else
                                tinsert(lines, string.format("%s,%d,%d,%s", nameKey, itemID, specID, note))
                            end
                        end
                    end
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

--- Display label: "ClassName - SpecName" (localized when API provides it). No spec ID in the string.
--- Label: "ClassName - SpecName" using GetSpecializationInfoByID returns:
--- id, name, description, icon, role, classFile, className
local function GetSpecEditorDropdownLabel(specID)
    if not specID then return "" end

    if GetSpecializationInfoByID then
        local _, name, _, _, _, classFile, className = GetSpecializationInfoByID(specID)
        if name and name ~= "" then
            local cn = className
            if not cn or cn == "" then
                if classFile and classFile ~= "" then
                    cn = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
                        or LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile]
                end
            end
            if cn and cn ~= "" then
                return string.format("%s - %s", cn, name)
            end
            return name
        end
    end

    return tostring(specID)
end

--- CSV lines: itemid,note (note may contain commas; split on first comma only).
local function ParseItemNoteCSV(csvText)
    local map = {}
    if not csvText or csvText:match("^%s*$") then return map end

    for line in csvText:gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" then
            local comma = line:find(",", 1, true)
            if comma then
                local itemID = tonumber(trim(line:sub(1, comma - 1)))
                local note = trim(line:sub(comma + 1))
                if itemID then
                    if note == "" then note = "BiS" end
                    map[itemID] = note
                end
            else
                local itemID = tonumber(line)
                if itemID then
                    map[itemID] = "BiS"
                end
            end
        end
    end

    return map
end

local function SpecItemsTableToCSV(itemToNote)
    if not itemToNote or next(itemToNote) == nil then return "" end
    local rows = {}
    for itemIDMaybe, note in pairs(itemToNote) do
        local itemID = tonumber(itemIDMaybe)
        if itemID and note then
            rows[#rows + 1] = { itemID, tostring(note) }
        end
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    local lines = {}
    for _, r in ipairs(rows) do
        lines[#lines + 1] = tostring(r[1]) .. "," .. r[2]
    end
    return table.concat(lines, "\n")
end

local function RebuildCustomSpecBisSourcesFromDB()
    -- Removes all previously generated custom sources and recreates them from DB.
    BlingtronAppDB.customSpecBis = BlingtronAppDB.customSpecBis or {}

    for key in pairs(BlingtronApp.BisListSources) do
        if type(key) == "string" and key:match("^custom_spec_") then
            BlingtronApp.BisListSources[key] = nil
        end
    end

    for key in pairs(BlingtronApp.BisList) do
        if type(key) == "string" and key:match("^custom_spec_") then
            BlingtronApp.BisList[key] = nil
        end
    end

    for specIDMaybe, itemToTier in pairs(BlingtronAppDB.customSpecBis) do
        local specID = tonumber(specIDMaybe)
        if specID and type(itemToTier) == "table" and next(itemToTier) ~= nil then
            local normalizedItems = {}
            for itemIDMaybe, tier in pairs(itemToTier) do
                local iid = tonumber(itemIDMaybe)
                if iid and tier then
                    normalizedItems[iid] = tier
                end
            end
            if next(normalizedItems) == nil then
                -- skip
            else
                local sourceKey = "custom_spec_" .. tostring(specID)
                BlingtronApp.BisListSources[sourceKey] = {
                    label = GetSpecEditorDropdownLabel(specID),
                    id = sourceKey,
                    order = 1000,
                }
                BlingtronApp.BisList[sourceKey] = { [specID] = normalizedItems }
            end
        end
    end
end

local function OnBisSourceSelected(self, sourceKey)
    if not sourceKey then return end
    BlingtronAppDB.bisListSource = sourceKey
    BlingtronApp.activeBisSource = sourceKey
    if sourceDropdown then
        UIDropDownMenu_SetText(sourceDropdown, BlingtronApp.BisListSources[sourceKey].label)
    end
    CloseDropDownMenus()
end

local function RefreshBisSourceDropdown()
    if not sourceDropdown then return end

    UIDropDownMenu_Initialize(sourceDropdown, function(self, level)
        local keys = BuildSortedSources()
        local selectedKey = BlingtronApp.Helpers.getBisListSourceKey()

        for _, key in ipairs(keys) do
            local source = BlingtronApp.BisListSources[key]
            local info = UIDropDownMenu_CreateInfo()
            info.text = source.label
            info.arg1 = key
            info.func = OnBisSourceSelected
            info.checked = (key == selectedKey)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local selectedKey = BlingtronApp.Helpers.getBisListSourceKey()
    local selected = selectedKey and BlingtronApp.BisListSources[selectedKey]
    if selected then
        UIDropDownMenu_SetText(sourceDropdown, selected.label)
    end
end

local playerBisDialogFrame = nil
local playerBisTextArea = nil
local playerBisStatusText = nil

function BlingtronApp:ShowPlayerBisCSVDialog()
    if not playerBisDialogFrame then
        playerBisDialogFrame = CreateFrame("Frame", "BlingtronAppPlayerBisCSVDialog", UIParent, "BasicFrameTemplateWithInset")
        playerBisDialogFrame:SetSize(520, 340)
        playerBisDialogFrame:SetPoint("CENTER")
        playerBisDialogFrame:SetMovable(true)
        playerBisDialogFrame:EnableMouse(true)
        playerBisDialogFrame:RegisterForDrag("LeftButton")
        playerBisDialogFrame:SetScript("OnDragStart", playerBisDialogFrame.StartMoving)
        playerBisDialogFrame:SetScript("OnDragStop", playerBisDialogFrame.StopMovingOrSizing)
        playerBisDialogFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        playerBisDialogFrame:Hide()

        local title = playerBisDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", playerBisDialogFrame, "TOP", 0, -5)
        title:SetText(BlingtronApp.logoIcon .. " Custom Player BIS (CSV)")

        local instructions = playerBisDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", playerBisDialogFrame, "TOPLEFT", 20, -35)
        instructions:SetWidth(playerBisDialogFrame:GetWidth() - 40)
        instructions:SetJustifyH("LEFT")
        instructions:SetText("Format: name-realm,itemid,specid(optional),note(optional). Saving replaces ALL overrides: anyone not listed is removed. Omit specid+note = all specs, note BiS. Third column: spec id (number) or note (text).")

        local scrollFrame = CreateFrame("ScrollFrame", nil, playerBisDialogFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", playerBisDialogFrame, "TOPLEFT", 15, -70)
        scrollFrame:SetPoint("BOTTOMRIGHT", playerBisDialogFrame, "BOTTOMRIGHT", -30, 60)

        playerBisTextArea = CreateFrame("EditBox", "BlingtronAppPlayerBisEditBox", scrollFrame)
        playerBisTextArea:SetMultiLine(true)
        playerBisTextArea:SetFontObject("GameFontHighlight")
        playerBisTextArea:SetAutoFocus(false)
        playerBisTextArea:SetTextInsets(5, 5, 5, 5)
        playerBisTextArea:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(playerBisTextArea)

        local bg = playerBisTextArea:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(playerBisTextArea)
        bg:SetColorTexture(0, 0, 0, 0.5)

        local function UpdateEditBoxSize()
            if not scrollFrame or not playerBisTextArea then return end
            playerBisTextArea:SetWidth(scrollFrame:GetWidth())
            playerBisTextArea:SetHeight(scrollFrame:GetHeight())
        end
        scrollFrame:SetScript("OnShow", UpdateEditBoxSize)
        scrollFrame:SetScript("OnSizeChanged", UpdateEditBoxSize)

        local saveBtn = CreateFrame("Button", nil, playerBisDialogFrame, "UIPanelButtonTemplate")
        saveBtn:SetSize(150, 30)
        saveBtn:SetPoint("BOTTOMRIGHT", playerBisDialogFrame, "BOTTOMRIGHT", -20, 20)
        saveBtn:SetText("Save CSV")
        saveBtn:SetScript("OnClick", function()
            -- Textarea is authoritative: full replace. Players/lines not present are removed.
            local csvText = playerBisTextArea and playerBisTextArea:GetText() or ""
            local parsed = ParseCustomPlayerBisCSV(csvText)
            BlingtronAppDB.customPlayerBis = parsed

            if playerBisStatusText then
                local numPlayers = 0
                for _ in pairs(parsed) do numPlayers = numPlayers + 1 end
                if numPlayers == 0 then
                    playerBisStatusText:SetText("|cff00ff00Saved — all player BIS overrides cleared|r")
                else
                    playerBisStatusText:SetText(string.format("|cff00ff00Saved %d player(s); previous list fully replaced|r", numPlayers))
                end
            end
            playerBisDialogFrame:Hide()
        end)

        playerBisStatusText = playerBisDialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        playerBisStatusText:SetPoint("BOTTOMLEFT", playerBisDialogFrame, "BOTTOMLEFT", 20, 20)
        playerBisStatusText:SetWidth(playerBisDialogFrame:GetWidth() - 80)
        playerBisStatusText:SetJustifyH("LEFT")
        playerBisStatusText:SetText("")
    end

    BlingtronAppDB.customPlayerBis = BlingtronAppDB.customPlayerBis or {}
    if playerBisTextArea then
        playerBisTextArea:SetText(CustomPlayerBisTableToCSV(BlingtronAppDB.customPlayerBis))
        playerBisTextArea:ClearFocus()
    end
    if playerBisStatusText then
        playerBisStatusText:SetText("")
    end
    playerBisDialogFrame:Show()
end

local specEditorFrame = nil
local specEditorDropdown = nil
local specEditorTextArea = nil
local specEditorStatusText = nil
local specEditorSelectedSpecID = nil

StaticPopupDialogs["BLINGTRONAPP_DELETE_ALL_SPEC_BIS"] = {
    text = "Delete custom BiS for ALL specs? This cannot be undone.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        BlingtronAppDB.customSpecBis = {}
        RebuildCustomSpecBisSourcesFromDB()
        RefreshBisSourceDropdown()
        if specEditorTextArea then
            specEditorTextArea:SetText("")
        end
        if specEditorStatusText then
            specEditorStatusText:SetText("|cff00ff00Deleted all specs|r")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function SpecEditorLoadCurrentSpecIntoTextarea()
    if not specEditorTextArea or not specEditorSelectedSpecID then return end
    BlingtronAppDB.customSpecBis = BlingtronAppDB.customSpecBis or {}
    local t = BlingtronAppDB.customSpecBis[specEditorSelectedSpecID]
    specEditorTextArea:SetText(SpecItemsTableToCSV(t))
end

local function OnSpecEditorSpecChosen(self, specID)
    specEditorSelectedSpecID = specID
    BlingtronAppDB.lastSpecEditorSpecID = specID
    if specEditorDropdown then
        UIDropDownMenu_SetText(specEditorDropdown, GetSpecEditorDropdownLabel(specID))
    end
    CloseDropDownMenus()
    SpecEditorLoadCurrentSpecIntoTextarea()
    if specEditorStatusText then
        specEditorStatusText:SetText("")
    end
end

local function SpecEditorInitDropdown()
    if not specEditorDropdown then return end
    UIDropDownMenu_SetWidth(specEditorDropdown, 280)
    UIDropDownMenu_Initialize(specEditorDropdown, function(_, level)
        local current = specEditorSelectedSpecID
        for _, specID in ipairs(BlingtronApp.ALL_CLASS_SPEC_IDS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = GetSpecEditorDropdownLabel(specID)
            info.arg1 = specID
            info.func = OnSpecEditorSpecChosen
            info.checked = (specID == current)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function BlingtronApp:ShowCustomSpecBisEditor()
    if not specEditorFrame then
        specEditorFrame = CreateFrame("Frame", "BlingtronAppSpecBisEditorFrame", UIParent, "BasicFrameTemplateWithInset")
        specEditorFrame:SetSize(560, 420)
        specEditorFrame:SetPoint("CENTER")
        specEditorFrame:SetMovable(true)
        specEditorFrame:EnableMouse(true)
        specEditorFrame:RegisterForDrag("LeftButton")
        specEditorFrame:SetScript("OnDragStart", specEditorFrame.StartMoving)
        specEditorFrame:SetScript("OnDragStop", specEditorFrame.StopMovingOrSizing)
        specEditorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        specEditorFrame:Hide()

        local title = specEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", specEditorFrame, "TOP", 0, -5)
        title:SetText(BlingtronApp.logoIcon .. " Custom Spec BIS")

        local instructions = specEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOPLEFT", specEditorFrame, "TOPLEFT", 20, -32)
        instructions:SetWidth(specEditorFrame:GetWidth() - 40)
        instructions:SetJustifyH("LEFT")
        instructions:SetText("Choose a spec, edit one line per item: itemid,note (note may contain commas). Empty file + Save clears this spec. Save before switching spec.")

        local specRowLabel = specEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        specRowLabel:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -12)
        specRowLabel:SetText("Specialization:")

        specEditorDropdown = CreateFrame("Frame", "BlingtronAppSpecBisSpecDropdown", specEditorFrame, "UIDropDownMenuTemplate")
        specEditorDropdown:SetPoint("TOPLEFT", specRowLabel, "BOTTOMLEFT", -16, -4)
        SpecEditorInitDropdown()

        local scrollFrame = CreateFrame("ScrollFrame", nil, specEditorFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", specEditorFrame, "TOPLEFT", 15, -118)
        scrollFrame:SetPoint("BOTTOMRIGHT", specEditorFrame, "BOTTOMRIGHT", -30, 55)

        specEditorTextArea = CreateFrame("EditBox", "BlingtronAppSpecBisItemNoteEditBox", scrollFrame)
        specEditorTextArea:SetMultiLine(true)
        specEditorTextArea:SetFontObject("GameFontHighlight")
        specEditorTextArea:SetAutoFocus(false)
        specEditorTextArea:SetTextInsets(5, 5, 5, 5)
        specEditorTextArea:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(specEditorTextArea)

        local bg = specEditorTextArea:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(specEditorTextArea)
        bg:SetColorTexture(0, 0, 0, 0.5)

        local function UpdateEditBoxSize()
            if not scrollFrame or not specEditorTextArea then return end
            specEditorTextArea:SetWidth(scrollFrame:GetWidth())
            specEditorTextArea:SetHeight(scrollFrame:GetHeight())
        end
        scrollFrame:SetScript("OnShow", UpdateEditBoxSize)
        scrollFrame:SetScript("OnSizeChanged", UpdateEditBoxSize)

        local saveBtn = CreateFrame("Button", nil, specEditorFrame, "UIPanelButtonTemplate")
        saveBtn:SetSize(140, 30)
        saveBtn:SetPoint("BOTTOMRIGHT", specEditorFrame, "BOTTOMRIGHT", -20, 18)
        saveBtn:SetText("Save")
        saveBtn:SetScript("OnClick", function()
            if not specEditorSelectedSpecID then return end
            local csvText = specEditorTextArea and specEditorTextArea:GetText() or ""
            local parsed = ParseItemNoteCSV(csvText)

            BlingtronAppDB.customSpecBis = BlingtronAppDB.customSpecBis or {}
            if next(parsed) == nil then
                BlingtronAppDB.customSpecBis[specEditorSelectedSpecID] = nil
            else
                BlingtronAppDB.customSpecBis[specEditorSelectedSpecID] = parsed
            end

            RebuildCustomSpecBisSourcesFromDB()
            RefreshBisSourceDropdown()

            if specEditorStatusText then
                specEditorStatusText:SetText("|cff00ff00Saved|r")
            end
        end)

        local deleteAllBtn = CreateFrame("Button", nil, specEditorFrame, "UIPanelButtonTemplate")
        deleteAllBtn:SetSize(140, 30)
        deleteAllBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
        deleteAllBtn:SetText("Delete All Specs")
        deleteAllBtn:SetScript("OnClick", function()
            StaticPopup_Show("BLINGTRONAPP_DELETE_ALL_SPEC_BIS")
        end)

        specEditorStatusText = specEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        specEditorStatusText:SetPoint("BOTTOMLEFT", specEditorFrame, "BOTTOMLEFT", 20, 24)
        specEditorStatusText:SetWidth(specEditorFrame:GetWidth() - 340)
        specEditorStatusText:SetJustifyH("LEFT")
        specEditorStatusText:SetText("")
    end

    BlingtronAppDB.lastSpecEditorSpecID = BlingtronAppDB.lastSpecEditorSpecID or BlingtronApp.ALL_CLASS_SPEC_IDS[1]
    local pick = BlingtronAppDB.lastSpecEditorSpecID
    local valid = false
    for _, id in ipairs(BlingtronApp.ALL_CLASS_SPEC_IDS) do
        if id == pick then valid = true break end
    end
    if not valid then pick = BlingtronApp.ALL_CLASS_SPEC_IDS[1] end
    specEditorSelectedSpecID = pick

    SpecEditorInitDropdown()
    UIDropDownMenu_SetText(specEditorDropdown, GetSpecEditorDropdownLabel(specEditorSelectedSpecID))
    SpecEditorLoadCurrentSpecIntoTextarea()
    if specEditorStatusText then
        specEditorStatusText:SetText("")
    end
    specEditorFrame:Show()
end

local function CreateMainMenuFrame()
    if mainMenuFrame then return end

    mainMenuFrame = CreateFrame("Frame", "BlingtronAppMainMenuFrame", UIParent, "BasicFrameTemplateWithInset")
    mainMenuFrame:SetSize(360, 556)
    mainMenuFrame:SetPoint("CENTER")
    mainMenuFrame:SetMovable(true)
    mainMenuFrame:EnableMouse(true)
    mainMenuFrame:RegisterForDrag("LeftButton")
    mainMenuFrame:SetScript("OnDragStart", mainMenuFrame.StartMoving)
    mainMenuFrame:SetScript("OnDragStop", mainMenuFrame.StopMovingOrSizing)
    mainMenuFrame:SetFrameStrata("DIALOG")
    mainMenuFrame:Hide()

    local title = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", mainMenuFrame, "TOP", 0, -5)
    title:SetText(logo .. " Blingtron.app")

    -- Promo section
    local promoHeadline = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    promoHeadline:SetPoint("TOPLEFT", mainMenuFrame, "TOPLEFT", 20, -40)
    promoHeadline:SetText("Check out Blingtron.app Discord Bot!")

    local promoText1 = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    promoText1:SetPoint("TOPLEFT", promoHeadline, "BOTTOMLEFT", 0, -6)
    promoText1:SetWidth(320)
    promoText1:SetJustifyH("LEFT")
    promoText1:SetText("Blingtron.app is a Discord bot that automates the repetitive work of running a guild — role management, weekly reminders, roster tracking, and more.")

    local promoText2 = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    promoText2:SetPoint("TOPLEFT", promoText1, "BOTTOMLEFT", 0, -6)
    promoText2:SetWidth(320)
    promoText2:SetJustifyH("LEFT")
    promoText2:SetText("· Discord reminders (great Vault, crest caps, tier progress)\n· Droptimizer wishlist syncing via browser extension\n· Raid lockout checks\n· Warcraft Logs attendance and performance tools.")

    local promoText3 = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    promoText3:SetPoint("TOPLEFT", promoText2, "BOTTOMLEFT", 0, -6)
    promoText3:SetWidth(320)
    promoText3:SetJustifyH("LEFT")
    promoText3:SetText("|cff44aaffblingtron.app|r — try it free with your guild. Feedback from raid leaders always welcome!")

    local visitBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    visitBtn:SetSize(170, 24)
    visitBtn:SetPoint("TOPLEFT", promoText3, "BOTTOMLEFT", 0, -8)
    visitBtn:SetText("Visit blingtron.app")
    visitBtn:SetScript("OnClick", function()
        BlingtronApp:ShowURLDialog()
    end)

    local helpBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    helpBtn:SetSize(80, 24)
    helpBtn:SetPoint("LEFT", visitBtn, "RIGHT", 8, 0)
    helpBtn:SetText("Help")
    helpBtn:SetScript("OnClick", function()
        BlingtronApp:ShowDiscordDialog()
    end)

    local separator = mainMenuFrame:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetWidth(320)
    separator:SetPoint("TOPLEFT", visitBtn, "BOTTOMLEFT", 0, -10)
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- Tools section
    local toolsLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toolsLabel:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -10)
    toolsLabel:SetText("Tools")

    local guildNoteSyncBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    guildNoteSyncBtn:SetSize(310, 30)
    guildNoteSyncBtn:SetPoint("TOPLEFT", toolsLabel, "BOTTOMLEFT", 0, -8)
    guildNoteSyncBtn:SetText("Guild Note Sync")
    guildNoteSyncBtn:SetScript("OnClick", function()
        mainMenuFrame:Hide()
        BlingtronApp:ToggleGuildNoteSync()
    end)

    local bonusRollBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    bonusRollBtn:SetSize(310, 30)
    bonusRollBtn:SetPoint("TOPLEFT", guildNoteSyncBtn, "BOTTOMLEFT", 0, -8)
    bonusRollBtn:SetText("Bonus Rolls")
    bonusRollBtn:SetScript("OnClick", function()
        BlingtronApp:ShowBonusRollFrame()
    end)

    -- Settings section
    local settingsLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsLabel:SetPoint("TOPLEFT", bonusRollBtn, "BOTTOMLEFT", 0, -20)
    settingsLabel:SetText("Settings")

    -- BiS Source label
    local bisLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bisLabel:SetPoint("TOPLEFT", settingsLabel, "BOTTOMLEFT", 0, -10)
    bisLabel:SetText("BiS List Source:")

    -- BiS Source dropdown
    sourceDropdown = CreateFrame("Frame", "BlingtronAppBisSourceDropdown", mainMenuFrame, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", bisLabel, "BOTTOMLEFT", -16, -2)

    UIDropDownMenu_SetWidth(sourceDropdown, 200)
    UIDropDownMenu_Initialize(sourceDropdown, function(self, level)
        local keys = BuildSortedSources()
        local selectedKey = BlingtronApp.Helpers.getBisListSourceKey()
        for _, key in ipairs(keys) do
            local source = BlingtronApp.BisListSources[key]
            local info = UIDropDownMenu_CreateInfo()
            info.text = source.label
            info.arg1 = key
            info.func = OnBisSourceSelected
            info.checked = (key == selectedKey)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local initialKey = BlingtronApp.Helpers.getBisListSourceKey()
    local initialSource = initialKey and BlingtronApp.BisListSources[initialKey]
    UIDropDownMenu_SetText(sourceDropdown, initialSource and initialSource.label)

    -- Custom BIS CSV buttons
    local customPlayerBisBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    customPlayerBisBtn:SetSize(310, 26)
    customPlayerBisBtn:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 16, -10)
    customPlayerBisBtn:SetText("Custom Player BIS CSV")
    customPlayerBisBtn:SetScript("OnClick", function()
        BlingtronApp:ShowPlayerBisCSVDialog()
    end)

    local customSpecBisBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    customSpecBisBtn:SetSize(310, 26)
    customSpecBisBtn:SetPoint("TOPLEFT", customPlayerBisBtn, "BOTTOMLEFT", 0, -8)
    customSpecBisBtn:SetText("Edit Custom Spec BIS")
    customSpecBisBtn:SetScript("OnClick", function()
        BlingtronApp:ShowCustomSpecBisEditor()
    end)

    -- Minimap button toggle
    local minimapCheckbox = CreateFrame("CheckButton", "BlingtronAppMinimapCheckbox", mainMenuFrame, "UICheckButtonTemplate")
    minimapCheckbox:SetPoint("TOPLEFT", customSpecBisBtn, "BOTTOMLEFT", 0, -10)
    minimapCheckbox:SetChecked(not BlingtronAppDB.hideMinimapButton)
    local minimapLabel = minimapCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapLabel:SetPoint("LEFT", minimapCheckbox, "RIGHT", 5, 0)
    minimapLabel:SetText("Show minimap button")
    minimapCheckbox:SetScript("OnClick", function(self)
        BlingtronAppDB.hideMinimapButton = not self:GetChecked()
        if BlingtronAppDB.hideMinimapButton then
            minimapButton:Hide()
        else
            minimapButton:Show()
        end
    end)
end

function BlingtronApp:HideMainMenu()
    if mainMenuFrame then
        mainMenuFrame:Hide()
    end
end

function BlingtronApp:ShowMainMenu()
    CreateMainMenuFrame()
    if BlingtronApp.HideBonusRollFrame then
        BlingtronApp:HideBonusRollFrame()
    end
    mainMenuFrame:Show()
end

function BlingtronApp:ToggleMainMenu()
    CreateMainMenuFrame()
    if mainMenuFrame:IsShown() then
        mainMenuFrame:Hide()
    else
        self:ShowMainMenu()
    end
end

local copyDialog = nil
local copyDialogTitle = nil
local copyDialogInstr = nil
local copyDialogEditBox = nil

local function ShowCopyDialog(dialogTitle, instruction, url)
    if not copyDialog then
        copyDialog = CreateFrame("Frame", "BlingtronAppCopyDialog", UIParent, "BasicFrameTemplateWithInset")
        copyDialog:SetSize(310, 95)
        copyDialog:SetPoint("CENTER")
        copyDialog:SetMovable(true)
        copyDialog:EnableMouse(true)
        copyDialog:RegisterForDrag("LeftButton")
        copyDialog:SetScript("OnDragStart", copyDialog.StartMoving)
        copyDialog:SetScript("OnDragStop", copyDialog.StopMovingOrSizing)
        copyDialog:SetFrameStrata("TOOLTIP")

        copyDialogTitle = copyDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyDialogTitle:SetPoint("TOP", copyDialog, "TOP", 0, -5)

        copyDialogInstr = copyDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        copyDialogInstr:SetPoint("TOPLEFT", copyDialog, "TOPLEFT", 15, -28)

        copyDialogEditBox = CreateFrame("EditBox", "BlingtronAppCopyEditBox", copyDialog, "InputBoxTemplate")
        copyDialogEditBox:SetSize(268, 20)
        copyDialogEditBox:SetPoint("TOPLEFT", copyDialogInstr, "BOTTOMLEFT", 5, -8)
        copyDialogEditBox:SetAutoFocus(true)
        copyDialogEditBox:SetScript("OnShow", function(self)
            self:SetFocus()
            self:HighlightText()
        end)
        copyDialogEditBox:SetScript("OnEscapePressed", function()
            copyDialog:Hide()
        end)
        copyDialogEditBox:SetScript("OnMouseUp", function(self)
            self:HighlightText()
        end)
    end

    copyDialogTitle:SetText(dialogTitle)
    copyDialogInstr:SetText(instruction)
    copyDialogEditBox:SetText(url)
    copyDialog:Show()
end

function BlingtronApp:ShowURLDialog()
    ShowCopyDialog(logo .. " Blingtron.app", "Copy the URL below:", "https://blingtron.app")
end

function BlingtronApp:ShowDiscordDialog()
    ShowCopyDialog(logo .. " Discord", "Copy the invite link below:", "https://discord.gg/YyX3fACweZ")
end

-- =============================================================================
-- ADDON SETTINGS PANEL (Interface Options)
-- =============================================================================

local settingsPanel = CreateFrame("Frame")
settingsPanel.name = "Blingtron.app"

local panelTitle = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", 16, -16)
panelTitle:SetText(logo .. " Blingtron.app")

local panelDesc = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
panelDesc:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -8)
panelDesc:SetWidth(500)
panelDesc:SetJustifyH("LEFT")
panelDesc:SetText("Use the minimap button or type /blingtron to open the main menu.")

local openButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
openButton:SetSize(180, 30)
openButton:SetPoint("TOPLEFT", panelDesc, "BOTTOMLEFT", 0, -16)
openButton:SetText("Open Main Menu")
openButton:SetScript("OnClick", function()
    BlingtronApp:ToggleMainMenu()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(settingsPanel, settingsPanel.name)
    Settings.RegisterAddOnCategory(category)
    BlingtronApp.settingsCategory = category
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(settingsPanel)
end

-- =============================================================================
-- SLASH COMMAND
-- =============================================================================

SLASH_BLINGTRONAPP1 = "/blingtron"
SLASH_BLINGTRONAPP2 = "/blingtronapp"
SlashCmdList["BLINGTRONAPP"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        BlingtronApp:ToggleMainMenu()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or "")
    rest = rest or ""
    if BlingtronApp.BonusRoll and BlingtronApp.BonusRoll.HandleCommand(cmd, rest) then
        return
    end
    if BlingtronApp.BonusRoll then
        BlingtronApp.BonusRoll.PrintHelp()
    end
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then return end

    BlingtronAppDB = BlingtronAppDB or {}
    BlingtronAppDB.minimapAngle = BlingtronAppDB.minimapAngle or 220
    if not BlingtronAppDB.bisListSource or BlingtronAppDB.bisListSource == "wowhead_overall" then
        BlingtronAppDB.bisListSource = "blingtron_overall"
    end
    BlingtronAppDB.customPlayerBis = BlingtronAppDB.customPlayerBis or {}
    BlingtronAppDB.customSpecBis = BlingtronAppDB.customSpecBis or {}
    BlingtronAppDB.bonusRoll = BlingtronAppDB.bonusRoll or {}

    RebuildCustomSpecBisSourcesFromDB()

    UpdateMinimapPosition(BlingtronAppDB.minimapAngle)

    if BlingtronAppDB.hideMinimapButton then
        minimapButton:Hide()
    end

    BlingtronApp.activeBisSource = BlingtronAppDB.bisListSource

    initFrame:UnregisterEvent("ADDON_LOADED")
end)
