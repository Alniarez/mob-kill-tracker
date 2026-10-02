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

-- Settings category  ------------------------------
local category, layout = Settings.RegisterVerticalLayoutCategory("MobKillTracker")
addon.settingsCategory = category

local function InitializeSettings()

	-- Tooltip options ------------------------------
	local showSessionSetting = Settings.RegisterAddOnSetting(
		category, -- category
		"MKT_SHOW_SESSION_TOOLTIP",  -- internal variable ID
		"showSessionInTooltip",  -- key in options table
		MobKillTrackerDB.options,  -- backing table (IMPORTANT)
		Settings.VarType.Boolean,  -- type
		"Show session kills in tooltip",  -- display name
		Settings.Default.False -- default
	)

	Settings.CreateCheckbox(
		category,
		showSessionSetting,
		"Displays the number of kills during the current session."
	)

	Settings.SetOnValueChangedCallback("MKT_SHOW_SESSION_TOOLTIP", function()
		MobKillTrackerDB.options.showSessionInTooltip = Settings.GetValue("MKT_SHOW_SESSION_TOOLTIP")
	end)

	-- Window options ------------------------------
	-- The theme used to be a "Golden theme" checkbox; carry it over once
	local options = MobKillTrackerDB.options
	if options.theme == nil then
		options.theme = options.goldenTheme and "gold" or "standard"
	end

	local themeSetting = Settings.RegisterAddOnSetting(
		category,
		"MKT_THEME",
		"theme",
		options,
		Settings.VarType.String,
		"Window theme",
		"standard"
	)

	-- every theme AlnUI can draw on this client
	local function GetThemeOptions()
		local container = Settings.CreateControlTextContainer()
		for _, name in ipairs(AlnUI:GetThemes()) do
			container:Add(name, name:sub(1, 1):upper() .. name:sub(2), THEME_DESCRIPTIONS[name])
		end
		return container:GetData()
	end

	Settings.CreateDropdown(
		category,
		themeSetting,
		GetThemeOptions,
		"The border and title style of the kill list window."
	)

	Settings.SetOnValueChangedCallback("MKT_THEME", function()
		MobKillTrackerDB.options.theme = Settings.GetValue("MKT_THEME")
		if MobKillTracker.ApplyWindowTheme then
			MobKillTracker.ApplyWindowTheme()
		end
	end)

	-- Action buttons ------------------------------
	local wipeAllInitializer = CreateSettingsButtonInitializer(
		"Erase all data",
		"Erase all data",
		function()
			if MobKillTracker and MobKillTracker.DeleteAllData then
				MobKillTracker.DeleteAllData()
			end
		end,
		"Deletes all stored kill data for every character.",
		true
	)

	local wipeCharInitializer = CreateSettingsButtonInitializer(
		"Erase character data",
		"Erase character data",
		function()
			if MobKillTracker and MobKillTracker.DeleteCharacterData then
				MobKillTracker.DeleteCharacterData()
			end
		end,
		"Deletes kill data for the current character only.",
		true
	)

	local addonLayout = SettingsPanel:GetLayout(category)
	addonLayout:AddInitializer(wipeAllInitializer)
	addonLayout:AddInitializer(wipeCharInitializer)

	-- Debug section ------------------------------
	addonLayout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Debug"))

	local showIDSetting = Settings.RegisterAddOnSetting(
		category,
		"MKT_SHOW_CREATURE_ID",
		"showCreatureID",
		MobKillTrackerDB.options,
		Settings.VarType.Boolean,
		"Show creature ID",
		Settings.Default.False
	)

	Settings.CreateCheckbox(
		category,
		showIDSetting,
		"Displays the NPC ID of the creature in the tooltip."
	)

	Settings.SetOnValueChangedCallback("MKT_SHOW_CREATURE_ID", function()
		MobKillTrackerDB.options.showCreatureID = Settings.GetValue("MKT_SHOW_CREATURE_ID")
	end)

	Settings.RegisterAddOnCategory(category)

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
