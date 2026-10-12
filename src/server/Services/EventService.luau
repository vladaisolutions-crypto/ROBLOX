--!strict
-- Server-wide timers: purchased Server Luck, the scheduled Slime Rain, and
-- seasonal events (Halloween, ...). Clients get the raw timestamps and count
-- down locally.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Signal = require(Shared.Util.Signal)
local NetService = require(script.Parent.NetService)

local EventService = {}
EventService.Changed = Signal.new()

local luckEndsAt = 0
local rainWasActive = false

local function now(): number
	return workspace:GetServerTimeNow()
end

function EventService.RainActive(): boolean
	return now() % Events.RainEverySeconds < Events.RainDurationSeconds
end

local function rainTimes(): (number, number)
	local t = now()
	local cycleStart = t - t % Events.RainEverySeconds
	return cycleStart + Events.RainDurationSeconds, cycleStart + Events.RainEverySeconds
end

function EventService.LuckActive(): boolean
	return now() < luckEndsAt
end

-- Multiplier applied to the weight of "Lucky" rarities on the belt.
function EventService.Luck(): number
	local luck = 1
	if EventService.LuckActive() then
		luck *= Monetization.ServerLuckMultiplier
	end
	if EventService.RainActive() then
		luck *= Events.RainLuck
	end
	return luck
end

function EventService.SpawnSpeedup(): number
	return if EventService.RainActive() then Events.RainSpawnSpeedup else 1
end

function EventService.SeasonalActive(eventId: string): boolean
	local t = os.time()
	for _, event in Events.Seasonal do
		if event.Id == eventId then
			return t >= event.Starts and t < event.Ends
		end
	end
	return false
end

local function activeSeasonal(): { Id: string, Name: string, Ends: number }?
	local t = os.time()
	for _, event in Events.Seasonal do
		if t >= event.Starts and t < event.Ends then
			return { Id = event.Id, Name = event.Name, Ends = event.Ends }
		end
	end
	return nil
end

function EventService.State(): { [string]: any }
	local rainEnds, nextRain = rainTimes()
	return {
		LuckEndsAt = luckEndsAt,
		LuckMultiplier = Monetization.ServerLuckMultiplier,
		RainActive = EventService.RainActive(),
		RainEndsAt = rainEnds,
		NextRainAt = nextRain,
		Seasonal = activeSeasonal(),
	}
end

local function broadcast()
	NetService.BroadcastEvents(EventService.State())
	EventService.Changed:Fire()
end

-- Adds server luck time (stacks). Called when someone buys Server Luck.
function EventService.AddServerLuck(seconds: number, buyerName: string)
	luckEndsAt = math.max(luckEndsAt, now()) + seconds
	NetService.Announce("🍀 " .. buyerName .. " bought SERVER LUCK x2 for everyone! 🍀", Color3.fromRGB(120, 255, 120))
	broadcast()
end

function EventService.Start()
	Players.PlayerAdded:Connect(function(player)
		NetService.SendEvents(player, EventService.State())
	end)
	task.spawn(function()
		while true do
			local active = EventService.RainActive()
			if active ~= rainWasActive then
				rainWasActive = active
				if active then
					NetService.Announce("🌧️ SLIME RAIN! Faster spawns and 3x luck for 2 minutes!", Color3.fromRGB(120, 200, 255))
				end
				broadcast()
			end
			task.wait(1)
		end
	end)
	broadcast()
end

return EventService
