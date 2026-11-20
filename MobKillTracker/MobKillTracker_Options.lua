local ADDON_NAME = ...
local addon = {}

-- What each window theme looks like, for the theme dropdown's tooltips
local THEME_DESCRIPTIONS = {
	basic    = "Blizzard's classic metal frame with a title bar.",
	gold     = "A gold dialog border with a title banner.",
	modern   = "The Game Menu's border and header.",
	panel    = "Blizzard's modern frame, as on the Character window.",
	standard = "A grey dialog border with a title banner.",
	tooltip  = "A tooltip's thin border.",
}

-- every theme AlnUI can draw on this client
local function GetThemeOptions()
	local list = {}
	for _, name in ipairs(AlnUI:GetThemes()) do
		table.insert(list, { value = name, label = name:sub(1, 1):upper() .. name:sub(2), tooltip = THEME_DESCRIPTIONS[name] })
	end
	return list
end

local function InitializeSettings()
	local options = MobKillTrackerDB.options

	-- The theme used to be a "Golden theme" checkbox; carry it over once
	if options.theme == nil then
		options.theme = options.goldenTheme and "gold" or "standard"
	end
	if options.showSessionInTooltip == nil then
		options.showSessionInTooltip = false
	end
	if options.showCreatureID == nil then
		options.showCreatureID = false
	end

	local page = AlnUI:CreateSettingsPage({ name = "MobKillTracker" })

	page:AddCheckbox({
		label   = "Show session kills in tooltip",
		tooltip = "Displays the number of kills during the current session.",
		get     = function() return options.showSessionInTooltip end,
		set     = function(value) options.showSessionInTooltip = value end,
	})

	page:AddDropdown({
		label   = "Window theme",
		tooltip = "The border and title style of the kill list window.",
		options = GetThemeOptions,
		get     = function() return options.theme end,
		set     = function(value)
			options.theme = value
			if MobKillTracker.ApplyWindowTheme then
				MobKillTracker.ApplyWindowTheme()
			end
		end,
	})

	page:AddButton({
		label   = "Erase all data",
		text    = "Erase all data",
		tooltip = "Deletes all stored kill data for every character.",
		onClick = function()
			if MobKillTracker and MobKillTracker.DeleteAllData then
				MobKillTracker.DeleteAllData()
			end
		end,
	})

	page:AddButton({
		label   = "Erase character data",
		text    = "Erase character data",
		tooltip = "Deletes kill data for the current character only.",
		onClick = function()
			if MobKillTracker and MobKillTracker.DeleteCharacterData then
				MobKillTracker.DeleteCharacterData()
			end
		end,
	})

	page:AddHeader("Debug")

	page:AddCheckbox({
		label   = "Show creature ID",
		tooltip = "Displays the NPC ID of the creature in the tooltip.",
		get     = function() return options.showCreatureID end,
		set     = function(value) options.showCreatureID = value end,
	})

	local category = page:Register()
	addon.settingsCategory = category

	-- AddOn Compartment ------------------------------
	if AddonCompartmentFrame then
		AddonCompartmentFrame:RegisterAddon({
			text                = "Mob Kill Tracker",
			icon                = "Interface\\Icons\\Inv_misc_noteblank2b",
			registerForAnyClick = true,
			func                = function()
				if GetMouseButtonClicked() == "RightButton" then
					Settings.OpenToCategory(category:GetID())
				elseif MobKillTracker and MobKillTracker.ToggleList then
					MobKillTracker.ToggleList()
				end
			end,
			funcOnEnter = function(button)
				GameTooltip:SetOwner(button, "ANCHOR_LEFT")
				GameTooltip:AddLine("Mob Kill Tracker", 1, 0.82, 0)
				GameTooltip:AddLine("Left-click: toggle kill list", 1, 1, 1)
				GameTooltip:AddLine("Right-click: open settings", 1, 1, 1)
				GameTooltip:Show()
			end,
			funcOnLeave = function() GameTooltip:Hide() end,
		})
	end
end

local optionsFrame = CreateFrame("Frame")
optionsFrame:RegisterEvent("ADDON_LOADED")
optionsFrame:SetScript("OnEvent", function(_, event, addonName)
	if addonName == ADDON_NAME then
		InitializeSettings()
		optionsFrame:UnregisterEvent("ADDON_LOADED")
	end
end)
