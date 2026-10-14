--!strict
-- All economy tuning lives here so balance changes never touch game logic.

local Economy = {
	StartingCash = 100,

	-- Base slots
	BaseSlots = 8,
	SlotsPerRebirth = 2,
	MaxRebirthSlots = 10,
	ExtraSlotsPass = 6, -- "+6 Slots" game pass

	-- Selling a slime refunds this fraction of its price.
	SellRefund = 0.5,

	-- Rebirth: costs all cash (minimum shown below), keeps slimes.
	RebirthBaseCost = 2e6,
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
	ThiefFirstDelay = 150, -- seconds after the server starts before the first raid
	ThiefMinInterval = 150, -- seconds between raids (random in this range)
	ThiefMaxInterval = 270,
	ThiefMinSlimes = 3, -- only bases with at least this many (they skip the best one)
	-- Thieves per base: weight for 1, 2, 3, 4, 5 (each after a different slime).
	ThiefGangWeights = { 0, 20, 35, 30, 15 },
	RaidMaxThieves = 26, -- cap for the whole server per raid (each thief has a Highlight; Roblox shows 31)
	-- Thieves fight back: a player right in front of one may get shoved over.
	ThiefShoveRange = 5,
	ThiefShoveChance = 0.7,
	ThiefShoveCooldown = 2.5,
	ThiefShoveForce = 30,
	ThiefShoveStun = 1.2,
	-- Guard Slime pass: bonks thieves near your base.
	GuardRange = 16, -- studs from the guard (at your gate)
	GuardInterval = 1.6, -- seconds between its bonks
	-- Everyone on the server gets this (free, base income) when a raid ends
	-- with thieves caught and none escaped.
	RaidVictoryMinutes = 3,
	RaidVictoryMinimum = 500,
	ThiefSpacingMin = 1.5, -- seconds between thieves in a raid (random in this range)
	ThiefSpacingMax = 5,
	ThiefWalkSpeed = 14, -- sneaking in
	ThiefCarrySpeed = 17.5, -- running away; players walk 18, so it's a real chase
	ThiefSpeedMin = 0.9, -- each thief's speed is scaled by a random amount in this range
	ThiefSpeedMax = 1.02, -- keep the fastest carrier (17.5 x 1.02) just under the players' 18
	ThiefGrabSeconds = 2,
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

function Economy.MaxSlots(rebirths: number, hasExtraSlots: boolean): number
	local fromRebirths = math.min(rebirths * Economy.SlotsPerRebirth, Economy.MaxRebirthSlots)
	return Economy.BaseSlots + fromRebirths + (if hasExtraSlots then Economy.ExtraSlotsPass else 0)
end

-- The absolute maximum number of slots any player can have. Plots are built
-- with this many pedestals.
Economy.AbsoluteMaxSlots = Economy.BaseSlots + Economy.MaxRebirthSlots + Economy.ExtraSlotsPass

return Economy
