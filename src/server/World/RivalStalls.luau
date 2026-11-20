-- RivalStalls: bot vendors fill the empty stalls with gremlins so the market looks alive, and now and
-- then swap one for a fresh catch from the belt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Stalls = require(script.Parent.Parent.Stalls)

local RivalStalls = {}

RivalStalls.NAMES = { "AUNTIE BISI'S BITES", "CHEF TUNDE'S GRILL", "MAMA NGOZI'S POT", "BABA SULE'S SKEWERS", "SISI EKO SNACKS" }

local rng = Random.new(42)

-- The Studio shot director sets this (os.clock time) so rival stalls do not change mid-shot.
RivalStalls.holdUntil = 0

-- One restock pass over every rival stall.
function RivalStalls.restock()
	for _, plot in Stalls.plots do
		if plot.rivalName then
			local index = Stalls.firstFreePedestal(plot)
			if index and index <= 9 then
				local id, mutation = RivalStalls.rollRivalGremlin()
				Stalls.placeGremlin(plot, id, mutation, index)
			elseif rng:NextNumber() < 0.5 then
				local swap = rng:NextInteger(1, 9)
				Stalls.removeGremlin(plot, swap)
				local id, mutation = RivalStalls.rollRivalGremlin()
				Stalls.placeGremlin(plot, id, mutation, swap)
			end
		end
	end
end

-- A rival's gremlin: rolled with high luck so their stalls look tempting.
function RivalStalls.rollRivalGremlin(): (string, string?)
	local rarity = Rarities.rollRarity(rng:NextNumber(), 6)
	local gremlin = GremlinCatalog.pickOfRarity(rarity, rng:NextNumber())
	return gremlin.id, Mutations.rollMutation(rng:NextNumber(), rng:NextNumber(), 3)
end

function RivalStalls.stockPlot(plot)
	local count = rng:NextInteger(6, 9)
	for index = 1, count do
		local id, mutation = RivalStalls.rollRivalGremlin()
		Stalls.placeGremlin(plot, id, mutation, index)
	end
end

-- Every stall without a player gets a rival vendor (call once players have claimed theirs).
function RivalStalls.fillEmptyStalls()
	local n = 0
	for _, plot in Stalls.plots do
		-- stall 1 (south centre) stays open for the first player
		if plot.index ~= 1 and not plot.owner and not plot.rivalName then
			n += 1
			plot.rivalName = RivalStalls.NAMES[(n - 1) % #RivalStalls.NAMES + 1]
			plot.signLabel.Text = plot.rivalName
			Stalls.refreshPlot(plot)
			RivalStalls.stockPlot(plot)
		end
	end
end

-- Keeps rival stalls stocked and changing.
function RivalStalls.start()
	task.spawn(function()
		while true do
			task.wait(20)
			if os.clock() >= RivalStalls.holdUntil then
				local ok, err = pcall(RivalStalls.restock)
				if not ok then
					warn("Rival restock failed: " .. tostring(err))
				end
			end
		end
	end)
end

return RivalStalls
