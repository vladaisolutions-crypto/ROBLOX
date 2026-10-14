--!strict
-- Developer product receipts. A receipt is only acknowledged after the
-- reward is granted AND saved, so players never pay without getting it and
-- retries can never grant twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Monetization = require(Shared.Config.Monetization)
local SlimeInfo = require(Shared.SlimeInfo)
local Format = require(Shared.Util.Format)

local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local ThiefService = require(script.Parent.ThiefService)

local MonetizationService = {}

-- Returns true once the product has been granted.
local function grant(player: Player, product: Monetization.Product): boolean
	if product.Kind == "Cash" then
		local amount = EconomyService.IncomeMinutes(player, product.CashMinutes or 10, product.CashMinimum or 0)
		EconomyService.AddCash(player, amount, "Robux", product.Key)
		NetService.Notify(player, "💰 +" .. Format.Cash(amount) .. "! Thanks for the support!", "Money")
		return true
	elseif product.Kind == "Luck" then
		EventService.AddServerLuck(Monetization.ServerLuckSeconds, player.DisplayName)
		return true
	elseif product.Kind == "InstantLock" then
		PlotService.Lock(player, true)
		return true
	elseif product.Kind == "RaidShield" then
		ThiefService.Shield(player, (product.ShieldMinutes or 15) * 60)
		NetService.Notify(player, "🛡️ Raid Shield up! Thieves will skip your base.", "Good")
		return true
	elseif product.Kind == "BeltSlime" and product.Rarity then
		return ConveyorService.GrantBeltProduct(player, product.Rarity) ~= nil
	elseif product.Kind == "Bundle" then
		local data = DataService.Get(player)
		if not data then
			return false
		end
		if product.OneTime and data.StarterBought then
			-- Bought again (e.g. from a stale shop): never leave it unpaid,
			-- give its cash value instead of a second pack.
			local amount = product.CashMinimum or 25000
			EconomyService.AddCash(player, amount, "Robux", product.Key)
			NetService.Notify(
				player,
				"You already have the " .. product.Name .. ", so here's " .. Format.Cash(amount) .. " instead!",
				"Money"
			)
			return true
		end
		if product.CashMinimum then
			local amount = EconomyService.IncomeMinutes(player, product.CashMinutes or 0, product.CashMinimum or 0)
			EconomyService.AddCash(player, amount, "Robux", product.Key)
		end
		if product.SlimeId then
			if not EconomyService.AddSlime(player, product.SlimeId, "", "Robux") then
				-- Base full: never leave the purchase short, pay its value in cash.
				local value = SlimeInfo.Price(product.SlimeId, "")
				EconomyService.AddCash(player, value, "Robux", product.Key)
				NetService.Notify(
					player,
					"Your base was full, so you got " .. Format.Cash(value) .. " instead of the slime.",
					"Money"
				)
			end
		end
		if product.DoubleMinutes then
			EconomyService.GiveTemporaryDouble(player, product.DoubleMinutes * 60)
		end
		if product.OneTime then
			data.StarterBought = true
		end
		NetService.Notify(player, product.Icon .. " " .. product.Name .. " unlocked! Thanks for the support!", "Money")
		EconomyService.PushState(player)
		return true
	end
	warn("[Monetization] Unknown product kind", product.Kind)
	return false
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Monetization.ProductById[receipt.ProductId]
	if not product then
		warn("[Monetization] Receipt for unknown product", receipt.ProductId, "- add its ID to Config/Monetization")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if DataService.ClaimReceipt(data, purchaseId) then
		-- Already granted. Only acknowledge once that grant is safely saved
		-- (a retry after a failed save lands here).
		return if DataService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grant, player, product)
	if not ok or not granted then
		warn("[Monetization] Grant failed", product.Key, granted)
		DataService.UnclaimReceipt(data, purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Stats.RobuxSpent += tonumber(receipt.CurrencySpent) or 0
	TelemetryService.Custom(player, "Robux_" .. product.Key, tonumber(receipt.CurrencySpent) or 0)
	EconomyService.PushState(player)

	if not DataService.SaveNow(player) then
		-- The receipt id is in memory, so a retry after the next successful
		-- autosave is acknowledged without granting twice.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
