-- UiKit: the few building blocks every HUD piece uses (rounded panels, outlined text, buttons).
local UiKit = {}

UiKit.FONT = Enum.Font.FredokaOne
UiKit.YELLOW = Color3.fromRGB(255, 205, 40)
UiKit.GREEN = Color3.fromRGB(90, 255, 110)
UiKit.CORAL = Color3.fromRGB(255, 95, 110)
UiKit.TEAL = Color3.fromRGB(0, 200, 190)
UiKit.INK = Color3.fromRGB(25, 15, 35)

function UiKit.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius or 0.2, 0)
	corner.Parent = parent
end

function UiKit.stroke(parent: Instance, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = parent:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UiKit.panel(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0.1
	frame.BorderSizePixel = 0
	UiKit.corner(frame, 0.18)
	frame.Parent = parent
	return frame
end

-- Bold, scaled, dark-outlined text that stays readable when the screen is shrunk.
function UiKit.text(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, color: Color3, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = UiKit.FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	UiKit.stroke(label, UiKit.INK, 3)
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = UiKit.FONT
	button.TextScaled = true
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	UiKit.corner(button, 0.25)
	UiKit.stroke(button, UiKit.INK, 3)
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Thickness = 2
	textStroke.Color = UiKit.INK
	textStroke.Parent = button
	button.Parent = parent
	return button
end

return UiKit
