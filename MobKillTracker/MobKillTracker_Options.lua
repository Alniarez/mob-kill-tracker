local ADDON_NAME = ...
local addon = {}

-- Ensure SavedVariables exist (options UI may load early)
MobKillTrackerDB = MobKillTrackerDB or {}
MobKillTrackerDB.options = MobKillTrackerDB.options or {}

-- Settings category  ------------------------------
local category, layout = Settings.RegisterVerticalLayoutCategory("MobKillTracker")
addon.settingsCategory = category

local function InitializeSettings()
	-- Tooltip options  ------------------------------
	local showSessionSetting = Settings.RegisterAddOnSetting(
		category, -- category
		"MKT_SHOW_SESSION_TOOLTIP", -- internal variable ID
		"showSessionInTooltip", -- key in options table
		MobKillTrackerDB.options, -- backing table (IMPORTANT)
		Settings.VarType.Boolean, -- type
		"Show session kills in tooltip", -- display name
		Settings.Default.False -- default
	)
	-- This was a bit confusing

	Settings.CreateCheckbox(category, showSessionSetting, "Displays the number of kills during the current session.")
	Settings.SetOnValueChangedCallback("MKT_SHOW_SESSION_TOOLTIP", function()
		MobKillTrackerDB.options.showSessionInTooltip = Settings.GetValue("MKT_SHOW_SESSION_TOOLTIP")
	end)

	-- Action buttons  ------------------------------
	local wipeAllInitializer = CreateSettingsButtonInitializer(
		"Erase all data", -- name
		"Erase all data", -- button text
		function()
			if MobKillTracker and MobKillTracker.DeleteAllData then
				MobKillTracker.DeleteAllData()
			end
		end,
		"Deletes all stored kill data for every character.",
		true -- addSearchTags (required)
	)

	local wipeCharInitializer = CreateSettingsButtonInitializer(
		"Erase character data",
		"Erase character data",
		function()
			if MobKillTracker and MobKillTracker.DeletedCharacterData then
				MobKillTracker.DeletedCharacterData()
			end
		end,
		"Deletes kill data for the current character only.",
		true
	)

	local addonLayout = SettingsPanel:GetLayout(category)
	addonLayout:AddInitializer(wipeAllInitializer)
	addonLayout:AddInitializer(wipeCharInitializer)

	Settings.RegisterAddOnCategory(category)
end

InitializeSettings()
