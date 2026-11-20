-- ShotDirectorServer (Studio only, outside the Server folder; the game runs without it): stages each screenshot through the real systems (cash, stall,
-- belt, events, surge, pirates, lock) and sends the client a camera for it. Keys 1-4 on the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent:WaitForChild("Server")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)
local PlayerState = require(Server.PlayerState)
local Stalls = require(Server.Stalls)
local Economy = require(Server.Economy)
local Carrying = require(Server.Carrying)
local SnackBelt = require(Server.SnackBelt)
local MarketEvents = require(Server.MarketEvents)
local LagoonSurge = require(Server.LagoonSurge)
local PocketPirates = require(Server.PocketPirates)
local ShutterLock = require(Server.ShutterLock)
local Upgrades = require(Server.Progression.Upgrades)

local ShotDirectorServer = {}

-- Eight gremlins of mixed rarities, two mutated, for the cover stall (pedestals 1-5 front, 6-10 back).
local COVER_BASE = {
	{ "PuffPuffPaladin", nil }, { "JollofJetpack", "Gold" }, { "DanfoDragon", nil }, { "SuyaSamurai", nil }, { "ZoboZeppelin", nil },
	{ "AmalaArchmage", nil }, { "GeneratorSeraph", "Rainbow" }, { "PlantainPharaoh", "Neon" },
}

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function placeCharacter(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
		local root = characterRoot(player)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

-- Rich player: lots of cash, upgrades, a full stall of COVER_BASE.
function ShotDirectorServer.stageRichStall(player: Player, plot)
	local state = PlayerState.get(player)
	if not state then
		return
	end
	Carrying.drop(player, nil)
	state.rebirths = 2
	state.upgrades = { pedestals = Config.MAX_PEDESTALS - Config.START_PEDESTALS, luck = 4, speed = 3, lockTime = 2 }
	Stalls.paintFloor(plot, state.rebirths)
	Stalls.clearPlot(plot)
	for index, entry in COVER_BASE do
		Stalls.placeGremlin(plot, entry[1], entry[2], index)
		PlayerState.discover(player, entry[1])
	end
	for i, gremlin in GremlinCatalog.list do
		if i % 2 == 0 then
			PlayerState.discover(player, gremlin.id)
		end
	end
	state.cash = 48_650_000
	Upgrades.applyWalkSpeed(player)
	Economy.payIncome()
end

local function cameraAt(plot, eye: Vector3, target: Vector3): CFrame
	local e = plot.cframe:PointToWorldSpace(eye)
	local t = plot.cframe:PointToWorldSpace(target)
	return CFrame.lookAt(e, t)
end

function ShotDirectorServer.stageCover(player: Player, plot)
	ShotDirectorServer.stageRichStall(player, plot)
	MarketEvents.startEvent("JollofRain", 120)
	Economy.payIncome()
	local fh = Config.STALL_FLOOR_HEIGHT
	local eye = plot.cframe:PointToWorldSpace(Vector3.new(6, 12.5, -27))
	local standAt = plot.cframe:PointToWorldSpace(Vector3.new(-15, fh + 3, -9))
	placeCharacter(player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	return { camera = cameraAt(plot, Vector3.new(6, 12.5, -27), Vector3.new(-1, 6, 2)), fov = 70 }
end

function ShotDirectorServer.stageBuy(player: Player, plot)
	local state = PlayerState.get(player)
	if not state then
		return nil
	end
	Carrying.drop(player, nil)
	SnackBelt.setPaused(true)
	SnackBelt.clear()
	local lineup = { { "KilishiKnight", nil, -8 }, { "AkaraAstronaut", nil, -1 }, { "TuwoTitan", nil, 6 }, { "OkraOctopus", "Pepper", 13 }, { "MoiMoiMonk", nil, 20 }, { "ChinChinCheetah", "Lagoon", 27 } }
	for _, entry in lineup do
		SnackBelt.spawnOnBelt(entry[1], entry[2], entry[3])
	end
	local x = plot.cframe.Position.X + 3
	placeCharacter(player, CFrame.lookAt(Vector3.new(x, 3, 7.5), Vector3.new(x, 3, 0)))
	task.wait(0.4)
	local legendary = SnackBelt.spawnOnBelt("DanfoDragon", nil, x)
	state.cash = math.max(state.cash, 2_500_000)
	if legendary then
		SnackBelt.tryBuyModel(player, legendary)
	end
	task.delay(25, function()
		SnackBelt.setPaused(false)
	end)
	return { camera = CFrame.lookAt(Vector3.new(x + 5, 10, 25), Vector3.new(x + 7, 5, 0)), fov = 70 }
end

function ShotDirectorServer.stageThreat(player: Player, plot)
	ShotDirectorServer.stageRichStall(player, plot)
	local state = PlayerState.get(player)
	if state then
		state.lockCooldownUntil = 0
	end
	ShutterLock.lock(player)
	local target = nil
	for _, other in Stalls.plots do
		if other.rivalName and other.cframe.Position.Z < 0 and math.abs(other.cframe.Position.X - plot.cframe.Position.X) < 1 then
			target = other
		end
	end
	target = target or Stalls.plots[4]
	if target then
		if next(Stalls.slotsOf(target)) == nil then
			Stalls.placeGremlin(target, "OgbonoOverlord", "Gold", 3)
		end
		PocketPirates.stageFrozenRaid(target)
	end
	LagoonSurge.stageFrozenWave(Config.LAGOON_EDGE_Z - 25, 7)
	local base = plot.cframe.Position
	placeCharacter(player, CFrame.lookAt(Vector3.new(base.X - 20, 3, 14), Vector3.new(base.X - 20, 3, -40)))
	return { camera = CFrame.lookAt(Vector3.new(base.X - 50, 22, 20), Vector3.new(base.X + 10, 4, 0)), fov = 70 }
end

function ShotDirectorServer.stageProgress(player: Player, plot)
	ShotDirectorServer.stageRichStall(player, plot)
	MarketEvents.startEvent("PepperHour", 120)
	local fh = Config.STALL_FLOOR_HEIGHT
	local eye = plot.cframe:PointToWorldSpace(Vector3.new(0, 14, -30))
	local standAt = plot.cframe:PointToWorldSpace(Vector3.new(0, fh + 3, -10))
	placeCharacter(player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	return { camera = cameraAt(plot, Vector3.new(0, 14, -30), Vector3.new(0, 6, 2)), fov = 70, panels = { "Upgrades", "Index" } }
end

local STAGES = {
	cover = ShotDirectorServer.stageCover,
	buy = ShotDirectorServer.stageBuy,
	threat = ShotDirectorServer.stageThreat,
	progress = ShotDirectorServer.stageProgress,
}

function ShotDirectorServer.start()
	if not RunService:IsStudio() then
		return
	end
	local ready = Remotes.get("ShotReady")
	Remotes.get("ShotRequest").OnServerEvent:Connect(function(player, shot)
		local stage = typeof(shot) == "string" and STAGES[shot]
		local plot = Stalls.plotOf(player)
		if not stage or not plot then
			return
		end
		local ok, result = pcall(stage, player, plot)
		if ok and result then
			result.shot = shot
			ready:FireClient(player, result)
		elseif not ok then
			warn("Shot " .. shot .. " failed: " .. tostring(result))
		end
	end)
end

return ShotDirectorServer
