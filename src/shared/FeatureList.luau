-- FeatureList: the thin "feature strip" line across the top of the HUD. Every count comes from the
-- game's own tables (catalogue, rarities, mutations, stall spots, events) and the system names are the
-- systems that actually started on the server, so the strip can never claim something the game lacks.
local GremlinCatalog = require(script.Parent.GremlinCatalog)
local Rarities = require(script.Parent.Rarities)
local Mutations = require(script.Parent.Mutations)
local Config = require(script.Parent.Config)

local FeatureList = {}

FeatureList.ATTRIBUTE = "FeatureStrip" -- ReplicatedStorage attribute the server writes and the client shows
FeatureList.SEPARATOR = " · "

-- Strip labels for the systems, in display order, keyed by the server's system name.
FeatureList.SYSTEM_LABELS = {
	{ system = "LagoonSurge", label = "SURGE" },
	{ system = "PocketPirates", label = "PIRATES" },
	{ system = "OgaPepperpot", label = "BOSS" },
	{ system = "ShutterLock", label = "LOCK" },
	{ system = "FusePot", label = "FUSE" },
	{ system = "MarketOrders", label = "ORDERS" },
	{ system = "Rebirth", label = "REBIRTH" },
}

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- The counts known to every side from shared tables.
function FeatureList.sharedCounts()
	return {
		gremlins = GremlinCatalog.count(),
		rarities = #Rarities.list,
		mutations = #Mutations.list,
		stalls = count(Config.STALL_SPOTS),
	}
end

-- Builds the strip text. `events` (number of timed events) and `started` (set of started system names)
-- are optional: without them the strip shows only the shared counts.
function FeatureList.build(events: number?, started: { [string]: boolean }?): string
	local c = FeatureList.sharedCounts()
	local parts = {
		c.gremlins .. " GREMLINS",
		c.rarities .. " RARITIES",
		c.mutations .. " MUTATIONS",
		c.stalls .. " STALLS",
	}
	if events and events > 0 then
		table.insert(parts, events .. " EVENTS")
	end
	if started then
		for _, entry in FeatureList.SYSTEM_LABELS do
			if started[entry.system] then
				table.insert(parts, entry.label)
			end
		end
	end
	return table.concat(parts, FeatureList.SEPARATOR)
end

FeatureList.count = count

return FeatureList
