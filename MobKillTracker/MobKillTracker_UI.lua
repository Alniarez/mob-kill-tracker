-- MobKillTracker/MobKillTracker_UI.lua

local UpdateList
local totalMobsText
local totalKillsText
local selectedCharKey  -- nil = current logged-in character
local charDropdown     -- nil on clients without the native dropdown
local sortKey          -- "name", "mine", "total", or nil for the default order
local sortAscending    = false

--------------------------------------------------
-- Main frame
--------------------------------------------------

local frame = AlnUI:CreateDialog({
    name       = "MobKillTrackerFrame",
    title      = "Mob Kill Tracker",
    titleWidth = 300,
    width      = 460,
    height     = 500,
    -- wide enough for the totals and the character dropdown
    resizable  = true,
    minWidth   = 360,
    minHeight  = 250,
    onResize   = function(w, h)
        MobKillTrackerDB.listSize = { width = w, height = h }
    end,
})

--------------------------------------------------
-- Column headers
--------------------------------------------------

-- Click a column to sort: ascending, descending, then back to the default
-- order (most total kills first). Mob fills the width left over, so the
-- columns follow the window size.
-- right = 40: the list's 36 inset for the scroll bar + the rows' 4
AlnUI:CreateSortHeader(frame, {
    x = 24, y = -44, right = 40,
    onSort = function(key, ascending)
        sortKey, sortAscending = key, ascending == true
        UpdateList()
    end,
}, {
    { text = "Mob",       key = "name",  fill  = true, justify = "LEFT" },
    { text = "Character", key = "mine",  width = 86,   justify = "RIGHT" },
    { text = "Total",     key = "total", width = 86,   justify = "RIGHT", gap = 6 },
})

AlnUI:CreateSeparator(frame, { y = -60, x1 = 18, x2 = -18 })

--------------------------------------------------
-- Kill list
--------------------------------------------------

-- Shows the full mob name when the Mob column is cut off
local function RowTooltip(row)
    local name = row.cols[1]
    if name:IsTruncated() then return name:GetText() end
end

local list = AlnUI:CreateScrollList(frame, {
    x1 = 18,  y1 = -64,
    x2 = -36, y2 = 56,
    rowHeight = 22,
    x         = 6,
    right     = 4,
    columns   = {
        { fill  = true, justify = "LEFT",  wordWrap = false },
        { width = 86,   justify = "RIGHT" },
        { width = 86,   justify = "RIGHT", gap = 6 },
    },
    -- rows are recycled, so the tooltip reads whatever the row shows now
    onRowInit = function(row)
        if not row.alnTooltip then AlnUI:AddTooltip(row, RowTooltip) end
    end,
})

-- anchored to the bottom so it stays just under the list while resizing
local bottomLine = AlnUI:CreateSeparator(frame, { x1 = 18, x2 = -18 })
bottomLine:ClearAllPoints()
bottomLine:SetPoint("BOTTOMLEFT", 18, 52)
bottomLine:SetPoint("BOTTOMRIGHT", -18, 52)

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

local function ApplyTheme()
    local options = MobKillTrackerDB and MobKillTrackerDB.options
    frame:SetTheme(options and options.theme or "standard")
end

MobKillTracker.ApplyWindowTheme = ApplyTheme

--------------------------------------------------
-- Name to show for a character entry
--------------------------------------------------

-- Entries keyed by GUID store their name (with surname where the client
-- has them). Characters not logged in since the switch to GUID keys still
-- use an old "Name-Realm" key, so strip the realm from those.
local function CharacterName(key, data)
    return data.name or key:match("^([^%-]+)") or key
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

    table.sort(result, function(a, b)
        -- default order: most total kills first
        if sortKey == nil then
            if a.total ~= b.total then return a.total > b.total end
            return a.name:lower() < b.name:lower()
        end
        local x, y = a[sortKey], b[sortKey]
        if sortKey == "name" then x, y = x:lower(), y:lower() end
        if x == y then return a.npcID < b.npcID end
        if sortAscending then return x < y end
        return x > y
    end)
    return result
end

--------------------------------------------------
-- Characters with at least one kill recorded
--------------------------------------------------

local function GetCharacterOptions()
    local options = {}
    if MobKillTrackerDB and MobKillTrackerDB.characters then
        for key, data in pairs(MobKillTrackerDB.characters) do
            if data.kills then
                for _, v in pairs(data.kills) do
                    if v > 0 then
                        table.insert(options, { value = key, label = CharacterName(key, data) })
                        break
                    end
                end
            end
        end
    end
    table.sort(options, function(a, b) return a.label < b.label end)
    return options
end

--------------------------------------------------
-- Update list
--------------------------------------------------

function UpdateList()
    local data       = GetSortedMobs()
    local rows       = {}
    local grandTotal = 0

    for i, entry in ipairs(data) do
        rows[i] = {
            entry.name,
            KillColorCode(entry.mine)  .. entry.mine  .. "|r",
            KillColorCode(entry.total) .. entry.total .. "|r",
        }
        grandTotal = grandTotal + entry.total
    end

    list:SetData(rows)

    totalMobsText:SetText("Mobs tracked: " .. #data)
    totalKillsText:SetText("Total kills: "  .. grandTotal)
end

--------------------------------------------------
-- Totals
--------------------------------------------------

totalMobsText = AlnUI:CreateLabel(frame, { text = "Mobs tracked: 0", color = { 1, 0.82, 0 } })
totalMobsText:SetPoint("BOTTOMLEFT", 20, 30)

totalKillsText = AlnUI:CreateLabel(frame, { text = "Total kills: 0", color = { 1, 0.82, 0 } })
totalKillsText:SetPoint("TOPLEFT", totalMobsText, "BOTTOMLEFT", 0, -2)

--------------------------------------------------
-- Character selector (bottom-right)
--------------------------------------------------

if AlnUI:HasDropdown() then
    charDropdown = AlnUI:CreateDropdown(frame, {
        width       = 140,
        placeholder = "Character",
        tooltip     = "Character",
        tooltipText = "Whose kills to show in the Character column.",
        onChange    = function(key)
            selectedCharKey = key
            UpdateList()
        end,
    })
    charDropdown:SetPoint("BOTTOMRIGHT", -26, 16)
end

-- Sync size, theme and the character list whenever the window opens
local sizeRestored = false
frame:HookScript("OnShow", function()
    -- SavedVariables aren't loaded when this file runs, so restore here
    local size = MobKillTrackerDB and MobKillTrackerDB.listSize
    if size and not sizeRestored then
        frame:SetClampedSize(size.width, size.height)
    end
    sizeRestored = true

    ApplyTheme()
    if charDropdown then
        charDropdown:SetOptions(GetCharacterOptions())
        charDropdown:SetValue(selectedCharKey or MobKillTracker.characterKey)
    end
end)

--------------------------------------------------
-- Toggle the kill list window
--------------------------------------------------

function MobKillTracker.ToggleList()
    if frame:IsShown() then
        frame:Hide()
    else
        UpdateList()
        frame:Show()
    end
end

--------------------------------------------------
-- Slash command: "list" toggles the window;
-- everything else delegates to the original handler.
--------------------------------------------------

local origSlash = SlashCmdList["MOBKILLTRACKER"]
SlashCmdList["MOBKILLTRACKER"] = function(msg)
    if msg:lower() == "list" then
        MobKillTracker.ToggleList()
    else
        origSlash(msg)
    end
end
