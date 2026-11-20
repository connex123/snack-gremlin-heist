-- Client bootstrap for Snack Gremlin Heist: builds the HUD, wires remotes to it and keys to actions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local ShotDirector = require(Shared.ShotDirector)
local Hud = require(script.Parent.Hud)
local Buttons = require(script.Parent.Buttons)
local Toasts = require(script.Parent.Toasts)
local EffectsClient = require(script.Parent.EffectsClient)
local UpgradePanel = require(script.Parent.UpgradePanel)
local IndexPanel = require(script.Parent.IndexPanel)
local InputController = require(script.Parent.InputController)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local gui = Hud.create()
Toasts.create(gui)
EffectsClient.create(gui)
UpgradePanel.create(gui)
IndexPanel.create(gui)

local actions = {
	lock = function()
		Remotes.get("RequestLock"):FireServer()
	end,
	whack = function()
		Remotes.get("RequestWhack"):FireServer()
	end,
	upgrades = function()
		IndexPanel.setOpen(false)
		UpgradePanel.toggle()
	end,
	rebirth = function()
		IndexPanel.setOpen(false)
		UpgradePanel.setOpen(true)
	end,
	index = function()
		UpgradePanel.setOpen(false)
		IndexPanel.toggle()
	end,
}
Buttons.create(gui, actions)
InputController.start(actions)

Remotes.get("StateChanged").OnClientEvent:Connect(function(snapshot)
	Hud.update(snapshot)
	Buttons.update(snapshot)
	UpgradePanel.update(snapshot)
	IndexPanel.update(snapshot)
end)
Remotes.get("Banner").OnClientEvent:Connect(Hud.showBanner)
Remotes.get("Toast").OnClientEvent:Connect(Toasts.show)
Remotes.get("Effect").OnClientEvent:Connect(EffectsClient.burst)
Remotes.get("IncomeTick").OnClientEvent:Connect(function(pops)
	for _, pop in pops do
		EffectsClient.popIncome(pop.position, pop.amount)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	Hud.step(dt)
	Buttons.step()
	EffectsClient.stepRainbow()
end)

ShotDirector.start({
	open = function(name: string)
		if name == "Upgrades" then
			UpgradePanel.setOpen(true)
		elseif name == "Index" then
			IndexPanel.setOpen(true)
		end
	end,
	closeAll = function()
		UpgradePanel.setOpen(false)
		IndexPanel.setOpen(false)
	end,
})
