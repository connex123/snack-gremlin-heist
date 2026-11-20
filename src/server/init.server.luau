-- Server bootstrap for Snack Gremlin Heist: builds the market, then starts every system.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
Remotes.createAll()

local PlayerState = require(script.PlayerState)
local WorldBuilder = require(script.World.WorldBuilder)
local Stalls = require(script.Stalls)
local Economy = require(script.Economy)
local Carrying = require(script.Carrying)
local SnackBelt = require(script.SnackBelt)
local MarketEvents = require(script.MarketEvents)
local LagoonSurge = require(script.LagoonSurge)
local PocketPirates = require(script.PocketPirates)
local ShutterLock = require(script.ShutterLock)
local Upgrades = require(script.Progression.Upgrades)
local Rebirth = require(script.Progression.Rebirth)
local RivalStalls = require(script.World.RivalStalls)

-- Runs one system step; a failure is logged with the system's name and the others still start.
local function guarded(name: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[SnackGremlinHeist] " .. name .. " failed to start: " .. tostring(err))
	end
	return ok
end

if not guarded("WorldBuilder", function()
	Stalls.init(WorldBuilder.buildAll())
end) then
	warn("[SnackGremlinHeist] the market did not build; stalls are missing")
end
guarded("RivalStalls.fill", RivalStalls.fillEmptyStalls)

local function onCharacterAdded(player: Player, character: Model)
	task.spawn(Carrying.watchCharacter, player, character)
	task.wait(0.2)
	local plot = Stalls.plotOf(player)
	if plot and character.Parent then
		character:PivotTo(Stalls.frontSpot(plot))
	end
	Upgrades.applyWalkSpeed(player)
end

local function onPlayerAdded(player: Player)
	PlayerState.create(player)
	guarded("Stalls.claimStall", Stalls.claimStall, player)
	guarded("MarketEvents.syncPlayer", MarketEvents.syncPlayer, player)
	task.delay(3, function()
		if player.Parent then
			Remotes.get("Toast"):FireClient(player, "Walk to the Snack Belt and press E to buy a gremlin!", Color3.fromRGB(255, 220, 60))
		end
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	Carrying.drop(player, nil)
	Stalls.releaseStall(player)
	PlayerState.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

guarded("PlayerState.snapshots", PlayerState.startSnapshotPump)
guarded("Economy", Economy.start)
guarded("Carrying", Carrying.start)
guarded("SnackBelt", SnackBelt.start)
guarded("LagoonSurge", LagoonSurge.start)
guarded("PocketPirates", PocketPirates.start)
guarded("ShutterLock", ShutterLock.start)
guarded("Upgrades", Upgrades.start)
guarded("Rebirth", Rebirth.start)
guarded("MarketEvents", MarketEvents.start)
guarded("RivalStalls", RivalStalls.start)
-- Studio-only screenshot staging lives beside this folder.
local shotDirector = script.Parent:FindFirstChild("ShotDirectorServer")
if shotDirector then
	guarded("ShotDirectorServer", function()
		require(shotDirector).start()
	end)
end
print("[SnackGremlinHeist] server ready")
