--!strict
-- Reasons to come back and stay: daily login streak and playtime gifts.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Codes = require(Shared.Config.Codes)
local Events = require(Shared.Config.Events)
local Format = require(Shared.Util.Format)

local DataTemplate = require(script.Parent.Parent.DataTemplate)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local TelemetryService = require(script.Parent.TelemetryService)
local PassService = require(script.Parent.PassService)

-- One-time secret codes live in a git-ignored server module (may be absent).
local secretModule = script.Parent.Parent:FindFirstChild("SecretCodes")
local SecretCodes: { [string]: { Kind: string } } = if secretModule and secretModule:IsA("ModuleScript")
	then (require :: any)(secretModule)
	else {}

type PlayerData = DataTemplate.PlayerData

-- Playtime gift rewards, matched to Events.GiftMinutes by position.
type Gift = { Kind: "Cash" | "Double" | "Slime", Minutes: number?, SlimeId: string? }
local GIFTS: { Gift } = Events.Gifts :: any
local DAY7_SLIME = "crystal"

local RewardService = {}

type Session = { Start: number, GiftsClaimed: number }
local sessions: { [Player]: Session } = {}

local function today(): number
	return os.time() // 86400
end

-- The streak day the player would claim today (1..7).
local function nextStreak(data: PlayerData): number
	if data.Daily.LastDay == today() - 1 then
		return data.Daily.Streak % 7 + 1
	end
	return 1
end

local function pushState(player: Player)
	local data = DataService.Get(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	local canClaim = data.Daily.LastDay < today()
	NetService.SendState(player, {
		DailyCanClaim = canClaim,
		DailyStreak = if canClaim then nextStreak(data) else data.Daily.Streak,
		DailyNextAt = (today() + 1) * 86400,
		SessionStart = session.Start,
		GiftsClaimed = session.GiftsClaimed,
	})
end

local function claimDaily(player: Player)
	local data = DataService.Get(player)
	if not data or data.Daily.LastDay >= today() then
		return
	end
	local streak = nextStreak(data)
	data.Daily.LastDay = today()
	data.Daily.Streak = streak
	local amount =
		EconomyService.FreeRewardCash(player, Events.DailyIncomeMinutes[streak], Events.DailyMinimumCash[streak])
	EconomyService.AddCash(player, amount, "Daily", "Day" .. streak)
	NetService.Notify(player, "📅 Day " .. streak .. " reward: " .. Format.Cash(amount) .. "!", "Money")
	if streak == 7 then
		if EconomyService.AddSlime(player, DAY7_SLIME, "", "Daily") then
			NetService.Notify(player, "🎁 Day 7 bonus: a free Epic Crystal slime!", "Good")
		else
			EconomyService.AddCash(player, amount, "Daily", "Day7Fallback")
		end
	end
	TelemetryService.Custom(player, "DailyClaim", streak)
	pushState(player)
	EconomyService.PushState(player)
end

local function claimGift(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local index = session.GiftsClaimed + 1
	local gift = GIFTS[index]
	local minutes = Events.GiftMinutes[index]
	if not gift or not minutes or workspace:GetServerTimeNow() - session.Start < minutes * 60 then
		return
	end
	session.GiftsClaimed = index
	if gift.Kind == "Cash" then
		local amount = EconomyService.FreeRewardCash(player, gift.Minutes or 2, (gift :: any).Minimum or 100)
		EconomyService.AddCash(player, amount, "Gift", "Gift" .. index)
		NetService.Notify(player, "🎁 Gift: " .. Format.Cash(amount) .. "!", "Money")
	elseif gift.Kind == "Double" then
		EconomyService.GiveTemporaryDouble(player, (gift.Minutes or 5) * 60)
		NetService.Notify(player, "🎁 Gift: 2x cash for " .. (gift.Minutes or 5) .. " minutes!", "Good")
	elseif gift.Kind == "Slime" and gift.SlimeId then
		if not EconomyService.AddSlime(player, gift.SlimeId, "", "Gift") then
			local amount = EconomyService.FreeRewardCash(player, 8, 2000)
			EconomyService.AddCash(player, amount, "Gift", "GiftFallback")
			NetService.Notify(player, "🎁 Your base was full, so you got " .. Format.Cash(amount) .. "!", "Money")
		else
			NetService.Notify(player, "🎁 Gift: a free slime!", "Good")
		end
	end
	TelemetryService.Custom(player, "GiftClaim", index)
	pushState(player)
end

local function redeem(player: Player, input: unknown)
	local data = DataService.Get(player)
	if not data or type(input) ~= "string" or #input > 40 then
		return
	end
	local key = string.upper((string.gsub(input, "%s", "")))
	local secret = SecretCodes[key]
	if secret then
		-- Claim it for this account across every server, once.
		local ok, owner = pcall(function()
			return game:GetService("DataStoreService"):GetDataStore("SecretCodeClaims"):UpdateAsync(key, function(old)
				return if old == nil then player.UserId else nil
			end)
		end)
		if not ok then
			NetService.Notify(player, "Couldn't check that code right now, try again in a minute.", "Bad")
			return
		end
		if owner ~= player.UserId then
			NetService.Notify(player, "That code has already been used!", "Bad")
			return
		end
		if secret.Kind == "AllPasses" then
			data.CompPasses = true
			PassService.GrantAll(player)
			if not EconomyService.AddSlime(player, "royal", "", "Code") then
				EconomyService.AddCash(player, 20e6, "Code", "SecretRoyal")
			end
			NetService.Notify(player, "👑 VIP code! Every game pass is yours, plus a Royal slime!", "Money")
		end
		data.Codes[key] = true
		DataService.SaveNow(player)
		EconomyService.PushState(player)
		return
	end
	local code = Codes.ByCode[key]
	if not code then
		NetService.Notify(player, "That code doesn't exist!", "Bad")
		return
	end
	if code.Expires and os.time() >= code.Expires then
		NetService.Notify(player, "That code has expired!", "Bad")
		return
	end
	if data.Codes[key] then
		NetService.Notify(player, "You already used that code!", "Bad")
		return
	end
	if code.Kind == "Slime" and code.SlimeId then
		if not EconomyService.AddSlime(player, code.SlimeId, "", "Code") then
			NetService.Notify(player, "Your base is full! Sell a slime, then try again.", "Bad")
			return
		end
		NetService.Notify(player, "🎟️ Code redeemed: a free slime!", "Good")
	elseif code.Kind == "Double" then
		EconomyService.GiveTemporaryDouble(player, (code.Minutes or 10) * 60)
		NetService.Notify(player, "🎟️ Code redeemed: 2x cash for " .. (code.Minutes or 10) .. " minutes!", "Good")
	else
		local amount = EconomyService.FreeRewardCash(player, code.Minutes or 3, code.Minimum or 300)
		EconomyService.AddCash(player, amount, "Code", key)
		NetService.Notify(player, "🎟️ Code redeemed: " .. Format.Cash(amount) .. "!", "Money")
	end
	data.Codes[key] = true
	TelemetryService.Custom(player, "Code_" .. key)
	EconomyService.PushState(player)
end

function RewardService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player, _data: PlayerData)
		sessions[player] = { Start = workspace:GetServerTimeNow(), GiftsClaimed = 0 }
		pushState(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	NetService.OnAction("ClaimDaily", claimDaily)
	NetService.OnAction("ClaimGift", claimGift)
	NetService.OnAction("Redeem", redeem)
end

function RewardService.Start()
	-- Re-send daily state hourly so a session spanning midnight sees the new day.
	task.spawn(function()
		while true do
			task.wait(3600)
			for player in sessions do
				pushState(player)
			end
		end
	end)
end

return RewardService
