-- Hud: the big cash counter with its per-second rate, the event and surge banners (top centre, clear
-- of Roblox's top-left menu), the "carrying: run home!" banner and the stall status line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Rarities = require(Shared.Rarities)
local Mutations = require(Shared.Mutations)
local UiKit = require(script.Parent.UiKit)

local Hud = {}

local gui: ScreenGui
local cashLabel: TextLabel
local rateLabel: TextLabel
local infoLabel: TextLabel
local carryFrame: Frame
local carryLabel: TextLabel
local banners: { [string]: { frame: Frame, title: TextLabel, sub: TextLabel, endsAt: number } } = {}
local shownCash = 0
local targetCash = 0

function Hud.create(): ScreenGui
	gui = Instance.new("ScreenGui")
	gui.Name = "SnackHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local cash = UiKit.panel(gui, "CashPanel", UDim2.fromScale(0.012, 0.1), UDim2.fromScale(0.25, 0.2), UiKit.INK, 0.2)
	UiKit.stroke(cash, UiKit.YELLOW, 4)
	cashLabel = UiKit.text(cash, "Cash", "$0", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.5), UiKit.YELLOW)
	rateLabel = UiKit.text(cash, "Rate", "+$0/s", UDim2.fromScale(0.05, 0.52), UDim2.fromScale(0.9, 0.28), UiKit.GREEN)
	infoLabel = UiKit.text(cash, "Info", "", UDim2.fromScale(0.05, 0.8), UDim2.fromScale(0.9, 0.17), Color3.new(1, 1, 1))

	for slotName, y in { event = 0.012, surge = 0.135 } do
		local frame = UiKit.panel(gui, slotName .. "Banner", UDim2.fromScale(0.5, y), UDim2.fromScale(0.52, slotName == "event" and 0.115 or 0.1), UiKit.CORAL, 0.05)
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Visible = false
		UiKit.stroke(frame, Color3.new(1, 1, 1), 4)
		local title = UiKit.text(frame, "Title", "", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.6), Color3.new(1, 1, 1))
		local sub = UiKit.text(frame, "Sub", "", UDim2.fromScale(0.03, 0.6), UDim2.fromScale(0.94, 0.36), UiKit.YELLOW)
		banners[slotName] = { frame = frame, title = title, sub = sub, endsAt = 0 }
	end

	-- game title, top right (Roblox's own menu sits top left)
	local logo = UiKit.text(gui, "Logo", "SNACK GREMLIN HEIST", UDim2.fromScale(0.985, 0.02), UDim2.fromScale(0.2, 0.09), UiKit.YELLOW)
	logo.AnchorPoint = Vector2.new(1, 0)
	logo.Rotation = 3
	local logoStroke = logo:FindFirstChildOfClass("UIStroke")
	if logoStroke then
		logoStroke.Thickness = 5
	end

	carryFrame = UiKit.panel(gui, "CarryBanner", UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.5, 0.085), UiKit.YELLOW, 0.05)
	carryFrame.AnchorPoint = Vector2.new(0.5, 0)
	carryFrame.Visible = false
	UiKit.stroke(carryFrame, UiKit.INK, 4)
	carryLabel = UiKit.text(carryFrame, "Text", "", UDim2.fromScale(0.03, 0.08), UDim2.fromScale(0.94, 0.84), Color3.new(1, 1, 1))
	return gui
end

-- Applies a server snapshot: cash, rate, stall fill, rebirth multiplier, carried gremlin.
function Hud.update(snapshot)
	targetCash = snapshot.cash
	rateLabel.Text = Format.perSecond(snapshot.rate)
	infoLabel.Text = string.format("STALL %d/%d  ·  REBIRTH x%.1f", snapshot.pedestalsUsed, snapshot.pedestals, snapshot.multiplier)
	local carrying = snapshot.carrying
	carryFrame.Visible = carrying ~= nil
	if carrying then
		local rarity = Rarities.get(carrying.rarity)
		local mutation = Mutations.get(carrying.mutation)
		carryLabel.Text = "CARRYING " .. string.upper((mutation and mutation.name .. " " or "") .. carrying.name) .. " (" .. string.upper(rarity.name) .. "): RUN HOME!"
		carryFrame.BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.25)
	end
end

-- Shows or clears a top banner ("event" or "surge") with a live countdown.
function Hud.showBanner(payload)
	local banner = banners[payload.slot]
	if not banner then
		return
	end
	if payload.clear then
		banner.frame.Visible = false
		return
	end
	banner.frame.Visible = true
	banner.frame.BackgroundColor3 = payload.color or UiKit.CORAL
	banner.title.Text = payload.title or ""
	banner.sub.Text = payload.sub or ""
	banner.endsAt = payload.endsAt or 0
	banner.baseSub = payload.sub or ""
end

-- Per-frame: rolls the cash counter toward its target and ticks banner countdowns.
function Hud.step(dt: number)
	shownCash += (targetCash - shownCash) * math.min(1, dt * 8)
	if math.abs(targetCash - shownCash) < 1 then
		shownCash = targetCash
	end
	cashLabel.Text = Format.money(shownCash)
	local now = Workspace:GetServerTimeNow()
	for _, banner in banners do
		if banner.frame.Visible and banner.endsAt > 0 then
			banner.sub.Text = (banner.baseSub or "") .. "  ·  " .. Format.seconds(banner.endsAt - now)
		end
	end
end

return Hud
