-- MobKillTracker/MobKillTracker_UI.lua

local rows         = {}
local UpdateList
local totalMobsText
local totalKillsText
local selectedCharKey  -- nil = current logged-in character
local charButton       -- forward ref (assigned after frame exists)
local pickerButtons    = {}
local sortMode         = "kills"  -- "kills" or "name"

--------------------------------------------------
-- Main frame
--------------------------------------------------

local frame = AlnUI:CreateDialog({
    name       = "MobKillTrackerFrame",
    title      = "Mob Kill Tracker",
    titleWidth = 300,
    width      = 460,
    height     = 500,
})

--------------------------------------------------
-- Column headers
--------------------------------------------------

AlnUI:CreateColumnRow(frame, { font = "GameFontNormal", x = 24, y = -44 }, {
    { text = "Mob",       width = 220, justify = "LEFT" },
    { text = "Character", width = 90,  justify = "RIGHT" },
    { text = "Total",     width = 90,  justify = "RIGHT", gap = 6 },
})

--------------------------------------------------
-- Scroll frame
--------------------------------------------------

local scroll, content = AlnUI:CreateScrollFrame(frame, {
    x1 = 18,  y1 = -62,
    x2 = -36, y2 = 50,
    contentWidth  = 360,
    contentHeight = 400,
})

--------------------------------------------------
-- Row cleanup
--------------------------------------------------

local function ClearRows()
    for _, fs in ipairs(rows) do
        fs:Hide()
        fs:SetParent(nil)
    end
    wipe(rows)
end

--------------------------------------------------
-- Kill count color codes (matching main tracker tiers)
--------------------------------------------------

local function KillColorCode(total)
    if     total >= 2000 then return "|cffff8000"   -- orange
    elseif total >= 800  then return "|cffa335ee"   -- purple
    elseif total >= 300  then return "|cff0070dd"   -- blue
    elseif total >= 120  then return "|cff1ece1e"   -- green
    elseif total >= 30   then return "|cffffffff"   -- white
    else                      return "|cff999999"   -- gray
    end
end

--------------------------------------------------
-- Theme
--------------------------------------------------

local THEME_TEXTURES = {
    gold     = { edge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", header = "Interface\\DialogFrame\\UI-DialogBox-Gold-Header" },
    standard = { edge = "Interface\\DialogFrame\\UI-DialogBox-Border",      header = "Interface\\DialogFrame\\UI-DialogBox-Header" },
}

local function ApplyTheme()
    local isGold = MobKillTrackerDB and MobKillTrackerDB.options and MobKillTrackerDB.options.goldenTheme
    local t = isGold and THEME_TEXTURES.gold or THEME_TEXTURES.standard
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = t.edge,
        edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    if frame.titleBanner then
        frame.titleBanner:SetTexture(t.header)
    end
end

MobKillTracker.ApplyWindowTheme = ApplyTheme

--------------------------------------------------
-- Strip realm suffix from a character key
--------------------------------------------------

local function ShortName(key)
    return key:match("^([^%-]+)") or key
end

--------------------------------------------------
-- Build sorted mob list
--------------------------------------------------

local function GetSortedMobs()
    if not MobKillTrackerDB or not MobKillTrackerDB.total then
        return {}
    end

    local charKey   = selectedCharKey or MobKillTracker.characterKey
    local charKills = (charKey
        and MobKillTrackerDB.characters[charKey]
        and MobKillTrackerDB.characters[charKey].kills)
        or {}

    local result = {}
    for npcID, total in pairs(MobKillTrackerDB.total) do
        if total > 0 then
            table.insert(result, {
                npcID = npcID,
                name  = MobKillTrackerDB.names[npcID] or ("NPC #" .. npcID),
                total = total,
                mine  = charKills[npcID] or 0,
            })
        end
    end

    if sortMode == "name" then
        table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    elseif sortMode == "killschar" then
        table.sort(result, function(a, b) return a.mine > b.mine end)
    else
        table.sort(result, function(a, b) return a.total > b.total end)
    end
    return result
end

--------------------------------------------------
-- Character picker popup
--------------------------------------------------

local pickerFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
pickerFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
pickerFrame:SetFrameStrata("DIALOG")
pickerFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
pickerFrame:Hide()

local function HidePicker()
    pickerFrame:Hide()
end

local function ShowPicker()
    -- Remove old buttons
    for _, btn in ipairs(pickerButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(pickerButtons)

    -- Collect characters that have at least one kill recorded
    local chars = {}
    if MobKillTrackerDB and MobKillTrackerDB.characters then
        for key, data in pairs(MobKillTrackerDB.characters) do
            if data.kills then
                for _, v in pairs(data.kills) do
                    if v > 0 then
                        table.insert(chars, key)
                        break
                    end
                end
            end
        end
    end
    table.sort(chars)

    if #chars == 0 then return end

    local btnHeight = 22
    local btnWidth  = 160
    local padding   = 6
    local activeKey = selectedCharKey or MobKillTracker.characterKey

    for i, key in ipairs(chars) do
        local btn = CreateFrame("Button", nil, pickerFrame, "UIPanelButtonTemplate")
        btn:SetSize(btnWidth, btnHeight)
        btn:SetPoint("TOPLEFT", padding, -padding - (i - 1) * (btnHeight + 2))
        btn:SetText(ShortName(key))

        -- Highlight the currently active character
        if key == activeKey then
            btn:GetFontString():SetTextColor(1, 0.82, 0)
        end

        btn:SetScript("OnClick", function()
            selectedCharKey = key
            charButton:SetText(ShortName(key))
            HidePicker()
            UpdateList()
        end)

        table.insert(pickerButtons, btn)
    end

    local totalH = padding * 2 + #chars * (btnHeight + 2)
    pickerFrame:SetSize(btnWidth + padding * 2, totalH)
    pickerFrame:SetPoint("BOTTOMLEFT", charButton, "TOPLEFT", 0, 4)
    pickerFrame:Show()
end

--------------------------------------------------
-- Update list
--------------------------------------------------

function UpdateList()
    ClearRows()

    local data       = GetSortedMobs()
    local rowHeight  = 22
    local startY     = -8
    local grandTotal = 0

    for i, entry in ipairs(data) do
        local y        = startY - (i - 1) * rowHeight
        local mineStr  = KillColorCode(entry.mine)  .. entry.mine  .. "|r"
        local totalStr = KillColorCode(entry.total) .. entry.total .. "|r"

        local cols = AlnUI:CreateColumnRow(content, { y = y }, {
            { text = entry.name, width = 220, justify = "LEFT",  wordWrap = false },
            { text = mineStr,    width = 90,  justify = "RIGHT" },
            { text = totalStr,   width = 90,  justify = "RIGHT", gap = 6 },
        })

        cols[1]:SetScript("OnEnter", function(self)
            if self:IsTruncated() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(entry.name, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        cols[1]:SetScript("OnLeave", GameTooltip_Hide)

        for _, fs in ipairs(cols) do table.insert(rows, fs) end

        grandTotal = grandTotal + entry.total
    end

    content:SetHeight(math.max(400, (#data + 1) * rowHeight))

    totalMobsText:SetText("Mobs tracked: " .. #data)
    totalKillsText:SetText("Total kills: "  .. grandTotal)
end

--------------------------------------------------
-- Totals
--------------------------------------------------

totalMobsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
totalMobsText:SetPoint("BOTTOMLEFT", 20, 30)
totalMobsText:SetJustifyH("LEFT")
totalMobsText:SetText("Mobs tracked: 0")
totalMobsText:SetTextColor(1, 0.82, 0)

totalKillsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
totalKillsText:SetPoint("TOPLEFT", totalMobsText, "BOTTOMLEFT", 0, -2)
totalKillsText:SetJustifyH("LEFT")
totalKillsText:SetText("Total kills: 0")
totalKillsText:SetTextColor(1, 0.82, 0)

--------------------------------------------------
-- Character selector button (bottom-right)
--------------------------------------------------

charButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
charButton:SetSize(140, 22)
charButton:SetPoint("BOTTOMRIGHT", -16, 16)
charButton:SetText("Character")

--------------------------------------------------
-- Sort toggle button
--------------------------------------------------

local sortButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
sortButton:SetSize(110, 22)
sortButton:SetPoint("BOTTOMRIGHT", charButton, "BOTTOMLEFT", -6, 0)
sortButton:SetText("Sort: Kills")

sortButton:SetScript("OnClick", function()
    if sortMode == "kills" then
        sortMode = "name"
        sortButton:SetText("Sort: Name")
    elseif sortMode == "name" then
        sortMode = "killschar"
        sortButton:SetText("Sort: Kills (C)")
    else
        sortMode = "kills"
        sortButton:SetText("Sort: Kills")
    end
    UpdateList()
end)

charButton:SetScript("OnClick", function()
    if pickerFrame:IsShown() then
        HidePicker()
    else
        ShowPicker()
    end
end)

-- Sync label, theme, and close picker whenever the window opens
frame:HookScript("OnShow", function()
    ApplyTheme()
    local key = selectedCharKey or MobKillTracker.characterKey
    charButton:SetText(key and ShortName(key) or "Character")
    HidePicker()
end)

--------------------------------------------------
-- Slash command: "list" toggles the window;
-- everything else delegates to the original handler.
--------------------------------------------------

local origSlash = SlashCmdList["MOBKILLTRACKER"]
SlashCmdList["MOBKILLTRACKER"] = function(msg)
    if msg:lower() == "list" then
        if frame:IsShown() then
            frame:Hide()
        else
            UpdateList()
            frame:Show()
        end
    else
        origSlash(msg)
    end
end
