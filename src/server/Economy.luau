-- Economy: every second, each pedestal pays its gremlin's income (mutation x rebirth x event)
-- into its owner's cash and the client shows a "+$X" pop-up over it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Mutations = require(Shared.Mutations)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)
local MarketEvents = require(script.Parent.MarketEvents)

local Economy = {}

-- Income per second of one slot for an owner state.
function Economy.slotIncome(slot: PlayerState.Slot, state: PlayerState.State): number
	local gremlin = GremlinCatalog.get(slot.id)
	if not gremlin then
		return 0
	end
	return gremlin.income * Mutations.multiplierOf(slot.mutation) * PlayerState.incomeMultiplier(state) * MarketEvents.incomeMultiplier()
end

-- Total income per second of a player's base right now.
function Economy.rateOf(state: PlayerState.State): number
	local total = 0
	for _, slot in state.base do
		total += Economy.slotIncome(slot, state)
	end
	return total
end

-- One payout: adds cash, records the rate, tells the client where each coin popped.
function Economy.payIncome()
	local incomeTick = Remotes.get("IncomeTick")
	for _, player in Players:GetPlayers() do
		local state = PlayerState.get(player)
		local plot = Stalls.plotOf(player)
		if state and plot then
			local pops = {}
			local total = 0
			for index, slot in state.base do
				local amount = Economy.slotIncome(slot, state)
				total += amount
				table.insert(pops, { position = Stalls.pedestalPosition(plot, index), amount = amount })
			end
			state.rate = total
			if total > 0 then
				PlayerState.addCash(player, total * Config.INCOME_TICK)
				incomeTick:FireClient(player, pops)
			end
			PlayerState.markDirty(player)
		end
	end
end

function Economy.start()
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK)
			local ok, err = pcall(Economy.payIncome)
			if not ok then
				warn("Economy tick failed: " .. tostring(err))
			end
		end
	end)
end

return Economy
