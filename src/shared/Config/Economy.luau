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
	BonkForce = 75,
	BonkForceGolden = 115,
	BonkLift = 0.6, -- upward launch as a fraction of the force
	BonkHitDelay = 0.22, -- seconds from click to contact, matching the swing
	BonkStunSeconds = 2,

	-- NPC thief (ThiefService): visits each player every few minutes.
	ThiefFirstDelay = 240, -- seconds after joining before the first visit
	ThiefMinInterval = 240,
	ThiefMaxInterval = 420,
	ThiefMinSlimes = 3, -- only bases with at least this many (he skips the best one)
	ThiefWalkSpeed = 13,
	ThiefCarrySpeed = 10, -- players walk 16, so you can always catch him
	ThiefGrabSeconds = 2,
	ThiefRewardMinutes = 2, -- bonk reward: this many minutes of the owner's income
	ThiefRewardMinimum = 250,

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
