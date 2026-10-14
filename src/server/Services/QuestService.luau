--!strict
-- Daily quests: three a day per player (Config/Quests), tracked from game
-- events and claimed from the Quests panel for free cash (base income, so
-- they never outshine what Robux buys).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Format = require(Shared.Util.Format)
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Slimes = require(Shared.Config.Slimes)

local DataService = require(script.Parent.DataService)
local DataTemplate = require(script.Parent.Parent.DataTemplate)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)
local ThiefService = require(script.Parent.ThiefService)

type PlayerData = DataTemplate.PlayerData

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

-- Today's quests for this player: a fixed draw per player per day.
local function ensureToday(player: Player, data: PlayerData)
	local day = today()
	if data.Quests.Day == day and #data.Quests.List > 0 then
		return
	end
	local rng = Random.new(day * 7919 + player.UserId)
	local pool = table.clone(Quests.Pool)
	local list = {}
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool)) :: Quests.Quest
		-- One quest per kind of event, so the three feel different.
		for i = #pool, 1, -1 do
			if pool[i].Event == quest.Event then
				table.remove(pool, i)
			end
		end
		table.insert(list, { Id = quest.Id, Progress = 0, Claimed = false })
		if #pool == 0 then
			break
		end
	end
	data.Quests = { Day = day, List = list }
end

local function push(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ensureToday(player, data)
	local out = {}
	for _, entry in data.Quests.List do
		local quest = Quests.ById[entry.Id]
		if quest then
			table.insert(out, {
				Text = quest.Text,
				Progress = math.min(entry.Progress, quest.Goal),
				Goal = quest.Goal,
				Claimed = entry.Claimed,
				Reward = EconomyService.FreeRewardCash(player, quest.RewardMinutes, quest.RewardMinimum),
			})
		end
	end
	NetService.SendState(player, { Quests = out, QuestsResetAt = (today() + 1) * 86400 })
end

-- Adds progress to every unclaimed quest of today that listens for `event`.
function QuestService.Progress(player: Player, event: string, amount: number?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ensureToday(player, data)
	local changed = false
	for _, entry in data.Quests.List do
		local quest = Quests.ById[entry.Id]
		if quest and quest.Event == event and not entry.Claimed and entry.Progress < quest.Goal then
			entry.Progress = math.min(quest.Goal, entry.Progress + (amount or 1))
			changed = true
			if entry.Progress >= quest.Goal then
				NetService.Notify(player, "✅ Quest done: " .. quest.Text .. "! Claim it in Quests.", "Good")
			end
		end
	end
	if changed then
		push(player)
	end
end

local function claim(player: Player, index: any)
	local data = DataService.Get(player)
	if not data or type(index) ~= "number" then
		return
	end
	ensureToday(player, data)
	local entry = data.Quests.List[index]
	local quest = entry and Quests.ById[entry.Id]
	if not entry or not quest or entry.Claimed or entry.Progress < quest.Goal then
		return
	end
	entry.Claimed = true
	local amount = EconomyService.FreeRewardCash(player, quest.RewardMinutes, quest.RewardMinimum)
	EconomyService.AddCash(player, amount, "Reward", "Quest" .. quest.Id)
	NetService.Notify(player, "🎯 Quest reward: +" .. Format.Cash(amount) .. "!", "Money")
	TelemetryService.Custom(player, "QuestClaimed", index)
	push(player)
end

function QuestService.Init()
	EconomyService.SlimeAdded:Connect(function(player: Player, slotData: any, source: string)
		if source == "Belt" then
			QuestService.Progress(player, "BuySlime")
			local def = Slimes.ById[slotData.Id]
			local rarity = def and Rarities.ByName[def.Rarity]
			if rarity and rarity.Order >= 3 then
				QuestService.Progress(player, "BuyRare")
			end
		elseif source == "Steal" then
			QuestService.Progress(player, "Steal")
		end
	end)
	EconomyService.Collected:Connect(function(player: Player)
		QuestService.Progress(player, "Collect")
	end)
	EconomyService.Merged:Connect(function(player: Player)
		QuestService.Progress(player, "Merge")
	end)
	ThiefService.Bonked:Connect(function(hero: Player)
		QuestService.Progress(hero, "BonkThief")
	end)
	NetService.OnAction("ClaimQuest", claim)
	DataService.ProfileLoaded:Connect(function(player: Player)
		push(player)
	end)
end

function QuestService.Start()
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				QuestService.Progress(player, "Minute")
			end
		end
	end)
end

return QuestService
