local ADDON_NAME = ...
local MKT = CreateFrame("Frame")

-- Configuration ------------------------------
local DEBUG = true

-- Runtime-only caches ------------------------------
local NPCNameCache = {}
local SessionKills = {}

-- Helper functions ------------------------------
local function GetKillColor(total)
	if total >= 2000 then
		return 1.00, 0.50, 0.00 -- orange
	elseif total >= 500 then
		return 0.64, 0.21, 0.93 -- purple
	elseif total >= 100 then
		return 0.00, 0.44, 0.87 -- blue
	elseif total >= 20 then
		return 0.10, 0.80, 0.10 -- green
	elseif total >= 5 then
		return 0.60, 0.60, 0.60 -- gray
	else
		return 1.00, 1.00, 1.00 -- white
	end
end

local function TryCacheNPCName(unit)
	if not UnitExists(unit) then
		return
	end

	local npcID = UnitCreatureID(unit)
	if not npcID then
		return
	end

	local name = UnitName(unit)
	if not name then
		return
	end

	if not canaccessvalue(name) then
		return
	end

	NPCNameCache[npcID] = name
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

	CHARACTER_KEY = UnitName("player") .. "-" .. GetNormalizedRealmName()
	MobKillTrackerDB.characters[CHARACTER_KEY] = MobKillTrackerDB.characters[CHARACTER_KEY] or { kills = {} }
end

-- Kill tracking ------------------------------
local function OnPartyKill()
	local guid = UnitGUID("target")
	if not guid then
		return
	end

	local npcID = GetNPCIDFromGUID(guid)
	if not npcID then
		return
	end

	TryCacheNPCName("target")

	SessionKills[npcID] = (SessionKills[npcID] or 0) + 1

	local total = MobKillTrackerDB.total
	total[npcID] = (total[npcID] or 0) + 1

	local charKills = MobKillTrackerDB.characters[CHARACTER_KEY].kills
	charKills[npcID] = (charKills[npcID] or 0) + 1

	DebugPrint(
		("NPC %d kills (session %d): %d / %d"):format(npcID, SessionKills[npcID], charKills[npcID], total[npcID])
	)
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
	tooltip:AddDoubleLine("Kills", ("%d / %d"):format(charKills, total), 0.7, 0.7, 0.7, r, g, b)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddKillLine)

-- Slash commands ------------------------------
SLASH_MOBKILLTRACKER1 = "/mkt"

SlashCmdList["MOBKILLTRACKER"] = function(msg)
	msg = msg:lower()

	if msg == "reset all" then
		MobKillTrackerDB.total = {}
		for _, char in pairs(MobKillTrackerDB.characters) do
			char.kills = {}
		end
		print("MobKillTracker: all data reset.")
		return
	end

	if msg == "reset char" then
		MobKillTrackerDB.characters[CHARACTER_KEY].kills = {}
		print("MobKillTracker: character data reset.")
		return
	end

	if msg == "reset target" then
		local guid = UnitGUID("target")
		local npcID = guid and GetNPCIDFromGUID(guid)
		if npcID then
			MobKillTrackerDB.total[npcID] = nil
			MobKillTrackerDB.characters[CHARACTER_KEY].kills[npcID] = nil
			print("MobKillTracker: target NPC reset.")
		else
			print("MobKillTracker: no valid NPC targeted.")
		end
		return
	end

	if msg == "session" then
		print("|cff33ff99MobKillTracker — Session kills|r")

		if not next(SessionKills) then
			print("No kills recorded this session.")
			return
		end

		for npcID, count in pairs(SessionKills) do
			local name = NPCNameCache[npcID]
			if name then
				print(("%s — %d kill%s"):format(name, count, count == 1 and "" or "s"))
			else
				print(("NPC ID %d — %d kill%s"):format(npcID, count, count == 1 and "" or "s"))
			end
		end

		return
	end

	local resetID = msg:match("^reset%s+(%d+)$")
	if resetID then
		local npcID = tonumber(resetID)
		MobKillTrackerDB.total[npcID] = nil

		local charData = MobKillTrackerDB.characters[CHARACTER_KEY]
		if charData and charData.kills then
			charData.kills[npcID] = nil
		end
		SessionKills[npcID] = nil
		NPCNameCache[npcID] = nil

		print(("MobKillTracker: NPC ID %d reset."):format(npcID))
		return
	end

	print("|cff33ff99MobKillTracker commands:|r")
	print("/mkt reset all - reset all characters")
	print("/mkt reset char - reset current character")
	print("/mkt reset target - reset current target NPC")
	print("/mkt reset <ID> - reset a specific NPC by ID")
	print("/mkt session - show kills this session")
end

-- Events ------------------------------
local function OnEvent(_, event)
	if event == "PLAYER_LOGIN" then
		InitDB()
		MKT:RegisterEvent("PARTY_KILL")
		DebugPrint("Loaded.")
	elseif event == "PARTY_KILL" then
		OnPartyKill()
	end
end

MKT:RegisterEvent("PLAYER_LOGIN")
MKT:SetScript("OnEvent", OnEvent)
