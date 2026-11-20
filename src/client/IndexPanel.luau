-- IndexPanel: the Gremlin Index, how many of each rarity you have discovered, with their names.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local Rarities = require(Shared.Rarities)
local GremlinCatalog = require(Shared.GremlinCatalog)
local UiKit = require(script.Parent.UiKit)

local IndexPanel = {}

local panel: Frame
local title: TextLabel
local rows: { [string]: { count: TextLabel, names: TextLabel, bar: Frame } } = {}

function IndexPanel.create(gui: ScreenGui)
	panel = UiKit.panel(gui, "IndexPanel", UDim2.fromScale(0.79, 0.605), UDim2.fromScale(0.38, 0.44), UiKit.INK, 0.08)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	UiKit.stroke(panel, Color3.fromRGB(255, 160, 20), 4)
	title = UiKit.text(panel, "Title", "GREMLIN INDEX", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.11), Color3.fromRGB(255, 190, 60))
	for i, rarity in Rarities.list do
		local y = 0.15 + (i - 1) * 0.104
		UiKit.text(panel, rarity.name, string.upper(rarity.name), UDim2.fromScale(0.03, y), UDim2.fromScale(0.3, 0.065), rarity.color, Enum.TextXAlignment.Left)
		local track = UiKit.panel(panel, rarity.name .. "Track", UDim2.fromScale(0.34, y + 0.012), UDim2.fromScale(0.42, 0.045), Color3.fromRGB(60, 55, 75), 0)
		local bar = UiKit.panel(track, "Bar", UDim2.new(), UDim2.fromScale(0, 1), rarity.color, 0)
		local count = UiKit.text(panel, rarity.name .. "Count", "0/0", UDim2.fromScale(0.78, y), UDim2.fromScale(0.19, 0.065), Color3.new(1, 1, 1))
		local names = UiKit.text(panel, rarity.name .. "Names", "", UDim2.fromScale(0.03, y + 0.064), UDim2.fromScale(0.94, 0.036), Color3.fromRGB(200, 200, 215), Enum.TextXAlignment.Left)
		rows[rarity.name] = { count = count, names = names, bar = bar }
	end
end

function IndexPanel.update(snapshot)
	local found: { [string]: boolean } = {}
	for _, id in snapshot.discovered do
		found[id] = true
	end
	for _, rarity in Rarities.list do
		local pool = GremlinCatalog.byRarity[rarity.name] or {}
		local have, names = 0, {}
		for _, gremlin in pool do
			if found[gremlin.id] then
				have += 1
				table.insert(names, gremlin.name)
			else
				table.insert(names, "???")
			end
		end
		local row = rows[rarity.name]
		row.count.Text = have .. "/" .. #pool
		row.bar.Size = UDim2.fromScale(#pool > 0 and have / #pool or 0, 1)
		row.names.Text = table.concat(names, " · ")
	end
	title.Text = "GREMLIN INDEX " .. #snapshot.discovered .. "/" .. GremlinCatalog.count()
end

function IndexPanel.setOpen(open: boolean)
	panel.Visible = open
end

function IndexPanel.toggle()
	panel.Visible = not panel.Visible
end

return IndexPanel
