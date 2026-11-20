-- WaveModel: builds the Lagoon Surge wave: a tall teal wall with a white foam crest and spray.
local Workspace = game:GetService("Workspace")

local WaveModel = {}
WaveModel.HEIGHT = 30
local WAVE_HEIGHT = WaveModel.HEIGHT

-- The wave: a tall teal wall with a white foam crest and spray particles.
function WaveModel.build(z: number): Model
	local model = Instance.new("Model")
	model.Name = "LagoonSurge"
	local wall = Instance.new("Part")
	wall.Name = "WaveWall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.Size = Vector3.new(420, WAVE_HEIGHT, 18)
	wall.Color = Color3.fromRGB(20, 170, 190)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.25
	wall.CFrame = CFrame.new(0, WAVE_HEIGHT / 2 - 2, z)
	wall.Parent = model
	local crest = Instance.new("Part")
	crest.Name = "Foam"
	crest.Anchored = true
	crest.CanCollide = false
	crest.CanQuery = false
	crest.Shape = Enum.PartType.Cylinder
	crest.Size = Vector3.new(420, 10, 10)
	crest.Color = Color3.fromRGB(240, 255, 255)
	crest.Material = Enum.Material.SmoothPlastic
	crest.CFrame = CFrame.new(0, WAVE_HEIGHT - 3, z + 5)
	crest.Parent = model
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 300
	spray.Lifetime = NumberRange.new(1, 2)
	spray.Speed = NumberRange.new(10, 20)
	spray.SpreadAngle = Vector2.new(40, 40)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Size = NumberSequence.new(2, 0)
	spray.Color = ColorSequence.new(Color3.new(1, 1, 1))
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Parent = crest
	model.PrimaryPart = wall
	model.Parent = Workspace
	return model
end

return WaveModel
