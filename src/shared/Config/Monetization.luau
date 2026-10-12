--!strict
-- Game passes and developer products.
--
-- SETUP: create each item in the Creator Hub (Monetization > Passes /
-- Developer Products) with the suggested price, then paste its ID below.
-- Anything left at 0 still shows in the shop as "Coming soon" and is never
-- offered for purchase, so the game runs fine before setup is finished.
--
-- No Robux purchase grants a random item, so the game stays clear of
-- Roblox's paid-random-item rules.

export type Pass = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	SuggestedPrice: number,
	Icon: string, -- emoji shown in the shop
}

export type Product = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	SuggestedPrice: number,
	Icon: string,
	Kind: string, -- "Cash" | "Luck" | "InstantLock" | "BeltSlime"
	CashMinutes: number?, -- Cash: minutes of the buyer's current income
	CashMinimum: number?, -- Cash: floor so new players still get value
	Rarity: string?, -- BeltSlime: rarity tier this product buys
	Shop: boolean, -- listed in the shop UI
}

local Passes: { Pass } = {
	{ Key = "DoubleCash", Id = 0, Name = "2x Cash", Description = "Double all cash your slimes make. Forever.", SuggestedPrice = 399, Icon = "💰" },
	{ Key = "VIP", Id = 0, Name = "VIP", Description = "1.5x cash, 4h offline earnings, VIP tag.", SuggestedPrice = 249, Icon = "👑" },
	{ Key = "AutoCollect", Id = 0, Name = "Auto Collect", Description = "Cash goes straight to your wallet.", SuggestedPrice = 149, Icon = "🧲" },
	{ Key = "ExtraSlots", Id = 0, Name = "+6 Slots", Description = "Six more pedestals in your base.", SuggestedPrice = 199, Icon = "📦" },
	{ Key = "LongLock", Id = 0, Name = "Long Lock", Description = "Your base lock lasts twice as long.", SuggestedPrice = 99, Icon = "🔒" },
	{ Key = "SpeedBoots", Id = 0, Name = "Speed Boots", Description = "Run faster and carry slimes faster.", SuggestedPrice = 99, Icon = "👟" },
	{ Key = "GoldenBat", Id = 0, Name = "Golden Bat", Description = "Bonk harder and from further away.", SuggestedPrice = 79, Icon = "🏏" },
}

local Products: { Product } = {
	{ Key = "CashSmall", Id = 0, Name = "Cash Bag", Description = "10 minutes of your income.", SuggestedPrice = 29, Icon = "💵", Kind = "Cash", CashMinutes = 10, CashMinimum = 1000, Shop = true },
	{ Key = "CashMedium", Id = 0, Name = "Cash Crate", Description = "1 hour of your income.", SuggestedPrice = 99, Icon = "💰", Kind = "Cash", CashMinutes = 60, CashMinimum = 10000, Shop = true },
	{ Key = "CashLarge", Id = 0, Name = "Cash Vault", Description = "8 hours of your income.", SuggestedPrice = 399, Icon = "🏦", Kind = "Cash", CashMinutes = 480, CashMinimum = 100000, Shop = true },
	{ Key = "ServerLuck", Id = 0, Name = "Server Luck x2", Description = "2x rare spawns for EVERYONE for 15 min.", SuggestedPrice = 99, Icon = "🍀", Kind = "Luck", Shop = true },
	{ Key = "InstantLock", Id = 0, Name = "Instant Lock", Description = "Lock your base now, skipping cooldown.", SuggestedPrice = 19, Icon = "⚡", Kind = "InstantLock", Shop = false },
	{ Key = "BeltEpic", Id = 0, Name = "Buy Epic Slime", Description = "Buy this Epic slime from the belt.", SuggestedPrice = 49, Icon = "🟣", Kind = "BeltSlime", Rarity = "Epic", Shop = false },
	{ Key = "BeltLegendary", Id = 0, Name = "Buy Legendary Slime", Description = "Buy this Legendary slime from the belt.", SuggestedPrice = 99, Icon = "🟡", Kind = "BeltSlime", Rarity = "Legendary", Shop = false },
	{ Key = "BeltMythic", Id = 0, Name = "Buy Mythic Slime", Description = "Buy this Mythic slime from the belt.", SuggestedPrice = 199, Icon = "🔴", Kind = "BeltSlime", Rarity = "Mythic", Shop = false },
	{ Key = "BeltSecret", Id = 0, Name = "Buy Secret Slime", Description = "Buy this Secret slime from the belt.", SuggestedPrice = 399, Icon = "💎", Kind = "BeltSlime", Rarity = "Secret", Shop = false },
}

local passByKey: { [string]: Pass } = {}
local passById: { [number]: Pass } = {}
for _, pass in Passes do
	passByKey[pass.Key] = pass
	if pass.Id ~= 0 then
		passById[pass.Id] = pass
	end
end

local productByKey: { [string]: Product } = {}
local productById: { [number]: Product } = {}
local beltProductByRarity: { [string]: Product } = {}
for _, product in Products do
	productByKey[product.Key] = product
	if product.Id ~= 0 then
		productById[product.Id] = product
	end
	if product.Kind == "BeltSlime" and product.Rarity then
		beltProductByRarity[product.Rarity] = product
	end
end

return {
	-- Roblox group that players join for the group bonus. 0 disables it.
	GroupId = 0,

	ServerLuckSeconds = 15 * 60,
	ServerLuckMultiplier = 2,

	Passes = Passes,
	Products = Products,
	PassByKey = passByKey,
	PassById = passById,
	ProductByKey = productByKey,
	ProductById = productById,
	BeltProductByRarity = beltProductByRarity,
}
