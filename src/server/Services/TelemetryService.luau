--!strict
-- Wraps Roblox's AnalyticsService so a failed log never breaks gameplay.
-- Everything logged here shows up in Creator Hub > Analytics, which is what
-- we use to decide what to change after launch.

local AnalyticsService = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)

local TelemetryService = {}

-- Onboarding funnel steps. Keep numbers stable once live; append new ones.
TelemetryService.Onboarding = {
	Joined = 1,
	BoughtFirstSlime = 2,
	CollectedCash = 3,
	BoughtSecondSlime = 4,
	LockedBase = 5,
	FirstSteal = 6,
	FirstRebirth = 7,
}

local ONBOARDING_NAMES: { [number]: string } = {}
for name: string, step: number in TelemetryService.Onboarding :: any do
	ONBOARDING_NAMES[step] = name
end

-- Logs an onboarding step once per player, ever.
function TelemetryService.Onboard(player: Player, step: number)
	local data = DataService.Get(player)
	if not data or data.Funnel[tostring(step)] then
		return
	end
	data.Funnel[tostring(step)] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, ONBOARDING_NAMES[step])
	end)
end

function TelemetryService.Source(player: Player, amount: number, balance: number, transaction: string, sku: string?)
	if amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Cash",
			amount,
			balance,
			transaction,
			sku
		)
	end)
end

function TelemetryService.Sink(player: Player, amount: number, balance: number, transaction: string, sku: string?)
	if amount <= 0 then
		return
	end
	pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Sink,
			"Cash",
			amount,
			balance,
			transaction,
			sku
		)
	end)
end

function TelemetryService.Custom(player: Player, name: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
end

function TelemetryService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player)
		TelemetryService.Onboard(player, TelemetryService.Onboarding.Joined)
	end)
end

return TelemetryService
