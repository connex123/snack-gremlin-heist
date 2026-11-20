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

check(Catalog.count() >= 64, "at least 64 gremlins, got " .. Catalog.count())
-- every body recipe distinct: no two gremlins share shape + hat + extra, or body + accent colours
local recipes, colours = {}, {}
for _, g in Catalog.list do
	local r = g.recipe
	local key = r.shape .. "|" .. r.hat .. "|" .. tostring(r.extra)
	check(not recipes[key], "recipe " .. key .. " shared by " .. g.name .. " and " .. tostring(recipes[key]))
	recipes[key] = g.name
	local c = r.body:ToHex() .. r.accent:ToHex()
	check(not colours[c], "colours shared by " .. g.name)
	colours[c] = g.name
end
-- more of the cast at the top: each tier from Legendary up has at least 6
for _, name in { "Legendary", "Mythic", "Divine", "Secret" } do
	check(#Catalog.byRarity[name] >= 6, name .. " has 6+ gremlins")
end
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
check(#Mutations.list == 8, "8 mutations")
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
-- feature strip: counts come from the tables, systems only when started
local FeatureList = load("FeatureList")
local strip = FeatureList.build(5, { LagoonSurge = true, Rebirth = true })
check(strip:find(Catalog.count() .. " GREMLINS", 1, true) ~= nil, "strip gremlin count: " .. strip)
check(strip:find(#Mutations.list .. " MUTATIONS", 1, true) ~= nil, "strip mutation count")
check(strip:find("5 EVENTS", 1, true) ~= nil and strip:find("SURGE", 1, true) ~= nil, "strip events and surge")
check(strip:find("BOSS", 1, true) == nil, "strip leaves out systems that did not start")
local full = FeatureList.build(5, { LagoonSurge = true, PocketPirates = true, OgaPepperpot = true, ShutterLock = true, FusePot = true, MarketOrders = true, Rebirth = true })
local l1, l2 = FeatureList.twoLines(full)
check(l1 .. FeatureList.SEPARATOR .. l2 == full, "strip lines join back to the full text")
check(math.max(#l1, #l2) <= math.ceil(#full / 2) + 8, "strip lines are balanced: " .. #l1 .. " / " .. #l2)
check(FeatureList.twoLines("ONE") == "ONE", "single-part strip stays one line")
-- market orders
local OrderBook = load("OrderBook")
local buy = OrderBook.make(OrderBook.template("buy"), 100, 0.99)
check(buy.goal == 4 and buy.rewardCash == 100 * 40 * 4, "buy order goal and reward")
check(not OrderBook.apply(buy, "whack", 1), "other kinds do not count")
OrderBook.apply(buy, "buy", 3)
check(buy.progress == 3 and not buy.done, "buy progress")
check(OrderBook.apply(buy, "buy", 1) and buy.done, "buy completes")
local rare = OrderBook.make(OrderBook.template("placeRare"), 0, 0)
check(not OrderBook.apply(rare, "place", 1, "Uncommon"), "Uncommon is not Rare+")
check(OrderBook.apply(rare, "place", 1, "Epic") and rare.reward == "Epic gremlin", "Epic counts for Rare+")
check(#OrderBook.candidates({}, false) == #OrderBook.TEMPLATES - 1, "boss order only with the boss")
-- fuse pot
local FuseRules = load("FuseRules")
check(FuseRules.nextRarity("Common") == "Uncommon" and FuseRules.nextRarity("Secret") == nil, "fuse ladder")
local function rarityOf(id) local g = Catalog.get(id) return g and g.rarity end
local function incomeOf(id) local g = Catalog.get(id) return g and g.income or 0 end
local slots = { [1] = { id = "SuyaSamurai" }, [2] = { id = "PuffPuffPaladin" }, [3] = { id = "KilishiKnight" }, [5] = { id = "GarriGoblin" }, [7] = { id = "PlantainPharaoh" }, [8] = { id = "TigerNutToad" } }
local fr, fi = FuseRules.findFusable(slots, rarityOf, incomeOf)
check(fr == "Common" and fi and #fi == 3 and fi[1] == 2, "fuses the lowest rarity with 3, cheapest first: " .. tostring(fr))
check(FuseRules.findFusable({ [1] = { id = "SuyaSamurai" } }, rarityOf, incomeOf) == nil, "nothing to fuse")
print("strip line 1: " .. l1)
print("strip line 2: " .. l2)
print(failures == 0 and "ALL CHECKS PASSED" or (failures .. " FAILURES"))
