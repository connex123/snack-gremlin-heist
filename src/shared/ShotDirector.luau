-- ShotDirector (client, Studio only): number keys stage the four screenshots through the server's
-- real systems, then frame the camera. 1 cover, 2 buy, 3 threat, 4 progress, 0 back to play.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(script.Parent.Remotes)

local ShotDirector = {}

local SHOT_KEYS = {
	[Enum.KeyCode.One] = "cover",
	[Enum.KeyCode.Two] = "buy",
	[Enum.KeyCode.Three] = "threat",
	[Enum.KeyCode.Four] = "progress",
}

local function setCoreGui(kind: Enum.CoreGuiType, enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, enabled)
	end)
end

-- Frames the staged shot and opens any panels it asks for.
function ShotDirector.applyShot(payload, panels)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	panels.closeAll()
	for _, name in payload.panels or {} do
		panels.open(name)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = payload.fov or 70
	camera.CFrame = payload.camera
end

function ShotDirector.resetCamera(panels)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	panels.closeAll()
	setCoreGui(Enum.CoreGuiType.PlayerList, true)
end

function ShotDirector.start(panels)
	if not RunService:IsStudio() then
		return
	end
	setCoreGui(Enum.CoreGuiType.Backpack, false)
	local request = Remotes.get("ShotRequest")
	Remotes.get("ShotReady").OnClientEvent:Connect(function(payload)
		ShotDirector.applyShot(payload, panels)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local shot = SHOT_KEYS[input.KeyCode]
		if shot then
			setCoreGui(Enum.CoreGuiType.PlayerList, false)
			setCoreGui(Enum.CoreGuiType.Chat, false)
			request:FireServer(shot)
		elseif input.KeyCode == Enum.KeyCode.Zero then
			ShotDirector.resetCamera(panels)
		end
	end)
end

return ShotDirector
