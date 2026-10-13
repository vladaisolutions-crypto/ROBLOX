--!strict
-- Redeemable codes. Codes are a free growth channel: players search
-- "steal a slime codes" on Google/YouTube/TikTok, and posting new codes in
-- the group or on socials brings players back. Codes are case-insensitive.
--
-- Kinds: "Cash" (minutes of income, with a minimum), "Double" (2x cash for
-- N minutes), "Slime" (a specific slime). Expires is a UTC unix time or nil.

export type Code = {
	Code: string,
	Kind: "Cash" | "Double" | "Slime",
	Minutes: number?,
	Minimum: number?,
	SlimeId: string?,
	Expires: number?,
}

local function utc(year: number, month: number, day: number): number
	return os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })
end

local Codes: { Code } = {
	{ Code = "RELEASE", Kind = "Slime", SlimeId = "ocean" },
	{ Code = "SLIME", Kind = "Cash", Minutes = 10, Minimum = 500 },
	{ Code = "LUCKY", Kind = "Double", Minutes = 10 },
	{ Code = "SPOOKY", Kind = "Cash", Minutes = 20, Minimum = 2000, Expires = utc(2026, 11, 4) },
	-- Stream / launch codes. For a streamer's own code, copy a line and put
	-- their name in Code (e.g. "ERIK500"): their viewers redeem it on stream.
	{ Code = "CAULDRON", Kind = "Slime", SlimeId = "pumpkin", Expires = utc(2026, 11, 4) },
	{ Code = "STREAM", Kind = "Double", Minutes = 15 },
	{ Code = "MERGE", Kind = "Cash", Minutes = 15, Minimum = 1500 },
}

local byCode: { [string]: Code } = {}
for _, code in Codes do
	byCode[string.upper(code.Code)] = code
end

return {
	List = Codes,
	ByCode = byCode,
}
