-- ShotDirectorServer (Studio only, outside the Server folder; the game runs without it): stages each screenshot through the real systems (cash, stall,
-- belt, events, surge, pirates, lock) and sends the client a camera for it. Keys 1-4 on the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Server = script.Parent:WaitForChild("Server", 30)
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
local RivalStalls = require(Server.World.RivalStalls)
local ShotFraming = require(Shared.ShotFraming)

local ShotDirectorServer = {}

local HOLD_SECONDS = 45 -- surge, pirates, events and rival restocks pause this long after a shot key

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
	return CFrame.lookAt(plot.cframe:PointToWorldSpace(eye), plot.cframe:PointToWorldSpace(target))
end

-- Clears what a previous shot or a live timer left around, and holds the timers while this one is up.
local function prepare()
	local hold = os.clock() + HOLD_SECONDS
	LagoonSurge.holdUntil = hold
	MarketEvents.holdUntil = hold
	PocketPirates.holdUntil = hold
	RivalStalls.holdUntil = hold
	LagoonSurge.abort()
	LagoonSurge.clearWave()
	PocketPirates.clearAll()
end

-- What the client waits for before framing: the stall's gremlin models and the player at `stand`.
local function expectation(plot, stand: Vector3)
	local count = 0
	for _ in Stalls.slotsOf(plot) do
		count += 1
	end
	return { plotIndex = plot.index, models = count, stand = stand }
end

function ShotDirectorServer.stageCover(player: Player, plot)
	prepare()
	ShotDirectorServer.stageRichStall(player, plot)
	MarketEvents.startEvent("JollofRain", 120)
	Economy.payIncome()
	local eye = plot.cframe:PointToWorldSpace(ShotFraming.COVER_EYE)
	local standAt = plot.cframe:PointToWorldSpace(ShotFraming.COVER_STAND)
	placeCharacter(player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	return {
		camera = cameraAt(plot, ShotFraming.COVER_EYE, ShotFraming.COVER_TARGET),
		fov = ShotFraming.COVER_FOV,
		expect = expectation(plot, standAt),
	}
end

function ShotDirectorServer.stageBuy(player: Player, plot)
	local state = PlayerState.get(player)
	if not state then
		return nil
	end
	prepare()
	Carrying.drop(player, nil)
	MarketEvents.stopEvent() -- the buy moment reads cleaner without a banner over the carried gremlin
	SnackBelt.setPaused(true)
	SnackBelt.clear()
	local x = plot.cframe.Position.X
	for _, entry in ShotFraming.BUY_LINEUP do
		SnackBelt.spawnOnBelt(entry[1], entry[2], x + entry[3])
	end
	local stand = ShotFraming.BUY_PLAYER + Vector3.new(x, 0, 0)
	placeCharacter(player, CFrame.lookAt(stand, Vector3.new(stand.X, stand.Y, Config.BELT_Z)))
	task.wait(0.4)
	local legendary = SnackBelt.spawnOnBelt("DanfoDragon", nil, stand.X)
	state.cash = math.max(state.cash, 2_500_000)
	if legendary then
		SnackBelt.tryBuyModel(player, legendary)
	end
	task.delay(HOLD_SECONDS, function()
		SnackBelt.setPaused(false)
	end)
	return {
		camera = CFrame.lookAt(ShotFraming.BUY_EYE + Vector3.new(x, 0, 0), ShotFraming.BUY_TARGET + Vector3.new(x, 0, 0)),
		fov = ShotFraming.BUY_FOV,
		expect = { stand = stand },
	}
end

function ShotDirectorServer.stageThreat(player: Player, plot)
	prepare()
	ShotDirectorServer.stageRichStall(player, plot)
	local state = PlayerState.get(player)
	if state then
		state.lockCooldownUntil = 0
	end
	ShutterLock.lock(player)
	local x = plot.cframe.Position.X
	-- the rival stall straight across the belt: a pirate already stealing its centre-front gremlin
	local target = nil
	for _, other in Stalls.plots do
		if other.rivalName and other.cframe.Position.Z < 0 and math.abs(other.cframe.Position.X - x) < 1 then
			target = other
		end
	end
	if target then
		Stalls.removeGremlin(target, 3)
		Stalls.placeGremlin(target, "OgbonoOverlord", "Gold", 3)
		PocketPirates.stageFrozenRaid(target, 3)
	end
	PocketPirates.stageLockedOut(plot, ShotFraming.THREAT_PIRATE + Vector3.new(x, 0, 0))
	LagoonSurge.stageFrozenWave(ShotFraming.THREAT_WAVE_Z, 9)
	local stand = ShotFraming.THREAT_PLAYER + Vector3.new(x, 0, 0)
	local pirate = ShotFraming.THREAT_PIRATE + Vector3.new(x, stand.Y, 0)
	placeCharacter(player, CFrame.lookAt(stand, pirate))
	return {
		camera = CFrame.lookAt(ShotFraming.THREAT_EYE + Vector3.new(x, 0, 0), ShotFraming.THREAT_TARGET + Vector3.new(x, 0, 0)),
		fov = ShotFraming.THREAT_FOV,
		expect = expectation(plot, stand),
	}
end

function ShotDirectorServer.stageProgress(player: Player, plot)
	prepare()
	ShotDirectorServer.stageRichStall(player, plot)
	MarketEvents.startEvent("PepperHour", 120)
	local eye = plot.cframe:PointToWorldSpace(ShotFraming.PROGRESS_EYE)
	local standAt = plot.cframe:PointToWorldSpace(ShotFraming.PROGRESS_STAND)
	placeCharacter(player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	return {
		camera = cameraAt(plot, ShotFraming.PROGRESS_EYE, ShotFraming.PROGRESS_TARGET),
		fov = ShotFraming.PROGRESS_FOV,
		panels = { "Upgrades", "Index" },
		expect = expectation(plot, standAt),
	}
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
		if not stage then
			return
		end
		local plot = Stalls.plotOf(player)
		if not plot then
			-- Play Solo can beat the stall claim on a slow first load: claim now rather than ignore the key.
			plot = Stalls.claimStall(player)
		end
		if not plot then
			warn("[ShotDirector] shot " .. shot .. ": you have no stall yet")
			return
		end
		local ok, result = pcall(stage, player, plot)
		if ok and result then
			result.shot = shot
			ready:FireClient(player, result)
			print("[ShotDirector] staged " .. shot)
		elseif not ok then
			warn("[ShotDirector] shot " .. shot .. " failed: " .. tostring(result))
			ready:FireClient(player, { shot = shot, failed = tostring(result) })
		end
	end)
end

return ShotDirectorServer
