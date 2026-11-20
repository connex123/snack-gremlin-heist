-- OgaPepperpot: the boss raid. Every few minutes a giant gremlin chef (about 4x a gremlin) marches
-- down the south lane under a red "OGA PEPPERPOT RAID!" banner, stops at unlocked player stalls and
-- scoops a gremlin into his pot. Players whack him (F) to drive him off: he drops what he took and every
-- whacker gets a Divine gremlin. Locked stalls are safe. Isolated: its own loop, every tick in a pcall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Format = require(Shared.Format)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)
local ShutterLock = require(script.Parent.ShutterLock)

local OgaPepperpot = {}

OgaPepperpot.holdUntil = 0 -- the shot director pauses raids until this os.clock()
OgaPepperpot.FIRST_RAID = 150 -- seconds after the server starts
OgaPepperpot.INTERVAL = 240 -- seconds between raids
OgaPepperpot.HITS_PER_PLAYER = 6 -- whacks needed, per player in the server (capped)
OgaPepperpot.WHACK_RANGE = 22
OgaPepperpot.WALK_SPEED = 7
OgaPepperpot.SCOOP_SECONDS = 5 -- he stands at a stall this long before scooping
OgaPepperpot.LANE_Z = 14 -- the south lane, between the belt and the stall fronts
OgaPepperpot.TITLE = "OGA PEPPERPOT RAID!"

local RED = Color3.fromRGB(220, 30, 30)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 24)

type Boss = {
	model: Model,
	root: BasePart,
	status: TextLabel,
	hits: number,
	needed: number,
	whackers: { [Player]: boolean },
	scooped: { { plot: any, index: number, slot: any } },
	fleeing: boolean,
}

local boss: Boss? = nil

local function piece(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- The giant chef, built from Parts with his feet at `at` (facing its look vector).
function OgaPepperpot.build(at: CFrame): (Model, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "OgaPepperpot"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local up = CFrame.Angles(0, 0, math.rad(90))
	piece(model, root, "LegL", Vector3.new(2.4, 4, 2.4), CFrame.new(-2.6, 2, 0), BLACK)
	piece(model, root, "LegR", Vector3.new(2.4, 4, 2.4), CFrame.new(2.6, 2, 0), BLACK)
	local body = piece(model, root, "Body", Vector3.new(11, 11, 11), CFrame.new(0, 8.5, 0), Color3.fromRGB(196, 60, 30), Enum.PartType.Ball)
	piece(model, root, "Apron", Vector3.new(8, 6, 1), CFrame.new(0, 5.6, -5.2), WHITE)
	for _, side in { -1, 1 } do
		piece(model, root, "Eye", Vector3.new(3.2, 3.2, 3.2), CFrame.new(side * 1.9, 11.3, -4.1), WHITE, Enum.PartType.Ball)
		piece(model, root, "Pupil", Vector3.new(1.5, 1.5, 1.5), CFrame.new(side * 1.7, 11.0, -5.6), BLACK, Enum.PartType.Ball)
		piece(model, root, "Shine", Vector3.new(0.5, 0.5, 0.5), CFrame.new(side * 1.7 + 0.35, 11.4, -6.3), WHITE, Enum.PartType.Ball, Enum.Material.Neon)
		piece(model, root, "Brow", Vector3.new(2.6, 0.6, 0.6), CFrame.new(side * 1.9, 13.3, -4.6) * CFrame.Angles(0, 0, math.rad(side * 20)), BLACK)
		piece(model, root, "Moustache", Vector3.new(3, 0.9, 0.9), CFrame.new(side * 1.5, 9.9, -5.2) * CFrame.Angles(0, 0, math.rad(side * -15)), BLACK)
		piece(model, root, "Arm", Vector3.new(1.8, 6, 1.8), CFrame.new(side * 6.3, 8.5, -1) * CFrame.Angles(0, 0, math.rad(side * 40)), Color3.fromRGB(196, 60, 30))
	end
	piece(model, root, "Mouth", Vector3.new(3.6, 1.2, 0.6), CFrame.new(0, 9.0, -5.0), Color3.fromRGB(70, 10, 20))
	-- chef's hat and red bandana
	piece(model, root, "Bandana", Vector3.new(1.2, 10, 10), CFrame.new(0, 13.6, 0) * up, RED, Enum.PartType.Cylinder)
	piece(model, root, "HatBand", Vector3.new(3, 7.5, 7.5), CFrame.new(0, 15.6, 0) * up, WHITE, Enum.PartType.Cylinder)
	piece(model, root, "HatPuff", Vector3.new(9, 6, 9), CFrame.new(0, 19, 0), WHITE, Enum.PartType.Ball)
	-- the scooping pot in his left hand and a ladle in his right
	piece(model, root, "Pot", Vector3.new(4, 5, 5), CFrame.new(-8.6, 5.5, -2) * up, Color3.fromRGB(70, 70, 78), Enum.PartType.Cylinder, Enum.Material.Metal)
	piece(model, root, "PotStew", Vector3.new(0.4, 4.4, 4.4), CFrame.new(-8.6, 7.6, -2) * up, Color3.fromRGB(230, 80, 20), Enum.PartType.Cylinder, Enum.Material.Neon)
	piece(model, root, "Ladle", Vector3.new(0.6, 9, 0.6), CFrame.new(8.8, 10, -2) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(180, 180, 190), nil, Enum.Material.Metal)
	local steam = Instance.new("ParticleEmitter")
	steam.Color = ColorSequence.new(Color3.fromRGB(255, 160, 80))
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	steam.Rate = 10
	steam.Speed = NumberRange.new(3, 5)
	steam.EmissionDirection = Enum.NormalId.Right
	steam.Parent = model:FindFirstChild("PotStew")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 90, 40)
	light.Brightness = 3
	light.Range = 24
	light.Parent = body

	-- his name and the whack counter are printed on his apron, so they stay on screen wherever he is
	local apron = model:FindFirstChild("Apron") :: BasePart
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ApronSign"
	gui.Face = Enum.NormalId.Front
	gui.Adornee = apron
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.Text = "OGA\nPEPPERPOT"
	name.TextColor3 = RED
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = BLACK
	stroke.Parent = name
	name.Parent = gui
	local status = name:Clone()
	status.Name = "Status"
	status.Position = UDim2.fromScale(0, 0.62)
	status.Size = UDim2.fromScale(1, 0.34)
	status.Text = "WHACK HIM! (F)"
	status.TextColor3 = Color3.fromRGB(255, 220, 60)
	status.Parent = gui
	gui.Parent = apron

	model:PivotTo(at)
	model.Parent = workspace
	return model, root, status
end

local function banner(sub: string?, clear: boolean?)
	pcall(function()
		if clear then
			Remotes.get("Banner"):FireAllClients({ slot = "boss", clear = true })
		else
			Remotes.get("Banner"):FireAllClients({ slot = "boss", title = OgaPepperpot.TITLE, sub = sub, color = RED })
		end
	end)
end

local function updateStatus(b: Boss)
	b.status.Text = string.format("WHACK %d/%d (F)", b.hits, b.needed)
end

-- Removes the boss; `returnLoot` puts scooped gremlins back on their pedestals.
function OgaPepperpot.clear(returnLoot: boolean?)
	local b = boss
	boss = nil
	if not b then
		return
	end
	if returnLoot then
		for _, loot in b.scooped do
			pcall(Stalls.placeGremlin, loot.plot, loot.slot.id, loot.slot.mutation, loot.index)
		end
	end
	if b.model then
		b.model:Destroy()
	end
	banner(nil, true)
end

-- Driven off: loot back, a Divine gremlin (or its price if the stall is full) for every whacker.
function OgaPepperpot.defeat(b: Boss)
	b.fleeing = true
	b.status.Text = "DRIVEN OFF!"
	for _, loot in b.scooped do
		pcall(Stalls.placeGremlin, loot.plot, loot.slot.id, loot.slot.mutation, loot.index)
	end
	b.scooped = {}
	for player in b.whackers do
		pcall(function()
			local divine = GremlinCatalog.pickOfRarity("Divine", math.random())
			local plot = Stalls.plotOf(player)
			local index = plot and Stalls.placeGremlin(plot, divine.id, nil)
			if index then
				PlayerState.discover(player, divine.id)
				Remotes.get("Toast"):FireClient(player, "OGA PEPPERPOT FLED! Divine reward: " .. divine.name .. "!", Color3.fromRGB(120, 255, 240))
			else
				PlayerState.addCash(player, divine.price)
				Remotes.get("Toast"):FireClient(player, "OGA PEPPERPOT FLED! Stall full: +" .. Format.money(divine.price), Color3.fromRGB(120, 255, 240))
			end
			PlayerState.recordProgress(player, "boss", 1)
		end)
	end
	pcall(function()
		Remotes.get("Effect"):FireAllClients("whack", b.root.Position + Vector3.new(0, 10, 0))
	end)
	-- he bounces up and away, then is gone
	task.spawn(function()
		for _ = 1, 40 do
			if boss ~= b then
				return
			end
			pcall(function()
				b.model:PivotTo(b.model:GetPivot() * CFrame.new(0, 1.2, 1.5) * CFrame.Angles(0, math.rad(12), 0))
			end)
			task.wait(1 / 30)
		end
		if boss == b then
			OgaPepperpot.clear(false)
		end
	end)
end

-- A whack from a player (F); returns true when it landed.
function OgaPepperpot.whack(player: Player): boolean
	local b = boss
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not b or b.fleeing or not root then
		return false
	end
	local flat = (b.root.Position - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude > OgaPepperpot.WHACK_RANGE then
		return false
	end
	b.hits += 1
	b.whackers[player] = true
	updateStatus(b)
	pcall(function()
		Remotes.get("Effect"):FireAllClients("whack", root.Position + flat * 0.6 + Vector3.new(0, 8, 0))
	end)
	if b.hits >= b.needed then
		OgaPepperpot.defeat(b)
	end
	return true
end

-- The player stalls along the south lane he passes, in walking order.
local function laneStalls(): { any }
	local list = {}
	for _, plot in Stalls.plots do
		if plot.owner and plot.cframe.Position.Z > 0 then
			table.insert(list, plot)
		end
	end
	table.sort(list, function(a, b)
		return a.cframe.Position.X < b.cframe.Position.X
	end)
	return list
end

-- Walks the boss to x along the lane; false if the raid ended on the way.
local function walkTo(b: Boss, x: number): boolean
	while boss == b and not b.fleeing do
		local pos = b.model:GetPivot().Position
		local dx = x - pos.X
		if math.abs(dx) < 0.5 then
			return true
		end
		local dt = task.wait(1 / 20)
		local step = math.clamp(dx, -OgaPepperpot.WALK_SPEED * dt, OgaPepperpot.WALK_SPEED * dt)
		local bob = math.abs(math.sin(os.clock() * 6)) * 0.8
		local ok = pcall(function()
			b.model:PivotTo(CFrame.lookAt(Vector3.new(pos.X + step, bob, OgaPepperpot.LANE_Z), Vector3.new(pos.X + step, bob, Config.BELT_Z + 200)))
		end)
		if not ok then
			return false
		end
	end
	return false
end

-- One raid from the west end of the lane to the east end.
function OgaPepperpot.runRaid()
	if boss then
		return
	end
	local startX = Config.BELT_START_X + 20
	local model, root, status = OgaPepperpot.build(CFrame.new(startX, 0, OgaPepperpot.LANE_Z))
	local needed = math.clamp(#Players:GetPlayers(), 1, 4) * OgaPepperpot.HITS_PER_PLAYER
	local b: Boss = { model = model, root = root, status = status, hits = 0, needed = needed, whackers = {}, scooped = {}, fleeing = false }
	boss = b
	updateStatus(b)
	banner("He scoops gremlins from unlocked stalls! Lock (L) or whack him (F)")
	for _, plot in laneStalls() do
		if not walkTo(b, plot.cframe.Position.X) then
			return
		end
		task.wait(OgaPepperpot.SCOOP_SECONDS)
		if boss ~= b or b.fleeing then
			return
		end
		if not ShutterLock.isLocked(plot) then
			local best, bestIncome = nil, -1
			for index, slot in Stalls.slotsOf(plot) do
				local gremlin = GremlinCatalog.get(slot.id)
				if gremlin and gremlin.income > bestIncome then
					best, bestIncome = index, gremlin.income
				end
			end
			if best then
				local slot = Stalls.removeGremlin(plot, best)
				if slot then
					table.insert(b.scooped, { plot = plot, index = best, slot = slot })
					pcall(function()
						local gremlin = GremlinCatalog.get(slot.id)
						Remotes.get("Toast"):FireClient(plot.owner, "Oga Pepperpot scooped your " .. (gremlin and gremlin.name or "gremlin") .. "! Whack him to get it back!", RED)
					end)
				end
			end
		end
	end
	if walkTo(b, Config.BELT_END_X - 20) and boss == b then
		OgaPepperpot.clear(false) -- he got away with whatever is in the pot
	end
end

-- Studio shot director: the boss frozen mid-raid at `feet`, facing `faceTowards`, banner up.
function OgaPepperpot.stageFrozen(feet: Vector3, faceTowards: Vector3)
	OgaPepperpot.clear(false)
	local look = Vector3.new(faceTowards.X, 0, faceTowards.Z)
	local model, root, status = OgaPepperpot.build(CFrame.lookAt(Vector3.new(feet.X, 0, feet.Z), look))
	local b: Boss = { model = model, root = root, status = status, hits = 2, needed = 6, whackers = {}, scooped = {}, fleeing = false }
	boss = b
	updateStatus(b)
	banner("He scoops gremlins from unlocked stalls! Lock (L) or whack him (F)")
end

function OgaPepperpot.start()
	Remotes.get("RequestWhack").OnServerEvent:Connect(function(player)
		local ok, err = pcall(OgaPepperpot.whack, player)
		if not ok then
			warn("[OgaPepperpot] whack failed: " .. tostring(err))
		end
	end)
	task.spawn(function()
		local nextRaid = os.clock() + OgaPepperpot.FIRST_RAID
		while true do
			task.wait(1)
			if os.clock() >= nextRaid and os.clock() >= OgaPepperpot.holdUntil and #Players:GetPlayers() > 0 and not boss then
				nextRaid = os.clock() + OgaPepperpot.INTERVAL
				local ok, err = pcall(OgaPepperpot.runRaid)
				if not ok then
					warn("[OgaPepperpot] raid failed: " .. tostring(err))
					pcall(OgaPepperpot.clear, true)
				end
			end
		end
	end)
	if RunService:IsStudio() then
		print("[OgaPepperpot] first raid in " .. OgaPepperpot.FIRST_RAID .. " s")
	end
end

return OgaPepperpot
