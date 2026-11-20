-- ShutterLock: press L to drop a glowing shutter over your stall front for 45 s (+10 s per Longer Lock
-- level). Pocket Pirates bounce off a locked stall. Then a cooldown before the next lock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)

local ShutterLock = {}

function ShutterLock.isLocked(plot): boolean
	if not plot.owner then
		return false
	end
	local state = PlayerState.get(plot.owner)
	return state ~= nil and state.lockUntil > Workspace:GetServerTimeNow()
end

function ShutterLock.showShutter(plot, on: boolean, secondsLeft: number?)
	plot.shutter.Transparency = on and 0.35 or 1
	plot.shutter.CanCollide = false -- visual only: the owner can still walk in and out
	plot.shutterLabel.Visible = on
	if on then
		plot.shutterLabel.Text = "LOCKED " .. math.ceil(secondsLeft or 0) .. "s"
	end
end

-- Locks the player's stall if the cooldown allows.
function ShutterLock.lock(player: Player): boolean
	local state = PlayerState.get(player)
	local plot = Stalls.plotOf(player)
	if not state or not plot then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	if now < state.lockCooldownUntil then
		Remotes.get("Toast"):FireClient(player, "Shutter recharging: " .. math.ceil(state.lockCooldownUntil - now) .. "s", Color3.fromRGB(255, 160, 60))
		return false
	end
	local seconds = Config.lockSeconds(state.upgrades.lockTime or 0)
	state.lockUntil = now + seconds
	state.lockCooldownUntil = now + seconds + Config.LOCK_COOLDOWN
	PlayerState.markDirty(player)
	ShutterLock.showShutter(plot, true, seconds)
	Remotes.get("Toast"):FireClient(player, "Shutter LOCKED for " .. seconds .. "s!", Color3.fromRGB(80, 220, 255))
	return true
end

function ShutterLock.start()
	Remotes.get("RequestLock").OnServerEvent:Connect(function(player)
		ShutterLock.lock(player)
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = Workspace:GetServerTimeNow()
			for _, plot in Stalls.plots do
				local ok, err = pcall(function()
					local locked = ShutterLock.isLocked(plot)
					local state = plot.owner and PlayerState.get(plot.owner)
					ShutterLock.showShutter(plot, locked, state and state.lockUntil - now or 0)
				end)
				if not ok then
					warn("Shutter refresh failed: " .. tostring(err))
				end
			end
		end
	end)
end

return ShutterLock
