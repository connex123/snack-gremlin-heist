-- MarketOrders: three rotating quests per player ("Buy 3 gremlins", "Whack a pirate", "Survive a
-- surge", ...) shown in the HUD's orders panel. Progress arrives through PlayerState.recordProgress;
-- a finished order pays cash or a gremlin and is replaced a few seconds later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local OrderBook = require(Shared.OrderBook)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)

local MarketOrders = {}

MarketOrders.bossEnabled = false -- set by the server bootstrap once Oga Pepperpot has started
local REPLACE_AFTER = 4 -- seconds a finished order stays on the board (ticked) before a new one

-- Fills empty order slots for one player.
function MarketOrders.fill(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local changed = false
	while #state.orders < OrderBook.SLOTS do
		local candidates = OrderBook.candidates(state.orders, MarketOrders.bossEnabled)
		if #candidates == 0 then
			break
		end
		local template = candidates[math.random(1, #candidates)]
		table.insert(state.orders, OrderBook.make(template, state.rate, math.random()))
		changed = true
	end
	if changed then
		PlayerState.markDirty(player)
	end
end

-- Pays an order's reward: cash, or a gremlin of its rarity on a free pedestal (cash if the stall is full).
function MarketOrders.payReward(player: Player, order)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local message
	if order.rewardRarity then
		local gremlin = GremlinCatalog.pickOfRarity(order.rewardRarity, math.random())
		local plot = Stalls.plotOf(player)
		local index = plot and Stalls.placeGremlin(plot, gremlin.id, nil)
		if index then
			PlayerState.discover(player, gremlin.id)
			message = "ORDER DONE! " .. gremlin.name .. " joins your stall!"
		else
			PlayerState.addCash(player, gremlin.price)
			message = "ORDER DONE! Stall full, paid " .. Format.money(gremlin.price)
		end
	else
		PlayerState.addCash(player, order.rewardCash or 0)
		message = "ORDER DONE! +" .. Format.money(order.rewardCash or 0)
	end
	pcall(function()
		Remotes.get("Toast"):FireClient(player, message, Color3.fromRGB(90, 255, 120))
		Remotes.get("Effect"):FireClient(player, "upgrade", Vector3.zero)
	end)
end

-- A progress event from any system.
function MarketOrders.onProgress(player: Player, kind: string, amount: number, detail: any?)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	for _, order in state.orders do
		local wasProgress = order.progress
		if OrderBook.apply(order, kind, amount, detail) then
			local paid, err = pcall(MarketOrders.payReward, player, order)
			if not paid then
				warn("[MarketOrders] reward failed: " .. tostring(err))
			end
			task.delay(REPLACE_AFTER, function()
				local now = PlayerState.get(player)
				if now then
					local at = table.find(now.orders, order)
					if at then
						table.remove(now.orders, at)
						MarketOrders.fill(player)
					end
				end
			end)
		end
		if order.progress ~= wasProgress then
			PlayerState.markDirty(player)
		end
	end
end

-- Studio shot director: a board mid-way through the night (one done, two in progress).
function MarketOrders.stageShowcase(player: Player)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local rate = math.max(state.rate, 1000)
	local buy = OrderBook.make(OrderBook.template("buy"), rate, 0.5)
	buy.progress = buy.goal - 1
	local rare = OrderBook.make(OrderBook.template("placeRare"), rate, 0)
	rare.progress, rare.done = 1, true
	local third = OrderBook.make(OrderBook.template(MarketOrders.bossEnabled and "boss" or "whack"), rate, 0)
	state.orders = { buy, rare, third }
	PlayerState.markDirty(player)
end

function MarketOrders.start()
	PlayerState.onProgress(MarketOrders.onProgress)
	task.spawn(function()
		while true do
			for player in PlayerState.all() do
				local ok, err = pcall(MarketOrders.fill, player)
				if not ok then
					warn("[MarketOrders] fill failed: " .. tostring(err))
				end
			end
			task.wait(2)
		end
	end)
end

return MarketOrders
