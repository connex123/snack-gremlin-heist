-- WorldBuilder: builds the sunset night market from Parts at server start: plaza, lagoon, Snack Belt,
-- six stalls with pedestals and shutters, stilt decks (surge-safe), string lights, umbrellas, palms,
-- a parked danfo bus, the skyline, the title sign and golden-hour lighting.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared", 30).Config)

local WorldBuilder = {}

export type Plot = {
	index: number,
	cframe: CFrame,
	floor: BasePart,
	pedestals: { BasePart },
	pedestalTops: { CFrame },
	signLabel: TextLabel,
	shutter: BasePart,
	shutterLabel: TextLabel,
	owner: Player?,
	rivalName: string?,
	rivalSlots: { [number]: any },
	models: { [number]: Model },
}

local DANFO_YELLOW = Color3.fromRGB(255, 196, 0)
local STRIPE_BLACK = Color3.fromRGB(25, 25, 28)
local CORAL = Color3.fromRGB(255, 95, 110)
local TEAL = Color3.fromRGB(0, 200, 190)
local NEON_COLORS = { CORAL, TEAL, DANFO_YELLOW, Color3.fromRGB(180, 90, 255), Color3.fromRGB(90, 255, 120) }

local worldFolder: Folder

-- Creates one anchored part in the world folder.
local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or worldFolder
	return part
end

local function cylinder(name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
	local part = block(name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
end

-- A SurfaceGui with one big outlined line of text on a part's front face.
local function signText(part: BasePart, text: string, color: Color3, face: Enum.NormalId?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(30, 10, 30)
	stroke.Parent = label
	label.Parent = gui
	return label
end

-- Golden hour: low warm sun, haze over the lagoon, bloom on the neon, warm saturated grade.
function WorldBuilder.applyGoldenHourLighting()
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 6
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 50, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 110, 110)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local function ensure(className: string): Instance
		local existing = Lighting:FindFirstChildOfClass(className)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(255, 190, 150)
	atmosphere.Decay = Color3.fromRGB(190, 90, 120)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.4
	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.9
	bloom.Size = 30
	bloom.Threshold = 1.4
	local grade = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	grade.Saturation = 0.28
	grade.Contrast = 0.12
	grade.Brightness = 0.03
	grade.TintColor = Color3.fromRGB(255, 238, 220)
	local rays = ensure("SunRaysEffect") :: SunRaysEffect
	rays.Intensity = 0.12
	rays.Spread = 0.6
end

-- Plaza, lagoon water and sand, the lane strip.
function WorldBuilder.buildGroundAndLagoon()
	block("Plaza", Vector3.new(360, 2, 190), CFrame.new(0, -1, 17), Color3.fromRGB(196, 150, 110), Enum.Material.Cobblestone)
	block("Lane", Vector3.new(330, 0.2, 26), CFrame.new(0, 0.05, 0), Color3.fromRGB(70, 60, 70), Enum.Material.Asphalt)
	block("SouthSand", Vector3.new(700, 2, 300), CFrame.new(0, -1.2, 260), Color3.fromRGB(230, 200, 140), Enum.Material.Sand)
	block("Seawall", Vector3.new(360, 3, 3), CFrame.new(0, -0.4, Config.LAGOON_EDGE_Z), Color3.fromRGB(120, 110, 105), Enum.Material.Slate)
	local terrain = workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(20, 150, 160)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.3
	terrain.WaterReflectance = 0.6
	local ok, err = pcall(function()
		terrain:FillBlock(CFrame.new(0, -14, -330), Vector3.new(1200, 8, 500), Enum.Material.Sand)
		terrain:FillBlock(CFrame.new(0, -5.5, -330), Vector3.new(1200, 10, 500), Enum.Material.Water)
	end)
	if not ok then
		warn("Lagoon terrain failed: " .. tostring(err))
		block("LagoonFallback", Vector3.new(1200, 1, 500), CFrame.new(0, -1.5, -330), Color3.fromRGB(20, 150, 160), Enum.Material.Glass)
	end
	-- A pier where the Pocket Pirates moor their dinghy.
	block("Pier", Vector3.new(14, 1, 30), CFrame.new(0, 0.2, Config.LAGOON_EDGE_Z - 14), Color3.fromRGB(120, 80, 50), Enum.Material.WoodPlanks)
	local boat = block("PirateDinghy", Vector3.new(8, 2, 14), CFrame.new(12, -0.2, Config.LAGOON_EDGE_Z - 20), Color3.fromRGB(40, 40, 45), Enum.Material.Wood)
	cylinder("Mast", 12, 0.5, CFrame.new(12, 6, Config.LAGOON_EDGE_Z - 20), Color3.fromRGB(90, 60, 40))
	local sail = block("Sail", Vector3.new(0.2, 7, 6), CFrame.new(12, 7, Config.LAGOON_EDGE_Z - 20), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric)
	signText(sail, "$", Color3.fromRGB(255, 220, 60), Enum.NormalId.Right)
	boat.Name = "PirateDinghy"
end

-- The Snack Belt: a long conveyor with danfo-striped rails, a kitchen hatch at one end and a drop at the other.
function WorldBuilder.buildSnackBelt()
	local z, top = Config.BELT_Z, Config.BELT_TOP_Y
	local length = Config.BELT_END_X - Config.BELT_START_X + 20
	block("BeltBase", Vector3.new(length, top - 0.4, 9), CFrame.new(0, (top - 0.4) / 2, z), Color3.fromRGB(45, 45, 50), Enum.Material.Metal)
	block("BeltTop", Vector3.new(length, 0.4, 7), CFrame.new(0, top - 0.2, z), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber)
	local x = -length / 2
	local i = 0
	while x < length / 2 do
		for _, side in { -1, 1 } do
			block("Rail", Vector3.new(4, 1, 1), CFrame.new(x + 2, top + 0.3, z + side * 4), i % 2 == 0 and DANFO_YELLOW or STRIPE_BLACK)
		end
		x += 4
		i += 1
	end
	-- Kitchen hatch where gremlins hatch out, and the lagoon drop at the far end.
	local hatch = block("KitchenHatch", Vector3.new(14, 16, 16), CFrame.new(Config.BELT_START_X - 8, 8, z), Color3.fromRGB(150, 40, 60), Enum.Material.Brick)
	local hatchSign = block("HatchSign", Vector3.new(1, 5, 15), CFrame.new(Config.BELT_START_X - 0.6, 13, z), CORAL, Enum.Material.Neon)
	signText(hatchSign, "SNACK KITCHEN", Color3.new(1, 1, 1), Enum.NormalId.Right)
	addLight(hatch, CORAL, 30, 3)
	-- Arch gates over the belt.
	for _, ax in { -96, 96 } do
		for _, side in { -1, 1 } do
			block("ArchPost", Vector3.new(1.5, 18, 1.5), CFrame.new(ax, 9, z + side * 7), DANFO_YELLOW, Enum.Material.Metal)
		end
		local beam = block("ArchBeam", Vector3.new(3, 4, 16), CFrame.new(ax, 18, z), STRIPE_BLACK, Enum.Material.Metal)
		local face = block("ArchSign", Vector3.new(0.4, 3.4, 15), CFrame.new(ax + (ax < 0 and 1.7 or -1.7), 18, z), TEAL, Enum.Material.Neon)
		signText(face, "SNACK BELT", Color3.new(1, 1, 1), ax < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		addLight(beam, TEAL, 24, 2)
	end
end

-- One stall: tiered floor, ten pedestals, back wall with the owner's sign, a striped awning and a shutter.
function WorldBuilder.buildStall(index: number, position: Vector3): Plot
	local folder = Instance.new("Model")
	folder.Name = "Stall" .. index
	folder.Parent = worldFolder
	local cf = CFrame.lookAt(position, Vector3.new(position.X, position.Y, Config.BELT_Z))
	local fh = Config.STALL_FLOOR_HEIGHT
	local floor = block("Floor", Vector3.new(36, fh, 26), cf * CFrame.new(0, fh / 2, 0), Config.floorColor(0), Enum.Material.SmoothPlastic, folder)
	-- danfo stripes along the front edge
	for i = 0, 8 do
		block("Trim", Vector3.new(4, fh + 0.1, 1), cf * CFrame.new(-16 + i * 4, fh / 2, -13), i % 2 == 0 and DANFO_YELLOW or STRIPE_BLACK, nil, folder)
	end
	block("Riser", Vector3.new(34, 2.2, 9), cf * CFrame.new(0, fh + 1.1, 6), Color3.fromRGB(120, 70, 50), Enum.Material.WoodPlanks, folder)
	local pedestals, tops = {}, {}
	for row = 0, 1 do
		for col = 0, 4 do
			local x = -13 + col * 6.5
			local z = row == 0 and -4 or 6
			local base = fh + (row == 0 and 0 or 2.2)
			local pedestal = cylinder("Pedestal", 1, 4.4, cf * CFrame.new(x, base + 0.5, z), Color3.fromRGB(240, 240, 245), Enum.Material.Marble, folder)
			local ring = cylinder("PedestalRing", 0.3, 4.8, cf * CFrame.new(x, base + 0.1, z), TEAL, Enum.Material.Neon, folder)
			ring.Name = "PedestalRing"
			table.insert(pedestals, pedestal)
			table.insert(tops, cf * CFrame.new(x, base + 1, z))
		end
	end
	block("BackWall", Vector3.new(36, 13, 1.2), cf * CFrame.new(0, fh + 6.5, 12.6), Color3.fromRGB(60, 40, 70), Enum.Material.Brick, folder)
	local signBoard = block("SignBoard", Vector3.new(30, 4.5, 0.6), cf * CFrame.new(0, fh + 15, 12.2), STRIPE_BLACK, Enum.Material.SmoothPlastic, folder)
	local signLabel = signText(signBoard, "OPEN STALL", DANFO_YELLOW)
	addLight(signBoard, DANFO_YELLOW, 22, 2)
	for _, side in { -1, 1 } do
		block("Post", Vector3.new(1, 14, 1), cf * CFrame.new(side * 17.5, fh + 7, -12), DANFO_YELLOW, Enum.Material.Metal, folder)
		local lamp = block("Lamp", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(side * 17.5, fh + 14.5, -12), CORAL, Enum.Material.Neon, folder)
		addLight(lamp, Color3.fromRGB(255, 180, 120), 26, 2.5)
	end
	-- striped awning over the back row only, so the front stays open to the camera
	for i = 0, 8 do
		block("Awning", Vector3.new(4, 0.4, 9), cf * CFrame.new(-16 + i * 4, fh + 13.2, 8) * CFrame.Angles(math.rad(-14), 0, 0), i % 2 == 0 and CORAL or Color3.new(1, 1, 1), Enum.Material.Fabric, folder)
	end
	local shutter = block("Shutter", Vector3.new(36, 10, 0.4), cf * CFrame.new(0, fh + 5, -13.6), Color3.fromRGB(80, 220, 255), Enum.Material.ForceField, folder)
	shutter.Transparency = 1
	shutter.CanCollide = false
	local shutterLabel = signText(shutter, "", Color3.new(1, 1, 1))
	shutterLabel.Visible = false
	return {
		index = index,
		cframe = cf,
		floor = floor,
		pedestals = pedestals,
		pedestalTops = tops,
		signLabel = signLabel,
		shutter = shutter,
		shutterLabel = shutterLabel,
		owner = nil,
		rivalName = nil,
		rivalSlots = {},
		models = {},
	}
end

-- Raised stilt decks with steps: standing on one keeps you dry when the Lagoon Surge rolls through.
function WorldBuilder.buildStiltDecks()
	local spots = { Vector3.new(-36, 0, 22), Vector3.new(36, 0, 22), Vector3.new(-36, 0, -22), Vector3.new(36, 0, -22), Vector3.new(-120, 0, 22), Vector3.new(120, 0, -22) }
	for _, spot in spots do
		local h = Config.SURGE_SAFE_HEIGHT + 1
		block("StiltDeck", Vector3.new(14, 1, 12), CFrame.new(spot.X, h, spot.Z), Color3.fromRGB(140, 95, 60), Enum.Material.WoodPlanks)
		for _, dx in { -6, 6 } do
			for _, dz in { -5, 5 } do
				block("Stilt", Vector3.new(1, h, 1), CFrame.new(spot.X + dx, h / 2, spot.Z + dz), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
			end
		end
		for step = 1, h do
			block("Step", Vector3.new(5, 1, 1.6), CFrame.new(spot.X - 7 - (h - step) * 1.6 - 0.8, step - 0.5, spot.Z), Color3.fromRGB(160, 110, 70), Enum.Material.WoodPlanks)
		end
		local sign = block("SafeSign", Vector3.new(10, 2.2, 0.3), CFrame.new(spot.X, h + 3, spot.Z + (spot.Z > 0 and 5.8 or -5.8)) * CFrame.Angles(0, spot.Z > 0 and math.pi or 0, 0), Color3.fromRGB(30, 160, 80), Enum.Material.Neon)
		signText(sign, "SURGE SAFE DECK", Color3.new(1, 1, 1), Enum.NormalId.Back)
		signText(sign, "SURGE SAFE DECK", Color3.new(1, 1, 1), Enum.NormalId.Front)
	end
end

-- String lights, market umbrellas, palms and a parked danfo bus.
function WorldBuilder.buildDecor()
	-- string lights on poles along both sides of the lane
	for _, z in { -11, 11 } do
		local prev: Vector3? = nil
		for x = -165, 165, 30 do
			local pole = block("LightPole", Vector3.new(0.8, 18, 0.8), CFrame.new(x, 9, z), STRIPE_BLACK, Enum.Material.Metal)
			pole.CanCollide = true
			local topPos = Vector3.new(x, 17.5, z)
			if prev then
				for i = 1, 9 do
					local t = i / 10
					local p = prev:Lerp(topPos, t) - Vector3.new(0, math.sin(t * math.pi) * 3, 0)
					local bulb = block("Bulb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(p), NEON_COLORS[(i % #NEON_COLORS) + 1], Enum.Material.Neon)
					bulb.Shape = Enum.PartType.Ball
					bulb.CanCollide = false
					if i == 5 then
						addLight(bulb, bulb.Color, 18, 1.2)
					end
				end
			end
			prev = topPos
		end
	end
	-- umbrellas between stalls
	local umbrellaSpots = { Vector3.new(-36, 0, 60), Vector3.new(36, 0, 60), Vector3.new(-108, 0, 60), Vector3.new(108, 0, 60), Vector3.new(-36, 0, -60), Vector3.new(36, 0, -60), Vector3.new(-108, 0, -55), Vector3.new(108, 0, -55) }
	for i, spot in umbrellaSpots do
		block("UmbrellaPole", Vector3.new(0.4, 9, 0.4), CFrame.new(spot.X, 4.5, spot.Z), Color3.fromRGB(230, 230, 230))
		for k = 0, 5 do
			block("UmbrellaPanel", Vector3.new(4.2, 0.3, 5), CFrame.new(spot.X, 8.6, spot.Z) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0, -2.4) * CFrame.Angles(math.rad(20), 0, 0), k % 2 == 0 and NEON_COLORS[(i % #NEON_COLORS) + 1] or Color3.new(1, 1, 1), Enum.Material.Fabric)
		end
		block("Table", Vector3.new(5, 0.4, 5), CFrame.new(spot.X, 3, spot.Z), Color3.fromRGB(240, 240, 240))
	end
	-- palms
	for _, spot in { Vector3.new(-170, 0, 30), Vector3.new(170, 0, 30), Vector3.new(-160, 0, -70), Vector3.new(160, 0, -70), Vector3.new(-140, 0, 85), Vector3.new(140, 0, 85) } do
		for s = 0, 6 do
			block("PalmTrunk", Vector3.new(1.6, 3, 1.6), CFrame.new(spot.X + s * 0.4, 1.5 + s * 3, spot.Z) * CFrame.Angles(0, 0, math.rad(-6)), Color3.fromRGB(130, 90, 55), Enum.Material.Wood)
		end
		for k = 0, 6 do
			block("PalmLeaf", Vector3.new(1.6, 0.3, 9), CFrame.new(spot.X + 2.8, 21, spot.Z) * CFrame.Angles(0, k * math.pi * 2 / 7, 0) * CFrame.new(0, 0, -4) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(40, 160, 60), Enum.Material.Grass)
		end
	end
	-- a parked danfo bus: yellow, black stripes, windows
	local busCf = CFrame.new(-150, 4, 62) * CFrame.Angles(0, math.rad(80), 0)
	block("DanfoBody", Vector3.new(9, 7, 22), busCf, DANFO_YELLOW, Enum.Material.Metal)
	for _, y in { -1.6, 1.2 } do
		block("DanfoStripe", Vector3.new(9.1, 0.6, 22.1), busCf * CFrame.new(0, y, 0), STRIPE_BLACK)
	end
	block("DanfoWindows", Vector3.new(9.2, 2, 18), busCf * CFrame.new(0, 2.4, 0), Color3.fromRGB(120, 200, 230), Enum.Material.Glass)
	for _, wz in { -7, 7 } do
		for _, wx in { -4.6, 4.6 } do
			cylinder("Wheel", 1, 3, busCf * CFrame.new(wx, -3, wz) * CFrame.Angles(0, 0, math.rad(90)), STRIPE_BLACK)
		end
	end
end

-- Colourful buildings behind the south stalls and across the lagoon, plus the giant title sign.
function WorldBuilder.buildSkylineAndTitle()
	local rng = Random.new(7)
	for x = -220, 220, 22 do
		local h = rng:NextNumber(26, 60)
		local color = Color3.fromHSV(rng:NextNumber(0, 1), 0.45, 0.75)
		local tower = block("Building", Vector3.new(20, h, 18), CFrame.new(x, h / 2, 120 + rng:NextNumber(0, 20)), color, Enum.Material.Concrete)
		for wy = 6, h - 6, 8 do
			local win = block("Windows", Vector3.new(16, 2.5, 0.3), tower.CFrame * CFrame.new(0, wy - h / 2, -9.1), NEON_COLORS[rng:NextInteger(1, #NEON_COLORS)], Enum.Material.Neon)
			win.Transparency = 0.15
		end
		local far = block("FarShore", Vector3.new(26, h * 1.4, 20), CFrame.new(x * 2.2, h * 0.7 - 4, -560), Color3.fromHSV(rng:NextNumber(0.55, 0.9), 0.35, 0.35), Enum.Material.Concrete)
		far.CastShadow = false
	end
	local board = block("TitleBoard", Vector3.new(90, 22, 2), CFrame.new(0, 64, 100) * CFrame.Angles(0, math.pi, 0), STRIPE_BLACK, Enum.Material.SmoothPlastic)
	board.CFrame = CFrame.lookAt(Vector3.new(0, 64, 100), Vector3.new(0, 64, 0))
	local label = signText(board, "SNACK GREMLIN HEIST", DANFO_YELLOW)
	label.TextColor3 = DANFO_YELLOW
	local frame = block("TitleFrame", Vector3.new(94, 26, 1.5), board.CFrame * CFrame.new(0, 0, 1), CORAL, Enum.Material.Neon)
	frame.CastShadow = false
	for _, side in { -1, 1 } do
		block("TitleLeg", Vector3.new(2, 54, 2), CFrame.new(side * 36, 27, 101), STRIPE_BLACK, Enum.Material.Metal)
	end
	addLight(board, DANFO_YELLOW, 60, 3)
end

-- A spawn pad in front of the first stall.
function WorldBuilder.buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MarketSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.2, 18)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = TEAL
	spawn.Material = Enum.Material.Neon
	spawn.Parent = worldFolder
end

-- Builds everything; returns the stall plots in Config.STALL_SPOTS order.
function WorldBuilder.buildAll(): { Plot }
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "Market"
	worldFolder.Parent = workspace
	WorldBuilder.applyGoldenHourLighting()
	WorldBuilder.buildGroundAndLagoon()
	WorldBuilder.buildSnackBelt()
	local plots = {}
	for index, spot in Config.STALL_SPOTS do
		table.insert(plots, WorldBuilder.buildStall(index, spot))
	end
	WorldBuilder.buildStiltDecks()
	WorldBuilder.buildDecor()
	WorldBuilder.buildSkylineAndTitle()
	WorldBuilder.buildSpawn()
	return plots
end

return WorldBuilder
