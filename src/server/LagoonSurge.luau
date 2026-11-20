-- LagoonSurge: every minute, after a 10-second warning banner, a giant wave rolls out of the lagoon
-- across the whole market. Anyone it catches on the ground away from home drops their gremlin and is
-- thrown back; stilt decks and your own stall are safe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Carrying = require(script.Parent.Carrying)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)
local WaveModel = require(script.Parent.World.WaveModel)

local LagoonSurge = {}

local START_Z = Config.LAGOON_EDGE_Z - 60
local END_Z = 140
local WAVE_HEIGHT = WaveModel.HEIGHT
local wave: Model? = nil
local surging = false
local abortSweep = false

-- The Studio shot director sets this (os.clock time) so no surge starts or runs while a shot is staged.
LagoonSurge.holdUntil = 0

-- Stops a sweep in progress (its wave is removed) so a staged shot is not washed over.
function LagoonSurge.abort()
	if surging then
		abortSweep = true
	end
end

function LagoonSurge.setWaveZ(z: number)
	if wave and wave.PrimaryPart then
		wave:PivotTo(CFrame.new(0, WAVE_HEIGHT / 2 - 2, z))
	end
end

-- Safe when high on a stilt deck or standing inside your own stall.
function LagoonSurge.isSafe(player: Player, root: BasePart): boolean
	if root.Position.Y > Config.SURGE_SAFE_HEIGHT + 2 then
		return true
	end
	local plot = Stalls.plotOf(player)
	return plot ~= nil and Stalls.isInsideHome(plot, root.Position)
end

-- The wave hits a player: they drop their gremlin and get shoved inland.
function LagoonSurge.hitPlayer(player: Player, root: BasePart)
	Carrying.drop(player, "The Lagoon Surge washed your gremlin away!")
	root.AssemblyLinearVelocity = Vector3.new(0, 45, 70)
	Remotes.get("Effect"):FireClient(player, "splash", root.Position)
end

function LagoonSurge.announceWarning(seconds: number)
	Remotes.get("Banner"):FireAllClients({
		slot = "surge",
		title = "LAGOON SURGE INCOMING!",
		sub = "get home or up a SAFE DECK",
		color = Color3.fromRGB(20, 120, 220),
		endsAt = Workspace:GetServerTimeNow() + seconds,
	})
end

-- Sweeps the wave from the lagoon to the far side of the market, checking hits as it goes.
function LagoonSurge.sweepWave()
	if surging then
		return
	end
	surging = true
	abortSweep = false
	if wave then
		wave:Destroy()
	end
	wave = WaveModel.build(START_Z)
	local z = START_Z
	local hit: { [Player]: boolean } = {}
	while z < END_Z and not abortSweep do
		local dt = task.wait(1 / 20)
		if abortSweep then
			break
		end
		z += Config.SURGE_SPEED * dt
		LagoonSurge.setWaveZ(z)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and not hit[player] and math.abs(root.Position.Z - z) < 10 and not LagoonSurge.isSafe(player, root) then
				hit[player] = true
				LagoonSurge.hitPlayer(player, root)
			end
		end
	end
	if abortSweep then
		abortSweep = false
		surging = false
		return -- the shot director owns the wave and the banner now
	end
	if wave then
		wave:Destroy()
		wave = nil
	end
	Remotes.get("Banner"):FireAllClients({ slot = "surge", clear = true })
	for _, player in Players:GetPlayers() do
		if not hit[player] then
			PlayerState.recordProgress(player, "surge", 1)
		end
	end
	surging = false
end

-- Removes a staged or stranded wave and its banner (shot director, before staging a new shot).
function LagoonSurge.clearWave()
	if wave then
		wave:Destroy()
		wave = nil
	end
	Remotes.get("Banner"):FireAllClients({ slot = "surge", clear = true })
end

-- Studio shot director: a frozen wave mid-approach with the warning banner up.
function LagoonSurge.stageFrozenWave(z: number, warningSeconds: number)
	LagoonSurge.abort()
	if wave then
		wave:Destroy()
	end
	wave = WaveModel.build(z)
	LagoonSurge.announceWarning(warningSeconds)
end

function LagoonSurge.start()
	task.spawn(function()
		while true do
			task.wait(Config.SURGE_INTERVAL - Config.SURGE_WARNING)
			if os.clock() < LagoonSurge.holdUntil then
				continue
			end
			pcall(LagoonSurge.announceWarning, Config.SURGE_WARNING)
			task.wait(Config.SURGE_WARNING)
			if os.clock() < LagoonSurge.holdUntil then
				continue
			end
			local ok, err = pcall(LagoonSurge.sweepWave)
			if not ok then
				surging = false
				warn("Surge failed: " .. tostring(err))
			end
		end
	end)
end

return LagoonSurge
