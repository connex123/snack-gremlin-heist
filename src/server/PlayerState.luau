-- PlayerState: every player's state in one place (cash, base slots, upgrades, rebirths, carrying,
-- lock, index of discovered gremlins), the leaderstats, and the snapshot sent to that player's HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)

export type Slot = { id: string, mutation: string? }
export type Carry = { id: string, mutation: string?, model: Model? }
export type State = {
	cash: number,
	rate: number,
	rebirths: number,
	upgrades: { [string]: number },
	base: { [number]: Slot },
	discovered: { [string]: boolean },
	carrying: Carry?,
	lockUntil: number,
	lockCooldownUntil: number,
	plotIndex: number?,
	leaderCash: StringValue?,
	leaderRebirths: IntValue?,
	dirty: boolean,
}

local PlayerState = {}
local states: { [Player]: State } = {}

function PlayerState.create(player: Player): State
	local state: State = {
		cash = Config.STARTING_CASH,
		rate = 0,
		rebirths = 0,
		upgrades = { pedestals = 0, luck = 0, speed = 0, lockTime = 0 },
		base = {},
		discovered = {},
		carrying = nil,
		lockUntil = 0,
		lockCooldownUntil = 0,
		plotIndex = nil,
		leaderCash = nil,
		leaderRebirths = nil,
		dirty = true,
	}
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = Format.money(state.cash)
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player
	state.leaderCash = cash
	state.leaderRebirths = rebirths
	states[player] = state
	return state
end

function PlayerState.get(player: Player): State?
	return states[player]
end

function PlayerState.remove(player: Player)
	states[player] = nil
end

function PlayerState.all(): { [Player]: State }
	return states
end

function PlayerState.markDirty(player: Player)
	local state = states[player]
	if state then
		state.dirty = true
	end
end

function PlayerState.addCash(player: Player, amount: number)
	local state = states[player]
	if state then
		state.cash += amount
		state.dirty = true
	end
end

-- Spends cash if the player has enough; returns whether it did.
function PlayerState.trySpend(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.cash < amount then
		return false
	end
	state.cash -= amount
	state.dirty = true
	return true
end

function PlayerState.pedestalCount(state: State): number
	return Config.START_PEDESTALS + (state.upgrades.pedestals or 0)
end

function PlayerState.incomeMultiplier(state: State): number
	return Config.rebirthMultiplier(state.rebirths)
end

function PlayerState.discover(player: Player, gremlinId: string)
	local state = states[player]
	if state and not state.discovered[gremlinId] then
		state.discovered[gremlinId] = true
		state.dirty = true
	end
end

-- The HUD's view of the state: plain values only.
function PlayerState.buildSnapshot(state: State)
	local carrying = nil
	if state.carrying then
		local gremlin = GremlinCatalog.get(state.carrying.id)
		carrying = gremlin and { name = gremlin.name, rarity = gremlin.rarity, mutation = state.carrying.mutation }
	end
	local discovered = {}
	for id in state.discovered do
		table.insert(discovered, id)
	end
	local used = 0
	for _ in state.base do
		used += 1
	end
	return {
		cash = state.cash,
		rate = state.rate,
		rebirths = state.rebirths,
		multiplier = PlayerState.incomeMultiplier(state),
		upgrades = table.clone(state.upgrades),
		pedestals = PlayerState.pedestalCount(state),
		pedestalsUsed = used,
		carrying = carrying,
		discovered = discovered,
		lockUntil = state.lockUntil,
		lockCooldownUntil = state.lockCooldownUntil,
	}
end

-- Sends a snapshot to every player whose state changed (at most ten times a second).
function PlayerState.startSnapshotPump()
	local stateChanged = Remotes.get("StateChanged")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		for player, state in states do
			if state.dirty then
				state.dirty = false
				if state.leaderCash then
					state.leaderCash.Value = Format.money(state.cash)
				end
				if state.leaderRebirths then
					state.leaderRebirths.Value = state.rebirths
				end
				stateChanged:FireClient(player, PlayerState.buildSnapshot(state))
			end
		end
	end)
end

return PlayerState
