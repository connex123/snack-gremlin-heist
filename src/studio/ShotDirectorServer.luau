-- ShotDirectorServer (Studio only, outside the Server folder; the game runs without it): stages each screenshot through the real systems (cash, stall,
-- belt, events, surge, pirates, lock, boss, orders) and sends the client a camera for it. Keys 1-4 on the client.
-- Every staging step runs on its own (try): a failed optional step is warned and skipped, and the camera
-- payload is always sent, so a shot key never does nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Server = script.Parent:WaitForChild("Server", 30)
assert(Shared and Server, "ShotDirectorServer: Shared or Server folder missing")

-- Stand-in for a module that is missing or failed to load: any function on it raises, and try() below
-- turns that into a skipped step, so the camera still gets staged.
local function unavailable(path: string): any
	return setmetatable({}, {
		__index = function(_, key)
			return function()
				error(path .. "." .. tostring(key) .. " unavailable", 0)
			end
		end,
	})
end

-- Requires a module under `parent` by path ("Progression.Upgrades"), or a stand-in with a warning.
local function optional(parent: Instance, path: string): any
	local node: Instance? = parent
	for part in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	if not node or not node:IsA("ModuleScript") then
		warn("[ShotDirector] module missing: " .. path)
		return unavailable(path)
	end
	local ok, result = pcall(require, node)
	if not ok or typeof(result) ~= "table" then
		warn("[ShotDirector] module " .. path .. " failed to load: " .. tostring(result))
		return unavailable(path)
	end
	return result
end

local Config = require(Shared:WaitForChild("Config", 10))
local Remotes = require(Shared:WaitForChild("Remotes", 10))
local ShotFraming = require(Shared:WaitForChild("ShotFraming", 10))
local GremlinCatalog = optional(Shared, "GremlinCatalog")
local PlayerState = optional(Server, "PlayerState")
local Stalls = optional(Server, "Stalls")
local Economy = optional(Server, "Economy")
local Carrying = optional(Server, "Carrying")
local SnackBelt = optional(Server, "SnackBelt")
local MarketEvents = optional(Server, "MarketEvents")
local LagoonSurge = optional(Server, "LagoonSurge")
local PocketPirates = optional(Server, "PocketPirates")
local ShutterLock = optional(Server, "ShutterLock")
local Upgrades = optional(Server, "Progression.Upgrades")
local RivalStalls = optional(Server, "World.RivalStalls")
local MarketOrders = optional(Server, "MarketOrders")
local OgaPepperpot = optional(Server, "OgaPepperpot")

local ShotDirectorServer = {}

local HOLD_SECONDS = 45 -- surge, pirates, events, boss and rival restocks pause this long after a shot key

-- Runs one staging step; on failure warns with the shot and step name and carries on.
local currentShot = "?"
local function try(step: string, fn: (...any) -> ...any, ...: any): (boolean, any)
	local ok, result = pcall(fn, ...)
	if not ok then
		warn("[ShotDirector] " .. currentShot .. ": step '" .. step .. "' skipped: " .. tostring(result))
	end
	return ok, result
end

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

-- Rich player: lots of cash, upgrades, a full stall of ShotFraming.COVER_LINEUP.
function ShotDirectorServer.stageRichStall(player: Player, plot)
	local ok, state = pcall(PlayerState.get, player)
	if not ok or not state then
		warn("[ShotDirector] no player state; staging the camera only")
		return
	end
	try("drop carried", Carrying.drop, player, nil)
	state.rebirths = 2
	state.upgrades = { pedestals = Config.MAX_PEDESTALS - Config.START_PEDESTALS, luck = 4, speed = 3, lockTime = 2 }
	state.cash = 48_650_000
	try("paint floor", Stalls.paintFloor, plot, state.rebirths)
	try("clear stall", Stalls.clearPlot, plot)
	for index, entry in ShotFraming.COVER_LINEUP do
		try("place " .. entry[1], Stalls.placeGremlin, plot, entry[1], entry[2], index)
		pcall(PlayerState.discover, player, entry[1])
	end
	pcall(function()
		for i, gremlin in GremlinCatalog.list do
			if i % 2 == 0 then
				PlayerState.discover(player, gremlin.id)
			end
		end
	end)
	try("walk speed", Upgrades.applyWalkSpeed, player)
	try("pay income", Economy.payIncome)
	pcall(PlayerState.markDirty, player)
end

local function cameraAt(plot, eye: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(plot.cframe:PointToWorldSpace(eye), plot.cframe:PointToWorldSpace(target))
end

-- Clears what a previous shot or a live timer left around, and holds the timers while this one is up.
local function prepare()
	local hold = os.clock() + HOLD_SECONDS
	for _, system in { LagoonSurge, MarketEvents, PocketPirates, RivalStalls, OgaPepperpot } do
		pcall(function()
			system.holdUntil = hold
		end)
	end
	try("abort surge", LagoonSurge.abort)
	try("clear wave", LagoonSurge.clearWave)
	try("clear pirates", PocketPirates.clearAll)
	try("clear boss", OgaPepperpot.clear)
end

-- What the client waits for before framing: the stall's gremlin models and the player at `stand`.
local function expectation(plot, stand: Vector3)
	local count = 0
	pcall(function()
		for _ in Stalls.slotsOf(plot) do
			count += 1
		end
	end)
	return { plotIndex = plot.index, models = count, stand = stand }
end

local function showOrders(player: Player)
	try("orders showcase", MarketOrders.stageShowcase, player)
end

function ShotDirectorServer.stageCover(player: Player, plot)
	local eye = plot.cframe:PointToWorldSpace(ShotFraming.COVER_EYE)
	local standAt = plot.cframe:PointToWorldSpace(ShotFraming.COVER_STAND)
	local payload = {
		camera = cameraAt(plot, ShotFraming.COVER_EYE, ShotFraming.COVER_TARGET),
		fov = ShotFraming.COVER_FOV,
		expect = { stand = standAt },
	}
	prepare()
	try("rich stall", ShotDirectorServer.stageRichStall, player, plot)
	try("Jollof Rain", MarketEvents.startEvent, "JollofRain", 120)
	try("income", Economy.payIncome)
	showOrders(player)
	try("place character", placeCharacter, player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	payload.expect = expectation(plot, standAt)
	return payload
end

function ShotDirectorServer.stageBuy(player: Player, plot)
	local x = plot.cframe.Position.X
	local stand = ShotFraming.BUY_PLAYER + Vector3.new(x, 0, 0)
	local payload = {
		camera = CFrame.lookAt(ShotFraming.BUY_EYE + Vector3.new(x, 0, 0), ShotFraming.BUY_TARGET + Vector3.new(x, 0, 0)),
		fov = ShotFraming.BUY_FOV,
		expect = { stand = stand },
	}
	prepare()
	try("drop carried", Carrying.drop, player, nil)
	try("stop event", MarketEvents.stopEvent) -- the buy moment reads cleaner without a banner over the carried gremlin
	try("pause belt", SnackBelt.setPaused, true)
	try("clear belt", SnackBelt.clear)
	for _, entry in ShotFraming.BUY_LINEUP do
		try("belt " .. entry[1], SnackBelt.spawnOnBelt, entry[1], entry[2], x + entry[3])
	end
	try("place character", placeCharacter, player, CFrame.lookAt(stand, Vector3.new(stand.X, stand.Y, Config.BELT_Z)))
	task.wait(0.4)
	try("buy the Legendary", function()
		local state = PlayerState.get(player)
		if state then
			state.cash = math.max(state.cash, 2_500_000)
		end
		local legendary = SnackBelt.spawnOnBelt(ShotFraming.BUY_CARRIED, nil, stand.X)
		if legendary then
			SnackBelt.tryBuyModel(player, legendary)
		end
	end)
	showOrders(player)
	task.delay(HOLD_SECONDS, function()
		pcall(SnackBelt.setPaused, false)
	end)
	return payload
end

function ShotDirectorServer.stageThreat(player: Player, plot)
	local x = plot.cframe.Position.X
	local stand = ShotFraming.THREAT_PLAYER + Vector3.new(x, 0, 0)
	local payload = {
		camera = CFrame.lookAt(ShotFraming.THREAT_EYE + Vector3.new(x, 0, 0), ShotFraming.THREAT_TARGET + Vector3.new(x, 0, 0)),
		fov = ShotFraming.THREAT_FOV,
		hide = { "CashPanel" }, -- the boss's chef hat stands where the cash panel sits
		expect = { stand = stand },
	}
	prepare()
	try("stop event", MarketEvents.stopEvent) -- the top banner belongs to the boss raid in this shot
	try("rich stall", ShotDirectorServer.stageRichStall, player, plot)
	try("lock shutter", function()
		local state = PlayerState.get(player)
		if state then
			state.lockCooldownUntil = 0
		end
		ShutterLock.lock(player)
	end)
	-- the rival stall straight across the belt: a pirate already stealing its centre-front gremlin
	try("rival raid", function()
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
	end)
	try("locked-out pirate", PocketPirates.stageLockedOut, plot, ShotFraming.THREAT_PIRATE + Vector3.new(x, 0, 0))
	try("surge wave", LagoonSurge.stageFrozenWave, ShotFraming.THREAT_WAVE_Z, 9)
	try("Oga Pepperpot", OgaPepperpot.stageFrozen, ShotFraming.THREAT_BOSS + Vector3.new(x, 0, 0), ShotFraming.THREAT_EYE + Vector3.new(x, 0, 0))
	local pirate = ShotFraming.THREAT_PIRATE + Vector3.new(x, stand.Y, 0)
	try("place character", placeCharacter, player, CFrame.lookAt(stand, pirate))
	payload.expect = expectation(plot, stand)
	return payload
end

function ShotDirectorServer.stageProgress(player: Player, plot)
	local eye = plot.cframe:PointToWorldSpace(ShotFraming.PROGRESS_EYE)
	local standAt = plot.cframe:PointToWorldSpace(ShotFraming.PROGRESS_STAND)
	local payload = {
		camera = cameraAt(plot, ShotFraming.PROGRESS_EYE, ShotFraming.PROGRESS_TARGET),
		fov = ShotFraming.PROGRESS_FOV,
		panels = { "Upgrades", "Index" },
		expect = { stand = standAt },
	}
	prepare()
	try("rich stall", ShotDirectorServer.stageRichStall, player, plot)
	try("Pepper Hour", MarketEvents.startEvent, "PepperHour", 120)
	showOrders(player)
	try("place character", placeCharacter, player, CFrame.lookAt(standAt, Vector3.new(eye.X, standAt.Y, eye.Z)))
	payload.expect = expectation(plot, standAt)
	return payload
end

local STAGES = {
	cover = ShotDirectorServer.stageCover,
	buy = ShotDirectorServer.stageBuy,
	threat = ShotDirectorServer.stageThreat,
	progress = ShotDirectorServer.stageProgress,
}

-- The player's stall, claiming one now if Play Solo beat the claim on a slow first load.
local function stallFor(player: Player)
	local plot = nil
	pcall(function()
		plot = Stalls.plotOf(player) or Stalls.claimStall(player)
	end)
	return plot
end

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
		currentShot = shot
		local plot = stallFor(player)
		if not plot then
			warn("[ShotDirector] shot " .. shot .. ": you have no stall yet")
			ready:FireClient(player, { shot = shot, failed = "no stall yet: wait 5 s and press the key again" })
			return
		end
		local ok, result = pcall(stage, player, plot)
		if ok and typeof(result) == "table" then
			result.shot = shot
			ready:FireClient(player, result)
			print("[ShotDirector] staged " .. shot)
		else
			warn("[ShotDirector] shot " .. shot .. " failed: " .. tostring(result))
			ready:FireClient(player, { shot = shot, failed = tostring(result) })
		end
	end)
	print("[ShotDirector] server ready")
end

return ShotDirectorServer
