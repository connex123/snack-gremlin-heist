-- PirateModel: builds a Pocket Pirate from Parts: striped shirt, bandana, eyepatch, a huge loot bag
-- and a "POCKET PIRATE" label whose status line PocketPirates updates.
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PirateModel = {}

local function piece(model: Model, root: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- A Pocket Pirate: striped shirt, bandana, eyepatch, a huge checkered loot bag and a label.
function PirateModel.build(at: CFrame): (Model, TextLabel)
	local model = Instance.new("Model")
	model.Name = "PocketPirate"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 0.2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root
	local skin = Color3.fromRGB(150, 100, 70)
	for _, side in { -0.6, 0.6 } do
		piece(model, root, Vector3.new(0.8, 2.2, 0.8), CFrame.new(side, 1.1, 0), Color3.fromRGB(30, 30, 60))
	end
	for i = 0, 3 do
		piece(model, root, Vector3.new(2.6, 0.6, 1.4), CFrame.new(0, 2.5 + i * 0.6, 0), i % 2 == 0 and Color3.fromRGB(220, 30, 40) or Color3.new(1, 1, 1))
	end
	piece(model, root, Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 5.8, 0), skin, Enum.PartType.Ball)
	piece(model, root, Vector3.new(2.3, 0.7, 2.3), CFrame.new(0, 6.6, 0), Color3.fromRGB(200, 20, 30))
	piece(model, root, Vector3.new(0.7, 0.7, 0.2), CFrame.new(0.45, 6.0, -1.05), Color3.fromRGB(10, 10, 10))
	piece(model, root, Vector3.new(0.45, 0.45, 0.45), CFrame.new(-0.45, 6.0, -1.0), Color3.new(1, 1, 1), Enum.PartType.Ball)
	piece(model, root, Vector3.new(1.2, 0.25, 0.2), CFrame.new(0, 5.2, -1.05), Color3.fromRGB(60, 20, 20))
	for _, side in { -1, 1 } do
		piece(model, root, Vector3.new(0.6, 2.0, 0.6), CFrame.new(side * 1.6, 3.6, -0.3) * CFrame.Angles(math.rad(-50), 0, 0), skin)
	end
	local bag = piece(model, root, Vector3.new(2.6, 2.2, 1.6), CFrame.new(0, 3.4, 1.4), Color3.fromRGB(60, 80, 200))
	bag.Material = Enum.Material.Fabric
	piece(model, root, Vector3.new(2.7, 0.4, 1.7), CFrame.new(0, 3.4, 1.4), Color3.fromRGB(230, 60, 60))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
	gui.Adornee = root
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = "POCKET PIRATE"
	title.TextColor3 = Color3.fromRGB(255, 70, 70)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = title
	title.Parent = gui
	local status = title:Clone()
	status.Position = UDim2.fromScale(0, 0.55)
	status.Size = UDim2.fromScale(1, 0.45)
	status.Text = "sneaking..."
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Parent = gui
	gui.Parent = model
	model:PivotTo(at)
	model.Parent = Workspace
	return model, status
end

-- Welds a stolen gremlin on top of the pirate's loot bag.
function PirateModel.holdGremlin(pirate: Model, gremlin: Model?): Model?
	if not gremlin or not gremlin.PrimaryPart or not pirate.PrimaryPart then
		return nil
	end
	gremlin:PivotTo(pirate:GetPivot() * CFrame.new(0, 7.5, 1.5))
	gremlin.PrimaryPart.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = pirate.PrimaryPart
	weld.Part1 = gremlin.PrimaryPart
	weld.Parent = gremlin.PrimaryPart
	gremlin.Parent = pirate
	return gremlin
end

-- A whacked pirate spins up and away, then onDone runs.
function PirateModel.flyAway(pirate: Model, onDone: () -> ())
	local value = Instance.new("CFrameValue")
	value.Value = pirate:GetPivot()
	value.Changed:Connect(function(cf)
		if pirate.Parent then
			pirate:PivotTo(cf)
		end
	end)
	local target = pirate:GetPivot() * CFrame.new(0, 40, 30) * CFrame.Angles(math.rad(720), 0, math.rad(360))
	local tween = TweenService:Create(value, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
	tween:Play()
	tween.Completed:Once(function()
		value:Destroy()
		onDone()
	end)
end

return PirateModel
