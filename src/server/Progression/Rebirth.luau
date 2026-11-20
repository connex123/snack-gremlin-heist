-- Rebirth: trade all cash and your stall's gremlins for a permanent +50% income multiplier and a
-- new stall floor colour. Upgrades and your Index are kept.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Stalls = require(script.Parent.Parent.Stalls)
local Carrying = require(script.Parent.Parent.Carrying)

local Rebirth = {}

function Rebirth.tryRebirth(player: Player): boolean
	local state = PlayerState.get(player)
	if not state then
		return false
	end
	local cost = Config.rebirthCost(state.rebirths)
	if state.cash < cost then
		Remotes.get("Toast"):FireClient(player, "Rebirth needs " .. Format.money(cost), Color3.fromRGB(255, 90, 90))
		return false
	end
	Carrying.drop(player, nil)
	state.rebirths += 1
	state.cash = Config.STARTING_CASH
	PlayerState.markDirty(player)
	local plot = Stalls.plotOf(player)
	if plot then
		Stalls.clearPlot(plot)
		Stalls.paintFloor(plot, state.rebirths)
	end
	Remotes.get("Effect"):FireClient(player, "rebirth", Vector3.zero)
	Remotes.get("Toast"):FireClient(player, "REBIRTH " .. state.rebirths .. "! Income x" .. Config.rebirthMultiplier(state.rebirths), Color3.fromRGB(200, 120, 255))
	return true
end

function Rebirth.start()
	Remotes.get("RequestRebirth").OnServerEvent:Connect(function(player)
		Rebirth.tryRebirth(player)
	end)
end

return Rebirth
