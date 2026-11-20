-- FuseRules: pure rules for the Fuse Pot. Three gremlins of the same rarity on a stall cook into one
-- gremlin of the next rarity, with a chance of a mutation. Secret is the top: Secrets never fuse.
local Rarities = require(script.Parent.Rarities)

local FuseRules = {}

FuseRules.COUNT = 3
FuseRules.MUTATION_CHANCE = 0.25

-- The next rarity up, or nil at the top.
function FuseRules.nextRarity(rarityName: string): string?
	local tier = Rarities.get(rarityName).tier
	local next = Rarities.list[tier + 1]
	return next and next.name or nil
end

-- Finds the lowest rarity with three gremlins on the stall. `slots` maps pedestal -> { id }, and
-- `rarityOf(id)` returns a gremlin's rarity. Returns the rarity and the three pedestal indices (lowest
-- earners first, so the stall keeps its best), or nil.
function FuseRules.findFusable(slots: { [number]: { id: string } }, rarityOf: (string) -> string?, incomeOf: (string) -> number): (string?, { number }?)
	local byRarity: { [string]: { number } } = {}
	for index, slot in slots do
		local rarity = rarityOf(slot.id)
		if rarity and FuseRules.nextRarity(rarity) then
			byRarity[rarity] = byRarity[rarity] or {}
			table.insert(byRarity[rarity], index)
		end
	end
	for _, rarity in Rarities.list do
		local indices = byRarity[rarity.name]
		if indices and #indices >= FuseRules.COUNT then
			table.sort(indices, function(a, b)
				local ia, ib = incomeOf(slots[a].id), incomeOf(slots[b].id)
				if ia == ib then
					return a < b
				end
				return ia < ib
			end)
			return rarity.name, { indices[1], indices[2], indices[3] }
		end
	end
	return nil, nil
end

return FuseRules
