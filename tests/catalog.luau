-- Pure-logic checks for the shared modules, run with: lune run tests/catalog.luau
-- Loads src/shared modules with a tiny stand-in for Roblox's `script` and Color3.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local cache = {}
local function load(name)
	if cache[name] then
		return cache[name]
	end
	local source = fs.readFile("src/shared/" .. name .. ".luau")
	local parent = setmetatable({}, { __index = function(_, k) return k end })
	local env = setmetatable({
		script = { Parent = parent },
		require = function(n) return load(n) end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		Enum = roblox.Enum,
	}, { __index = _G })
	local fn = luau.load(source, { debugName = name, environment = env })
	cache[name] = fn()
	return cache[name]
end

local Format = load("Format")
local Rarities = load("Rarities")
local Mutations = load("Mutations")
local Catalog = load("GremlinCatalog")
local Config = load("Config")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("FAIL: " .. msg)
	end
end

check(Format.money(0) == "$0", "money 0: " .. Format.money(0))
check(Format.money(1250) == "$1.25K", "1250: " .. Format.money(1250))
check(Format.money(48650000) == "$48.6M", "48.65M: " .. Format.money(48650000))
check(Format.perSecond(2500) == "+$2.5K/s", "rate: " .. Format.perSecond(2500))
check(Format.money(999) == "$999", "999: " .. Format.money(999))

check(Catalog.count() >= 40, "at least 40 gremlins, got " .. Catalog.count())
local seen = {}
for _, g in Catalog.list do
	check(not seen[g.id], "unique id " .. g.id)
	seen[g.id] = true
	check(Rarities.byName[g.rarity] ~= nil, "rarity of " .. g.name)
	check(g.price > g.income, "price above income for " .. g.name)
end
for _, r in Rarities.list do
	check(Catalog.byRarity[r.name] and #Catalog.byRarity[r.name] >= 3, "3+ gremlins in " .. r.name)
end
-- each tier's cheapest costs more than the previous tier's cheapest
local prevMin = 0
for _, r in Rarities.list do
	local min = math.huge
	for _, g in Catalog.byRarity[r.name] do
		min = math.min(min, g.price)
	end
	check(min > prevMin, r.name .. " cheapest above previous tier")
	prevMin = min
end
check(#Mutations.list >= 6, "6+ mutations")
check(Rarities.rollRarity(0, 0) == "Common", "roll 0 is Common")
check(Rarities.rollRarity(0.99999, 0) == "Secret", "roll ~1 is Secret")
check(Mutations.rollMutation(0.5, 0.5, 1) == nil, "no mutation on high roll")
check(Mutations.rollMutation(0.01, 0, 1) == "Gold", "Gold on low roll")
check(Config.upgradeCost("pedestals", 0) == 250, "first pedestal cost")
check(Config.upgradeCost("pedestals", 6) == nil, "pedestals max")

-- shot director ids exist
for _, id in { "PuffPuffPaladin", "JollofJetpack", "DanfoDragon", "SuyaSamurai", "ZoboZeppelin", "AmalaArchmage", "GeneratorSeraph", "PlantainPharaoh", "KilishiKnight", "AkaraAstronaut", "TuwoTitan", "OkraOctopus", "MoiMoiMonk", "ChinChinCheetah", "OgbonoOverlord" } do
	check(Catalog.byId[id] ~= nil, "catalog has " .. id)
end

for _, r in Rarities.list do
	local names = {}
	for _, g in Catalog.byRarity[r.name] do
		table.insert(names, g.name .. " $" .. Format.short(g.price))
	end
	print(r.name .. ": " .. table.concat(names, ", "))
end
print(failures == 0 and "ALL CHECKS PASSED" or (failures .. " FAILURES"))
