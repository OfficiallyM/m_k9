Config = {}
Config = setmetatable(Config, {})

-- Restricts the dog to getting into certain vehicles
Config.VehicleRestriction = false
Config.VehiclesList = {
	
}

Config.OpenDoorsOnSearch = true

-- Used for Random Search Type --
Config.Items = {
	"joint",
	"cokebaggy",
	"crack_baggy",
	"xtcbaggy",
	"weed_white-widow",
	"weed_skunk",
	"weed_purple-haze",
	"weed_og-kush",
	"weed_amnesia",
	"weed_ak47",
	"weed_brick",
	"coke_brick",
	"coke_small_brick",
	"puremeth",
	"meth"
}

-- Language --
Config.LanguageChoice = "English"
Config.Languages = {
	["English"] = {
		follow = "Come",
		stop = "Heel",
		attack = "Bite",
		enter = "In",
		exit = "Out"
	}
}

Config.KeyDefaults = {
	-- Open K9 menu.
	open_menu = "numpad5",

	-- Toggle K9 attacking.
	toggle_attack = "numpad8",

	-- Toggle K9 following/heeling.
	toggle_follow = "numpad4",

	-- Toggle K9 entering/exiting vehicles.
	toggle_vehicle = "numpad6",
}