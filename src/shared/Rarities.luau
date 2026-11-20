-- Rarities: the eight-step ladder, its colours, belt odds, payback time and model scale.
local Rarities = {}

export type Rarity = {
	name: string,
	tier: number,
	color: Color3,
	beltWeight: number,
	payback: number,
	scale: number,
}

Rarities.list = {
	{ name = "Common", tier = 1, color = Color3.fromRGB(200, 205, 215), beltWeight = 50, payback = 12, scale = 1.0 },
	{ name = "Uncommon", tier = 2, color = Color3.fromRGB(90, 230, 110), beltWeight = 26, payback = 20, scale = 1.06 },
	{ name = "Rare", tier = 3, color = Color3.fromRGB(70, 170, 255), beltWeight = 13, payback = 35, scale = 1.12 },
	{ name = "Epic", tier = 4, color = Color3.fromRGB(190, 90, 255), beltWeight = 7, payback = 55, scale = 1.2 },
	{ name = "Legendary", tier = 5, color = Color3.fromRGB(255, 190, 40), beltWeight = 3.2, payback = 80, scale = 1.3 },
	{ name = "Mythic", tier = 6, color = Color3.fromRGB(255, 70, 90), beltWeight = 1.1, payback = 120, scale = 1.4 },
	{ name = "Divine", tier = 7, color = Color3.fromRGB(120, 255, 240), beltWeight = 0.3, payback = 170, scale = 1.5 },
	{ name = "Secret", tier = 8, color = Color3.fromRGB(255, 255, 255), beltWeight = 0.07, payback = 240, scale = 1.6 },
} :: { Rarity }

Rarities.byName = {} :: { [string]: Rarity }
for _, rarity in Rarities.list do
	Rarities.byName[rarity.name] = rarity
end

function Rarities.get(name: string): Rarity
	return Rarities.byName[name] or Rarities.list[1]
end

-- Belt Luck raises the weight of every tier above Common: +25% per level per tier step.
function Rarities.weightWithLuck(rarity: Rarity, luckLevel: number): number
	return rarity.beltWeight * (1 + luckLevel * 0.25 * (rarity.tier - 1))
end

-- Picks a rarity name from a 0..1 roll, so tests can drive it without randomness.
function Rarities.rollRarity(roll: number, luckLevel: number): string
	local total = 0
	for _, rarity in Rarities.list do
		total += Rarities.weightWithLuck(rarity, luckLevel)
	end
	local pick = roll * total
	for _, rarity in Rarities.list do
		pick -= Rarities.weightWithLuck(rarity, luckLevel)
		if pick <= 0 then
			return rarity.name
		end
	end
	return Rarities.list[#Rarities.list].name
end

return Rarities
