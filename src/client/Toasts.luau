-- Toasts: short messages that slide in on the right and fade.
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)

local Toasts = {}

local holder: Frame

function Toasts.create(gui: ScreenGui)
	holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.fromScale(0.99, 0.33)
	holder.Size = UDim2.fromScale(0.3, 0.4)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	holder.Parent = gui
end

-- Hidden while a screenshot is framed so toasts never cover the gremlin labels.
function Toasts.setVisible(visible: boolean)
	holder.Visible = visible
end

local order = 0
function Toasts.show(text: string, color: Color3?)
	order -= 1
	local frame = UiKit.panel(holder, "Toast", UDim2.new(), UDim2.fromScale(1, 0.16), UiKit.INK, 0.15)
	frame.LayoutOrder = order
	UiKit.stroke(frame, color or Color3.new(1, 1, 1), 3)
	local label = UiKit.text(frame, "Text", text, UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.8), color or Color3.new(1, 1, 1))
	if #holder:GetChildren() > 5 then
		for _, child in holder:GetChildren() do
			if child:IsA("Frame") and child.LayoutOrder > order + 3 then
				child:Destroy()
			end
		end
	end
	task.delay(3.5, function()
		if frame.Parent then
			local fade = TweenInfo.new(0.5)
			TweenService:Create(frame, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			task.wait(0.5)
			frame:Destroy()
		end
	end)
end

return Toasts
