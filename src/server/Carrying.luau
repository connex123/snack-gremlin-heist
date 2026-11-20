-- Carrying: a bought gremlin rides above the player's head until they reach their stall, where it
-- lands on the next free pedestal. Dropping it (surge, death) loses it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)

local Carrying = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Carrying.isCarrying(player: Player): boolean
	local state = PlayerState.get(player)
	return state ~= nil and state.carrying ~= nil
end

-- Welds a gremlin model above the player's head and records the carry.
function Carrying.pickUp(player: Player, model: Model, gremlinId: string, mutation: string?): boolean
	local state = PlayerState.get(player)
	local root = rootOf(player)
	if not state or not root or state.carrying then
		return false
	end
	local primary = model.PrimaryPart
	if not primary then
		return false
	end
	model:PivotTo(root.CFrame * CFrame.new(0, 3.2, 0))
	primary.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.Parent = primary
	model.Parent = player.Character
	state.carrying = { id = gremlinId, mutation = mutation, model = model }
	PlayerState.discover(player, gremlinId)
	PlayerState.markDirty(player)
	local gremlin = GremlinCatalog.get(gremlinId)
	Remotes.get("Effect"):FireClient(player, "buy", root.Position + Vector3.new(0, 4, 0))
	Remotes.get("Toast"):FireClient(player, "Got " .. (gremlin and gremlin.name or "a gremlin") .. "! Run it home!", Color3.fromRGB(255, 220, 60))
	return true
end

-- Loses the carried gremlin, with a reason shown to the player.
function Carrying.drop(player: Player, reason: string?)
	local state = PlayerState.get(player)
	if not state or not state.carrying then
		return
	end
	local carry = state.carrying
	state.carrying = nil
	if carry.model then
		carry.model:Destroy()
	end
	PlayerState.markDirty(player)
	if reason then
		Remotes.get("Toast"):FireClient(player, reason, Color3.fromRGB(255, 90, 90))
	end
end

-- Puts the carried gremlin on the next free pedestal if the player stands in their stall.
function Carrying.deliverIfHome(player: Player)
	local state = PlayerState.get(player)
	local root = rootOf(player)
	local plot = Stalls.plotOf(player)
	if not state or not state.carrying or not root or not plot then
		return
	end
	if not Stalls.isInsideHome(plot, root.Position) then
		return
	end
	local carry = state.carrying
	local index = Stalls.placeGremlin(plot, carry.id, carry.mutation)
	if not index then
		if not state.fullWarned then
			state.fullWarned = true
			Remotes.get("Toast"):FireClient(player, "Stall full! Buy More Pedestals (U)", Color3.fromRGB(255, 160, 60))
		end
		return
	end
	state.fullWarned = nil
	state.carrying = nil
	if carry.model then
		carry.model:Destroy()
	end
	PlayerState.markDirty(player)
	local gremlin = GremlinCatalog.get(carry.id)
	Remotes.get("Effect"):FireClient(player, "place", Stalls.pedestalPosition(plot, index) + Vector3.new(0, 3, 0))
	Remotes.get("Toast"):FireClient(player, (gremlin and gremlin.name or "Gremlin") .. " is earning on pedestal " .. index .. "!", Color3.fromRGB(90, 255, 120))
end

function Carrying.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Carrying.deliverIfHome, player)
				if not ok then
					warn("Deliver failed: " .. tostring(err))
				end
			end
		end
	end)
end

-- Dying drops what you carry.
function Carrying.watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			Carrying.drop(player, "You dropped your gremlin!")
		end)
	end
end

return Carrying
