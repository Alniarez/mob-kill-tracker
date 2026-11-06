local ADDON_NAME = ...
local MKT = CreateFrame("Frame")

-- Configuration ------------------------------
local DEBUG = AlniDev and AlniDev.debug[ADDON_NAME] or false

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

local function GetNPCNameFromGUID(guid)
	if not guid or issecretvalue(guid) then
		return nil
	end

	local function GetNameIfMatch(unit)
		if UnitExists(unit) and UnitGUID(unit) == guid then
			local name = UnitName(unit)
			if name and name ~= "" then
				return name
			end
		end
	end

	-- target
	local name = GetNameIfMatch("target")
	if name then
		return name
	end

	-- mouseover
	name = GetNameIfMatch("mouseover")
	if name then
		return name
	end

	-- nameplates
	for i = 1, 40 do
		name = GetNameIfMatch("nameplate" .. i)
		if name then
			return name
		end
	end

	return nil
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
	MobKillTrackerDB.version = MobKillTrackerDB.version or 1 -- Storage DB version
	MobKillTrackerDB.total = MobKillTrackerDB.total or {}
	MobKillTrackerDB.characters = MobKillTrackerDB.characters or {}
	MobKillTrackerDB.names = MobKillTrackerDB.names or {}

	if MobKillTrackerDB.options == nil then
		MobKillTrackerDB.options = {}
	end
end

-- Characters are keyed by GUID, which survives renames and surname
-- changes. Each entry also keeps a display name, refreshed every login.
local function InitCharacter()
	local guid  = UnitGUID("player")
	local chars = MobKillTrackerDB.characters

	-- One-time move from the old "Name-Realm" key
	local oldKey = UnitName("player") .. "-" .. GetNormalizedRealmName()
	if not chars[guid] and chars[oldKey] then
		chars[guid] = chars[oldKey]
		chars[oldKey] = nil
		DebugPrint("Moved character data from " .. oldKey .. " to " .. guid .. ".")
	end

	chars[guid] = chars[guid] or { kills = {} }
	-- includes the surname on clients that have them
	chars[guid].name = GetUnitName("player", true) or UnitName("player")

	CHARACTER_KEY = guid
	MobKillTracker.characterKey = CHARACTER_KEY
end

-- Kill tracking ------------------------------
-- PARTY_KILL counts the player's and the group's killing blows. UNIT_DIED
-- fills in the two kills it never fires for:
--   * the pet's killing blow
--   * a mob the player fought that someone outside the group finished. Only
--     its tagger can loot the corpse, so it counts once looted.
local ENGAGED_KEEP_SEC = 60 -- a mob is ours this long after its last threat update
local PET_LEFT_KEEP_SEC = 60 -- the pet's kill can land after it switched targets
local CLAIM_KEEP_SEC = 300 -- how long a corpse waits for its loot
local PRUNE_SEC = 60

local counted = {} -- GUID -> true, so one death never counts twice
local engaged = {} -- GUID -> { at, name } while the player is on its threat list
local claimable = {} -- GUID -> when it died, waiting for its loot
local petTarget -- GUID the pet is on
local petLeft = {} -- GUID -> when the pet left it
local lastPrune = 0

-- Since 12.0 instances hide unit identity: GUIDs there are secret, and
-- comparing one is an error pcall can't catch. These handlers stay out.
local function InInstance()
	local _, kind = IsInInstance()
	return kind ~= nil and kind ~= "none"
end

local function ReadGUID(unit)
	local guid = UnitGUID(unit)
	if issecretvalue(guid) then
		return nil
	end
	return guid
end

-- Whether someone outside the group tagged the mob, read from any unit token
-- the client still has for it. False when unknown.
local function TaggedBySomeoneElse(guid)
	local token = UnitTokenFromGUID and UnitTokenFromGUID(guid)
	if not token or issecretvalue(token) then
		return false
	end
	local ok, denied = pcall(UnitIsTapDenied, token)
	return ok and not issecretvalue(denied) and denied == true
end

local function Prune()
	local now = GetTime()
	if now - lastPrune < PRUNE_SEC then
		return
	end
	lastPrune = now
	for guid, entry in pairs(engaged) do
		if now - entry.at > ENGAGED_KEEP_SEC then
			engaged[guid] = nil
		end
	end
	for guid, at in pairs(petLeft) do
		if now - at > PET_LEFT_KEEP_SEC then
			petLeft[guid] = nil
		end
	end
	for guid, at in pairs(claimable) do
		if now - at > CLAIM_KEEP_SEC then
			claimable[guid] = nil
		end
	end
end

local function RecordKill(guid, source)
	if not guid or issecretvalue(guid) or counted[guid] then
		return
	end

	local npcID = GetNPCIDFromGUID(guid)
	if not npcID then
		return
	end

	counted[guid] = true
	local fought = engaged[guid]
	engaged[guid] = nil
	claimable[guid] = nil
	local targetGUID = guid

	SessionKills[npcID] = (SessionKills[npcID] or 0) + 1

	local total = MobKillTrackerDB.total
	total[npcID] = (total[npcID] or 0) + 1

	local charKills = MobKillTrackerDB.characters[CHARACTER_KEY].kills
	charKills[npcID] = (charKills[npcID] or 0) + 1

	-- Best-effort name catalog ------------------------------
	-- the corpse may be gone from every unit token by now, so fall back to the
	-- name seen while fighting it
	local name = GetNPCNameFromGUID(targetGUID) or (fought and fought.name)

	local names = MobKillTrackerDB.names
	local existing = names[npcID]

	if name and name ~= "" then
		-- Prefer a real name over Unknown, but do not overwrite existing names
		if not existing or existing == "Unknown" then
			names[npcID] = name
		end
	end

	if DEBUG then
		local displayName = name or names[npcID] or "Unknown"
		DebugPrint(
			("NPC %s (%d) kills (session %d): %d / %d [%s]"):format(
				displayName, npcID, SessionKills[npcID], charKills[npcID], total[npcID], source
			)
		)
	end
end

-- A threat list changed (target, focus or a nameplate): note the mobs the
-- player is on, with their name while it can still be read.
local function OnThreatUpdate(unit)
	if not unit or issecretvalue(unit) then
		return
	end
	local guid = ReadGUID(unit)
	if not guid or not GetNPCIDFromGUID(guid) then
		return
	end
	local ok, status = pcall(UnitThreatSituation, "player", unit)
	if not ok or issecretvalue(status) or status == nil then
		return
	end
	local name = UnitName(unit)
	if issecretvalue(name) then
		name = nil
	end
	local entry = engaged[guid]
	engaged[guid] = { at = GetTime(), name = name or (entry and entry.name) }
end

-- The pet changed target: remember the mob it left, and the one it's on now.
local function OnPetTarget()
	local guid = ReadGUID("pettarget")
	if petTarget and petTarget ~= guid then
		petLeft[petTarget] = GetTime()
	end
	petTarget = guid
end

local function PetWasOn(guid)
	if petTarget == guid or ReadGUID("pettarget") == guid then
		return true
	end
	local left = petLeft[guid]
	return left ~= nil and GetTime() - left <= PET_LEFT_KEEP_SEC
end

-- Fires for every death the client sees, whoever caused it. The player's own
-- blows already counted through PARTY_KILL; this only takes the pet's, and
-- holds the mobs the player fought until their corpse is looted.
local function OnUnitDied(guid)
	if not guid or issecretvalue(guid) or counted[guid] then
		return
	end
	Prune()
	if PetWasOn(guid) and not TaggedBySomeoneElse(guid) then
		RecordKill(guid, "pet")
		return
	end
	local entry = engaged[guid]
	if entry and GetTime() - entry.at <= ENGAGED_KEEP_SEC then
		claimable[guid] = GetTime()
	end
end

-- A loot window: each slot names the corpses it comes from.
local function OnLoot()
	if not GetLootSourceInfo then
		return
	end
	for slot = 1, GetNumLootItems() do
		local sources = { GetLootSourceInfo(slot) }
		for i = 1, #sources, 2 do
			local guid = sources[i]
			if guid and not issecretvalue(guid) then
				local at = claimable[guid]
				if at and GetTime() - at <= CLAIM_KEEP_SEC then
					RecordKill(guid, "looted")
				end
			end
		end
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

function MobKillTracker.DeleteCharacterData()
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

    -- Debug: show NPC ID ------------------------------
    if MobKillTrackerDB
        and MobKillTrackerDB.options
        and MobKillTrackerDB.options.showCreatureID
    then
        tooltip:AddDoubleLine(
            "Creature ID",
            ("|cff00ccff%d|r"):format(npcID),
            0.7, 0.7, 0.7,
            1.0, 1.0, 1.0
        )
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

	print("|cffffff00/mkt list|r " .. "|cffbbbbbb- show the kill list window|r")
	print("|cffffff00/mkt delete all|r " .. "|cffbbbbbb- delete all characters|r")
	print("|cffffff00/mkt delete character|r " .. "|cffbbbbbb- delete current character|r")
	print("|cffffff00/mkt delete target|r " .. "|cffbbbbbb- delete current target NPC|r")
	print("|cffffff00/mkt delete |cff00ccff<ID>|r " .. "|cffbbbbbb- delete a specific NPC by ID|r")
end

-- Events ------------------------------
-- RegisterEvent raises on an event the client doesn't know; a missing extra
-- source must not stop PARTY_KILL from counting.
local function SafeRegister(event, unit)
	local ok, registered
	if unit then
		ok, registered = pcall(MKT.RegisterUnitEvent, MKT, event, unit)
	else
		ok, registered = pcall(MKT.RegisterEvent, MKT, event)
	end
	if not ok or registered == false then
		DebugPrint("Could not register " .. event .. ".")
	end
end

local function OnEvent(_, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == ADDON_NAME then
			InitDB()
			MKT:UnregisterEvent("ADDON_LOADED")
			DebugPrint("Loaded.")
		end
	elseif event == "PLAYER_LOGIN" then
		InitCharacter()
		MKT:RegisterEvent("PARTY_KILL")
		SafeRegister("UNIT_DIED")
		SafeRegister("UNIT_THREAT_LIST_UPDATE")
		SafeRegister("UNIT_TARGET", "pet")
		SafeRegister("LOOT_READY")
		SafeRegister("LOOT_OPENED")
	elseif event == "PARTY_KILL" then
		local _, targetGUID = ...
		RecordKill(targetGUID, "killing blow")
	elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
		OnLoot()
	elseif InInstance() then
		-- the payloads below are secret in instances
		return
	elseif event == "UNIT_DIED" then
		OnUnitDied((...))
	elseif event == "UNIT_THREAT_LIST_UPDATE" then
		OnThreatUpdate((...))
	elseif event == "UNIT_TARGET" then
		OnPetTarget()
	end
end

MKT:RegisterEvent("ADDON_LOADED")
MKT:RegisterEvent("PLAYER_LOGIN")
MKT:SetScript("OnEvent", OnEvent)
