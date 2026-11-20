-- Client bootstrap for Snack Gremlin Heist: builds the HUD, wires remotes to it and keys to actions.
-- Every module is loaded and started in isolation: a failure is warned with its name and the rest of
-- the client, above all the Studio shot keys, still starts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- Runs one setup step; a failure is logged and the rest of the client (and the shot keys) still start.
local function guarded(name: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[SnackGremlinHeist] client " .. name .. " failed: " .. tostring(err))
	end
	return ok
end

-- Requires a module by name from `parent`, or returns nil (with a warning) if it is missing or errors.
local function safeRequire(parent: Instance?, name: string): any
	local module = parent and parent:FindFirstChild(name)
	if not module then
		warn("[SnackGremlinHeist] client module missing: " .. name)
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[SnackGremlinHeist] client module " .. name .. " failed to load: " .. tostring(result))
		return nil
	end
	return result
end

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Remotes = safeRequire(Shared, "Remotes")
local ShotDirector = safeRequire(Shared, "ShotDirector")
local Hud = safeRequire(script.Parent, "Hud")
local Buttons = safeRequire(script.Parent, "Buttons")
local Toasts = safeRequire(script.Parent, "Toasts")
local EffectsClient = safeRequire(script.Parent, "EffectsClient")
local UpgradePanel = safeRequire(script.Parent, "UpgradePanel")
local IndexPanel = safeRequire(script.Parent, "IndexPanel")
local InputController = safeRequire(script.Parent, "InputController")
local FeatureStrip = safeRequire(script.Parent, "FeatureStrip")
local OrdersPanel = safeRequire(script.Parent, "OrdersPanel")

-- Calls module[fnName](...) if both exist, guarded.
local function call(module: any, label: string, fnName: string, ...: any)
	if module and typeof(module[fnName]) == "function" then
		guarded(label, module[fnName], ...)
	end
end

local gui: ScreenGui? = nil
if Hud then
	guarded("Hud", function()
		gui = Hud.create()
	end)
end
if not gui then
	-- a bare ScreenGui so every other panel still has a home
	guarded("fallback gui", function()
		local fallback = Instance.new("ScreenGui")
		fallback.Name = "SnackHud"
		fallback.IgnoreGuiInset = true
		fallback.ResetOnSpawn = false
		fallback.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 30)
		gui = fallback
	end)
end

local panels = {
	open = function(name: string)
		if name == "Upgrades" then
			call(UpgradePanel, "UpgradePanel.open", "setOpen", true)
		elseif name == "Index" then
			call(IndexPanel, "IndexPanel.open", "setOpen", true)
		end
	end,
	closeAll = function()
		call(UpgradePanel, "UpgradePanel.close", "setOpen", false)
		call(IndexPanel, "IndexPanel.close", "setOpen", false)
	end,
	setShotMode = function(on: boolean)
		call(Toasts, "Toasts.setVisible", "setVisible", not on)
	end,
}

-- The shot keys first: nothing below can stop them.
call(ShotDirector, "ShotDirector", "start", panels)

call(Toasts, "Toasts", "create", gui)
call(EffectsClient, "EffectsClient", "create", gui)
call(UpgradePanel, "UpgradePanel", "create", gui)
call(IndexPanel, "IndexPanel", "create", gui)
call(FeatureStrip, "FeatureStrip", "create", gui)
call(OrdersPanel, "OrdersPanel", "create", gui)

local function fire(remoteName: string)
	return function()
		if Remotes then
			guarded("fire " .. remoteName, function()
				Remotes.get(remoteName):FireServer()
			end)
		end
	end
end

local actions = {
	lock = fire("RequestLock"),
	whack = fire("RequestWhack"),
	upgrades = function()
		call(IndexPanel, "IndexPanel.close", "setOpen", false)
		call(UpgradePanel, "UpgradePanel.toggle", "toggle")
	end,
	rebirth = function()
		call(IndexPanel, "IndexPanel.close", "setOpen", false)
		call(UpgradePanel, "UpgradePanel.open", "setOpen", true)
	end,
	index = function()
		call(UpgradePanel, "UpgradePanel.close", "setOpen", false)
		call(IndexPanel, "IndexPanel.toggle", "toggle")
	end,
}
call(Buttons, "Buttons", "create", gui, actions)
call(InputController, "InputController", "start", actions)

-- Connects a handler to a server remote, guarded both at connect time and per event.
local function onRemote(remoteName: string, handler: (...any) -> ())
	if not Remotes then
		return
	end
	guarded("connect " .. remoteName, function()
		Remotes.get(remoteName).OnClientEvent:Connect(function(...)
			guarded(remoteName, handler, ...)
		end)
	end)
end

onRemote("StateChanged", function(snapshot)
	call(Hud, "Hud.update", "update", snapshot)
	call(Buttons, "Buttons.update", "update", snapshot)
	call(UpgradePanel, "UpgradePanel.update", "update", snapshot)
	call(IndexPanel, "IndexPanel.update", "update", snapshot)
	call(OrdersPanel, "OrdersPanel.update", "update", snapshot)
end)
onRemote("Banner", function(payload)
	call(Hud, "Hud.showBanner", "showBanner", payload)
end)
onRemote("Toast", function(text, color)
	call(Toasts, "Toasts.show", "show", text, color)
end)
onRemote("Effect", function(kind, position)
	call(EffectsClient, "EffectsClient.burst", "burst", kind, position)
end)
onRemote("IncomeTick", function(pops)
	if EffectsClient and typeof(pops) == "table" then
		for _, pop in pops do
			pcall(EffectsClient.popIncome, pop.position, pop.amount)
		end
	end
end)

local stepWarned = false
RunService.RenderStepped:Connect(function(dt)
	local ok, err = pcall(function()
		if Hud then
			Hud.step(dt)
		end
		if Buttons then
			Buttons.step()
		end
		if EffectsClient then
			EffectsClient.stepRainbow()
		end
	end)
	if not ok and not stepWarned then
		stepWarned = true -- once, so a broken frame step cannot flood the Output
		warn("[SnackGremlinHeist] client frame step failed: " .. tostring(err))
	end
end)
