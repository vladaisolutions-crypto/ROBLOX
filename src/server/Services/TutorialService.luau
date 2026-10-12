--!strict
-- First-session onboarding. A low first-play bounce rate is one of the
-- strongest signals Roblox's recommendation system uses, so new players get
-- a guided arrow through the core loop within their first minute.

local Players = game:GetService("Players")

local ConveyorService = require(script.Parent.ConveyorService)
local DataTemplate = require(script.Parent.Parent.DataTemplate)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)

type PlayerData = DataTemplate.PlayerData

local STEPS = {
	"Buy a slime from the belt! Walk up to it and press E.",
	"Your slime makes cash! Step on the green pad to collect it.",
	"Buy more slimes to earn faster!",
	"Others can steal your slimes! Step on the red pad to lock your base.",
	"Steal from other bases (hold E) and run home. Bonk thieves with your bat!",
}
local DONE = #STEPS + 1

local TutorialService = {}

local lastSent: { [Player]: { Step: number, Target: Instance? } } = {}
local stepStarted: { [Player]: number } = {}

local function setStep(player: Player, data: PlayerData, step: number)
	if data.TutorialStep >= step then
		return
	end
	data.TutorialStep = step
	stepStarted[player] = os.clock()
end

local function target(player: Player, data: PlayerData): Instance?
	local step = data.TutorialStep
	if step == 1 or step == 3 then
		return ConveyorService.CheapestAffordable(data.Cash)
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return nil
	end
	if step == 2 then
		for _, slot in data.Slots do
			if slot.Stored > 0 then
				return plot.CollectPads[slot.Slot]
			end
		end
	elseif step == 4 then
		return plot.LockPad
	end
	return nil
end

local function update(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if data.TutorialStep == 5 and os.clock() - (stepStarted[player] or 0) > 20 then
		setStep(player, data, DONE)
	end
	-- Auto Collect owners never step on pads, so skip the collect step.
	if data.TutorialStep == 2 and PassService.Has(player, "AutoCollect") then
		setStep(player, data, 3)
	end
	local step = data.TutorialStep
	local goal = if step < DONE then target(player, data) else nil
	local sent = lastSent[player]
	if sent and sent.Step == step and sent.Target == goal then
		return
	end
	lastSent[player] = { Step = step, Target = goal }
	NetService.SendTutorial(player, if step < DONE then step else 0, STEPS[step], goal)
end

function TutorialService.Init()
	EconomyService.SlimeAdded:Connect(function(player: Player)
		local data = DataService.Get(player)
		if not data then
			return
		end
		if data.TutorialStep == 1 then
			setStep(player, data, 2)
		elseif data.TutorialStep == 3 and #data.Slots >= 3 then
			setStep(player, data, 4)
		end
	end)
	EconomyService.Collected:Connect(function(player: Player)
		local data = DataService.Get(player)
		if data and data.TutorialStep == 2 then
			setStep(player, data, 3)
		end
	end)
	PlotService.Locked:Connect(function(player: Player)
		local data = DataService.Get(player)
		if data and data.TutorialStep == 4 then
			setStep(player, data, 5)
		end
	end)
	-- Returning players who already know the game skip straight to the end.
	DataService.ProfileLoaded:Connect(function(player: Player, data: PlayerData)
		if data.TutorialStep < DONE and data.Stats.SlimesBought >= 5 and data.Stats.PlaySeconds > 600 then
			data.TutorialStep = DONE
		end
		stepStarted[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
		stepStarted[player] = nil
	end)
end

function TutorialService.Start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				update(player)
			end
			task.wait(1)
		end
	end)
end

return TutorialService
