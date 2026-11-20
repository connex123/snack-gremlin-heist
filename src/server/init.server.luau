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

Stalls.init(WorldBuilder.buildAll())
RivalStalls.fillEmptyStalls()

local function onCharacterAdded(player: Player, character: Model)
	Carrying.watchCharacter(player, character)
	task.wait(0.2)
	local plot = Stalls.plotOf(player)
	if plot and character.Parent then
		character:PivotTo(Stalls.frontSpot(plot))
	end
	Upgrades.applyWalkSpeed(player)
end

local function onPlayerAdded(player: Player)
	PlayerState.create(player)
	Stalls.claimStall(player)
	MarketEvents.syncPlayer(player)
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

PlayerState.startSnapshotPump()
Economy.start()
Carrying.start()
SnackBelt.start()
LagoonSurge.start()
PocketPirates.start()
ShutterLock.start()
Upgrades.start()
Rebirth.start()
MarketEvents.start()
RivalStalls.start()
-- Studio-only screenshot staging lives beside this folder.
local shotDirector = script.Parent:FindFirstChild("ShotDirectorServer")
if shotDirector then
	local ok, err = pcall(function()
		require(shotDirector).start()
	end)
	if not ok then
		warn("ShotDirectorServer: " .. tostring(err))
	end
end
