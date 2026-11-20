-- FeatureStrip: a slim full-width line at the very top centre listing the game's counts and systems
-- (text from Shared.FeatureList, written by the server into a ReplicatedStorage attribute).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local FeatureList = require(Shared:WaitForChild("FeatureList", 10))
local UiKit = require(script.Parent.UiKit)

local FeatureStrip = {}

-- Screen-scale rectangle, mirrored in tests/shots.luau (clear of Roblox's top-left buttons).
FeatureStrip.POSITION = UDim2.fromScale(0.17, 0)
FeatureStrip.SIZE = UDim2.fromScale(0.66, 0.042)

function FeatureStrip.create(gui: ScreenGui)
	local strip = UiKit.panel(gui, "FeatureStrip", FeatureStrip.POSITION, FeatureStrip.SIZE, UiKit.INK, 0.25)
	UiKit.stroke(strip, UiKit.YELLOW, 2)
	local label = UiKit.text(strip, "Text", FeatureList.build(), UDim2.fromScale(0.02, 0.1), UDim2.fromScale(0.96, 0.8), UiKit.YELLOW)
	local function refresh()
		local text = ReplicatedStorage:GetAttribute(FeatureList.ATTRIBUTE)
		if typeof(text) == "string" and #text > 0 then
			label.Text = text
		end
	end
	refresh()
	ReplicatedStorage:GetAttributeChangedSignal(FeatureList.ATTRIBUTE):Connect(function()
		pcall(refresh)
	end)
end

return FeatureStrip
