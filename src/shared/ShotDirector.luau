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

local STAGE_WAIT = 2.5 -- seconds the client waits for the staged world to replicate before framing
local REQUEST_TIMEOUT = 8 -- a key is ignored while a shot is in flight, at most this long

local busyUntil = 0

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Waits (bounded) until the stall's gremlin models and the teleported character have replicated.
local function waitForStage(expect): boolean
	if typeof(expect) ~= "table" then
		return true
	end
	local deadline = os.clock() + STAGE_WAIT
	while os.clock() < deadline do
		local ready = true
		if expect.plotIndex and (expect.models or 0) > 0 then
			local count = 0
			for _, child in Workspace:GetChildren() do
				if child:IsA("Model") and child:GetAttribute("PlotIndex") == expect.plotIndex then
					count += 1
				end
			end
			ready = count >= expect.models
		end
		if ready and typeof(expect.stand) == "Vector3" then
			local root = localRoot()
			ready = root ~= nil and (root.Position - expect.stand).Magnitude < 5
		end
		if ready then
			return true
		end
		task.wait(0.05)
	end
	return false
end

-- Frames the staged shot and opens any panels it asks for.
function ShotDirector.applyShot(payload, panels)
	local camera = Workspace.CurrentCamera
	if not camera or typeof(payload) ~= "table" or typeof(payload.camera) ~= "CFrame" then
		return
	end
	if not waitForStage(payload.expect) then
		warn("[ShotDirector] " .. tostring(payload.shot) .. ": world still replicating after " .. STAGE_WAIT .. " s, framing anyway")
	end
	task.wait(0.2) -- one more beat for labels and the cash counter to settle
	pcall(panels.closeAll)
	for _, name in payload.panels or {} do
		pcall(panels.open, name)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = payload.fov or 70
	-- hold the frame for a few renders in case the camera module was mid-update
	for _ = 1, 6 do
		camera.CFrame = payload.camera
		RunService.RenderStepped:Wait()
	end
	busyUntil = 0
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
	pcall(panels.closeAll)
	pcall(panels.setShotMode, false)
	setCoreGui(Enum.CoreGuiType.PlayerList, true)
	setCoreGui(Enum.CoreGuiType.Chat, true)
end

function ShotDirector.start(panels)
	if not RunService:IsStudio() then
		return
	end
	setCoreGui(Enum.CoreGuiType.Backpack, false)
	local request = Remotes.get("ShotRequest")
	Remotes.get("ShotReady").OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.failed then
			warn("[ShotDirector] server could not stage " .. tostring(payload.shot) .. ": " .. tostring(payload.failed))
			busyUntil = 0
			return
		end
		local ok, err = pcall(ShotDirector.applyShot, payload, panels)
		if not ok then
			warn("[ShotDirector] framing failed: " .. tostring(err))
			busyUntil = 0
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		-- Only typing (chat or another TextBox) blocks the shot keys; a plain click on the game view
		-- followed by 1-4 must always work, whatever else marked the key as processed.
		if gameProcessed and UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local shot = SHOT_KEYS[input.KeyCode]
		if shot then
			if os.clock() < busyUntil then
				return
			end
			local stamp = os.clock() + REQUEST_TIMEOUT
			busyUntil = stamp
			setCoreGui(Enum.CoreGuiType.PlayerList, false)
			setCoreGui(Enum.CoreGuiType.Chat, false)
			pcall(panels.setShotMode, true)
			print("[ShotDirector] key " .. shot .. ": staging...")
			request:FireServer(shot)
			task.delay(REQUEST_TIMEOUT, function()
				if busyUntil == stamp then
					busyUntil = 0
					warn("[ShotDirector] no reply from the server for " .. shot .. ": press the key again, or 0 for the play camera")
				end
			end)
		elseif input.KeyCode == Enum.KeyCode.Zero then
			busyUntil = 0
			ShotDirector.resetCamera(panels)
		end
	end)
	print("[ShotDirector] ready: press 1 cover, 2 buy, 3 threat, 4 progress, 0 back to play")
end

return ShotDirector
