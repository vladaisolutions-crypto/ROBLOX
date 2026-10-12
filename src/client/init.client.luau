--!strict
-- Client entry point: builds the UI and starts client controllers.

local Players = game:GetService("Players")

local Store = require(script.Store)
local Kit = require(script.UI.Kit)
local Hud = require(script.UI.Hud)
local Panels = require(script.UI.Panels)
local Controllers = require(script.Controllers)
local ChatTags = require(script.ChatTags)

local player = Players.LocalPlayer

Store.Init()

local screen = Instance.new("ScreenGui")
screen.Name = "Game"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

-- Scale the whole UI with screen height so it fits phones and monitors.
local uiScale = Instance.new("UIScale")
uiScale.Parent = screen
local function rescale()
	local camera = workspace.CurrentCamera
	if camera then
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.25)
	end
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local menus: Hud.Menus = {
	Shop = Panels.Shop(screen),
	Index = Panels.Index(screen),
	Rebirth = Panels.Rebirth(screen),
	Daily = Panels.Daily(screen),
	Codes = Panels.Codes(screen),
}
Hud.Create(screen, menus)

-- Sits above the lock button (0.75), which in turn sits above the backpack hotbar.
local tutorialLabel = Kit.Label(screen, "", UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.2, 0.67), Color3.fromRGB(255, 240, 120))
tutorialLabel.Visible = false

Controllers.Start(tutorialLabel)
ChatTags.Start()

-- Open the daily reward panel on join if there's something to claim.
task.delay(4, function()
	if Store.Get("DailyCanClaim", false) then
		menus.Daily.Open()
	end
end)
