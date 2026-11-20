-- OrdersPanel: the compact "TONIGHT'S ORDERS" board on the right: three quests with progress bars
-- and rewards, from the snapshot's orders (server: MarketOrders).
local UiKit = require(script.Parent.UiKit)

local OrdersPanel = {}

-- Screen-scale rectangle, mirrored in tests/shots.luau.
OrdersPanel.POSITION = UDim2.fromScale(0.8, 0.135)
OrdersPanel.SIZE = UDim2.fromScale(0.19, 0.285)

type Row = { frame: Frame, text: TextLabel, fill: Frame, count: TextLabel, reward: TextLabel }
local rows: { Row } = {}
local panel: Frame? = nil

function OrdersPanel.create(gui: ScreenGui)
	local frame = UiKit.panel(gui, "OrdersPanel", OrdersPanel.POSITION, OrdersPanel.SIZE, UiKit.INK, 0.15)
	UiKit.stroke(frame, UiKit.TEAL, 3)
	frame.Visible = false -- shown with the first snapshot that has orders
	UiKit.text(frame, "Title", "TONIGHT'S ORDERS", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.14), UiKit.YELLOW)
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Order" .. i
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0.04, 0.18 + (i - 1) * 0.27)
		row.Size = UDim2.fromScale(0.92, 0.25)
		row.Parent = frame
		local text = UiKit.text(row, "Text", "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.42), Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
		local bar = UiKit.panel(row, "Bar", UDim2.fromScale(0, 0.48), UDim2.fromScale(0.5, 0.4), Color3.fromRGB(60, 50, 75), 0)
		local fill = UiKit.panel(bar, "Fill", UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), UiKit.GREEN, 0)
		local count = UiKit.text(bar, "Count", "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1))
		count.ZIndex = 3
		local reward = UiKit.text(row, "Reward", "", UDim2.fromScale(0.53, 0.46), UDim2.fromScale(0.47, 0.46), UiKit.GREEN, Enum.TextXAlignment.Right)
		rows[i] = { frame = row, text = text, fill = fill, count = count, reward = reward }
	end
	panel = frame
end

function OrdersPanel.update(snapshot)
	if not panel or typeof(snapshot) ~= "table" or typeof(snapshot.orders) ~= "table" then
		return
	end
	panel.Visible = #snapshot.orders > 0
	for i, row in rows do
		local order = snapshot.orders[i]
		row.frame.Visible = order ~= nil
		if order then
			local goal = math.max(1, tonumber(order.goal) or 1)
			local progress = math.clamp(tonumber(order.progress) or 0, 0, goal)
			row.text.Text = tostring(order.text)
			row.fill.Size = UDim2.fromScale(progress / goal, 1)
			row.fill.BackgroundColor3 = order.done and UiKit.YELLOW or UiKit.GREEN
			row.count.Text = order.done and "DONE!" or (progress .. "/" .. goal)
			row.reward.Text = "+" .. tostring(order.reward)
		end
	end
end

return OrdersPanel
