-- UpgradePanel: the four upgrades with level and cost, and the Rebirth section with its reward.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local UiKit = require(script.Parent.UiKit)

local UpgradePanel = {}

local panel: Frame
local rows: { [string]: { level: TextLabel, buy: TextButton } } = {}
local rebirthInfo: TextLabel

function UpgradePanel.create(gui: ScreenGui)
	panel = UiKit.panel(gui, "UpgradePanel", UDim2.fromScale(0.27, 0.47), UDim2.fromScale(0.4, 0.6), UiKit.INK, 0.08)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	UiKit.stroke(panel, Color3.fromRGB(60, 190, 80), 4)
	UiKit.text(panel, "Title", "UPGRADES", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.12), Color3.fromRGB(120, 255, 140))
	local request = Remotes.get("RequestUpgrade")
	for i, info in Config.UPGRADES do
		local y = 0.15 + (i - 1) * 0.135
		UiKit.text(panel, info.key .. "Name", info.label, UDim2.fromScale(0.04, y), UDim2.fromScale(0.46, 0.07), Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
		local level = UiKit.text(panel, info.key .. "Level", info.hint, UDim2.fromScale(0.04, y + 0.07), UDim2.fromScale(0.5, 0.05), Color3.fromRGB(190, 190, 210), Enum.TextXAlignment.Left)
		local buy = UiKit.button(panel, info.key .. "Buy", "", UDim2.fromScale(0.58, y + 0.01), UDim2.fromScale(0.38, 0.1), Color3.fromRGB(60, 190, 80))
		buy.Activated:Connect(function()
			request:FireServer(info.key)
		end)
		rows[info.key] = { level = level, buy = buy }
	end
	local rebirthBox = UiKit.panel(panel, "RebirthBox", UDim2.fromScale(0.03, 0.71), UDim2.fromScale(0.94, 0.26), Color3.fromRGB(90, 40, 140), 0.05)
	UiKit.stroke(rebirthBox, Color3.fromRGB(200, 140, 255), 3)
	rebirthInfo = UiKit.text(rebirthBox, "Info", "", UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.55, 0.84), Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	local rebirthButton = UiKit.button(rebirthBox, "RebirthNow", "REBIRTH!", UDim2.fromScale(0.6, 0.15), UDim2.fromScale(0.37, 0.7), Color3.fromRGB(160, 80, 240))
	rebirthButton.Activated:Connect(function()
		Remotes.get("RequestRebirth"):FireServer()
	end)
end

function UpgradePanel.update(snapshot)
	for key, row in rows do
		local level = snapshot.upgrades[key] or 0
		local info = Config.upgradeInfo(key)
		local cost = Config.upgradeCost(key, level)
		row.level.Text = "LV " .. level .. "/" .. (info and info.max or 0) .. " · " .. (info and info.hint or "")
		row.buy.Text = cost and Format.money(cost) or "MAX"
		row.buy.BackgroundColor3 = (cost and snapshot.cash >= cost) and Color3.fromRGB(60, 190, 80) or Color3.fromRGB(110, 110, 120)
	end
	local nextMult = Config.rebirthMultiplier(snapshot.rebirths + 1)
	rebirthInfo.Text = string.format("REBIRTH %d -> x%.1f INCOME\ncost %s, new stall floor", snapshot.rebirths + 1, nextMult, Format.money(Config.rebirthCost(snapshot.rebirths)))
end

function UpgradePanel.setOpen(open: boolean)
	panel.Visible = open
end

function UpgradePanel.toggle()
	panel.Visible = not panel.Visible
end

return UpgradePanel
