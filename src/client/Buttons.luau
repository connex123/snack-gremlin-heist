-- Buttons: the bottom row of big rounded buttons with key hints: Lock (L), Whack (F), Upgrades (U),
-- Rebirth (R), Index (I). Each calls an action handed in by the bootstrap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Format = require(Shared.Format)
local Config = require(Shared.Config)
local UiKit = require(script.Parent.UiKit)

local Buttons = {}

local DEFS = {
	{ key = "L", action = "lock", title = "LOCK", color = Color3.fromRGB(0, 170, 220) },
	{ key = "F", action = "whack", title = "WHACK", color = Color3.fromRGB(235, 60, 60) },
	{ key = "U", action = "upgrades", title = "UPGRADES", color = Color3.fromRGB(60, 190, 80) },
	{ key = "R", action = "rebirth", title = "REBIRTH", color = Color3.fromRGB(160, 80, 240) },
	{ key = "I", action = "index", title = "INDEX", color = Color3.fromRGB(255, 160, 20) },
}

local subs: { [string]: TextLabel } = {}
local lastSnapshot = nil

function Buttons.create(gui: ScreenGui, actions: { [string]: () -> () })
	local width, gap = 0.15, 0.012
	local total = #DEFS * width + (#DEFS - 1) * gap
	for i, def in DEFS do
		local x = 0.5 - total / 2 + (i - 1) * (width + gap)
		local button = UiKit.button(gui, def.title .. "Button", "", UDim2.fromScale(x, 0.835), UDim2.fromScale(width, 0.14), def.color)
		UiKit.text(button, "Title", def.title, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.5), Color3.new(1, 1, 1))
		subs[def.action] = UiKit.text(button, "Sub", "", UDim2.fromScale(0.05, 0.6), UDim2.fromScale(0.9, 0.32), UiKit.YELLOW)
		local badge = UiKit.panel(button, "KeyBadge", UDim2.fromScale(-0.06, -0.18), UDim2.fromScale(0.28, 0.42), Color3.new(1, 1, 1), 0)
		badge.SizeConstraint = Enum.SizeConstraint.RelativeYY
		badge.Size = UDim2.fromScale(0.42, 0.42)
		UiKit.corner(badge, 0.5)
		UiKit.stroke(badge, UiKit.INK, 3)
		local keyText = UiKit.text(badge, "Key", def.key, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), UiKit.INK)
		keyText:FindFirstChildOfClass("UIStroke"):Destroy()
		button.Activated:Connect(function()
			local action = actions[def.action]
			if action then
				action()
			end
		end)
	end
end

function Buttons.update(snapshot)
	lastSnapshot = snapshot
	subs.upgrades.Text = "4 BOOSTS"
	subs.rebirth.Text = Format.money(Config.rebirthCost(snapshot.rebirths))
	subs.index.Text = #snapshot.discovered .. " FOUND"
	subs.whack.Text = "STOP THIEVES"
end

-- Per-frame: the lock button counts down.
function Buttons.step()
	if not lastSnapshot then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if lastSnapshot.lockUntil > now then
		subs.lock.Text = "LOCKED " .. Format.seconds(lastSnapshot.lockUntil - now)
	elseif lastSnapshot.lockCooldownUntil > now then
		subs.lock.Text = "WAIT " .. Format.seconds(lastSnapshot.lockCooldownUntil - now)
	else
		subs.lock.Text = "READY"
	end
end

return Buttons
