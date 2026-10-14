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
