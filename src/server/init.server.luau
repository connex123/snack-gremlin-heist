-- Server bootstrap for Snack Gremlin Heist: builds the market, then starts every system.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared", 30):WaitForChild("Remotes", 10))
Remotes.createAll()

-- Requires a server module by path, or returns nil with a warning so the other systems still start.
local function safeRequire(path: string): any
	local node: Instance? = script
	for part in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	if not node then
		warn("[SnackGremlinHeist] module missing: " .. path)
		return nil
	end
	local ok, result = pcall(require, node)
	if not ok then
		warn("[SnackGremlinHeist] module " .. path .. " failed to load: " .. tostring(result))
		return nil
	end
	return result
end

local PlayerState = safeRequire("PlayerState")
local WorldBuilder = safeRequire("World.WorldBuilder")
local Stalls = safeRequire("Stalls")
local Economy = safeRequire("Economy")
local Carrying = safeRequire("Carrying")
local SnackBelt = safeRequire("SnackBelt")
local MarketEvents = safeRequire("MarketEvents")
local LagoonSurge = safeRequire("LagoonSurge")
local PocketPirates = safeRequire("PocketPirates")
local ShutterLock = safeRequire("ShutterLock")
local Upgrades = safeRequire("Progression.Upgrades")
local Rebirth = safeRequire("Progression.Rebirth")
local RivalStalls = safeRequire("World.RivalStalls")
local MarketOrders = safeRequire("MarketOrders")
local OgaPepperpot = safeRequire("OgaPepperpot")

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
	if Carrying then
		task.spawn(guarded, "Carrying.watchCharacter", Carrying.watchCharacter, player, character)
	end
	task.wait(0.2)
	guarded("spawn at stall", function()
		local plot = Stalls.plotOf(player)
		if plot and character.Parent then
			character:PivotTo(Stalls.frontSpot(plot))
		end
	end)
	guarded("walk speed", Upgrades.applyWalkSpeed, player)
end

local function onPlayerAdded(player: Player)
	guarded("PlayerState.create", PlayerState.create, player)
	guarded("Stalls.claimStall", Stalls.claimStall, player)
	guarded("MarketEvents.syncPlayer", MarketEvents.syncPlayer, player)
	task.delay(3, function()
		if player.Parent then
			guarded("welcome toast", function()
				Remotes.get("Toast"):FireClient(player, "Walk to the Snack Belt and press E to buy a gremlin!", Color3.fromRGB(255, 220, 60))
			end)
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
	guarded("drop on leave", Carrying.drop, player, nil)
	guarded("release stall", Stalls.releaseStall, player)
	guarded("PlayerState.remove", PlayerState.remove, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Starts module.start() (or another function) if the module loaded; failures are named and skipped.
local started: { [string]: boolean } = {}
local function startSystem(name: string, module: any, fnName: string?)
	local fn = module and module[fnName or "start"]
	if typeof(fn) ~= "function" then
		warn("[SnackGremlinHeist] " .. name .. " not started (module unavailable)")
		return
	end
	started[name] = guarded(name, fn)
end

startSystem("PlayerState.snapshots", PlayerState, "startSnapshotPump")
startSystem("Economy", Economy)
startSystem("Carrying", Carrying)
startSystem("SnackBelt", SnackBelt)
startSystem("LagoonSurge", LagoonSurge)
startSystem("PocketPirates", PocketPirates)
startSystem("ShutterLock", ShutterLock)
startSystem("Upgrades", Upgrades)
startSystem("Rebirth", Rebirth)
startSystem("MarketEvents", MarketEvents)
startSystem("RivalStalls", RivalStalls)
startSystem("MarketOrders", MarketOrders)
startSystem("OgaPepperpot", OgaPepperpot)
if MarketOrders and started.OgaPepperpot then
	MarketOrders.bossEnabled = true
end
-- The HUD's feature strip: counts from the real tables, systems that really started.
guarded("FeatureStrip", function()
	local FeatureList = require(ReplicatedStorage:WaitForChild("Shared", 30):WaitForChild("FeatureList", 10))
	local events = 0
	if MarketEvents and MarketEvents.EVENTS and started.MarketEvents then
		events += FeatureList.count(MarketEvents.EVENTS)
	end
	for _, threat in { "LagoonSurge", "OgaPepperpot" } do
		if started[threat] then
			events += 1 -- the timed threats are market events too
		end
	end
	ReplicatedStorage:SetAttribute(FeatureList.ATTRIBUTE, FeatureList.build(events, started))
end)
-- Studio-only screenshot staging lives beside this folder.
local shotDirector = script.Parent:FindFirstChild("ShotDirectorServer")
if shotDirector then
	guarded("ShotDirectorServer", function()
		require(shotDirector).start()
	end)
end
print("[SnackGremlinHeist] server ready")
