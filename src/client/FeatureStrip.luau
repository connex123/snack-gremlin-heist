-- FeatureStrip: a dark bar across the top centre listing the game's counts and systems on two centred
-- lines (text from Shared.FeatureList, written by the server into a ReplicatedStorage attribute).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
local FeatureList = require(Shared:WaitForChild("FeatureList", 10))
local UiKit = require(script.Parent.UiKit)

local FeatureStrip = {}

-- Screen-scale rectangle, mirrored in tests/shots.luau (clear of Roblox's top-left buttons).
-- 0.08 high: two lines of about 14 px each in a 768x480 window.
FeatureStrip.POSITION = UDim2.fromScale(0.17, 0)
FeatureStrip.SIZE = UDim2.fromScale(0.66, 0.08)

local function line(strip: Frame, name: string, y: number): TextLabel
	local label = UiKit.text(strip, name, "", UDim2.fromScale(0.015, y), UDim2.fromScale(0.97, 0.43), UiKit.YELLOW)
	local outline = label:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Thickness = 2 -- a 3 px outline clogs ~16 px letters
	end
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = label
	return label
end

function FeatureStrip.create(gui: ScreenGui)
	local strip = UiKit.panel(gui, "FeatureStrip", FeatureStrip.POSITION, FeatureStrip.SIZE, UiKit.INK, 0.12)
	UiKit.stroke(strip, UiKit.YELLOW, 2)
	local top = line(strip, "Line1", 0.06)
	local bottom = line(strip, "Line2", 0.51)
	local function show(text: string)
		local a, b = FeatureList.twoLines(text)
		top.Text = a
		bottom.Text = b
	end
	show(FeatureList.build())
	local function refresh()
		local text = ReplicatedStorage:GetAttribute(FeatureList.ATTRIBUTE)
		if typeof(text) == "string" and #text > 0 then
			show(text)
		end
	end
	refresh()
	ReplicatedStorage:GetAttributeChangedSignal(FeatureList.ATTRIBUTE):Connect(function()
		pcall(refresh)
	end)
end

return FeatureStrip
