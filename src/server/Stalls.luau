-- Stalls: the six market stalls (bases). Assigns one to each player, shows the gremlins of its
-- slots on pedestals, finds free pedestals, and paints the floor after a rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local GremlinCatalog = require(Shared.GremlinCatalog)
local Mutations = require(Shared.Mutations)
local ShotFraming = require(Shared.ShotFraming)
local PlayerState = require(script.Parent.PlayerState)
local GremlinModel = require(script.Parent.World.GremlinModel)

local Stalls = {}
Stalls.plots = {} :: { any }

local LOCKED_COLOR = Color3.fromRGB(70, 70, 80)
local OPEN_COLOR = Color3.fromRGB(240, 240, 245)

function Stalls.init(plots: { any })
	Stalls.plots = plots
end

function Stalls.plotOf(player: Player)
	local state = PlayerState.get(player)
	if state and state.plotIndex then
		return Stalls.plots[state.plotIndex]
	end
	return nil
end

-- The slots table for a plot: the owner's base in PlayerState, or the rival's own slots.
function Stalls.slotsOf(plot): { [number]: PlayerState.Slot }
	if plot.owner then
		local state = PlayerState.get(plot.owner)
		return state and state.base or {}
	end
	return plot.rivalSlots
end

function Stalls.capacityOf(plot): number
	if plot.owner then
		local state = PlayerState.get(plot.owner)
		return state and PlayerState.pedestalCount(state) or 0
	end
	return Config.MAX_PEDESTALS
end

function Stalls.incomeMultiplierOf(plot): number
	if plot.owner then
		local state = PlayerState.get(plot.owner)
		return state and PlayerState.incomeMultiplier(state) or 1
	end
	return 1
end

-- Rebuilds the gremlin model on one pedestal from its slot.
function Stalls.renderPedestal(plot, index: number)
	local old = plot.models[index]
	if old then
		old:Destroy()
		plot.models[index] = nil
	end
	local slot = Stalls.slotsOf(plot)[index]
	if not slot then
		return
	end
	local gremlin = GremlinCatalog.get(slot.id)
	local model = GremlinModel.build(slot.id, slot.mutation, plot.pedestalTops[index], plot.owner ~= nil)
	if not model or not gremlin then
		return
	end
	local income = gremlin.income * Mutations.multiplierOf(slot.mutation) * Stalls.incomeMultiplierOf(plot)
	GremlinModel.attachLabel(model, gremlin, slot.mutation, income, nil, ShotFraming.labelLift(index))
	model:SetAttribute("PlotIndex", plot.index)
	model:SetAttribute("Pedestal", index)
	model.Parent = workspace
	plot.models[index] = model
end

-- Re-renders every pedestal and colours locked ones dark.
function Stalls.refreshPlot(plot)
	local capacity = Stalls.capacityOf(plot)
	for index, pedestal in plot.pedestals do
		pedestal.Color = index <= capacity and OPEN_COLOR or LOCKED_COLOR
		Stalls.renderPedestal(plot, index)
	end
end

function Stalls.firstFreePedestal(plot): number?
	local slots = Stalls.slotsOf(plot)
	for index = 1, Stalls.capacityOf(plot) do
		if slots[index] == nil then
			return index
		end
	end
	return nil
end

-- Puts a gremlin on the plot's next free pedestal; returns the pedestal index or nil if full.
function Stalls.placeGremlin(plot, gremlinId: string, mutation: string?, preferredIndex: number?): number?
	local slots = Stalls.slotsOf(plot)
	local index = preferredIndex
	if not index or slots[index] ~= nil or index > Stalls.capacityOf(plot) then
		index = Stalls.firstFreePedestal(plot)
	end
	if not index then
		return nil
	end
	slots[index] = { id = gremlinId, mutation = mutation }
	if plot.owner then
		PlayerState.markDirty(plot.owner)
	end
	Stalls.renderPedestal(plot, index)
	return index
end

-- Takes a gremlin off a pedestal; returns its slot.
function Stalls.removeGremlin(plot, index: number): PlayerState.Slot?
	local slots = Stalls.slotsOf(plot)
	local slot = slots[index]
	if not slot then
		return nil
	end
	slots[index] = nil
	if plot.owner then
		PlayerState.markDirty(plot.owner)
	end
	Stalls.renderPedestal(plot, index)
	return slot
end

function Stalls.clearPlot(plot)
	local slots = Stalls.slotsOf(plot)
	for index in slots do
		slots[index] = nil
	end
	Stalls.refreshPlot(plot)
end

function Stalls.pedestalPosition(plot, index: number): Vector3
	return plot.pedestalTops[index].Position
end

-- True when a world position is on the plot's floor (home).
function Stalls.isInsideHome(plot, position: Vector3): boolean
	local localPos = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= 18.5 and math.abs(localPos.Z) <= 13.5 and localPos.Y < 14
end

function Stalls.paintFloor(plot, rebirths: number)
	plot.floor.Color = Config.floorColor(rebirths)
end

-- The spot in front of a stall, facing it.
function Stalls.frontSpot(plot): CFrame
	local spot = plot.cframe * CFrame.new(0, 3, -17)
	return CFrame.lookAt(spot.Position, (plot.cframe * CFrame.new(0, 3, 0)).Position)
end

-- Gives a joining player a free stall (the centre one first); rivals give theirs up if needed.
function Stalls.claimStall(player: Player)
	local chosen = nil
	for _, plot in Stalls.plots do
		if not plot.owner and not plot.rivalName then
			chosen = plot
			break
		end
	end
	if not chosen then
		for _, plot in Stalls.plots do
			if not plot.owner then
				chosen = plot
				break
			end
		end
	end
	if not chosen then
		return nil
	end
	-- a rival stall taken over: clear its gremlins first
	if chosen.rivalName then
		for index in chosen.rivalSlots do
			chosen.rivalSlots[index] = nil
		end
		chosen.rivalName = nil
	end
	local state = PlayerState.get(player)
	chosen.owner = player
	if state then
		state.plotIndex = chosen.index
		Stalls.paintFloor(chosen, state.rebirths)
	end
	chosen.signLabel.Text = string.upper(player.DisplayName) .. "'S STALL"
	Stalls.refreshPlot(chosen)
	return chosen
end

function Stalls.releaseStall(player: Player)
	for _, plot in Stalls.plots do
		if plot.owner == player then
			plot.owner = nil
			plot.signLabel.Text = "OPEN STALL"
			for index, model in plot.models do
				model:Destroy()
				plot.models[index] = nil
			end
			Stalls.paintFloor(plot, 0)
		end
	end
end

function Stalls.ownerPlots()
	local list = {}
	for _, plot in Stalls.plots do
		if plot.owner and plot.owner.Parent == Players then
			table.insert(list, plot)
		end
	end
	return list
end

return Stalls
