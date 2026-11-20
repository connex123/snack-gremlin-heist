-- InputController: keyboard shortcuts for the button row (L lock, F whack, U upgrades, R rebirth, I index).
local UserInputService = game:GetService("UserInputService")

local InputController = {}

local KEYS = {
	[Enum.KeyCode.L] = "lock",
	[Enum.KeyCode.F] = "whack",
	[Enum.KeyCode.U] = "upgrades",
	[Enum.KeyCode.R] = "rebirth",
	[Enum.KeyCode.I] = "index",
}

function InputController.start(actions: { [string]: () -> () })
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local name = KEYS[input.KeyCode]
		local action = name and actions[name]
		if action then
			action()
		end
	end)
end

return InputController
