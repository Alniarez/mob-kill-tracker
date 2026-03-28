local ADDON_NAME = ...
local addon = {}

-- Ensure SavedVariables exist (options UI may load early)
MobKillTrackerDB = MobKillTrackerDB or {}
MobKillTrackerDB.options = MobKillTrackerDB.options or {}

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
	local goldenThemeSetting = Settings.RegisterAddOnSetting(
		category,
		"MKT_GOLDEN_THEME",
		"goldenTheme",
		MobKillTrackerDB.options,
		Settings.VarType.Boolean,
		"Golden theme",
		Settings.Default.False
	)

	Settings.CreateCheckbox(
		category,
		goldenThemeSetting,
		"Use a gold border and header on the kill list window."
	)

	Settings.SetOnValueChangedCallback("MKT_GOLDEN_THEME", function()
		MobKillTrackerDB.options.goldenTheme = Settings.GetValue("MKT_GOLDEN_THEME")
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
end

InitializeSettings()
