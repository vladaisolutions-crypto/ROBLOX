--!strict
-- Cash, slots, income, multipliers, selling, rebirths and the Index.
-- Every change to a player's money or slimes goes through here.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Monetization = require(Shared.Config.Monetization)
local Slimes = require(Shared.Config.Slimes)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local SlimeInfo = require(Shared.SlimeInfo)

local DataTemplate = require(script.Parent.Parent.DataTemplate)
local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PassService = require(script.Parent.PassService)
local TelemetryService = require(script.Parent.TelemetryService)

type PlayerData = DataTemplate.PlayerData
type SlotData = DataTemplate.SlotData

local EconomyService = {}
EconomyService.SlotsChanged = Signal.new() -- (player)
EconomyService.SlimeAdded = Signal.new() -- (player, slotData, source)
EconomyService.Collected = Signal.new() -- (player, amount)
EconomyService.Rebirthed = Signal.new() -- (player, rebirths)

type Runtime = {
	FriendsInServer: number,
	InGroup: boolean,
	DoubleUntil: number, -- temporary 2x cash from gifts/daily rewards
	Leaderstats: Folder?,
}

local runtime: { [Player]: Runtime } = {}
local friendCache: { [Player]: { [number]: boolean } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function indexCount(data: PlayerData): number
	local count = 0
	for _ in data.Index do
		count += 1
	end
	return count
end

function EconomyService.Multiplier(player: Player): number
	local data = DataService.Get(player)
	local state = runtime[player]
	if not data or not state then
		return 1
	end
	local multiplier = 1 + data.Rebirths * Economy.RebirthMultiplier
	multiplier *= 1 + indexCount(data) * Economy.IndexBonusPerSlime
	multiplier *= 1 + math.min(state.FriendsInServer * Economy.FriendBoostPerFriend, Economy.FriendBoostMax)
	if state.InGroup then
		multiplier *= 1 + Economy.GroupBonus
	end
	if PassService.Has(player, "VIP") then
		multiplier *= Economy.VipMultiplier
	end
	if PassService.Has(player, "DoubleCash") then
		multiplier *= Economy.DoubleCashMultiplier
	end
	if now() < state.DoubleUntil then
		multiplier *= 2
	end
	return multiplier
end

-- Raw income of all slimes in the base, before multipliers.
function EconomyService.BaseIncome(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local total = 0
	for _, slot in data.Slots do
		total += SlimeInfo.Income(slot.Id, slot.Mutation)
	end
	return total
end

function EconomyService.IncomePerSecond(player: Player): number
	return EconomyService.BaseIncome(player) * EconomyService.Multiplier(player)
end

function EconomyService.MaxSlots(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return Economy.BaseSlots
	end
	return Economy.MaxSlots(data.Rebirths, PassService.Has(player, "ExtraSlots"))
end

function EconomyService.FreeSlot(player: Player): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local used: { [number]: boolean } = {}
	for _, slot in data.Slots do
		used[slot.Slot] = true
	end
	for slot = 1, EconomyService.MaxSlots(player) do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

function EconomyService.GetSlot(player: Player, slot: number): SlotData?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	for _, slotData in data.Slots do
		if slotData.Slot == slot then
			return slotData
		end
	end
	return nil
end

function EconomyService.PushState(player: Player)
	local data = DataService.Get(player)
	local state = runtime[player]
	if not data or not state then
		return
	end
	NetService.SendState(player, {
		Cash = data.Cash,
		Income = EconomyService.IncomePerSecond(player),
		Multiplier = EconomyService.Multiplier(player),
		Rebirths = data.Rebirths,
		RebirthCost = Economy.RebirthCost(data.Rebirths),
		MaxSlots = EconomyService.MaxSlots(player),
		UsedSlots = #data.Slots,
		Passes = PassService.Owned(player),
		IndexCount = indexCount(data),
		FriendsInServer = state.FriendsInServer,
		InGroup = state.InGroup,
		DoubleUntil = state.DoubleUntil,
	})
	local leaderstats = state.Leaderstats
	if leaderstats then
		local cash = leaderstats:FindFirstChild("Cash")
		if cash and cash:IsA("StringValue") then
			cash.Value = Format.Cash(data.Cash)
		end
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if rebirths and rebirths:IsA("IntValue") then
			rebirths.Value = data.Rebirths
		end
	end
end

function EconomyService.AddCash(player: Player, amount: number, transaction: string, sku: string?)
	local data = DataService.Get(player)
	if not data or amount <= 0 or amount ~= amount then
		return
	end
	data.Cash += amount
	data.TotalEarned += amount
	TelemetryService.Source(player, amount, data.Cash, transaction, sku)
end

function EconomyService.SpendCash(player: Player, amount: number, transaction: string, sku: string?): boolean
	local data = DataService.Get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	TelemetryService.Sink(player, amount, data.Cash, transaction, sku)
	return true
end

function EconomyService.GiveTemporaryDouble(player: Player, seconds: number)
	local state = runtime[player]
	if state then
		state.DoubleUntil = math.max(state.DoubleUntil, now()) + seconds
		EconomyService.PushState(player)
	end
end

local function discover(player: Player, data: PlayerData, slimeId: string, mutation: string)
	local key = if mutation == "" then "Normal" else mutation
	local entry = data.Index[slimeId]
	local isNewSlime = entry == nil
	if not entry then
		entry = {}
		data.Index[slimeId] = entry
	end
	if not entry[key] then
		entry[key] = true
		NetService.SendIndex(player, data.Index)
		if isNewSlime then
			local def = Slimes.ById[slimeId]
			NetService.Notify(player, "📖 New slime discovered: " .. (if def then def.Name else slimeId) .. "! +2% cash forever", "Good")
		end
	end
end

-- Puts a slime into the player's first free slot (or `preferredSlot` if
-- free). Returns the slot data, or nil if the base is full.
function EconomyService.AddSlime(player: Player, slimeId: string, mutation: string, source: string, preferredSlot: number?): SlotData?
	local data = DataService.Get(player)
	if not data or not Slimes.ById[slimeId] then
		return nil
	end
	local slot = EconomyService.FreeSlot(player)
	if preferredSlot and preferredSlot <= EconomyService.MaxSlots(player) and not EconomyService.GetSlot(player, preferredSlot) then
		slot = preferredSlot
	end
	if not slot then
		return nil
	end
	local slotData: SlotData = { Slot = slot, Id = slimeId, Mutation = mutation, Stored = 0 }
	table.insert(data.Slots, slotData)
	discover(player, data, slimeId, mutation)
	EconomyService.SlotsChanged:Fire(player)
	EconomyService.SlimeAdded:Fire(player, slotData, source)
	EconomyService.PushState(player)
	return slotData
end

-- Removes and returns the slime in `slot` (stored cash goes with it).
function EconomyService.RemoveSlime(player: Player, slot: number): SlotData?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	for i, slotData in data.Slots do
		if slotData.Slot == slot then
			table.remove(data.Slots, i)
			EconomyService.SlotsChanged:Fire(player)
			EconomyService.PushState(player)
			return slotData
		end
	end
	return nil
end

function EconomyService.Collect(player: Player, slot: number): number
	local slotData = EconomyService.GetSlot(player, slot)
	if not slotData or slotData.Stored <= 0 then
		return 0
	end
	local amount = slotData.Stored
	slotData.Stored = 0
	EconomyService.AddCash(player, amount, "Income")
	EconomyService.Collected:Fire(player, amount)
	return amount
end

function EconomyService.Sell(player: Player, slot: number): boolean
	local slotData = EconomyService.GetSlot(player, slot)
	if not slotData then
		return false
	end
	EconomyService.Collect(player, slot)
	EconomyService.RemoveSlime(player, slot)
	local refund = SlimeInfo.Price(slotData.Id, slotData.Mutation) * Economy.SellRefund
	EconomyService.AddCash(player, refund, "Sell", slotData.Id)
	NetService.Notify(player, "Sold " .. SlimeInfo.DisplayName(slotData.Id, slotData.Mutation) .. " for " .. Format.Cash(refund), "Money")
	EconomyService.PushState(player)
	return true
end

function EconomyService.Rebirth(player: Player): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local cost = Economy.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		NetService.Notify(player, "You need " .. Format.Cash(cost) .. " to rebirth!", "Bad")
		return false
	end
	EconomyService.SpendCash(player, data.Cash, "Rebirth")
	data.Cash = Economy.StartingCash
	data.Rebirths += 1
	if data.Rebirths == 1 then
		TelemetryService.Onboard(player, TelemetryService.Onboarding.FirstRebirth)
	end
	NetService.Announce("✨ " .. player.DisplayName .. " reached Rebirth " .. data.Rebirths .. "! ✨", Color3.fromRGB(255, 220, 120))
	EconomyService.SlotsChanged:Fire(player)
	EconomyService.Rebirthed:Fire(player, data.Rebirths)
	EconomyService.PushState(player)
	return true
end

-- Cash from `minutes` of the player's current income, with a floor.
function EconomyService.IncomeMinutes(player: Player, minutes: number, minimum: number): number
	return math.max(minimum, math.floor(EconomyService.IncomePerSecond(player) * minutes * 60))
end

local function refreshFriends()
	local players = Players:GetPlayers()
	for _, player in players do
		local state = runtime[player]
		if state then
			local cache = friendCache[player]
			if not cache then
				cache = {}
				friendCache[player] = cache
			end
			local count = 0
			for _, other in players do
				if other ~= player then
					local isFriend = cache[other.UserId]
					if isFriend == nil then
						local ok, result = pcall(function()
							return player:IsFriendsWith(other.UserId)
						end)
						isFriend = ok and result == true
						cache[other.UserId] = isFriend
					end
					if isFriend then
						count += 1
					end
				end
			end
			if count ~= state.FriendsInServer then
				state.FriendsInServer = count
				if count > 0 then
					NetService.Notify(player, "👥 Friend boost: +" .. math.floor(math.min(count * Economy.FriendBoostPerFriend, Economy.FriendBoostMax) * 100) .. "% cash!", "Good")
				end
			end
		end
	end
end

-- `lastOnline` is captured when the profile loads, because any save in the
-- meantime (autosave, receipt) overwrites data.LastOnline.
local function payOfflineEarnings(player: Player, lastOnline: number, loadedAt: number)
	if lastOnline <= 0 then
		return
	end
	local cap = if PassService.Has(player, "VIP") then Economy.OfflineCapSecondsVip else Economy.OfflineCapSeconds
	local away = math.min(loadedAt - lastOnline, cap)
	if away < 60 then
		return
	end
	local amount = math.floor(EconomyService.IncomePerSecond(player) * away * Economy.OfflineEfficiency)
	if amount > 0 then
		EconomyService.AddCash(player, amount, "Offline")
		NetService.Notify(player, "💤 Your slimes made " .. Format.Cash(amount) .. " while you were away!", "Money")
	end
end

local function onProfileLoaded(player: Player, data: PlayerData)
	local lastOnline, loadedAt = data.LastOnline, os.time()
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	runtime[player] = { FriendsInServer = 0, InGroup = false, DoubleUntil = 0, Leaderstats = leaderstats }
	if Monetization.GroupId ~= 0 then
		local ok, inGroup = pcall(function()
			return player:IsInGroupAsync(Monetization.GroupId)
		end)
		runtime[player].InGroup = ok and inGroup == true
	end
	refreshFriends()
	NetService.SendIndex(player, data.Index)
	EconomyService.PushState(player)

	-- Give pass checks a moment so VIP's longer offline cap applies.
	task.delay(3, function()
		if player.Parent and DataService.Get(player) == data then
			payOfflineEarnings(player, lastOnline, loadedAt)
			EconomyService.PushState(player)
		end
	end)
end

local function tick()
	for player in runtime do
		local data = DataService.Get(player)
		if data then
			local multiplier = EconomyService.Multiplier(player)
			local auto = PassService.Has(player, "AutoCollect")
			for _, slot in data.Slots do
				local amount = SlimeInfo.Income(slot.Id, slot.Mutation) * multiplier
				if auto then
					data.Cash += amount
					data.TotalEarned += amount
				else
					slot.Stored += amount
				end
			end
			data.Stats.PlaySeconds += 1
			EconomyService.PushState(player)
		end
	end
end

function EconomyService.Init()
	DataService.ProfileLoaded:Connect(onProfileLoaded)
	DataService.ProfileReleasing:Connect(function(player: Player, data: PlayerData)
		data.LastOnline = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player)
		runtime[player] = nil
		friendCache[player] = nil
		task.defer(refreshFriends)
	end)
	PassService.Changed:Connect(function(player: Player)
		EconomyService.SlotsChanged:Fire(player)
		EconomyService.PushState(player)
	end)
	NetService.OnAction("Rebirth", function(player: Player)
		EconomyService.Rebirth(player)
	end)
end

function EconomyService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return EconomyService
