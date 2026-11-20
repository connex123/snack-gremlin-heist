-- EffectsClient: floating "+$X" coins over earning pedestals, particle bursts for buys, placements,
-- whacks and splashes, a screen flash for upgrades/rebirths, and rainbow colour cycling.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Format = require(Shared.Format)
local UiKit = require(script.Parent.UiKit)

local EffectsClient = {}

local flash: Frame
local BURST_COLORS = {
	buy = Color3.fromRGB(255, 220, 60),
	place = Color3.fromRGB(90, 255, 120),
	whack = Color3.fromRGB(255, 80, 80),
	splash = Color3.fromRGB(120, 230, 255),
	swing = Color3.fromRGB(255, 255, 255),
}

function EffectsClient.create(gui: ScreenGui)
	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 50
	flash.Parent = gui
end

local function worldAttachment(position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = position
	return attachment
end

-- A "+$X" that rises and fades over a pedestal.
function EffectsClient.popIncome(position: Vector3, amount: number)
	local attachment = worldAttachment(position + Vector3.new(0, 1, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5, 1.6)
	gui.Adornee = attachment
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = UiKit.text(gui, "Pop", "+" .. Format.money(amount), UDim2.new(), UDim2.fromScale(1, 1), UiKit.GREEN)
	gui.Parent = attachment
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

function EffectsClient.burst(kind: string, position: Vector3)
	if kind == "upgrade" or kind == "rebirth" then
		flash.BackgroundColor3 = kind == "rebirth" and Color3.fromRGB(200, 120, 255) or Color3.fromRGB(120, 255, 140)
		flash.BackgroundTransparency = 0.4
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		return
	end
	if kind == "splash" then
		EffectsClient.knockback()
	end
	local attachment = worldAttachment(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(BURST_COLORS[kind] or Color3.new(1, 1, 1))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(kind == "swing" and 10 or 40)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

-- The surge shoves the local character inland (the client owns its character's physics).
function EffectsClient.knockback()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.new(0, 45, 70)
	end
end

-- Rainbow-mutated parts shift hue every frame.
function EffectsClient.stepRainbow()
	local hue = (os.clock() * 0.25) % 1
	for _, part in CollectionService:GetTagged("RainbowPart") do
		if part:IsA("BasePart") then
			part.Color = Color3.fromHSV(hue, 0.8, 1)
		end
	end
end

return EffectsClient
