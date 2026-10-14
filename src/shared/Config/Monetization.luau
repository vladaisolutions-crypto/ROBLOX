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
	Kind: string, -- "Cash" | "Luck" | "InstantLock" | "BeltSlime" | "Bundle" | "RaidShield"
	CashMinutes: number?, -- Cash: minutes of the buyer's current income
	CashMinimum: number?, -- Cash: floor so new players still get value
	Rarity: string?, -- BeltSlime: rarity tier this product buys
	Shop: boolean, -- listed in the shop UI
	-- Bundle: a specific slime, cash and/or a 2x cash boost, all stated up front.
	SlimeId: string?,
	DoubleMinutes: number?,
	OneTime: boolean?, -- offered once per account (the Starter Pack)
	ShieldMinutes: number?, -- RaidShield: thieves skip your base this long
	Event: string?, -- only offered while this event runs (it really ends)
}

local Passes: { Pass } = {
	{
		Key = "DoubleCash",
		Id = 2032730441,
		Name = "2x Cash",
		Description = "Double all cash your slimes make. Forever.",
		SuggestedPrice = 399,
		Icon = "💰",
	},
	{
		Key = "VIP",
		Id = 2034434429,
		Name = "VIP",
		Description = "1.5x cash, 4h offline earnings, VIP tag.",
		SuggestedPrice = 249,
		Icon = "👑",
	},
	{
		Key = "AutoCollect",
		Id = 2034332421,
		Name = "Auto Collect",
		Description = "Cash goes straight to your wallet.",
		SuggestedPrice = 149,
		Icon = "🧲",
	},
	{
		Key = "ExtraSlots",
		Id = 2035610253,
		Name = "+6 Slots",
		Description = "Six more pedestals in your base.",
		SuggestedPrice = 199,
		Icon = "📦",
	},
	{
		Key = "LongLock",
		Id = 2032658411,
		Name = "Long Lock",
		Description = "Your base lock lasts twice as long.",
		SuggestedPrice = 99,
		Icon = "🔒",
	},
	{
		Key = "SpeedBoots",
		Id = 2034050433,
		Name = "Speed Boots",
		Description = "Run faster and carry slimes faster.",
		SuggestedPrice = 99,
		Icon = "👟",
	},
	{
		Key = "GoldenBat",
		Id = 2033714426,
		Name = "Golden Bat",
		Description = "Bonk harder and from further away.",
		SuggestedPrice = 79,
		Icon = "🏏",
	},
	{
		Key = "GuardSlime",
		Id = 2036348370,
		Name = "Guard Slime",
		Description = "A guard slime at your gate bonks thieves for you.",
		SuggestedPrice = 199,
		Icon = "🛡️",
	},
}

local Products: { Product } = {
	{
		Key = "StarterPack",
		Id = 3718401332,
		Name = "Starter Pack",
		Description = "One time only: 45 min of income (at least 30K), an Epic Crystal slime and 30 min of 2x cash.",
		SuggestedPrice = 49,
		Icon = "🎁",
		Kind = "Bundle",
		CashMinutes = 45,
		CashMinimum = 30000,
		SlimeId = "crystal",
		DoubleMinutes = 30,
		OneTime = true,
		Shop = true,
	},
	{
		Key = "EpicPack",
		Id = 3718549159,
		Name = "Epic Pack",
		Description = "An Epic Lava slime, 40 min of income (at least 25K) and 30 min of 2x cash.",
		SuggestedPrice = 129,
		Icon = "🔥",
		Kind = "Bundle",
		CashMinutes = 40,
		CashMinimum = 25000,
		SlimeId = "lava",
		DoubleMinutes = 30,
		Shop = true,
	},
	{
		Key = "RoyalPack",
		Id = 3718549176,
		Name = "Royal Pack",
		Description = "EXCLUSIVE: the golden Royal slime (Robux only), 2 h of income (at least 300K) and 2 h of 2x cash.",
		SuggestedPrice = 799,
		Icon = "👑",
		Kind = "Bundle",
		CashMinutes = 120,
		CashMinimum = 300000,
		SlimeId = "royal",
		DoubleMinutes = 120,
		Shop = true,
	},
	{
		Key = "HalloweenBundle",
		Id = 3718401335,
		Name = "Halloween Bundle",
		Description = "Until Nov 4: a Legendary Witch slime and 1 hour of 2x cash.",
		SuggestedPrice = 199,
		Icon = "🎃",
		Kind = "Bundle",
		SlimeId = "witch",
		DoubleMinutes = 60,
		Event = "Halloween",
		Shop = true,
	},
	{
		Key = "CashSmall",
		Id = 3718399797,
		Name = "Cash Bag",
		Description = "25 minutes of your income.",
		SuggestedPrice = 29,
		Icon = "💵",
		Kind = "Cash",
		CashMinutes = 25,
		CashMinimum = 5000,
		Shop = true,
	},
	{
		Key = "CashMedium",
		Id = 3718399810,
		Name = "Cash Crate",
		Description = "100 minutes of your income.",
		SuggestedPrice = 99,
		Icon = "💰",
		Kind = "Cash",
		CashMinutes = 100,
		CashMinimum = 40000,
		Shop = true,
	},
	{
		Key = "CashLarge",
		Id = 3718399820,
		Name = "Cash Vault",
		Description = "8 hours of your income.",
		SuggestedPrice = 399,
		Icon = "🏦",
		Kind = "Cash",
		CashMinutes = 480,
		CashMinimum = 200000,
		Shop = true,
	},
	{
		Key = "CashMega",
		Id = 3718549183,
		Name = "Cash Mountain",
		Description = "24 hours of your income.",
		SuggestedPrice = 999,
		Icon = "🏔️",
		Kind = "Cash",
		CashMinutes = 1440,
		CashMinimum = 600000,
		Shop = true,
	},
	{
		Key = "RaidShield",
		Id = 3718549197,
		Name = "Raid Shield",
		Description = "Thieves skip your base for 15 minutes.",
		SuggestedPrice = 49,
		Icon = "🛡️",
		Kind = "RaidShield",
		ShieldMinutes = 15,
		Shop = true,
	},
	{
		Key = "ServerLuck",
		Id = 3718399834,
		Name = "Server Luck x2",
		Description = "2x rare spawns for EVERYONE for 15 min.",
		SuggestedPrice = 99,
		Icon = "🍀",
		Kind = "Luck",
		Shop = true,
	},
	{
		Key = "InstantLock",
		Id = 3718399745,
		Name = "Instant Lock",
		Description = "Lock your base now, skipping cooldown.",
		SuggestedPrice = 19,
		Icon = "⚡",
		Kind = "InstantLock",
		Shop = false,
	},
	{
		Key = "BeltEpic",
		Id = 3718399842,
		Name = "Buy Epic Slime",
		Description = "Buy this Epic slime from the belt.",
		SuggestedPrice = 49,
		Icon = "🟣",
		Kind = "BeltSlime",
		Rarity = "Epic",
		Shop = false,
	},
	{
		Key = "BeltLegendary",
		Id = 3718399852,
		Name = "Buy Legendary Slime",
		Description = "Buy this Legendary slime from the belt.",
		SuggestedPrice = 99,
		Icon = "🟡",
		Kind = "BeltSlime",
		Rarity = "Legendary",
		Shop = false,
	},
	{
		Key = "BeltMythic",
		Id = 3718399861,
		Name = "Buy Mythic Slime",
		Description = "Buy this Mythic slime from the belt.",
		SuggestedPrice = 199,
		Icon = "🔴",
		Kind = "BeltSlime",
		Rarity = "Mythic",
		Shop = false,
	},
	{
		Key = "BeltSecret",
		Id = 3718399868,
		Name = "Buy Secret Slime",
		Description = "Buy this Secret slime from the belt.",
		SuggestedPrice = 399,
		Icon = "💎",
		Kind = "BeltSlime",
		Rarity = "Secret",
		Shop = false,
	},
	{
		Key = "BeltDivine",
		Id = 3718551945,
		Name = "Buy Divine Slime",
		Description = "Buy this Divine slime from the belt.",
		SuggestedPrice = 599,
		Icon = "🌟",
		Kind = "BeltSlime",
		Rarity = "Divine",
		Shop = false,
	},
	{
		Key = "BeltEternal",
		Id = 3718551950,
		Name = "Buy Eternal Slime",
		Description = "Buy this Eternal slime from the belt.",
		SuggestedPrice = 999,
		Icon = "♾️",
		Kind = "BeltSlime",
		Rarity = "Eternal",
		Shop = false,
	},
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
