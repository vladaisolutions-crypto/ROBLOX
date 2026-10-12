--!strict
-- Small helpers so UI code stays readable: rounded frames, chunky buttons,
-- labels and modal panels in one consistent style.

local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Colors = {
	Panel = Color3.fromRGB(35, 30, 60),
	PanelLight = Color3.fromRGB(55, 48, 92),
	Stroke = Color3.fromRGB(15, 10, 30),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(180, 175, 210),
	Green = Color3.fromRGB(70, 210, 90),
	Red = Color3.fromRGB(235, 70, 80),
	Gold = Color3.fromRGB(255, 200, 50),
	Blue = Color3.fromRGB(70, 150, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Grey = Color3.fromRGB(110, 110, 130),
}

function Kit.Corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
end

function Kit.Stroke(parent: Instance, thickness: number?, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 3
	stroke.Color = color or Kit.Colors.Stroke
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function Kit.Frame(parent: Instance, size: UDim2, position: UDim2?, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position or UDim2.new()
	frame.BackgroundColor3 = color or Kit.Colors.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Kit.Corner(frame)
	return frame
end

function Kit.Label(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.new()
	label.Font = Kit.Font
	label.Text = text
	label.TextColor3 = color or Kit.Colors.Text
	label.TextScaled = true
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Kit.Colors.Stroke
	stroke.Parent = label
	return label
end

function Kit.Button(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?, onClick: (() -> ())?): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position or UDim2.new()
	button.BackgroundColor3 = color or Kit.Colors.Green
	button.AutoButtonColor = true
	button.Font = Kit.Font
	button.Text = text
	button.TextColor3 = Kit.Colors.Text
	button.TextScaled = true
	button.BorderSizePixel = 0
	button.Parent = parent
	Kit.Corner(button)
	Kit.Stroke(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = button
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Kit.Colors.Stroke
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = button
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A quick "pop" scale animation, used on buttons and counters.
function Kit.Pop(instance: GuiObject)
	local uiScale = instance:FindFirstChildOfClass("UIScale")
	if not uiScale then
		local created = Instance.new("UIScale")
		created.Parent = instance
		uiScale = created
	end
	assert(uiScale)
	uiScale.Scale = 1.15
	TweenService:Create(uiScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

export type Panel = {
	Frame: Frame,
	Body: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

local openPanel: Panel? = nil

-- Centered modal panel with a title and close button. Only one is open at a time.
function Kit.Panel(screen: ScreenGui, title: string, color: Color3?): Panel
	local frame = Kit.Frame(screen, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.25, 0.19))
	frame.Visible = false
	frame.ZIndex = 10
	Kit.Stroke(frame, 4)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1.45
	ratio.Parent = frame
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)

	local header = Kit.Frame(frame, UDim2.new(1, 0, 0.13, 0), nil, color or Kit.Colors.Purple)
	Kit.Label(header, title, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1))

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -24, 0.87, -16)
	body.Position = UDim2.new(0, 12, 0.13, 8)
	body.Parent = frame

	local panel: Panel
	local function close()
		frame.Visible = false
		if openPanel == panel then
			openPanel = nil
		end
	end
	local function open()
		if openPanel and openPanel ~= panel then
			openPanel.Close()
		end
		openPanel = panel
		frame.Visible = true
		Kit.Pop(frame)
	end
	local closeButton = Kit.Button(header, "X", UDim2.fromScale(0.07, 0.8), UDim2.fromScale(0.92, 0.1), Kit.Colors.Red, close)
	local closeRatio = Instance.new("UIAspectRatioConstraint")
	closeRatio.Parent = closeButton

	panel = {
		Frame = frame,
		Body = body,
		Open = open,
		Close = close,
		IsOpen = function()
			return frame.Visible
		end,
	}
	return panel
end

function Kit.Toggle(panel: Panel)
	if panel.IsOpen() then
		panel.Close()
	else
		panel.Open()
	end
end

return Kit
