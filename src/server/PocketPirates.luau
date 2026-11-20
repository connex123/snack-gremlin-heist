-- PocketPirates: sneaky NPC thieves row in from the lagoon, walk to a stall and grab a gremlin.
-- A locked shutter bounces them off; a whack (F) knocks them flying and puts the gremlin back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local GremlinCatalog = require(Shared.GremlinCatalog)
local PlayerState = require(script.Parent.PlayerState)
local Stalls = require(script.Parent.Stalls)
local ShutterLock = require(script.Parent.ShutterLock)
local GremlinModel = require(script.Parent.World.GremlinModel)
local PirateModel = require(script.Parent.World.PirateModel)

local PocketPirates = {}

type Raid = {
	model: Model,
	plot: any,
	status: TextLabel,
	stolen: PlayerState.Slot?,
	stolenIndex: number?,
	stolenModel: Model?,
	whacked: boolean,
	frozen: boolean,
}
local raids: { Raid } = {}
local rng = Random.new()

-- Glides the pirate toward a point; returns false if it was whacked on the way.
function PocketPirates.walkTo(raid: Raid, target: Vector3, speed: number): boolean
	local t = 0
	while not raid.whacked and raid.model.Parent do
		if raid.frozen then
			task.wait(0.2)
			continue
		end
		local dt = task.wait()
		t += dt
		local pos = raid.model:GetPivot().Position
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		if flat.Magnitude < 1 then
			return true
		end
		local step = flat.Unit * math.min(speed * dt, flat.Magnitude)
		local newPos = Vector3.new(pos.X + step.X, target.Y + math.abs(math.sin(t * 10)) * 0.5, pos.Z + step.Z)
		raid.model:PivotTo(CFrame.lookAt(newPos, newPos + flat))
	end
	return false
end

local function dockFor(plot): Vector3
	return Vector3.new(plot.cframe.Position.X + 8, 0, Config.LAGOON_EDGE_Z + 3)
end

-- Lifts a stolen gremlin off a pedestal and onto the pirate's bag.
function PocketPirates.grab(raid: Raid, index: number)
	local slot = Stalls.removeGremlin(raid.plot, index)
	if not slot then
		return
	end
	raid.stolen = slot
	raid.stolenIndex = index
	raid.stolenModel = PirateModel.holdGremlin(raid.model, GremlinModel.build(slot.id, slot.mutation, raid.model:GetPivot()))
	raid.status.Text = "STEALING!"
	raid.status.TextColor3 = Color3.fromRGB(255, 220, 60)
	local gremlin = GremlinCatalog.get(slot.id)
	if raid.plot.owner then
		Remotes.get("Toast"):FireClient(raid.plot.owner, "A Pocket Pirate grabbed your " .. (gremlin and gremlin.name or "gremlin") .. "! Whack it (F)!", Color3.fromRGB(255, 70, 70))
	end
end

local function pickOccupied(plot): number?
	local occupied = {}
	for index in Stalls.slotsOf(plot) do
		table.insert(occupied, index)
	end
	if #occupied == 0 then
		return nil
	end
	return occupied[rng:NextInteger(1, #occupied)]
end

local function finishRaid(raid: Raid)
	local i = table.find(raids, raid)
	if i then
		table.remove(raids, i)
	end
	if raid.model.Parent then
		raid.model:Destroy()
	end
end

-- One raid from the dock to a stall and back.
function PocketPirates.runRaid(plot)
	local dock = dockFor(plot)
	local model, status = PirateModel.build(CFrame.new(dock))
	local raid: Raid = { model = model, plot = plot, status = status, whacked = false, frozen = false }
	table.insert(raids, raid)
	local front = (plot.cframe * CFrame.new(0, 0, -15)).Position
	if not PocketPirates.walkTo(raid, front, Config.PIRATE_WALK_SPEED) then
		return
	end
	if ShutterLock.isLocked(plot) then
		status.Text = "BOUNCED OFF!"
		if plot.owner then
			Remotes.get("Toast"):FireClient(plot.owner, "Your shutter stopped a Pocket Pirate!", Color3.fromRGB(80, 220, 255))
		end
		PocketPirates.walkTo(raid, dock, Config.PIRATE_WALK_SPEED)
		finishRaid(raid)
		return
	end
	local index = pickOccupied(plot)
	if not index then
		PocketPirates.walkTo(raid, dock, Config.PIRATE_WALK_SPEED)
		finishRaid(raid)
		return
	end
	local target = Stalls.pedestalPosition(plot, index)
	if not PocketPirates.walkTo(raid, (CFrame.new(target) * plot.cframe.Rotation * CFrame.new(0, 0, -3)).Position, Config.PIRATE_WALK_SPEED) then
		return
	end
	if raid.whacked then
		return
	end
	PocketPirates.grab(raid, index)
	if PocketPirates.walkTo(raid, dock, Config.PIRATE_ESCAPE_SPEED) and raid.stolen then
		local gremlin = GremlinCatalog.get(raid.stolen.id)
		if plot.owner then
			Remotes.get("Toast"):FireClient(plot.owner, "A Pocket Pirate sailed off with your " .. (gremlin and gremlin.name or "gremlin") .. "!", Color3.fromRGB(255, 70, 70))
		end
		finishRaid(raid)
	end
end

-- Whack the nearest pirate in range: it flies off, the gremlin goes back, you earn a bounty.
function PocketPirates.whack(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local best, bestDist = nil, Config.WHACK_RANGE
	for _, raid in raids do
		local d = (raid.model:GetPivot().Position - root.Position).Magnitude
		if not raid.whacked and d <= bestDist then
			best, bestDist = raid, d
		end
	end
	Remotes.get("Effect"):FireClient(player, "swing", root.Position)
	if not best then
		return false
	end
	local raid = best :: Raid
	raid.whacked = true
	raid.status.Text = "WHACKED!"
	if raid.stolen then
		if raid.stolenModel then
			raid.stolenModel:Destroy()
		end
		Stalls.placeGremlin(raid.plot, raid.stolen.id, raid.stolen.mutation, raid.stolenIndex)
	end
	local state = PlayerState.get(player)
	local bounty = math.max(50, (state and state.rate or 0) * Config.WHACK_BOUNTY_SECONDS)
	PlayerState.addCash(player, bounty)
	Remotes.get("Effect"):FireAllClients("whack", raid.model:GetPivot().Position + Vector3.new(0, 4, 0))
	Remotes.get("Toast"):FireClient(player, "WHACK! Pirate sent flying. Bounty +$" .. math.floor(bounty), Color3.fromRGB(90, 255, 120))
	PirateModel.flyAway(raid.model, function()
		finishRaid(raid)
	end)
	return true
end

-- Chooses a stall to raid: players' stocked stalls first, else a rival stall for show.
function PocketPirates.pickTarget()
	local candidates = {}
	for _, plot in Stalls.ownerPlots() do
		if next(Stalls.slotsOf(plot)) ~= nil then
			table.insert(candidates, plot)
		end
	end
	if #candidates == 0 or rng:NextNumber() < 0.3 then
		for _, plot in Stalls.plots do
			if plot.rivalName and next(plot.rivalSlots) ~= nil then
				table.insert(candidates, plot)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Studio shot director: a frozen pirate in front of a stall, already holding a gremlin.
function PocketPirates.stageFrozenRaid(plot)
	local index = pickOccupied(plot)
	if not index then
		return
	end
	local spot = (CFrame.new(Stalls.pedestalPosition(plot, index)) * plot.cframe.Rotation * CFrame.new(0, 0, -6)).Position
	local model, status = PirateModel.build(CFrame.lookAt(spot, spot + plot.cframe.LookVector))
	local raid: Raid = { model = model, plot = plot, status = status, whacked = false, frozen = true }
	table.insert(raids, raid)
	PocketPirates.grab(raid, index)
	task.spawn(function()
		task.wait(30)
		raid.frozen = false
		PocketPirates.walkTo(raid, dockFor(plot), Config.PIRATE_ESCAPE_SPEED)
		finishRaid(raid)
	end)
end

function PocketPirates.start()
	Remotes.get("RequestWhack").OnServerEvent:Connect(function(player)
		PocketPirates.whack(player)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.PIRATE_INTERVAL)
			if #Players:GetPlayers() > 0 then
				local plot = PocketPirates.pickTarget()
				if plot then
					task.spawn(function()
						local ok, err = pcall(PocketPirates.runRaid, plot)
						if not ok then
							warn("Raid failed: " .. tostring(err))
						end
					end)
				end
			end
		end
	end)
end

return PocketPirates
