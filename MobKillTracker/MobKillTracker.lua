local ADDON_NAME = ...
local MKT = CreateFrame("Frame")

-- Configuration ------------------------------
local DEBUG = false

-- Runtime-only caches ------------------------------
local SessionKills = {}

-- Helper functions ------------------------------
local function GetKillColor(total)
	if total >= 2000 then
		return 1.00, 0.50, 0.00 -- orange
	elseif total >= 800 then
		return 0.64, 0.21, 0.93 -- purple
	elseif total >= 300 then
		return 0.00, 0.44, 0.87 -- blue
	elseif total >= 120 then
		return 0.10, 0.80, 0.10 -- green
	elseif total >= 30 then
		return 1.00, 1.00, 1.00 -- white
	else
		return 0.60, 0.60, 0.60 -- gray
	end
end

local function GetNPCIDFromGUID(guid)
	if not guid or issecretvalue(guid) then
		return nil
	end

	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	if unitType == "Creature" or unitType == "Vehicle" then
		return tonumber(npcID)
	end
end

local function DebugPrint(...)
	if not DEBUG then
		return
	end
	print("|cff33ff99" .. ADDON_NAME .. ":|r", ...)
end

-- SavedVariables ------------------------------
local CHARACTER_KEY

local function InitDB()
	MobKillTrackerDB = MobKillTrackerDB or {}
	MobKillTrackerDB.version = MobKillTrackerDB.version or 1
	MobKillTrackerDB.total = MobKillTrackerDB.total or {}
	MobKillTrackerDB.characters = MobKillTrackerDB.characters or {}

	if MobKillTrackerDB.options == nil then
		MobKillTrackerDB.options = {}
	end

	if Settings.SetValue and MobKillTrackerDB.options.showSessionInTooltip ~= nil then
		Settings.SetValue("MKT_SHOW_SESSION_TOOLTIP", MobKillTrackerDB.options.showSessionInTooltip)
	end

	CHARACTER_KEY = UnitName("player") .. "-" .. GetNormalizedRealmName()
	MobKillTrackerDB.characters[CHARACTER_KEY] = MobKillTrackerDB.characters[CHARACTER_KEY] or { kills = {} }
end

-- Kill tracking ------------------------------
local function OnPartyKill(_attackerGUID, targetGUID)
	local npcID = targetGUID and GetNPCIDFromGUID(targetGUID)
	if not npcID then
		return
	end

	SessionKills[npcID] = (SessionKills[npcID] or 0) + 1

	local total = MobKillTrackerDB.total
	total[npcID] = (total[npcID] or 0) + 1

	local charKills = MobKillTrackerDB.characters[CHARACTER_KEY].kills
	charKills[npcID] = (charKills[npcID] or 0) + 1

	if DEBUG then
		DebugPrint(
			("NPC %d kills (session %d): %d / %d"):format(npcID, SessionKills[npcID], charKills[npcID], total[npcID])
		)
	end
end

-- MobKillTracker logic ------------------------------
MobKillTracker = {}
function MobKillTracker.DeleteAllData()
	MobKillTrackerDB.total = {}

	for _, char in pairs(MobKillTrackerDB.characters) do
		char.kills = {}
	end

	SessionKills = {}

	DebugPrint("All data reset.")
end

function MobKillTracker.DeletedCharacterData()
	if MobKillTrackerDB.characters[CHARACTER_KEY] then
		MobKillTrackerDB.characters[CHARACTER_KEY].kills = {}
	end

	DebugPrint("Character data reset.")
end

-- Tooltip  ------------------------------
local function AddKillLine(tooltip)
	if not MobKillTrackerDB or not CHARACTER_KEY then
		return
	end

	local data = tooltip:GetTooltipData()
	if not data then
		return
	end

	local npcID

	if data.unitToken then
		npcID = UnitCreatureID(data.unitToken)
	end

	if not npcID and data.guid and not issecretvalue(data.guid) then
		npcID = GetNPCIDFromGUID(data.guid)
	end

	if not npcID then
		return
	end

	local total = MobKillTrackerDB.total[npcID]
	if not total or total <= 0 then
		return
	end

	local charKills = MobKillTrackerDB.characters[CHARACTER_KEY].kills[npcID] or 0

	local r, g, b = GetKillColor(total)
	local rightText = ("%d / %d"):format(charKills, total)

	if Settings.GetValue("MKT_SHOW_SESSION_TOOLTIP") then
		local session = SessionKills[npcID] or 0
		if session > 0 then
			rightText = rightText .. (" |cff66ccff(session %d)|r"):format(session)
		end
	end

	tooltip:AddDoubleLine(
		"Kills",
		rightText,
		0.7,
		0.7,
		0.7, -- left label color
		r,
		g,
		b -- right text color
	)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddKillLine)

-- Slash commands ------------------------------
SLASH_MOBKILLTRACKER1 = "/mkt"

SlashCmdList["MOBKILLTRACKER"] = function(msg)
	msg = msg:lower()

	local prefix = "|cff33ff99MobKillTracker:|r "

	if msg == "delete all" then
		MobKillTracker.DeleteAllData()
		print(prefix .. "|cffff5555all data deleted.|r")
		return
	end

	if msg == "delete character" or msg == "delete char" then
		MobKillTracker.DeleteCharacterData()
		print(prefix .. "|cffff5555character data deleted.|r")
		return
	end

	if msg == "delete target" or msg == "delete tar" then
		local guid = UnitGUID("target")
		local npcID = guid and GetNPCIDFromGUID(guid)
		if npcID then
			MobKillTrackerDB.total[npcID] = nil
			MobKillTrackerDB.characters[CHARACTER_KEY].kills[npcID] = nil
			SessionKills[npcID] = nil
			print(prefix .. ("|cffffaa00target NPC |cff00ccff%d|r |cffff5555deleted.|r"):format(npcID))
		else
			print(prefix .. "|cffff3333no valid NPC targeted.|r")
		end
		return
	end

	local deleteID = msg:match("^delete%s+(%d+)$")
	if deleteID then
		local npcID = tonumber(deleteID)
		MobKillTrackerDB.total[npcID] = nil

		local charData = MobKillTrackerDB.characters[CHARACTER_KEY]
		if charData and charData.kills then
			charData.kills[npcID] = nil
		end
		SessionKills[npcID] = nil

		print(prefix .. ("|cffffaa00NPC ID |cff00ccff%d|r |cffff5555deleted.|r"):format(npcID))
		return
	end

	-- Help
	print("|cff33ff99MobKillTracker commands:|r")

	print("|cffffff00/mkt delete all|r " .. "|cffbbbbbb- delete all characters|r")
	print("|cffffff00/mkt delete character|r " .. "|cffbbbbbb- delete current character|r")
	print("|cffffff00/mkt delete target|r " .. "|cffbbbbbb- delete current target NPC|r")
	print("|cffffff00/mkt delete |cff00ccff<ID>|r " .. "|cffbbbbbb- delete a specific NPC by ID|r")
end

-- Events ------------------------------
local function OnEvent(_, event, ...)
	if event == "PLAYER_LOGIN" then
		InitDB()
		MKT:RegisterEvent("PARTY_KILL")
		DebugPrint("Loaded.")
	elseif event == "PARTY_KILL" then
		local attackerGUID, targetGUID = ...
		OnPartyKill(attackerGUID, targetGUID)
	end
end

MKT:RegisterEvent("PLAYER_LOGIN")
MKT:SetScript("OnEvent", OnEvent)
