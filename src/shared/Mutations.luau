-- Mutations: rare variants that multiply a gremlin's income and change its look.
local Mutations = {}

export type Mutation = {
	name: string,
	multiplier: number,
	color: Color3,
	material: Enum.Material,
	weight: number,
	particle: Color3,
	effect: string?, -- particle style: nil sparkle, "haze" drifting dust, "lace" shimmering pattern + sparkles
}

Mutations.list = {
	{ name = "Gold", multiplier = 2, color = Color3.fromRGB(255, 200, 40), material = Enum.Material.Foil, weight = 40, particle = Color3.fromRGB(255, 230, 120) },
	{ name = "Pepper", multiplier = 2.5, color = Color3.fromRGB(235, 40, 30), material = Enum.Material.SmoothPlastic, weight = 30, particle = Color3.fromRGB(255, 120, 20) },
	{ name = "Diamond", multiplier = 3, color = Color3.fromRGB(150, 235, 255), material = Enum.Material.Glass, weight = 20, particle = Color3.fromRGB(210, 250, 255) },
	{ name = "Lagoon", multiplier = 3.5, color = Color3.fromRGB(20, 200, 190), material = Enum.Material.Glass, weight = 16, particle = Color3.fromRGB(120, 255, 240) },
	{ name = "Neon", multiplier = 4, color = Color3.fromRGB(255, 60, 200), material = Enum.Material.Neon, weight = 10, particle = Color3.fromRGB(255, 120, 230) },
	{ name = "Harmattan", multiplier = 4.5, color = Color3.fromRGB(226, 180, 98), material = Enum.Material.Sand, weight = 8, particle = Color3.fromRGB(255, 214, 140), effect = "haze" },
	{ name = "Owambe Lace", multiplier = 5, color = Color3.fromRGB(196, 120, 255), material = Enum.Material.Fabric, weight = 6, particle = Color3.fromRGB(255, 225, 120), effect = "lace" },
	{ name = "Rainbow", multiplier = 6, color = Color3.fromRGB(255, 120, 60), material = Enum.Material.Neon, weight = 4, particle = Color3.fromRGB(255, 255, 255) },
} :: { Mutation }

Mutations.byName = {} :: { [string]: Mutation }
for _, mutation in Mutations.list do
	Mutations.byName[mutation.name] = mutation
end

-- Base chance that a belt gremlin arrives mutated (Pepper Hour multiplies it).
Mutations.BASE_CHANCE = 0.06

function Mutations.get(name: string?): Mutation?
	if name == nil then
		return nil
	end
	return Mutations.byName[name]
end

function Mutations.multiplierOf(name: string?): number
	local mutation = Mutations.get(name)
	return mutation and mutation.multiplier or 1
end

-- Picks a mutation from two 0..1 rolls: the first decides whether, the second which.
function Mutations.rollMutation(chanceRoll: number, pickRoll: number, chanceMultiplier: number): string?
	if chanceRoll > Mutations.BASE_CHANCE * chanceMultiplier then
		return nil
	end
	local total = 0
	for _, mutation in Mutations.list do
		total += mutation.weight
	end
	local pick = pickRoll * total
	for _, mutation in Mutations.list do
		pick -= mutation.weight
		if pick <= 0 then
			return mutation.name
		end
	end
	return Mutations.list[1].name
end

return Mutations
