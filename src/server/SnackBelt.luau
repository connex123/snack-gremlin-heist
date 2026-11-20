-- SnackBelt: gremlins hatch from the Snack Kitchen and ride the conveyor past the stalls with price
-- labels; walk up and press E to buy one if you can afford it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Format = require(Shared.Format)
local PlayerState = require(script.Parent.PlayerState)
local Carrying = require(script.Parent.Carrying)
local GremlinModel = require(script.Parent.World.GremlinModel)
local MarketEvents = require(script.Parent.MarketEvents)

local SnackBelt = {}

type BeltItem = { model: Model, x: number, gremlin: GremlinCatalog.Gremlin, mutation: string? }
local items: { BeltItem } = {}
local rng = Random.new()
local paused = false

-- The belt is shared, so it uses the best Belt Luck among players in the server.
function SnackBelt.serverLuck(): number
	local best = 0
	for _, state in PlayerState.all() do
		best = math.max(best, state.upgrades.luck or 0)
	end
	return best
end

-- Rolls a rarity (luck-weighted), a gremlin of it, and maybe a mutation (Pepper Hour boosts it).
function SnackBelt.rollGremlin(): (GremlinCatalog.Gremlin, string?)
	local rarity = Rarities.rollRarity(rng:NextNumber(), SnackBelt.serverLuck())
	local gremlin = GremlinCatalog.pickOfRarity(rarity, rng:NextNumber())
	local mutation = Mutations.rollMutation(rng:NextNumber(), rng:NextNumber(), MarketEvents.mutationMultiplier())
	return gremlin, mutation
end

function SnackBelt.priceOf(gremlin: GremlinCatalog.Gremlin, mutation: string?): number
	return math.floor(gremlin.price * Mutations.multiplierOf(mutation))
end

local function beltCFrame(x: number): CFrame
	return CFrame.new(x, Config.BELT_TOP_Y, Config.BELT_Z) * CFrame.Angles(0, math.pi, 0)
end

-- Puts one gremlin on the belt at x with its label and buy prompt.
function SnackBelt.spawnOnBelt(gremlinId: string, mutation: string?, x: number?): Model?
	local gremlin = GremlinCatalog.get(gremlinId)
	if not gremlin then
		return nil
	end
	local startX = x or Config.BELT_START_X
	local model = GremlinModel.build(gremlinId, mutation, beltCFrame(startX))
	if not model then
		return nil
	end
	local price = SnackBelt.priceOf(gremlin, mutation)
	GremlinModel.attachLabel(model, gremlin, mutation, gremlin.income * Mutations.multiplierOf(mutation), price)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy " .. Format.money(price)
	prompt.ObjectText = gremlin.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	local item: BeltItem = { model = model, x = startX, gremlin = gremlin, mutation = mutation }
	prompt.Triggered:Connect(function(player)
		SnackBelt.tryBuy(player, item)
	end)
	model.Parent = workspace
	table.insert(items, item)
	return model
end

-- Server-checked purchase: not already carrying, enough cash, still on the belt.
function SnackBelt.tryBuy(player: Player, item: BeltItem): boolean
	local index = table.find(items, item)
	if not index then
		return false
	end
	if Carrying.isCarrying(player) then
		Remotes.get("Toast"):FireClient(player, "Hands full! Take your gremlin home first.", Color3.fromRGB(255, 160, 60))
		return false
	end
	local price = SnackBelt.priceOf(item.gremlin, item.mutation)
	if not PlayerState.trySpend(player, price) then
		Remotes.get("Toast"):FireClient(player, "Need " .. Format.money(price) .. " for " .. item.gremlin.name, Color3.fromRGB(255, 90, 90))
		return false
	end
	table.remove(items, index)
	local prompt = item.model.PrimaryPart and item.model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	GremlinModel.attachLabel(item.model, item.gremlin, item.mutation, item.gremlin.income * Mutations.multiplierOf(item.mutation), nil)
	if not Carrying.pickUp(player, item.model, item.gremlin.id, item.mutation) then
		PlayerState.addCash(player, price) -- refund: no character to carry it
		item.model:Destroy()
		return false
	end
	return true
end

-- Buys the belt gremlin shown by a model (used by the Studio shot director).
function SnackBelt.tryBuyModel(player: Player, model: Model): boolean
	for _, item in items do
		if item.model == model then
			return SnackBelt.tryBuy(player, item)
		end
	end
	return false
end

-- Slides every belt gremlin along; ones that reach the end tumble into the lagoon.
function SnackBelt.moveAll(dt: number)
	if paused then
		return
	end
	for i = #items, 1, -1 do
		local item = items[i]
		item.x += Config.BELT_SPEED * dt
		if item.x > Config.BELT_END_X or not item.model.Parent then
			table.remove(items, i)
			item.model:Destroy()
		else
			item.model:PivotTo(beltCFrame(item.x))
		end
	end
end

function SnackBelt.setPaused(on: boolean)
	paused = on
end

function SnackBelt.clear()
	for _, item in items do
		item.model:Destroy()
	end
	table.clear(items)
end

-- Fills the belt at start so it is never empty.
function SnackBelt.prefill()
	local x = Config.BELT_START_X
	while x < Config.BELT_END_X - 10 do
		local gremlin, mutation = SnackBelt.rollGremlin()
		SnackBelt.spawnOnBelt(gremlin.id, mutation, x)
		x += Config.BELT_SPEED * Config.BELT_SPAWN_INTERVAL
	end
end

function SnackBelt.start()
	SnackBelt.prefill()
	RunService.Heartbeat:Connect(SnackBelt.moveAll)
	task.spawn(function()
		while true do
			task.wait(Config.BELT_SPAWN_INTERVAL / MarketEvents.spawnRateMultiplier())
			if not paused and #Players:GetPlayers() > 0 then
				local gremlin, mutation = SnackBelt.rollGremlin()
				local ok, err = pcall(SnackBelt.spawnOnBelt, gremlin.id, mutation, nil)
				if not ok then
					warn("Belt spawn failed: " .. tostring(err))
				end
			end
		end
	end)
end

return SnackBelt
