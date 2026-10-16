--!strict
-- Client side of chaos events (server: ChaosService). Reads the workspace
-- attributes Chaos / ChaosEndsAt.
--
--   Countdown  a small timer under the top of the screen while one runs.
--   Blackout   the world goes dark (slimes with lights still glow) and the
--              Watcher shows up a few seconds in.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Watcher = require(script.Parent.Watcher)

local Chaos = {}

local NAMES: { [string]: string } = {
	CashRain = "💰 Cash Rain",
	Meteors = "☄️ Meteor Shower",
	LowGravity = "🌙 Low Gravity",
	SpeedFrenzy = "⚡ Speed Frenzy",
	LuckyStorm = "🍀 Lucky Storm",
	Blackout = "🌑 Blackout",
}

local saved: { [string]: any }? = nil

local function blackout(on: boolean)
	local info = TweenInfo.new(if on then 2.5 else 2)
	if on then
		saved = {
			ClockTime = Lighting.ClockTime,
			Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ExposureCompensation = Lighting.ExposureCompensation,
		}
		TweenService:Create(Lighting, info, {
			ClockTime = 0,
			Brightness = 0.2,
			Ambient = Color3.fromRGB(25, 20, 40),
			OutdoorAmbient = Color3.fromRGB(35, 30, 55),
			ExposureCompensation = -0.4,
		}):Play()
		task.delay(7, Watcher.Appear)
	elseif saved then
		TweenService:Create(Lighting, info, saved):Play()
		saved = nil
	end
end

function Chaos.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Chaos"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 70)
	label.Size = UDim2.fromOffset(260, 34)
	label.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 225, 100)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	local current = ""
	local function update()
		local id = workspace:GetAttribute("Chaos")
		local now = if type(id) == "string" then id else ""
		if now == current then
			return
		end
		if current == "Blackout" then
			blackout(false)
		end
		current = now
		if current == "Blackout" then
			blackout(true)
		end
	end
	workspace:GetAttributeChangedSignal("Chaos"):Connect(update)
	update()

	RunService.Heartbeat:Connect(function()
		local name = NAMES[current]
		local endsAt = workspace:GetAttribute("ChaosEndsAt")
		if name and type(endsAt) == "number" then
			local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			label.Text = name .. "  " .. left .. "s"
			label.Visible = true
		else
			label.Visible = false
		end
	end)
end

return Chaos
