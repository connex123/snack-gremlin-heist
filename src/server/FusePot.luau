-- FusePot: a bubbling cooking pot in every stall. The owner presses E at it: three gremlins of the same
-- rarity (lowest first) cook into one gremlin of the next rarity, sometimes mutated, with a burst of
-- steam and sparkles. Rules in Shared.FuseRules. Isolated: built and run under pcall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local FuseRules = require(Shared.FuseRules)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Mutations = require(Shared.Mutations)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)

local FusePot = {}

-- Stall-local spot of the pot: the front corner beside pedestal 5, inside the stall, clear of the riser.
FusePot.LOCAL_SPOT = Vector3.new(16, 0, -9)

local function rarityOf(id: string): string?
	local gremlin = GremlinCatalog.get(id)
	return gremlin and gremlin.rarity
end

local function incomeOf(id: string): number
	local gremlin = GremlinCatalog.get(id)
	return gremlin and gremlin.income or 0
end

local function toast(player: Player, text: string, color: Color3)
	pcall(function()
		Remotes.get("Toast"):FireClient(player, text, color)
	end)
end

-- Cooks three same-rarity gremlins on the player's stall into one of the next rarity.
function FusePot.fuse(player: Player, pot: BasePart?): boolean
	local plot = Stalls.plotOf(player)
	if not plot then
		return false
	end
	local slots = Stalls.slotsOf(plot)
	local rarity, indices = FuseRules.findFusable(slots, rarityOf, incomeOf)
	if not rarity or not indices then
		toast(player, "Fuse Pot needs 3 gremlins of the same rarity on your stall", Color3.fromRGB(255, 160, 60))
		return false
	end
	local nextRarity = FuseRules.nextRarity(rarity)
	if not nextRarity then
		return false
	end
	for _, index in indices do
		Stalls.removeGremlin(plot, index)
	end
	local result = GremlinCatalog.pickOfRarity(nextRarity, math.random())
	local mutation = nil
	if math.random() < FuseRules.MUTATION_CHANCE then
		mutation = Mutations.rollMutation(0, math.random(), 1)
	end
	local index = Stalls.placeGremlin(plot, result.id, mutation, indices[1])
	PlayerState.discover(player, result.id)
	PlayerState.markDirty(player)
	toast(player, "FUSED! 3 " .. rarity .. " -> " .. (mutation and (mutation .. " ") or "") .. result.name .. " (" .. nextRarity .. ")!", Color3.fromRGB(255, 220, 60))
	if pot then
		local burst = pot:FindFirstChild("FuseBurst")
		if burst and burst:IsA("ParticleEmitter") then
			burst:Emit(60)
		end
	end
	if index then
		pcall(function()
			Remotes.get("Effect"):FireClient(player, "place", Stalls.pedestalPosition(plot, index) + Vector3.new(0, 3, 0))
		end)
	end
	PlayerState.recordProgress(player, "fuse", 1)
	return true
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Shape = shape
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- Builds the pot in one stall; the prompt only works for the stall's owner.
function FusePot.build(plot)
	local floor = plot.cframe * CFrame.new(FusePot.LOCAL_SPOT + Vector3.new(0, Config.STALL_FLOOR_HEIGHT, 0))
	local model = Instance.new("Model")
	model.Name = "FusePot"
	local up = CFrame.Angles(0, 0, math.rad(90))
	part("Fire", Vector3.new(0.6, 3.6, 3.6), floor * CFrame.new(0, 0.3, 0) * up, Color3.fromRGB(255, 120, 20), Enum.PartType.Cylinder, Enum.Material.Neon, model)
	local pot = part("Pot", Vector3.new(2.6, 3.4, 3.4), floor * CFrame.new(0, 1.9, 0) * up, Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder, Enum.Material.Metal, model)
	local stew = part("Stew", Vector3.new(0.3, 3, 3), floor * CFrame.new(0, 3.2, 0) * up, Color3.fromRGB(255, 80, 160), Enum.PartType.Cylinder, Enum.Material.Neon, model)
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 240))
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	steam.Rate = 6
	steam.Lifetime = NumberRange.new(1, 1.6)
	steam.Speed = NumberRange.new(2, 3)
	steam.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	steam.Parent = stew
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "FuseBurst"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 120, 230))
	burst.LightEmission = 1
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.8, 1.5)
	burst.Speed = NumberRange.new(8, 14)
	burst.SpreadAngle = Vector2.new(50, 50)
	burst.EmissionDirection = Enum.NormalId.Right
	burst.Parent = stew
	local gui = Instance.new("BillboardGui")
	gui.Name = "PotLabel"
	gui.Size = UDim2.fromScale(5, 1.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = "FUSE POT 3→1"
	text.TextColor3 = Color3.fromRGB(255, 150, 230)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = gui
	gui.Parent = stew
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fuse 3 → 1"
	prompt.ObjectText = "Fuse Pot"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = pot
	prompt.Triggered:Connect(function(player)
		if plot.owner ~= player then
			toast(player, "That is not your Fuse Pot!", Color3.fromRGB(255, 90, 90))
			return
		end
		local ok, err = pcall(FusePot.fuse, player, stew)
		if not ok then
			warn("[FusePot] fuse failed: " .. tostring(err))
		end
	end)
	model.Parent = workspace
	return model
end

function FusePot.start()
	for _, plot in Stalls.plots do
		local ok, err = pcall(FusePot.build, plot)
		if not ok then
			warn("[FusePot] could not build a pot: " .. tostring(err))
		end
	end
end

return FusePot
