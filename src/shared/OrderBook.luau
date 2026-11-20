-- OrderBook: pure rules for the Market Orders quests (what each order asks, its goal, its reward and
-- how progress counts). MarketOrders on the server keeps three per player; tests drive these directly.
local Format = require(script.Parent.Format)
local Rarities = require(script.Parent.Rarities)

local OrderBook = {}

export type Order = {
	kind: string,
	text: string,
	progress: number,
	goal: number,
	rewardCash: number?,
	rewardRarity: string?,
	reward: string,
	done: boolean,
}

-- kind, text pattern (%d = goal), goal range, reward: cash seconds of income (with a floor) or a gremlin rarity.
OrderBook.TEMPLATES = {
	{ kind = "buy", text = "Buy %d gremlins", min = 2, max = 4, seconds = 40, floor = 150 },
	{ kind = "placeRare", text = "Place a Rare+ gremlin", min = 1, max = 1, rarity = "Epic" },
	{ kind = "whack", text = "Whack %d pirates", min = 1, max = 2, seconds = 60, floor = 300 },
	{ kind = "surge", text = "Survive a Lagoon Surge", min = 1, max = 1, seconds = 45, floor = 250 },
	{ kind = "rebirth", text = "Rebirth once", min = 1, max = 1, rarity = "Legendary" },
	{ kind = "boss", text = "Drive off Oga Pepperpot", min = 1, max = 1, rarity = "Mythic", needsBoss = true },
}

OrderBook.SLOTS = 3

function OrderBook.template(kind: string)
	for _, t in OrderBook.TEMPLATES do
		if t.kind == kind then
			return t
		end
	end
	return nil
end

-- Makes an order from a template; `rate` is the player's income per second, `roll` 0..1 picks the goal.
function OrderBook.make(template, rate: number, roll: number): Order
	local goal = math.clamp(template.min + math.floor(roll * (template.max - template.min + 1)), template.min, template.max)
	local order: Order = {
		kind = template.kind,
		text = string.format(template.text, goal),
		progress = 0,
		goal = goal,
		rewardCash = nil,
		rewardRarity = nil,
		reward = "",
		done = false,
	}
	if template.rarity then
		order.rewardRarity = template.rarity
		order.reward = Rarities.get(template.rarity).name .. " gremlin"
	else
		local cash = math.max(template.floor, math.floor(rate * template.seconds * goal))
		order.rewardCash = cash
		order.reward = Format.money(cash)
	end
	return order
end

-- Templates that may fill a free slot: not already on the board, boss only when the boss runs.
function OrderBook.candidates(current: { Order }, bossEnabled: boolean)
	local taken = {}
	for _, order in current do
		taken[order.kind] = true
	end
	local list = {}
	for _, t in OrderBook.TEMPLATES do
		if not taken[t.kind] and (bossEnabled or not t.needsBoss) then
			table.insert(list, t)
		end
	end
	return list
end

-- Counts a progress event towards an order; returns true when this event completes it.
function OrderBook.apply(order: Order, kind: string, amount: number, detail: any?): boolean
	if order.done then
		return false
	end
	if order.kind == "placeRare" then
		if kind ~= "place" or typeof(detail) ~= "string" or Rarities.get(detail).tier < 3 then
			return false
		end
	elseif order.kind ~= kind then
		return false
	end
	order.progress = math.min(order.goal, order.progress + amount)
	if order.progress >= order.goal then
		order.done = true
		return true
	end
	return false
end

return OrderBook
