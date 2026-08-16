-- BlingtronApp - Bonus-roll tracker window (display only)

local NAME_W = 210
local TIER_W = 88
local SAVE_W = 88
local ITEM_W = 58
local ADD_W = 78
local ROW_H = 40
local HEADER_H = 22
local PAD = 8

local WEIGHT_QUALITY = {
    [100] = 6,
    [75]  = 5,
    [50]  = 4,
    [25]  = 3,
}

local TIER_QUALITY = {
    BiS = 6,
    S   = 5,
    A   = 4,
    B   = 3,
    C   = 2,
    D   = 1,
}

local QUALITY_FALLBACK = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
}

local frame
local subtitle
local scrollFrame
local scrollChild
local statusText
local addMenuFrame
local addMenuRow
local sortKey = "score"
local sortAsc = false
local RefreshBoard

local function qualityColor(quality)
    quality = quality or 0
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r then
            return r, g, b
        end
    end
    local colors = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if colors then
        return colors.r, colors.g, colors.b
    end
    local fb = QUALITY_FALLBACK[quality] or QUALITY_FALLBACK[0]
    return fb[1], fb[2], fb[3]
end

local function setQualityText(fs, quality, text)
    fs:SetText(text or "")
    fs:SetTextColor(qualityColor(quality))
end

local function itemIconTexture(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

local function contentWidth(maxItems, maxExtraItems)
    maxItems = maxItems or 0
    maxExtraItems = maxExtraItems or 0
    return PAD + NAME_W + TIER_W + SAVE_W + (maxItems * ITEM_W) + (maxExtraItems * ITEM_W) + ADD_W + PAD
end

local function wipeChildren(parent)
    local kids = { parent:GetChildren() }
    for i = 1, #kids do
        kids[i]:Hide()
        kids[i]:SetParent(nil)
    end
end

local function addHeaderCell(parent, x, width, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -4)
    fs:SetSize(width - 4, HEADER_H - 6)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function addSortHeader(parent, x, width, label, key, tipKey)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -2)
    btn:SetSize(width - 4, HEADER_H - 4)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH("LEFT")
    local marker = ""
    if sortKey == key then
        marker = sortAsc and " ^" or " v"
        fs:SetTextColor(1, 0.82, 0)
    end
    fs:SetText(label .. marker)

    btn:SetScript("OnClick", function()
        if sortKey == key then
            sortAsc = not sortAsc
        else
            sortKey = key
            sortAsc = false
        end
        RefreshBoard()
    end)
    btn:SetScript("OnEnter", function(self)
        local extra = { "Click to sort. Click again to reverse." }
        if BlingtronApp.BonusRoll and BlingtronApp.BonusRoll.ShowColumnHeaderTooltip and tipKey then
            BlingtronApp.BonusRoll.ShowColumnHeaderTooltip(self, tipKey, extra)
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to sort")
        GameTooltip:AddLine("Click again to reverse.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return btn
end

local function sortRows(rows)
    table.sort(rows, function(a, b)
        local av, bv
        if sortKey == "saving" then
            av = a.saving or -1
            bv = b.saving or -1
        else
            av = a.score or 0
            bv = b.score or 0
        end
        if av == bv then
            return (a.name or "") < (b.name or "")
        end
        if sortAsc then
            return av < bv
        end
        return av > bv
    end)
end

local function applyStatusVisual(icon, statusFS, status)
    if status == "rolled" then
        setQualityText(statusFS, 5, "BR")
        icon:SetDesaturated(true)
        icon:SetAlpha(0.7)
    elseif status == "loot" then
        setQualityText(statusFS, 3, "Loot")
        icon:SetDesaturated(true)
        icon:SetAlpha(0.7)
    else
        setQualityText(statusFS, 0, "—")
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
    end
end

local function showItemTooltip(owner, item)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(item.id)
    else
        GameTooltip:SetHyperlink("item:" .. item.id)
    end
    GameTooltip:AddLine(" ")
    if item.extra then
        GameTooltip:AddLine("Not on your targeted BiS list.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Bonus-rolled: removed from this loot pool.", 1, 0.5, 0)
        GameTooltip:AddLine("Click x to remove.", 0.8, 0.8, 0.8)
    else
        if item.weight and item.weight > 0 then
            GameTooltip:AddLine("Bonus-roll weight: " .. item.weight, 1, 1, 1)
        else
            GameTooltip:AddLine("Not on your weighted BiS list.", 0.7, 0.7, 0.7)
        end
        if item.saving then
            GameTooltip:AddLine(string.format("BR save: %.1f", item.saving), 1, 1, 1)
        end
        if item.status == "rolled" then
            GameTooltip:AddLine("Status: bonus-rolled (removed from this pool)", 1, 0.5, 0)
        elseif item.status == "loot" then
            GameTooltip:AddLine("Status: looted normally (still in bonus-roll pool)", 0, 0.44, 0.87)
        else
            GameTooltip:AddLine("Status: not looted yet", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine("Click the status to cycle: — → BR → Loot.", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function makeItemCell(parent, x, y, item, sourceKey)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(ITEM_W - 4, ROW_H - 4)
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cell:EnableMouse(false)

    local iconBtn = CreateFrame("Button", nil, cell)
    iconBtn:SetSize(18, 18)
    iconBtn:SetPoint("TOPLEFT", 2, -2)
    iconBtn:EnableMouse(true)

    local icon = iconBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local tex = itemIconTexture(item.id)
    if tex then
        icon:SetTexture(tex)
    else
        icon:SetColorTexture(0.2, 0.2, 0.2, 1)
    end

    if item.extra then
        local removeBtn = CreateFrame("Button", nil, cell)
        removeBtn:SetSize(14, 14)
        removeBtn:SetPoint("LEFT", iconBtn, "RIGHT", 2, 0)
        removeBtn:RegisterForClicks("LeftButtonUp")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
        local removeFS = removeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        removeFS:SetAllPoints()
        removeFS:SetJustifyH("CENTER")
        removeFS:SetText("x")
        removeFS:SetTextColor(1, 0.3, 0.3)
        removeBtn:SetScript("OnClick", function()
            GameTooltip:Hide()
            if BlingtronApp.BonusRoll.SetItemStatus(sourceKey, item.id, "open") then
                RefreshBoard()
            end
        end)
        removeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Remove bonus-roll mark")
            GameTooltip:AddLine("Puts this item back in the loot pool and Add BR list.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        removeBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    else
        local scoreFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        scoreFS:SetPoint("LEFT", iconBtn, "RIGHT", 3, 0)
        scoreFS:SetJustifyH("LEFT")
        if item.weight and item.weight > 0 then
            setQualityText(scoreFS, WEIGHT_QUALITY[item.weight] or 1, tostring(item.weight))
        else
            setQualityText(scoreFS, 0, "-")
        end
    end

    local statusBtn = CreateFrame("Button", nil, cell)
    statusBtn:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", -2, -1)
    statusBtn:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 0, 0)
    statusBtn:RegisterForClicks("LeftButtonUp")
    statusBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local statusFS = statusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetAllPoints()
    statusFS:SetJustifyH("LEFT")
    applyStatusVisual(icon, statusFS, item.status)

    if item.extra then
        statusBtn:EnableMouse(false)
    else
        statusBtn:SetScript("OnClick", function()
            GameTooltip:Hide()
            if BlingtronApp.BonusRoll.CycleItemStatus(sourceKey, item.id) then
                RefreshBoard()
            end
        end)
        statusBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Item status")
            GameTooltip:AddLine("Click to cycle: not looted (—), bonus-rolled (BR), looted (Loot).", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        statusBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    iconBtn:SetScript("OnEnter", function(self)
        showItemTooltip(self, item)
    end)
    iconBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return cell
end

local function addMenuInitialize(_, level)
    if level ~= 1 then
        return
    end
    local row = addMenuRow
    local list = row and row.extraCandidates or {}
    if #list == 0 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "No other loot-pool items"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        return
    end
    for _, item in ipairs(list) do
        local itemID = item.id
        local sourceKey = row.key
        local info = UIDropDownMenu_CreateInfo()
        info.text = item.name or ("Item " .. tostring(itemID))
        info.notCheckable = true
        info.icon = itemIconTexture(itemID)
        info.func = function()
            CloseDropDownMenus()
            if BlingtronApp.BonusRoll.SetItemStatus(sourceKey, itemID, "rolled") then
                RefreshBoard()
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

local function openAddMenu(anchor, row)
    addMenuRow = row
    if not addMenuFrame then
        addMenuFrame = CreateFrame("Frame", "BlingtronAppBonusRollAddMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(addMenuFrame, addMenuInitialize, "MENU")
    ToggleDropDownMenu(1, nil, addMenuFrame, anchor, 0, 0)
end

local function makeRow(parent, row, y, index, maxItems, maxExtraItems)
    local width = contentWidth(maxItems, maxExtraItems)
    local rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:SetSize(width, ROW_H)
    rowFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

    local bg = rowFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(1, 1, 1, 0.04)
    else
        bg:SetColorTexture(0, 0, 0, 0.15)
    end

    local x = PAD
    local nameFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameFS:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", x, -4)
    nameFS:SetSize(NAME_W - 6, 16)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetJustifyV("TOP")
    nameFS:SetText(row.name)

    local subFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, 0)
    subFS:SetSize(NAME_W - 6, 14)
    subFS:SetJustifyH("LEFT")
    subFS:SetText(row.subName or "")

    x = x + NAME_W
    local tierFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tierFS:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", x, -4)
    tierFS:SetSize(TIER_W - 6, ROW_H - 8)
    tierFS:SetJustifyH("LEFT")
    tierFS:SetJustifyV("MIDDLE")
    if row.tier then
        setQualityText(tierFS, TIER_QUALITY[row.tier] or 1, string.format("%s (%.1f)", row.tier, row.score))
    else
        setQualityText(tierFS, 0, string.format("%.1f", row.score or 0))
    end

    x = x + TIER_W
    local saveFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    saveFS:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", x, -4)
    saveFS:SetSize(SAVE_W - 6, ROW_H - 8)
    saveFS:SetJustifyH("LEFT")
    saveFS:SetJustifyV("MIDDLE")
    if row.saving then
        local saveText = BlingtronApp.BonusRoll.FormatSaveText(row.saving)
        local saveTier = BlingtronApp.BonusRoll.SaveToTier(row.saving)
        setQualityText(saveFS, TIER_QUALITY[saveTier] or 1, saveText or string.format("%.1f", row.saving))
    else
        setQualityText(saveFS, 0, "-")
    end

    x = x + SAVE_W
    for i = 1, maxItems do
        local item = row.items[i]
        if item then
            makeItemCell(rowFrame, x, -2, item, row.key)
        end
        x = x + ITEM_W
    end

    local extraItems = row.extraItems or {}
    for i = 1, maxExtraItems do
        local item = extraItems[i]
        if item then
            makeItemCell(rowFrame, x, -2, item, row.key)
        end
        x = x + ITEM_W
    end

    local addBtn = CreateFrame("Button", nil, rowFrame, "UIPanelButtonTemplate")
    addBtn:SetSize(ADD_W - 6, 22)
    addBtn:SetPoint("LEFT", rowFrame, "LEFT", x + 2, 0)
    addBtn:SetText("Add BR")
    local hasCandidates = row.extraCandidates and #row.extraCandidates > 0
    if hasCandidates then
        addBtn:Enable()
    else
        addBtn:Disable()
    end
    addBtn:SetScript("OnClick", function(self)
        openAddMenu(self, row)
    end)
    addBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Add bonus-rolled item")
        GameTooltip:AddLine("Mark other loot-pool items (not on your targeted list) as bonus-rolled. That removes them from this source's remaining pool.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    addBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return rowFrame
end

function RefreshBoard()
    if not frame or not scrollChild then
        return
    end
    if CloseDropDownMenus then
        CloseDropDownMenus()
    end
    local oldScroll = 0
    if scrollFrame then
        oldScroll = scrollFrame:GetVerticalScroll() or 0
    end
    wipeChildren(scrollChild)

    local data, err = BlingtronApp.BonusRoll.GetBoardData()
    if not data then
        subtitle:SetText("")
        statusText:SetText(err or "Could not load bonus-roll data.")
        scrollChild:SetSize(400, 40)
        return
    end

    subtitle:SetText(data.specName .. "  |  " .. data.bisLabel)
    statusText:SetText(string.format("%d sources", #data.rows))

    sortRows(data.rows)

    local maxItems = data.maxItems or 0
    local maxExtraItems = data.maxExtraItems or 0
    local width = contentWidth(maxItems, maxExtraItems)
    local height = HEADER_H + (#data.rows * ROW_H) + PAD

    local header = CreateFrame("Frame", nil, scrollChild)
    header:SetSize(width, HEADER_H)
    header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0, 0, 0, 0.45)
    addHeaderCell(header, PAD, NAME_W, "Name")
    addSortHeader(header, PAD + NAME_W, TIER_W, "BR Tier", "score", "brTier")
    addSortHeader(header, PAD + NAME_W + TIER_W, SAVE_W, "BR Save", "saving", "brSave")
    local itemX = PAD + NAME_W + TIER_W + SAVE_W
    for i = 1, maxItems do
        addHeaderCell(header, itemX + (i - 1) * ITEM_W, ITEM_W, tostring(i))
    end
    local extraX = itemX + maxItems * ITEM_W
    for i = 1, maxExtraItems do
        addHeaderCell(header, extraX + (i - 1) * ITEM_W, ITEM_W, "+")
    end
    addHeaderCell(header, extraX + maxExtraItems * ITEM_W, ADD_W, "Add")

    for i, row in ipairs(data.rows) do
        local y = -(HEADER_H + (i - 1) * ROW_H)
        makeRow(scrollChild, row, y, i, maxItems, maxExtraItems)
    end

    scrollChild:SetSize(width, height)
    frame:SetWidth(math.max(420, width + 44))
    if scrollFrame then
        local viewHeight = scrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, height - viewHeight)
        scrollFrame:SetVerticalScroll(math.min(oldScroll, maxScroll))
    end
end

local function CreateBoardFrame()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "BlingtronAppBonusRollFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(420, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "BlingtronAppBonusRollFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -5)
    title:SetText((BlingtronApp.logoIcon or "") .. " Bonus Rolls")

    local optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsBtn:SetSize(130, 22)
    optionsBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
    optionsBtn:SetText("Options & Tools")
    optionsBtn:SetScript("OnClick", function()
        if BlingtronApp.ShowMainMenu then
            BlingtronApp:ShowMainMenu()
        end
    end)

    subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    subtitle:SetPoint("RIGHT", optionsBtn, "LEFT", -8, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("MIDDLE")
    subtitle:SetWordWrap(false)
    if subtitle.SetMaxLines then
        subtitle:SetMaxLines(1)
    end

    scrollFrame = CreateFrame("ScrollFrame", "BlingtronAppBonusRollScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 28)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(400, 200)
    scrollFrame:SetScrollChild(scrollChild)

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 10)
    statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)
    statusText:SetJustifyH("LEFT")

    frame:SetScript("OnShow", RefreshBoard)
end

function BlingtronApp:HideBonusRollFrame()
    if frame then
        frame:Hide()
    end
end

function BlingtronApp:ShowBonusRollFrame()
    CreateBoardFrame()
    if BlingtronApp.HideMainMenu then
        BlingtronApp:HideMainMenu()
    end
    if BlingtronApp.HideGuildNoteSync then
        BlingtronApp:HideGuildNoteSync()
    end
    if not frame:IsShown() then
        frame:Show()
    end
    RefreshBoard()
end

function BlingtronApp:ToggleBonusRollFrame()
    CreateBoardFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:ShowBonusRollFrame()
    end
end
