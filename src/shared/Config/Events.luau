--!strict
-- Timed events. Dates are UTC unix timestamps.

local function utc(year: number, month: number, day: number): number
	return os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

return {
	-- Seasonal events unlock limited slimes and mutations (see Slimes.Event /
	-- Mutations.Event). Add Christmas etc. here when the time comes.
	Seasonal = {
		{ Id = "Halloween", Name = "🎃 Halloween Event", Starts = utc(2026, 10, 10), Ends = utc(2026, 11, 4) },
	},

	-- The Watcher: now and then a tall faceless figure appears far off, stares
	-- at one player (client-only, nobody else sees it) and vanishes.
	Watcher = {
		FirstDelay = 180, -- seconds after joining before the first sighting
		MinInterval = 240, -- seconds between sightings (random in this range)
		MaxInterval = 540,
		MinDistance = 38,
		MaxDistance = 60,
		StareSeconds = 6, -- longest he stays
		SeenSeconds = 1, -- looking straight at him this long makes him vanish
		VanishDistance = 16, -- walking this close makes him vanish
	},

	-- Chaos events (ChaosService): every few minutes something random happens
	-- to the whole server so it never gets boring. Never during a raid or
	-- Slime Rain. Weight = how often each one is picked.
	Chaos = {
		FirstDelay = 90,
		MinInterval = 150,
		MaxInterval = 270,
		List = {
			{
				Id = "CashRain",
				Weight = 3,
				Seconds = 40,
				Text = "💰 CASH RAIN! Coins are falling everywhere - grab them!",
			},
			{
				Id = "Meteors",
				Weight = 2,
				Seconds = 40,
				Text = "☄️ METEOR SHOWER! Dodge the red circles, grab the crystals!",
			},
			{ Id = "LowGravity", Weight = 2, Seconds = 40, Text = "🌙 LOW GRAVITY! Moon jumps for 40 seconds!" },
			{ Id = "SpeedFrenzy", Weight = 2, Seconds = 40, Text = "⚡ SPEED FRENZY! Everyone runs 1.5x faster!" },
			{
				Id = "LuckyStorm",
				Weight = 2,
				Seconds = 60,
				Text = "🍀 LUCKY STORM! 3x luck on the belt for 60 seconds!",
			},
			{
				Id = "Blackout",
				Weight = 2,
				Seconds = 45,
				Text = "🌑 BLACKOUT! The lights went out... something is watching.",
			},
		},
		CoinEvery = 0.2, -- seconds between falling coins (Cash Rain)
		CoinMinutes = 0.04, -- each coin pays this many minutes of base income
		CoinMinimum = 5,
		MeteorEvery = 1.4,
		MeteorWarnSeconds = 1.5,
		MeteorRadius = 10, -- knockback radius
		CrystalMinutes = 0.4, -- each meteor crystal pays this many minutes of base income
		CrystalMinimum = 40,
		LowGravity = 60, -- workspace gravity during Low Gravity (normal 196.2)
		SpeedMultiplier = 1.5,
		Luck = 3,
	},

	-- Slime Rain: a short burst of faster, luckier spawns on a fixed timer so
	-- every server has something to wait for.
	RainEverySeconds = 20 * 60,
	RainDurationSeconds = 2 * 60,
	RainSpawnSpeedup = 2,
	RainLuck = 3,

	-- Playtime gifts: claimable after this many minutes in a session, and
	-- what each gives (Cash: minutes of base income, with a floor).
	GiftMinutes = { 3, 8, 15, 25, 40, 60 },
	Gifts = {
		{ Kind = "Cash", Minutes = 2, Minimum = 100 },
		{ Kind = "Double", Minutes = 5 },
		{ Kind = "Cash", Minutes = 3, Minimum = 300 },
		{ Kind = "Double", Minutes = 10 },
		{ Kind = "Cash", Minutes = 5, Minimum = 500 },
		{ Kind = "Slime", SlimeId = "ember" },
	} :: { { Kind: string, Minutes: number?, Minimum: number?, SlimeId: string? } },

	-- Daily streak rewards, in minutes of income (minimum cash floor applies).
	-- Day 7 also grants a free Epic slime.
	DailyIncomeMinutes = { 2, 3, 4, 5, 6, 8, 12 },
	DailyMinimumCash = { 100, 200, 350, 500, 800, 1200, 2000 },
}
