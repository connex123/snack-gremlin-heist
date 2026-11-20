-- MarketEvents: timed market-wide events with a banner: Jollof Rain (x2 income), Pepper Hour
-- (mutation chance x4) and Belt Rush (belt spawns twice as fast).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local MarketEvents = {}

MarketEvents.EVENTS = {
	JollofRain = { title = "JOLLOF RAIN!", sub = "x2 INCOME for every stall", color = Color3.fromRGB(255, 110, 30), incomeMult = 2, mutationMult = 1, spawnMult = 1 },
	PepperHour = { title = "PEPPER HOUR!", sub = "mutation chance x4 on the belt", color = Color3.fromRGB(220, 30, 40), incomeMult = 1, mutationMult = 4, spawnMult = 1 },
	BeltRush = { title = "BELT RUSH!", sub = "gremlins hatch twice as fast", color = Color3.fromRGB(0, 190, 180), incomeMult = 1, mutationMult = 1, spawnMult = 2 },
}
local ORDER = { "JollofRain", "PepperHour", "BeltRush" }

local active: string? = nil
local endsAt = 0
local rainPart: BasePart? = nil

-- The Studio shot director sets this (os.clock time) so the timer does not swap a staged event.
MarketEvents.holdUntil = 0

function MarketEvents.activeEvent()
	return active and MarketEvents.EVENTS[active] or nil
end

function MarketEvents.incomeMultiplier(): number
	local event = MarketEvents.activeEvent()
	return event and event.incomeMult or 1
end

function MarketEvents.mutationMultiplier(): number
	local event = MarketEvents.activeEvent()
	return event and event.mutationMult or 1
end

function MarketEvents.spawnRateMultiplier(): number
	local event = MarketEvents.activeEvent()
	return event and event.spawnMult or 1
end

-- Jollof Rain: a sky-wide emitter dropping orange-red grains over the market.
function MarketEvents.setJollofRain(on: boolean)
	if on and not rainPart then
		local part = Instance.new("Part")
		part.Name = "JollofRainCloud"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(300, 1, 160)
		part.CFrame = CFrame.new(0, 60, 0)
		local emitter = Instance.new("ParticleEmitter")
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Rate = 400
		emitter.Lifetime = NumberRange.new(3, 4)
		emitter.Speed = NumberRange.new(18, 24)
		emitter.Size = NumberSequence.new(0.45)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 90, 20), Color3.fromRGB(255, 180, 40))
		emitter.LightEmission = 0.6
		emitter.Parent = part
		part.Parent = Workspace
		rainPart = part
	elseif not on and rainPart then
		rainPart:Destroy()
		rainPart = nil
	end
end

local function bannerPayload()
	local event = MarketEvents.activeEvent()
	if not event then
		return { slot = "event", clear = true }
	end
	return { slot = "event", title = event.title, sub = event.sub, color = event.color, endsAt = endsAt }
end

-- Starts an event now (used by the timer and by the Studio shot director).
function MarketEvents.startEvent(name: string, duration: number?)
	if not MarketEvents.EVENTS[name] then
		return
	end
	active = name
	endsAt = Workspace:GetServerTimeNow() + (duration or Config.EVENT_DURATION)
	MarketEvents.setJollofRain(name == "JollofRain")
	Remotes.get("Banner"):FireAllClients(bannerPayload())
	local myEnd = endsAt
	task.delay(duration or Config.EVENT_DURATION, function()
		if active == name and endsAt == myEnd then
			MarketEvents.stopEvent()
		end
	end)
end

function MarketEvents.stopEvent()
	active = nil
	MarketEvents.setJollofRain(false)
	Remotes.get("Banner"):FireAllClients(bannerPayload())
end

function MarketEvents.syncPlayer(player: Player)
	if active then
		Remotes.get("Banner"):FireClient(player, bannerPayload())
	end
end

function MarketEvents.start()
	task.spawn(function()
		local turn = 0
		while true do
			task.wait(Config.EVENT_INTERVAL)
			if os.clock() >= MarketEvents.holdUntil then
				turn += 1
				local ok, err = pcall(MarketEvents.startEvent, ORDER[(turn - 1) % #ORDER + 1])
				if not ok then
					warn("Market event failed: " .. tostring(err))
				end
			end
		end
	end)
end

return MarketEvents
