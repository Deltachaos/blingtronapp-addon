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
icon:SetTexture("Interface\\AddOns\\BlingtronApp\\Media\\logo")
icon:SetPoint("CENTER", 0, 1)

local function UpdateMinimapPosition(angle)
    local rad = math.rad(angle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
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
        BlingtronApp:ToggleMainMenu()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(logo .. " Blingtron.app")
    GameTooltip:AddLine("|cffffffffLeft-click|r to open main menu", 0.8, 0.8, 0.8)
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
    local keys = {}
    for k in pairs(BlingtronApp.BisListSources) do
        tinsert(keys, k)
    end
    table.sort(keys)
    return keys
end

local function CreateMainMenuFrame()
    if mainMenuFrame then return end

    mainMenuFrame = CreateFrame("Frame", "BlingtronAppMainMenuFrame", UIParent, "BasicFrameTemplateWithInset")
    mainMenuFrame:SetSize(360, 300)
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

    -- Tools section
    local toolsLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toolsLabel:SetPoint("TOPLEFT", mainMenuFrame, "TOPLEFT", 20, -35)
    toolsLabel:SetText("Tools")

    local guildNoteSyncBtn = CreateFrame("Button", nil, mainMenuFrame, "UIPanelButtonTemplate")
    guildNoteSyncBtn:SetSize(310, 30)
    guildNoteSyncBtn:SetPoint("TOPLEFT", toolsLabel, "BOTTOMLEFT", 0, -8)
    guildNoteSyncBtn:SetText("Guild Note Sync")
    guildNoteSyncBtn:SetScript("OnClick", function()
        mainMenuFrame:Hide()
        BlingtronApp:ToggleGuildNoteSync()
    end)

    -- Settings section
    local settingsLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    settingsLabel:SetPoint("TOPLEFT", guildNoteSyncBtn, "BOTTOMLEFT", 0, -20)
    settingsLabel:SetText("Settings")

    -- BiS Source label
    local bisLabel = mainMenuFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bisLabel:SetPoint("TOPLEFT", settingsLabel, "BOTTOMLEFT", 0, -10)
    bisLabel:SetText("BiS List Source:")

    -- BiS Source dropdown
    sourceDropdown = CreateFrame("Frame", "BlingtronAppBisSourceDropdown", mainMenuFrame, "UIDropDownMenuTemplate")
    sourceDropdown:SetPoint("TOPLEFT", bisLabel, "BOTTOMLEFT", -16, -2)

    local function OnSourceSelected(self, sourceKey)
        BlingtronAppDB.bisListSource = sourceKey
        BlingtronApp.activeBisSource = sourceKey
        UIDropDownMenu_SetText(sourceDropdown, BlingtronApp.BisListSources[sourceKey].label)
        CloseDropDownMenus()
    end

    UIDropDownMenu_SetWidth(sourceDropdown, 200)
    UIDropDownMenu_Initialize(sourceDropdown, function(self, level)
        local keys = BuildSortedSources()
        local currentSource = BlingtronAppDB.bisListSource or "wowhead"
        for _, key in ipairs(keys) do
            local source = BlingtronApp.BisListSources[key]
            local info = UIDropDownMenu_CreateInfo()
            info.text = source.label
            info.arg1 = key
            info.func = OnSourceSelected
            info.checked = (key == currentSource)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local currentKey = BlingtronAppDB.bisListSource or "wowhead"
    local currentSource = BlingtronApp.BisListSources[currentKey]
    UIDropDownMenu_SetText(sourceDropdown, currentSource and currentSource.label or "Wowhead")

    -- Minimap button toggle
    local minimapCheckbox = CreateFrame("CheckButton", "BlingtronAppMinimapCheckbox", mainMenuFrame, "UICheckButtonTemplate")
    minimapCheckbox:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 16, -10)
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

function BlingtronApp:ToggleMainMenu()
    CreateMainMenuFrame()
    if mainMenuFrame:IsShown() then
        mainMenuFrame:Hide()
    else
        mainMenuFrame:Show()
    end
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
SlashCmdList["BLINGTRONAPP"] = function()
    BlingtronApp:ToggleMainMenu()
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
    BlingtronAppDB.bisListSource = BlingtronAppDB.bisListSource or "wowhead"

    BlingtronApp.activeBisSource = BlingtronAppDB.bisListSource
    UpdateMinimapPosition(BlingtronAppDB.minimapAngle)

    if BlingtronAppDB.hideMinimapButton then
        minimapButton:Hide()
    end

    initFrame:UnregisterEvent("ADDON_LOADED")
end)
