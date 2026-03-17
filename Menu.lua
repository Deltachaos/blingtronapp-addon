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
    mainMenuFrame:SetSize(360, 455)
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
    promoText2:SetText("· Discord reminders (great vault, crest caps, tier progress)\n· Droptimizer wishlist syncing via browser extension\n· Raid lockout checks\n· Warcraft Logs attendance and performance tools.")

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
        UIDropDownMenu_SetText(sourceDropdown, BlingtronApp.BisListSources[sourceKey].label)
        CloseDropDownMenus()
    end

    UIDropDownMenu_SetWidth(sourceDropdown, 200)
    UIDropDownMenu_Initialize(sourceDropdown, function(self, level)
        local keys = BuildSortedSources()
        local currentSource = BlingtronAppDB.bisListSource
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

    local currentKey = BlingtronAppDB.bisListSource
    local currentSource = BlingtronApp.BisListSources[currentKey]
    UIDropDownMenu_SetText(sourceDropdown, currentSource and currentSource.label)

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

    UpdateMinimapPosition(BlingtronAppDB.minimapAngle)

    if BlingtronAppDB.hideMinimapButton then
        minimapButton:Hide()
    end

    initFrame:UnregisterEvent("ADDON_LOADED")
end)
