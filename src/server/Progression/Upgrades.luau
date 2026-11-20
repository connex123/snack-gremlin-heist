-- Upgrades: spend cash on More Pedestals, Belt Luck, Quick Feet and Longer Lock (costs in Config).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Stalls = require(script.Parent.Parent.Stalls)

local Upgrades = {}

function Upgrades.applyWalkSpeed(player: Player)
	local state = PlayerState.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if state and humanoid then
		humanoid.WalkSpeed = Config.walkSpeed(state.upgrades.speed or 0)
	end
end

-- Buys one level of an upgrade if affordable and not maxed.
function Upgrades.buy(player: Player, key: string): boolean
	local state = PlayerState.get(player)
	local info = Config.upgradeInfo(key)
	if not state or not info then
		return false
	end
	local level = state.upgrades[key] or 0
	local cost = Config.upgradeCost(key, level)
	local toast = Remotes.get("Toast")
	if not cost then
		toast:FireClient(player, info.label .. " is maxed!", Color3.fromRGB(255, 220, 60))
		return false
	end
	if not PlayerState.trySpend(player, cost) then
		toast:FireClient(player, "Need " .. Format.money(cost) .. " for " .. info.label, Color3.fromRGB(255, 90, 90))
		return false
	end
	state.upgrades[key] = level + 1
	PlayerState.markDirty(player)
	if key == "pedestals" then
		local plot = Stalls.plotOf(player)
		if plot then
			Stalls.refreshPlot(plot)
		end
	elseif key == "speed" then
		Upgrades.applyWalkSpeed(player)
	end
	toast:FireClient(player, info.label .. " -> level " .. (level + 1) .. "!", Color3.fromRGB(90, 255, 120))
	Remotes.get("Effect"):FireClient(player, "upgrade", Vector3.zero)
	return true
end

function Upgrades.start()
	Remotes.get("RequestUpgrade").OnServerEvent:Connect(function(player, key)
		if typeof(key) == "string" then
			Upgrades.buy(player, key)
		end
	end)
end

return Upgrades
