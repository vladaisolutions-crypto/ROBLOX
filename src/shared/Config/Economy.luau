--!strict
-- All economy tuning lives here so balance changes never touch game logic.

local Economy = {
	StartingCash = 100,

	-- Base slots
	BaseSlots = 10,
	SlotsPerRebirth = 2,
	MaxRebirthSlots = 10,
	ExtraSlotsPass = 6, -- "+6 Slots" game pass
	-- Expand your base with cash (the pad by the entrance): each extra slot
	-- costs more than the last. Kept through rebirths.
	BuySlotsMax = 12,
	BuySlotBasePrice = 5000,
	BuySlotGrowth = 2.2,

	-- Selling a slime refunds this fraction of its price.
	SellRefund = 0.5,

	-- Rebirth: costs all cash (minimum shown below), keeps slimes.
	RebirthBaseCost = 2.5e6,
	RebirthCostGrowth = 8,
	RebirthMultiplier = 0.5, -- +50% income per rebirth

	-- Permanent income bonus per unique slime discovered in the Index.
	IndexBonusPerSlime = 0.02,

	-- Social boosts
	FriendBoostPerFriend = 0.1,
	FriendBoostMax = 0.5,
	GroupBonus = 0.1,

	-- Pass multipliers
	VipMultiplier = 1.5,
	DoubleCashMultiplier = 2,

	-- Offline earnings, paid on rejoin.
	OfflineCapSeconds = 60 * 60,
	OfflineCapSecondsVip = 4 * 60 * 60,
	OfflineEfficiency = 0.25,

	-- Base lock
	LockSeconds = 60,
	LockSecondsLongPass = 120,
	LockCooldownSeconds = 30,

	-- Stealing
	StealHoldSeconds = 1.2,
	CarrySpeedFactor = 0.7,
	CarrySpeedFactorBoots = 0.9,
	CarryTimeoutSeconds = 60,
	WalkSpeed = 18,
	WalkSpeedBoots = 24,

	-- Bonk bat
	BonkCooldown = 0.9,
	BonkRange = 9,
	BonkRangeGolden = 13,
	BonkForce = 42,
	BonkForceGolden = 62,
	BonkLift = 0.45, -- upward launch as a fraction of the force
	BonkHitDelay = 0.28, -- seconds from click to contact, matching BatSwing.ContactTime
	BonkStunSeconds = 2,

	-- Thief raids (ThiefService): every few minutes a wave of thieves hits
	-- every base on the server at once; anyone can bonk any thief.
	ThiefFirstDelay = 110, -- seconds after the server starts before the first raid
	ThiefMinInterval = 120, -- seconds between raids (random in this range)
	ThiefMaxInterval = 210,
	ThiefMinSlimes = 3, -- only bases with at least this many (they skip the best one)
	-- Thieves per base: weight for 1, 2, 3, 4, 5 (each after a different slime).
	ThiefGangWeights = { 0, 10, 30, 35, 25 },
	RaidMaxThieves = 26, -- cap for the whole server per raid (each thief has a Highlight; Roblox shows 31)
	-- Thieves fight back: a player right in front of one may get shoved over.
	ThiefShoveRange = 6.5,
	ThiefShoveChance = 0.85,
	ThiefShoveCooldown = 1.8,
	ThiefShoveForce = 36,
	ThiefShoveStun = 1.2,
	-- Everyone on the server gets this (free, base income) when a raid ends
	-- with thieves caught and none escaped.
	RaidVictoryMinutes = 3,
	RaidVictoryMinimum = 500,
	ThiefSpacingMin = 1.5, -- seconds between thieves in a raid (random in this range)
	ThiefSpacingMax = 5,
	ThiefWalkSpeed = 24, -- sneaking in (players walk 18)
	ThiefCarrySpeed = 22, -- running away: faster than a player (18), so cut them off or swing early; Speed Boots (24) catch them
	ThiefSpeedMin = 0.92, -- each thief's speed is scaled by a random amount in this range
	ThiefSpeedMax = 1.03,
	ThiefGrabSeconds = 1.5,
	ThiefRushMultiplier = 1.3, -- spotted before the grab: he rushes in this much faster
	-- Thieves keep trying until they're bonked (or get away with a slime);
	-- this only stops one that's been at it this long (a broken path).
	ThiefPersistSeconds = 240,
	-- A locked base doesn't stop them: a thief kneels at the gate and picks
	-- the lock for this long (bonk him first). Re-locking (Instant Lock) while
	-- he's at it or inside still traps him.
	ThiefPickSeconds = 7,
	-- Toughness: bat hits to take one down. A hit that doesn't finish him
	-- makes him shove back and sprint. Brutes are bigger and take more.
	ThiefHits = 2,
	ThiefBruteChance = 0.2,
	ThiefBruteHits = 3,
	ThiefBruteScale = 1.3,
	-- Juking: a player this close makes him sidestep and sprint.
	ThiefDodgeRange = 11,
	ThiefDodgeCooldown = 1.6,
	ThiefSprintMultiplier = 1.25,
	ThiefRewardMinutes = 1, -- bonk reward: minutes of the owner's base income
	ThiefRewardMinimum = 150,

	-- Growth: slimes grow while they sit in a base, up to double income
	-- (and a bigger, juicier target) after GrowSeconds. Stolen slimes keep it.
	GrowSeconds = 30 * 60,
	GrowIncomeBonus = 1, -- +100% income when fully grown
	GrowSizeBonus = 0.35, -- +35% size when fully grown
	BigCarrySpeedFactor = 0.85, -- extra slowdown carrying a big slime

	-- Merging: three identical slimes become one of the next tier.
	MergeCount = 3,
	MergeTiers = {
		{ Name = "", Income = 1, Size = 1 },
		{ Name = "Giant", Income = 3.6, Size = 1.4 },
		{ Name = "Colossal", Income = 13, Size = 1.8 },
	},
}

function Economy.RebirthCost(rebirths: number): number
	return Economy.RebirthBaseCost * Economy.RebirthCostGrowth ^ rebirths
end

function Economy.MaxSlots(rebirths: number, hasExtraSlots: boolean, bought: number?): number
	local fromRebirths = math.min(rebirths * Economy.SlotsPerRebirth, Economy.MaxRebirthSlots)
	local fromCash = math.clamp(bought or 0, 0, Economy.BuySlotsMax)
	return Economy.BaseSlots + fromRebirths + (if hasExtraSlots then Economy.ExtraSlotsPass else 0) + fromCash
end

-- Cash price of the next base expansion, after `bought` of them.
function Economy.SlotPrice(bought: number): number
	return math.floor(Economy.BuySlotBasePrice * Economy.BuySlotGrowth ^ bought / 100 + 0.5) * 100
end

-- The absolute maximum number of slots any player can have. Plots are built
-- with this many pedestals.
Economy.AbsoluteMaxSlots = Economy.BaseSlots + Economy.MaxRebirthSlots + Economy.ExtraSlotsPass + Economy.BuySlotsMax

return Economy
