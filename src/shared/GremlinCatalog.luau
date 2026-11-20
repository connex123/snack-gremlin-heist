-- GremlinCatalog: the cast of Snack Gremlins, street-food creatures of the lagoon night market.
-- Each has a rarity, a base income per second, a price (income x the rarity's payback) and a body recipe.
local Rarities = require(script.Parent.Rarities)

export type Recipe = {
	shape: string, -- "Block" | "Ball" | "Tall"
	body: Color3,
	accent: Color3,
	hat: string, -- prop on its head, built by GremlinModel
	extra: string?, -- optional second prop (wings, halo, cape, tail...)
}

export type Gremlin = {
	id: string,
	name: string,
	rarity: string,
	income: number,
	price: number,
	quip: string,
	recipe: Recipe,
}

local GremlinCatalog = {}

local function hex(code: string): Color3
	return Color3.fromHex(code)
end

-- name, rarity, income/s, shape, body, accent, hat, extra, quip
local CAST = {
	{ "Puff-Puff Paladin", "Common", 2, "Ball", "#E8A33D", "#FFF1C9", "bun", "cape", "Deep-fried and sworn to protect." },
	{ "Chin-Chin Cheetah", "Common", 3, "Block", "#F2C14E", "#7A4A1F", "ears", "tail", "Crunchy, fast, slightly sugary." },
	{ "Garri Goblin", "Common", 3, "Block", "#F4EBD0", "#C9B37E", "bowl", nil, "Soaks up anything. Including your cash." },
	{ "Pure Water Pixie", "Common", 4, "Tall", "#BFE9FF", "#2E8BE6", "sachet", "wings", "Bites the corner off every deal." },
	{ "Groundnut Gremlet", "Common", 4, "Ball", "#C68B59", "#7D4E2D", "shell", nil, "Shell-shocked, but in a fun way." },
	{ "Boli Bandit", "Common", 5, "Tall", "#F28C28", "#3B2A1A", "mask", nil, "Roasted. Toasted. Wanted." },
	{ "Kuli-Kuli Koala", "Common", 5, "Block", "#B5651D", "#E0B07A", "ears", nil, "Hugs the stall rails, chews loudly." },
	{ "Tiger Nut Toad", "Common", 6, "Ball", "#9C6B3E", "#E7C27D", "crown", nil, "Croaks in Pidgin, rules a puddle." },
	{ "Garri Ghost", "Common", 7, "Tall", "#FFF8E7", "#D9C48F", "ghost", "wings", "Drink it cold. It drinks you back." },

	{ "Akara Astronaut", "Uncommon", 12, "Ball", "#D9822B", "#FFFFFF", "helmet", "jetpack", "Bean fritter. Moon-bound. Oily orbit." },
	{ "Moi-Moi Monk", "Uncommon", 14, "Tall", "#D9534F", "#4E9A3E", "leaf", nil, "Meditates inside a leaf wrap." },
	{ "Zobo Zeppelin", "Uncommon", 16, "Ball", "#8B1E3F", "#F7C8D8", "balloon", nil, "Floats on hibiscus fizz and hope." },
	{ "Agege Bread Baron", "Uncommon", 18, "Block", "#F5DEB3", "#8B5A2B", "loaf", nil, "Owns the softest real estate in town." },
	{ "Meat Pie Mime", "Uncommon", 20, "Block", "#E3B26B", "#FFFFFF", "beret", nil, "Says nothing. Charges extra." },
	{ "Ewa Agoyin Ogre", "Uncommon", 22, "Ball", "#6B3E26", "#C0392B", "pot", nil, "Mashed beans, mighty roar." },
	{ "Kokoro Kangaroo", "Uncommon", 25, "Tall", "#E8C07D", "#9E6B2F", "ears", "tail", "Hops away with your snacks." },
	{ "Kunu Kelpie", "Uncommon", 27, "Ball", "#E9DCC0", "#8D6E4A", "fin", "tail", "Millet milk horse. Neighs in bubbles." },
	{ "Fura Phantom", "Uncommon", 30, "Block", "#F7F3E3", "#B08D57", "hood", nil, "Floats in a calabash at noon." },

	{ "Suya Samurai", "Rare", 60, "Block", "#8E2B12", "#F2B134", "skewer", "katana", "One cut. Perfect pepper." },
	{ "Kilishi Knight", "Rare", 70, "Block", "#6E1E0E", "#C0C0C0", "visor", "shield", "Armour made of dried beef." },
	{ "Plantain Pharaoh", "Rare", 80, "Tall", "#F7D23E", "#1F4E8C", "pyramid", nil, "Ripe on the outside, royal within." },
	{ "Shawarma Sheriff", "Rare", 90, "Tall", "#E6C38A", "#7B3F00", "cowboy", nil, "Wraps up every case." },
	{ "Abacha Acrobat", "Rare", 100, "Ball", "#F3E5AB", "#E67E22", "flip", nil, "Does cartwheels in palm oil." },
	{ "Fish Roll Phantom", "Rare", 115, "Tall", "#C9A26B", "#7FB3D5", "fin", "tail", "Appears at bus stops. Vanishes." },
	{ "Coconut Candy Comet", "Rare", 125, "Ball", "#FFF4E0", "#8B5E3C", "flame", "wings", "Crunches across the night sky." },
	{ "Dodo Duke", "Rare", 135, "Block", "#F4A300", "#5A2E0C", "crown", "cape", "Fried plantain nobility. Very ripe." },
	{ "Ojojo Ostrich", "Rare", 150, "Tall", "#C9A15B", "#4E7D2B", "beret", "wings", "Water-yam fritter on long legs." },

	{ "Jollof Jetpack", "Epic", 320, "Ball", "#E4572E", "#F3A712", "flame", "jetpack", "Party rice with a launch window." },
	{ "Pepper Soup Professor", "Epic", 380, "Block", "#B22222", "#FFFFFF", "graduate", nil, "Lectures you until you sweat." },
	{ "Egusi Emperor", "Epic", 440, "Ball", "#E9C46A", "#2A9D8F", "crown", "cape", "Rules from a bowl of melon seeds." },
	{ "Ofada Oracle", "Epic", 500, "Tall", "#5C8A3A", "#F4F1DE", "eye", nil, "Sees the future. It is spicy." },
	{ "Asun Assassin", "Epic", 580, "Block", "#4A1C10", "#FF3B1F", "mask", "katana", "Smoky goat, silent steps." },
	{ "Okra Octopus", "Epic", 660, "Ball", "#3FA34D", "#C7F2A4", "tentacles", nil, "Slippery deals, eight hands." },
	{ "Efo Riro Enchantress", "Epic", 720, "Tall", "#2E7D32", "#E53935", "wizard", "cape", "Spinach spells, pepper potions." },
	{ "Isi Ewu Inquisitor", "Epic", 790, "Block", "#5D4037", "#FFCA28", "hood", "shield", "Asks questions. Answers in goat." },
	{ "Gizdodo Gunslinger", "Epic", 860, "Tall", "#A0522D", "#F9A825", "cowboy", "katana", "Gizzard and plantain, fastest fork." },

	{ "Danfo Dragon", "Legendary", 2500, "Block", "#FFC107", "#111111", "horns", "wings", "Yellow, striped, never stops." },
	{ "Keke Kraken", "Legendary", 3000, "Ball", "#00A86B", "#FFD60A", "tentacles", "antenna", "Three wheels, nine arms." },
	{ "Ogbono Overlord", "Legendary", 3500, "Tall", "#556B2F", "#D4AF37", "tophat", "cape", "Stretchy soup, iron grip." },
	{ "Bole Baroness", "Legendary", 4100, "Tall", "#E25822", "#3E2723", "tiara", nil, "Charred to perfection, never late." },
	{ "Tuwo Titan", "Legendary", 4800, "Block", "#FAF3E0", "#8D6E63", "pot", "shield", "Rice-ball muscles, gentle heart." },
	{ "Ofe Owerri Oligarch", "Legendary", 5400, "Block", "#33691E", "#FFB300", "tophat", "wings", "Owns every leaf in the soup." },
	{ "Banga Soup Behemoth", "Legendary", 6000, "Ball", "#BF360C", "#FFE0B2", "horns", "shield", "Palm-nut armour, slow-cooked rage." },
	{ "Afang Admiral", "Legendary", 6700, "Tall", "#1B5E20", "#ECEFF1", "helmet", "cape", "Commands a fleet of soup bowls." },
	{ "Peppered Snail Sultan", "Legendary", 7500, "Ball", "#6D4C41", "#FF7043", "shell", "cape", "Slow. Spicy. Unstoppable." },

	{ "Amala Archmage", "Mythic", 18000, "Tall", "#3B2F2F", "#9B5DE5", "wizard", "halo", "Casts spells in dark yam flour." },
	{ "Pounded Yam Poltergeist", "Mythic", 22000, "Ball", "#FFFFFF", "#B8F2E6", "ghost", nil, "Haunts the mortar at midnight." },
	{ "Nkwobi Necromancer", "Mythic", 27000, "Block", "#7B2D26", "#7CFF6B", "hood", "staff", "Raises cow-foot from the dead." },
	{ "Ofe Nsala Sphinx", "Mythic", 33000, "Block", "#F0E2B6", "#1D3557", "pharaoh", "wings", "Answer its riddle or wash plates." },
	{ "Kunu Leviathan", "Mythic", 39000, "Ball", "#D7CCC8", "#00897B", "tentacles", "wings", "Rises from a cooler of millet milk." },
	{ "Edikang Ikong Enigma", "Mythic", 46000, "Tall", "#004D40", "#C6FF00", "eye", "halo", "Twelve leaves, one all-seeing eye." },
	{ "Ukodo Unicorn", "Mythic", 54000, "Block", "#FFF3E0", "#EC407A", "horns", "antenna", "Yam pepper soup with one golden horn." },

	{ "Generator Seraph", "Divine", 120000, "Block", "#F8F9FA", "#FFB703", "halo", "wings", "Lights up when the power goes out." },
	{ "Mama Put Goddess", "Divine", 160000, "Tall", "#FF6F91", "#FFC75F", "tiara", "halo", "One plate feeds a whole street." },
	{ "Big Pot Archangel", "Divine", 210000, "Ball", "#9E9E9E", "#FFFFFF", "pot", "wings", "Stirs the lagoon with a ladle." },
	{ "Agbalumo Angel", "Divine", 260000, "Ball", "#FF8F00", "#FFF59D", "tiara", "wings", "Sticky-sweet blessings, in season only." },
	{ "Catfish Pepper Celestial", "Divine", 320000, "Tall", "#455A64", "#FF5252", "fin", "halo", "Swims through clouds of pepper steam." },
	{ "Dodo Deity", "Divine", 390000, "Block", "#FFB300", "#FF3D00", "flame", "halo", "Every plantain prays to it." },

	{ "Owambe Overlord Supreme", "Secret", 1000000, "Tall", "#7400B8", "#FFD700", "gele", "cape", "Sprays money. Dances forever." },
	{ "The Last Jollof Grain", "Secret", 1400000, "Ball", "#FF4500", "#FFE066", "flame", "halo", "The party is over. It is not." },
	{ "Aso Ebi Anomaly", "Secret", 2000000, "Tall", "#00F5D4", "#F15BB5", "gele", "wings", "Matches every outfit at once." },
	{ "Pepperpot Prophet", "Secret", 2600000, "Block", "#B71C1C", "#FFD54F", "wizard", "staff", "Foretold Oga Pepperpot. Nobody listened." },
	{ "Infinite Puff-Puff Paradox", "Secret", 3300000, "Ball", "#FFAB40", "#7C4DFF", "bun", "wings", "Eat one, two more appear." },
	{ "Danfo of Destiny", "Secret", 4200000, "Block", "#FFEA00", "#000000", "horns", "jetpack", "Last bus home. Goes everywhere." },
}

-- Rounds a price to two significant digits so labels read cleanly ($1,800 not $1,837).
local function roundPrice(value: number): number
	local magnitude = 10 ^ math.max(0, math.floor(math.log10(value)) - 1)
	return math.floor(value / magnitude + 0.5) * magnitude
end

local function makeId(name: string): string
	return (name:gsub("[^%w]", ""))
end

GremlinCatalog.list = {} :: { Gremlin }
GremlinCatalog.byId = {} :: { [string]: Gremlin }
GremlinCatalog.byRarity = {} :: { [string]: { Gremlin } }

for _, row in CAST do
	local rarity = Rarities.get(row[2])
	local gremlin: Gremlin = {
		id = makeId(row[1]),
		name = row[1],
		rarity = rarity.name,
		income = row[3],
		price = roundPrice(row[3] * rarity.payback),
		quip = row[9],
		recipe = {
			shape = row[4],
			body = hex(row[5]),
			accent = hex(row[6]),
			hat = row[7],
			extra = row[8],
		},
	}
	table.insert(GremlinCatalog.list, gremlin)
	GremlinCatalog.byId[gremlin.id] = gremlin
	GremlinCatalog.byRarity[rarity.name] = GremlinCatalog.byRarity[rarity.name] or {}
	table.insert(GremlinCatalog.byRarity[rarity.name], gremlin)
end

function GremlinCatalog.get(id: string): Gremlin?
	return GremlinCatalog.byId[id]
end

-- Picks a gremlin of a rarity from a 0..1 roll.
function GremlinCatalog.pickOfRarity(rarityName: string, roll: number): Gremlin
	local pool = GremlinCatalog.byRarity[rarityName] or GremlinCatalog.byRarity.Common
	local index = math.clamp(math.floor(roll * #pool) + 1, 1, #pool)
	return pool[index]
end

function GremlinCatalog.count(): number
	return #GremlinCatalog.list
end

return GremlinCatalog
