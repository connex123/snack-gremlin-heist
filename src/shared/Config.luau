-- Config: tuning numbers and cost formulas shared by server and client.
local Config = {}

Config.STARTING_CASH = 120
Config.INCOME_TICK = 1 -- seconds between income payouts

-- Market layout (studs). The Snack Belt runs along X at z = 0; stalls sit on both sides; the lagoon lies north.
Config.BELT_Z = 0
Config.BELT_TOP_Y = 3
Config.BELT_START_X = -150
Config.BELT_END_X = 150
Config.BELT_SPEED = 6
Config.BELT_SPAWN_INTERVAL = 2.4

Config.STALL_SPOTS = {
	Vector3.new(0, 0, 42), -- the first player's stall: south centre
	Vector3.new(-72, 0, 42),
	Vector3.new(72, 0, 42),
	Vector3.new(0, 0, -42),
	Vector3.new(-72, 0, -42),
	Vector3.new(72, 0, -42),
}
Config.STALL_FLOOR_HEIGHT = 1.6
Config.MAX_PEDESTALS = 10
Config.START_PEDESTALS = 4

Config.LAGOON_EDGE_Z = -78 -- water begins north of this line

-- Lagoon Surge
Config.SURGE_INTERVAL = 60
Config.SURGE_WARNING = 10
Config.SURGE_SPEED = 34
Config.SURGE_SAFE_HEIGHT = 7 -- standing higher than this (on a stilt deck) is safe

-- Pocket Pirates
Config.PIRATE_INTERVAL = 32
Config.PIRATE_WALK_SPEED = 11
Config.PIRATE_ESCAPE_SPEED = 9
Config.WHACK_RANGE = 14
Config.WHACK_BOUNTY_SECONDS = 10 -- a whack pays this many seconds of your income

-- Shutter Lock
Config.LOCK_BASE_SECONDS = 45
Config.LOCK_COOLDOWN = 20

-- Market events
Config.EVENT_INTERVAL = 70
Config.EVENT_DURATION = 25

-- Upgrades: cost = base * growth ^ level
Config.UPGRADES = {
	{ key = "pedestals", label = "More Pedestals", hint = "+1 pedestal on your stall", base = 250, growth = 3.4, max = Config.MAX_PEDESTALS - Config.START_PEDESTALS },
	{ key = "luck", label = "Belt Luck", hint = "rarer gremlins on the belt", base = 600, growth = 2.8, max = 10 },
	{ key = "speed", label = "Quick Feet", hint = "+2 walk speed", base = 180, growth = 2.3, max = 8 },
	{ key = "lockTime", label = "Longer Lock", hint = "+10 s Shutter Lock", base = 400, growth = 2.5, max = 6 },
}

function Config.upgradeInfo(key: string)
	for _, info in Config.UPGRADES do
		if info.key == key then
			return info
		end
	end
	return nil
end

function Config.upgradeCost(key: string, level: number): number?
	local info = Config.upgradeInfo(key)
	if not info or level >= info.max then
		return nil
	end
	return math.floor(info.base * info.growth ^ level)
end

function Config.lockSeconds(level: number): number
	return Config.LOCK_BASE_SECONDS + 10 * level
end

function Config.walkSpeed(level: number): number
	return 16 + 2 * level
end

-- Rebirth: costs grow x5 each time; each rebirth adds +50% income forever.
function Config.rebirthCost(rebirths: number): number
	return 250000 * 5 ^ rebirths
end

function Config.rebirthMultiplier(rebirths: number): number
	return 1 + 0.5 * rebirths
end

-- A new stall floor colour for every rebirth.
Config.REBIRTH_FLOORS = {
	Color3.fromRGB(255, 196, 0), -- danfo yellow
	Color3.fromRGB(0, 200, 190), -- lagoon teal
	Color3.fromRGB(255, 95, 110), -- coral
	Color3.fromRGB(160, 90, 255), -- violet
	Color3.fromRGB(80, 230, 120), -- lime
	Color3.fromRGB(255, 255, 255), -- pearl
}

function Config.floorColor(rebirths: number): Color3
	return Config.REBIRTH_FLOORS[(rebirths % #Config.REBIRTH_FLOORS) + 1]
end

return Config
