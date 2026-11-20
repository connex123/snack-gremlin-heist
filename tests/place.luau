-- Built-place check, run after `rojo build default.project.json --output game.rbxl` with:
--   lune run tests/place.luau
-- Opens game.rbxl with @lune/roblox and asserts every source file landed at its expected path as the right
-- script class with non-empty source, the bootstraps are a Script / LocalScript with a sane RunContext,
-- Players.CharacterAutoLoads is on and the Studio shot director modules are present.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("  FAIL " .. message)
	end
end

local game = roblox.deserializePlace(fs.readFile("game.rbxl"))

local function find(path: string): any
	local node = game
	for part in string.gmatch(path, "[^%.]+") do
		if node == game then
			node = game:GetService(part)
		else
			node = node:FindFirstChild(part)
		end
		if not node then
			return nil
		end
	end
	return node
end

-- Every .luau file under a source folder, mapped to its instance path and class the way Rojo does it.
local expected = {}
local function walk(dir: string, path: string)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			walk(full, path .. "." .. name)
		elseif name == "init.server.luau" then
			table.insert(expected, { path = path, class = "Script", file = full })
		elseif string.match(name, "%.server%.luau$") then
			table.insert(expected, { path = path .. "." .. string.gsub(name, "%.server%.luau$", ""), class = "Script", file = full })
		elseif string.match(name, "%.client%.luau$") then
			table.insert(expected, { path = path .. "." .. string.gsub(name, "%.client%.luau$", ""), class = "LocalScript", file = full })
		elseif string.match(name, "%.luau$") then
			table.insert(expected, { path = path .. "." .. string.gsub(name, "%.luau$", ""), class = "ModuleScript", file = full })
		end
	end
end
walk("src/shared", "ReplicatedStorage.Shared")
walk("src/server", "ServerScriptService.Server")
walk("src/client", "StarterPlayer.StarterPlayerScripts.Client")
table.insert(expected, { path = "ServerScriptService.ShotDirectorServer", class = "ModuleScript", file = "src/studio/ShotDirectorServer.luau" })

for _, entry in expected do
	local instance = find(entry.path)
	check(instance ~= nil, "missing " .. entry.path)
	if instance then
		check(instance.ClassName == entry.class, entry.path .. " is a " .. instance.ClassName .. ", expected " .. entry.class)
		local source = instance.Source
		check(typeof(source) == "string" and #source > 20, entry.path .. " has empty source")
		check(source == fs.readFile(entry.file), entry.path .. " source differs from " .. entry.file .. " (rebuild game.rbxl)")
	end
end

-- Must-haves by name, so a renamed or dropped file fails here and not in the owner's Studio session.
for _, path in {
	"ServerScriptService.Server",
	"ServerScriptService.ShotDirectorServer",
	"ServerScriptService.Server.MarketOrders",
	"ServerScriptService.Server.OgaPepperpot",
	"ReplicatedStorage.Shared.ShotDirector",
	"ReplicatedStorage.Shared.ShotFraming",
	"ReplicatedStorage.Shared.Remotes",
	"ReplicatedStorage.Shared.FeatureList",
	"StarterPlayer.StarterPlayerScripts.Client.Game",
	"StarterPlayer.StarterPlayerScripts.Client.FeatureStrip",
	"StarterPlayer.StarterPlayerScripts.Client.OrdersPanel",
} do
	check(find(path) ~= nil, "must-have missing: " .. path)
end

local server = find("ServerScriptService.Server")
if server then
	check(server.ClassName == "Script", "server bootstrap must be a Script")
	local context = server.RunContext
	check(context == nil or context == roblox.Enum.RunContext.Legacy or context == roblox.Enum.RunContext.Server, "server bootstrap RunContext must be Legacy or Server, got " .. tostring(context))
	check(server.Disabled ~= true, "server bootstrap is disabled")
end
local client = find("StarterPlayer.StarterPlayerScripts.Client.Game")
if client then
	check(client.ClassName == "LocalScript", "client bootstrap must be a LocalScript")
	check(client.Disabled ~= true, "client bootstrap is disabled")
end

local players = game:GetService("Players")
check(players.CharacterAutoLoads == true, "Players.CharacterAutoLoads must be true")

print(string.format("place: %d scripts checked", #expected))
if failures > 0 then
	print(failures .. " place problem(s)")
	process.exit(1)
end
print("place: all checks passed")
