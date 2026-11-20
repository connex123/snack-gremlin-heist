-- Remotes: every RemoteEvent of the game, created in one place by the server and fetched by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.NAMES = {
	"StateChanged", -- server -> client: the player's snapshot (cash, rate, base, upgrades...)
	"IncomeTick", -- server -> client: per-pedestal income for "+$X" pop-ups
	"Banner", -- server -> all: event / surge banners
	"Toast", -- server -> client: short message
	"Effect", -- server -> client: burst of particles at a point
	"RequestLock", -- client -> server: Shutter Lock
	"RequestWhack", -- client -> server: whack the nearest Pocket Pirate
	"RequestUpgrade", -- client -> server: buy an upgrade by key
	"RequestRebirth", -- client -> server: rebirth
	"ShotRequest", -- client -> server (Studio only): stage a screenshot
	"ShotReady", -- server -> client (Studio only): camera for the staged shot
}

local FOLDER_NAME = "Remotes"

-- Server: creates the folder and every RemoteEvent.
function Remotes.createAll()
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in Remotes.NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Either side: returns a RemoteEvent by name, waiting a bounded time for the server to create it.
function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	assert(folder, "Remotes folder missing")
	local remote = folder:WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), "Remote missing: " .. name)
	return remote :: RemoteEvent
end

return Remotes
