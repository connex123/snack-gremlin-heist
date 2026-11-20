-- Hud: the big cash counter with its per-second rate, the event and surge banners (top centre, clear
-- of Roblox's top-left menu), the "carrying: run home!" banner and the stall status line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
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
local carryName: TextLabel
local banners: { [string]: { frame: Frame, title: TextLabel, sub: TextLabel, endsAt: number } } = {}
local shownCash = 0
local targetCash = 0

function Hud.create(): ScreenGui
	gui = Instance.new("ScreenGui")
	gui.Name = "SnackHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 30)

	-- left column, below Roblox's own top-left buttons and clear of the centred banners (x 0.24-0.76)
	local cash = UiKit.panel(gui, "CashPanel", UDim2.fromScale(0.012, 0.13), UDim2.fromScale(0.22, 0.18), UiKit.INK, 0.15)
	UiKit.stroke(cash, UiKit.YELLOW, 4)
	cashLabel = UiKit.text(cash, "Cash", "$0", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.5), UiKit.YELLOW)
	rateLabel = UiKit.text(cash, "Rate", "+$0/s", UDim2.fromScale(0.05, 0.52), UDim2.fromScale(0.9, 0.28), UiKit.GREEN)
	infoLabel = UiKit.text(cash, "Info", "", UDim2.fromScale(0.05, 0.8), UDim2.fromScale(0.9, 0.17), Color3.new(1, 1, 1))

	for slotName, y in { event = 0.048, boss = 0.048, surge = 0.165 } do -- under the feature strip
		local frame = UiKit.panel(gui, slotName .. "Banner", UDim2.fromScale(0.5, y), UDim2.fromScale(0.46, slotName == "event" and 0.105 or 0.1), UiKit.CORAL, 0.05)
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Visible = false
		UiKit.stroke(frame, Color3.new(1, 1, 1), 4)
		local title = UiKit.text(frame, "Title", "", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.6), Color3.new(1, 1, 1))
		local sub = UiKit.text(frame, "Sub", "", UDim2.fromScale(0.03, 0.6), UDim2.fromScale(0.94, 0.36), UiKit.YELLOW)
		banners[slotName] = { frame = frame, title = title, sub = sub, endsAt = 0 }
	end

	-- game title, top right (Roblox's own menu sits top left)
	local logo = UiKit.text(gui, "Logo", "SNACK GREMLIN HEIST", UDim2.fromScale(0.985, 0.05), UDim2.fromScale(0.185, 0.07), UiKit.YELLOW)
	logo.AnchorPoint = Vector2.new(1, 0)
	logo.Rotation = 3
	local logoStroke = logo:FindFirstChildOfClass("UIStroke")
	if logoStroke then
		logoStroke.Thickness = 5
	end

	-- the carry card sits under the cash panel so it never covers the player in the middle of the view
	carryFrame = UiKit.panel(gui, "CarryCard", UDim2.fromScale(0.012, 0.325), UDim2.fromScale(0.22, 0.13), UiKit.YELLOW, 0.05)
	carryFrame.Visible = false
	UiKit.stroke(carryFrame, UiKit.INK, 4)
	carryLabel = UiKit.text(carryFrame, "Text", "CARRYING: RUN HOME!", UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.4), Color3.new(1, 1, 1))
	carryName = UiKit.text(carryFrame, "Name", "", UDim2.fromScale(0.05, 0.5), UDim2.fromScale(0.9, 0.44), Color3.new(1, 1, 1))
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
		carryLabel.Text = "CARRYING: RUN HOME!"
		carryName.Text = string.upper((mutation and mutation.name .. " " or "") .. carrying.name)
		carryName.TextColor3 = mutation and mutation.color or rarity.color
		carryFrame.BackgroundColor3 = UiKit.INK
		local stroke = carryFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = rarity.color
		end
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
	-- the boss raid banner takes the top slot while it is up
	local boss = banners.boss
	if payload.slot == "event" and boss and boss.frame.Visible then
		banner.frame.Visible = false
	elseif payload.slot == "boss" and banners.event then
		banners.event.frame.Visible = false
	end
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
