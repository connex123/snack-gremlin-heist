-- GremlinModel: builds a Snack Gremlin from Parts (body, eyes, limbs, food hat, extra prop),
-- applies its mutation look and hangs a big name / rarity / income label over it.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local Format = require(Shared.Format)
local ShotFraming = require(Shared.ShotFraming)

local GremlinModel = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(20, 20, 24)
local DARK = Color3.fromRGB(50, 35, 30)

type Builder = {
	model: Model,
	root: BasePart,
	s: number,
	top: number,
	recipe: GremlinCatalog.Recipe,
}

-- Adds one welded, massless, non-colliding part at an offset from the gremlin's feet.
local function addPart(b: Builder, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size * b.s
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = b.root.CFrame * CFrame.new(offset.Position * b.s) * offset.Rotation
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = b.root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = b.model
	return part
end

local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.rad(90))

-- Body shapes: returns the height of the body top above the feet (unscaled).
local function buildBody(b: Builder): number
	local r = b.recipe
	addPart(b, "LegL", Vector3.new(0.6, 0.9, 0.6), CFrame.new(-0.55, 0.45, 0), DARK)
	addPart(b, "LegR", Vector3.new(0.6, 0.9, 0.6), CFrame.new(0.55, 0.45, 0), DARK)
	local top, faceZ, halfWidth, mid
	if r.shape == "Ball" then
		addPart(b, "Body", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 2.1, 0), r.body, Enum.PartType.Ball)
		addPart(b, "Belly", Vector3.new(1.6, 1.6, 0.6), CFrame.new(0, 1.8, -1.05), r.accent, Enum.PartType.Ball)
		top, faceZ, halfWidth, mid = 3.4, -1.15, 1.3, 2.1
	elseif r.shape == "Tall" then
		addPart(b, "Body", Vector3.new(3.4, 2.0, 2.0), CFrame.new(0, 2.6, 0) * UPRIGHT_CYLINDER, r.body, Enum.PartType.Cylinder)
		addPart(b, "Belly", Vector3.new(1.2, 1.6, 0.3), CFrame.new(0, 2.0, -0.92), r.accent)
		top, faceZ, halfWidth, mid = 4.3, -0.95, 1.0, 2.6
	else
		addPart(b, "Body", Vector3.new(2.4, 2.4, 2.0), CFrame.new(0, 2.1, 0), r.body)
		addPart(b, "Belly", Vector3.new(1.5, 1.3, 0.2), CFrame.new(0, 1.8, -1.05), r.accent)
		top, faceZ, halfWidth, mid = 3.3, -1.05, 1.2, 2.1
	end
	-- Big googly eyes and a grin: the gremlin face.
	local eyeY = top - 0.75
	for _, side in { -1, 1 } do
		addPart(b, "Eye", Vector3.new(0.95, 0.95, 0.95), CFrame.new(side * 0.45, eyeY, faceZ - 0.1), WHITE, Enum.PartType.Ball)
		addPart(b, "Pupil", Vector3.new(0.45, 0.45, 0.45), CFrame.new(side * 0.42, eyeY - 0.05, faceZ - 0.5), BLACK, Enum.PartType.Ball)
	end
	addPart(b, "Mouth", Vector3.new(0.9, 0.18, 0.2), CFrame.new(0, eyeY - 0.75, faceZ - 0.05), BLACK)
	addPart(b, "Tooth", Vector3.new(0.22, 0.22, 0.12), CFrame.new(0.2, eyeY - 0.9, faceZ - 0.1), WHITE)
	addPart(b, "ArmL", Vector3.new(0.45, 1.3, 0.45), CFrame.new(-halfWidth - 0.2, mid, -0.2) * CFrame.Angles(0, 0, math.rad(-35)), r.body)
	addPart(b, "ArmR", Vector3.new(0.45, 1.3, 0.45), CFrame.new(halfWidth + 0.2, mid, -0.2) * CFrame.Angles(0, 0, math.rad(35)), r.body)
	return top
end

-- Food hats and head props, one builder per recipe.hat.
local HATS: { [string]: (Builder) -> () } = {
	bun = function(b)
		addPart(b, "Hat", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, b.top + 0.5, 0), b.recipe.accent, Enum.PartType.Ball)
	end,
	ears = function(b)
		for _, side in { -1, 1 } do
			addPart(b, "Ear", Vector3.new(0.5, 0.8, 0.3), CFrame.new(side * 0.7, b.top + 0.3, 0) * CFrame.Angles(0, 0, side * math.rad(-15)), b.recipe.accent)
		end
	end,
	bowl = function(b)
		addPart(b, "Hat", Vector3.new(0.5, 2.0, 2.0), CFrame.new(0, b.top + 0.2, 0) * UPRIGHT_CYLINDER, b.recipe.accent, Enum.PartType.Cylinder)
		addPart(b, "Garri", Vector3.new(1.5, 0.6, 1.5), CFrame.new(0, b.top + 0.5, 0), b.recipe.body, Enum.PartType.Ball)
	end,
	sachet = function(b)
		addPart(b, "Hat", Vector3.new(1.4, 1.0, 0.4), CFrame.new(0, b.top + 0.5, 0) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(220, 245, 255), nil, Enum.Material.Glass)
	end,
	shell = function(b)
		addPart(b, "Hat", Vector3.new(1.0, 1.6, 1.0), CFrame.new(0, b.top + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), b.recipe.accent, Enum.PartType.Ball)
	end,
	mask = function(b)
		addPart(b, "Hat", Vector3.new(2.2, 0.45, 0.25), CFrame.new(0, b.top - 0.75, -1.25), BLACK)
	end,
	crown = function(b)
		addPart(b, "Hat", Vector3.new(1.5, 0.5, 1.5), CFrame.new(0, b.top + 0.2, 0), Color3.fromRGB(255, 205, 50), nil, Enum.Material.Foil)
		for i = -1, 1 do
			addPart(b, "Spike", Vector3.new(0.3, 0.5, 0.3), CFrame.new(i * 0.55, b.top + 0.6, 0), Color3.fromRGB(255, 205, 50), nil, Enum.Material.Foil)
		end
	end,
	helmet = function(b)
		local dome = addPart(b, "Hat", Vector3.new(3.1, 3.1, 3.1), CFrame.new(0, b.top - 1.2, 0), Color3.fromRGB(200, 240, 255), Enum.PartType.Ball, Enum.Material.Glass)
		dome.Transparency = 0.6
	end,
	leaf = function(b)
		addPart(b, "Hat", Vector3.new(2.4, 0.2, 1.4), CFrame.new(0, b.top + 0.15, 0) * CFrame.Angles(0, 0, math.rad(10)), b.recipe.accent, nil, Enum.Material.Grass)
	end,
	balloon = function(b)
		addPart(b, "Hat", Vector3.new(1.6, 3.0, 1.6), CFrame.new(0, b.top + 1.0, 0) * CFrame.Angles(0, 0, math.rad(90)), b.recipe.accent, Enum.PartType.Ball)
		addPart(b, "Fin", Vector3.new(0.15, 0.8, 0.8), CFrame.new(0, b.top + 1.0, 1.4), b.recipe.body)
	end,
	loaf = function(b)
		addPart(b, "Hat", Vector3.new(2.6, 0.9, 1.1), CFrame.new(0, b.top + 0.4, 0), b.recipe.accent)
		addPart(b, "Crust", Vector3.new(2.7, 0.3, 1.15), CFrame.new(0, b.top + 0.85, 0), Color3.fromRGB(150, 90, 40))
	end,
	beret = function(b)
		addPart(b, "Hat", Vector3.new(0.4, 1.8, 1.8), CFrame.new(0.2, b.top + 0.15, 0) * UPRIGHT_CYLINDER * CFrame.Angles(math.rad(10), 0, 0), BLACK, Enum.PartType.Cylinder)
	end,
	pot = function(b)
		addPart(b, "Hat", Vector3.new(1.1, 1.7, 1.7), CFrame.new(0, b.top + 0.45, 0) * UPRIGHT_CYLINDER, Color3.fromRGB(70, 70, 75), Enum.PartType.Cylinder, Enum.Material.Metal)
		addPart(b, "Lid", Vector3.new(0.2, 1.8, 1.8), CFrame.new(0, b.top + 1.05, 0) * UPRIGHT_CYLINDER, b.recipe.accent, Enum.PartType.Cylinder)
	end,
	skewer = function(b)
		addPart(b, "Hat", Vector3.new(0.12, 3.2, 0.12), CFrame.new(0, b.top + 1.3, 0), Color3.fromRGB(230, 200, 150))
		for i = 0, 2 do
			addPart(b, "Meat", Vector3.new(0.6, 0.45, 0.6), CFrame.new(0, b.top + 0.6 + i * 0.75, 0), b.recipe.body)
		end
	end,
	visor = function(b)
		addPart(b, "Hat", Vector3.new(2.3, 1.0, 2.1), CFrame.new(0, b.top + 0.1, 0), b.recipe.accent, nil, Enum.Material.Metal)
		addPart(b, "Plume", Vector3.new(0.3, 1.0, 0.9), CFrame.new(0, b.top + 0.9, 0), Color3.fromRGB(220, 30, 30))
	end,
	pyramid = function(b)
		for i = 0, 3 do
			local w = 2.0 - i * 0.5
			addPart(b, "Hat", Vector3.new(w, 0.4, w), CFrame.new(0, b.top + 0.2 + i * 0.4, 0), i % 2 == 0 and b.recipe.accent or Color3.fromRGB(255, 205, 50))
		end
	end,
	cowboy = function(b)
		addPart(b, "Brim", Vector3.new(0.15, 2.6, 2.6), CFrame.new(0, b.top + 0.1, 0) * UPRIGHT_CYLINDER, b.recipe.accent, Enum.PartType.Cylinder)
		addPart(b, "Hat", Vector3.new(1.2, 1.3, 1.3), CFrame.new(0, b.top + 0.6, 0) * UPRIGHT_CYLINDER, b.recipe.accent, Enum.PartType.Cylinder)
	end,
	flip = function(b)
		addPart(b, "Hat", Vector3.new(0.6, 1.6, 0.6), CFrame.new(0.5, b.top + 0.6, 0) * CFrame.Angles(0, 0, math.rad(-30)), b.recipe.accent)
	end,
	fin = function(b)
		addPart(b, "Hat", Vector3.new(0.2, 1.2, 1.4), CFrame.new(0, b.top + 0.4, 0.2), b.recipe.accent)
	end,
	flame = function(b)
		local f = addPart(b, "Hat", Vector3.new(1.1, 1.6, 1.1), CFrame.new(0, b.top + 0.7, 0), Color3.fromRGB(255, 140, 0), Enum.PartType.Ball, Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = f
	end,
	graduate = function(b)
		addPart(b, "Hat", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, b.top + 0.25, 0), BLACK)
		addPart(b, "Board", Vector3.new(2.2, 0.15, 2.2), CFrame.new(0, b.top + 0.55, 0) * CFrame.Angles(0, math.rad(45), 0), BLACK)
		addPart(b, "Tassel", Vector3.new(0.15, 0.9, 0.15), CFrame.new(0.9, b.top + 0.2, -0.3), Color3.fromRGB(255, 205, 50))
	end,
	eye = function(b)
		addPart(b, "Hat", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, b.top + 0.6, 0), WHITE, Enum.PartType.Ball)
		addPart(b, "Iris", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, b.top + 0.6, -0.4), Color3.fromRGB(150, 60, 255), Enum.PartType.Ball, Enum.Material.Neon)
	end,
	tentacles = function(b)
		for i = 0, 5 do
			local a = i * math.pi / 3
			addPart(b, "Tentacle", Vector3.new(0.35, 1.3, 0.35), CFrame.new(math.cos(a) * 0.7, b.top + 0.4, math.sin(a) * 0.7) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6), b.recipe.accent)
		end
	end,
	horns = function(b)
		for _, side in { -1, 1 } do
			addPart(b, "Horn", Vector3.new(0.4, 1.4, 0.4), CFrame.new(side * 0.8, b.top + 0.5, 0) * CFrame.Angles(0, 0, side * math.rad(-25)), WHITE)
		end
		addPart(b, "Stripe", Vector3.new(2.5, 0.35, 2.1), CFrame.new(0, b.top - 1.6, 0), BLACK)
	end,
	tophat = function(b)
		addPart(b, "Brim", Vector3.new(0.15, 2.2, 2.2), CFrame.new(0, b.top + 0.1, 0) * UPRIGHT_CYLINDER, BLACK, Enum.PartType.Cylinder)
		addPart(b, "Hat", Vector3.new(1.8, 1.4, 1.4), CFrame.new(0, b.top + 1.0, 0) * UPRIGHT_CYLINDER, BLACK, Enum.PartType.Cylinder)
		addPart(b, "Band", Vector3.new(0.35, 1.45, 1.45), CFrame.new(0, b.top + 0.4, 0) * UPRIGHT_CYLINDER, b.recipe.accent, Enum.PartType.Cylinder)
	end,
	tiara = function(b)
		addPart(b, "Hat", Vector3.new(1.6, 0.4, 0.3), CFrame.new(0, b.top + 0.2, -0.3), Color3.fromRGB(255, 215, 0), nil, Enum.Material.Foil)
		addPart(b, "Gem", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, b.top + 0.5, -0.35), Color3.fromRGB(255, 50, 120), Enum.PartType.Ball, Enum.Material.Neon)
	end,
	wizard = function(b)
		for i = 0, 3 do
			local w = 2.2 - i * 0.5
			addPart(b, "Hat", Vector3.new(w, 0.55, w), CFrame.new(0, b.top + 0.25 + i * 0.5, 0) * CFrame.Angles(0, i * 0.3, 0), b.recipe.accent)
		end
	end,
	ghost = function(b)
		addPart(b, "Hat", Vector3.new(2.0, 0.7, 2.0), CFrame.new(0, b.top + 0.15, 0), b.recipe.accent, Enum.PartType.Ball, Enum.Material.Glass)
	end,
	hood = function(b)
		addPart(b, "Hat", Vector3.new(2.5, 1.3, 2.3), CFrame.new(0, b.top - 0.1, 0.15), BLACK)
	end,
	pharaoh = function(b)
		addPart(b, "Hat", Vector3.new(2.6, 0.6, 2.0), CFrame.new(0, b.top + 0.2, 0), Color3.fromRGB(255, 205, 50), nil, Enum.Material.Foil)
		for _, side in { -1, 1 } do
			addPart(b, "Flap", Vector3.new(0.4, 1.8, 1.0), CFrame.new(side * 1.3, b.top - 0.7, 0.2), b.recipe.accent)
		end
	end,
	halo = function(b)
		addPart(b, "Hat", Vector3.new(0.2, 2.0, 2.0), CFrame.new(0, b.top + 0.9, 0) * UPRIGHT_CYLINDER, Color3.fromRGB(255, 230, 120), Enum.PartType.Cylinder, Enum.Material.Neon)
	end,
	gele = function(b)
		for i = 0, 2 do
			addPart(b, "Hat", Vector3.new(2.6 - i * 0.4, 0.7, 1.6), CFrame.new(0, b.top + 0.3 + i * 0.55, 0) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 12 or -12)), b.recipe.accent, nil, Enum.Material.Foil)
		end
	end,
}

-- Extra props behind or beside the body.
local EXTRAS: { [string]: (Builder) -> () } = {
	cape = function(b)
		addPart(b, "Cape", Vector3.new(2.4, 2.4, 0.15), CFrame.new(0, 1.9, 1.15) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(190, 20, 40))
	end,
	tail = function(b)
		addPart(b, "Tail", Vector3.new(0.35, 0.35, 1.8), CFrame.new(0, 1.3, 1.5) * CFrame.Angles(math.rad(30), 0, 0), b.recipe.accent)
	end,
	wings = function(b)
		for _, side in { -1, 1 } do
			addPart(b, "Wing", Vector3.new(1.8, 1.4, 0.15), CFrame.new(side * 1.5, b.top - 0.6, 0.9) * CFrame.Angles(0, side * math.rad(-30), side * math.rad(-20)), WHITE, nil, Enum.Material.Neon).Transparency = 0.2
		end
	end,
	jetpack = function(b)
		for _, side in { -1, 1 } do
			local tank = addPart(b, "Tank", Vector3.new(1.6, 0.6, 0.6), CFrame.new(side * 0.4, 2.0, 1.25) * UPRIGHT_CYLINDER, Color3.fromRGB(180, 185, 195), Enum.PartType.Cylinder, Enum.Material.Metal)
			local fire = Instance.new("Fire")
			fire.Size = 2
			fire.Heat = -6
			fire.Parent = tank
		end
	end,
	katana = function(b)
		addPart(b, "Katana", Vector3.new(0.15, 3.0, 0.3), CFrame.new(1.4, 2.6, 0.3) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(220, 225, 235), nil, Enum.Material.Metal)
	end,
	shield = function(b)
		addPart(b, "Shield", Vector3.new(0.25, 1.8, 1.8), CFrame.new(-1.6, 1.9, -0.3) * UPRIGHT_CYLINDER * CFrame.Angles(0, math.rad(90), 0), b.recipe.accent, Enum.PartType.Cylinder, Enum.Material.Metal)
	end,
	antenna = function(b)
		addPart(b, "Antenna", Vector3.new(0.1, 1.6, 0.1), CFrame.new(0.6, b.top + 0.8, 0), BLACK)
		addPart(b, "Bulb", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.6, b.top + 1.65, 0), Color3.fromRGB(255, 220, 0), Enum.PartType.Ball, Enum.Material.Neon)
	end,
	staff = function(b)
		addPart(b, "Staff", Vector3.new(0.2, 4.0, 0.2), CFrame.new(1.7, 2.0, -0.3), Color3.fromRGB(90, 60, 40))
		addPart(b, "Orb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(1.7, 4.1, -0.3), b.recipe.accent, Enum.PartType.Ball, Enum.Material.Neon)
	end,
	halo = function(b)
		addPart(b, "Halo", Vector3.new(0.2, 2.4, 2.4), CFrame.new(0, b.top + 1.9, 0) * UPRIGHT_CYLINDER, Color3.fromRGB(255, 230, 120), Enum.PartType.Cylinder, Enum.Material.Neon)
	end,
}

-- Roblox draws at most 31 Highlights at once; belt and rival gremlins share a smaller budget so the
-- player's own stall (priority) always glows.
local GLOW_TAG = "MutationGlow"
local SHARED_GLOW_BUDGET = 18

-- Mutations recolour the body, swap its material, add a glow outline (budgeted) and particles.
function GremlinModel.applyMutation(model: Model, mutationName: string?, priority: boolean?)
	local mutation = Mutations.get(mutationName)
	if not mutation then
		return
	end
	for _, partName in { "Body", "ArmL", "ArmR", "LegL", "LegR" } do
		for _, child in model:GetChildren() do
			if child.Name == partName and child:IsA("BasePart") then
				child.Color = mutation.color
				child.Material = mutation.material
				if mutation.name == "Rainbow" then
					CollectionService:AddTag(child, "RainbowPart")
				end
			end
		end
	end
	if priority or #CollectionService:GetTagged(GLOW_TAG) < SHARED_GLOW_BUDGET then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.75
		highlight.FillColor = mutation.color
		highlight.OutlineColor = mutation.particle
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		if not priority then
			CollectionService:AddTag(highlight, GLOW_TAG)
		end
	end
	local body = model:FindFirstChild("Body")
	if body then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(mutation.particle)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Rate = 14
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1.5, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end
end

local function makeText(parent: Instance, name: string, text: string, color: Color3, height: number, order: number, strokeColor: Color3?)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, height)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = strokeColor or Color3.new(0, 0, 0)
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- The floating label: name, rarity (+ mutation), "+$X/s", and the price while on the belt. Sized in
-- studs (ShotFraming) so it reads at judge size; `lift` raises it (back-row pedestals sit higher).
function GremlinModel.attachLabel(model: Model, gremlin: GremlinCatalog.Gremlin, mutationName: string?, incomePerSecond: number, price: number?, lift: number?)
	local old = model:FindFirstChild("GremlinLabel")
	if old then
		old:Destroy()
	end
	local rarity = Rarities.get(gremlin.rarity)
	local mutation = Mutations.get(mutationName)
	local root = model.PrimaryPart
	local top = (model:GetAttribute("TopHeight") or 4) :: number
	local gui = Instance.new("BillboardGui")
	gui.Name = "GremlinLabel"
	gui.Adornee = root
	local height = price and ShotFraming.LABEL_HEIGHT_PRICED or ShotFraming.LABEL_HEIGHT
	gui.Size = UDim2.fromScale(ShotFraming.LABEL_WIDTH, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top + ShotFraming.LABEL_GAP + height / 2 + (lift or 0), 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local h = price and 0.25 or 1 / 3
	makeText(gui, "NameLine", gremlin.name, Color3.new(1, 1, 1), h * 1.08, 1)
	local rarityText = string.upper(rarity.name)
	if mutation then
		rarityText = string.upper(mutation.name) .. " " .. rarityText
	end
	makeText(gui, "RarityLine", rarityText, mutation and mutation.color or rarity.color, h * 0.92, 2, Color3.fromRGB(25, 10, 30))
	makeText(gui, "IncomeLine", Format.perSecond(incomePerSecond), Color3.fromRGB(80, 255, 90), h, 3, Color3.fromRGB(0, 50, 0))
	if price then
		makeText(gui, "PriceLine", Format.money(price), Color3.fromRGB(255, 220, 60), h, 4, Color3.fromRGB(60, 30, 0))
	end
	gui.Parent = model
end

-- Builds a whole gremlin model with its feet at `pivot`; the root is anchored.
function GremlinModel.build(gremlinId: string, mutationName: string?, pivot: CFrame, priorityGlow: boolean?): Model?
	local gremlin = GremlinCatalog.get(gremlinId)
	if not gremlin then
		warn("Unknown gremlin " .. tostring(gremlinId))
		return nil
	end
	local rarity = Rarities.get(gremlin.rarity)
	local model = Instance.new("Model")
	model.Name = gremlin.id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.Massless = true
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local b: Builder = { model = model, root = root, s = rarity.scale, top = 0, recipe = gremlin.recipe }
	b.top = buildBody(b)
	local hat = HATS[gremlin.recipe.hat]
	if hat then
		hat(b)
	end
	local extra = gremlin.recipe.extra and EXTRAS[gremlin.recipe.extra]
	if extra then
		extra(b)
	end
	model:SetAttribute("GremlinId", gremlin.id)
	model:SetAttribute("Mutation", mutationName)
	model:SetAttribute("TopHeight", (b.top + 1.2) * b.s)
	GremlinModel.applyMutation(model, mutationName, priorityGlow)
	model:PivotTo(pivot)
	return model
end

return GremlinModel
