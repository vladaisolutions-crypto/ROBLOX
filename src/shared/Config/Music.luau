--!strict
-- Background music: licensed tracks from DistroKid's verified Roblox account
-- (public, free to use in any experience). Played client-side, shuffled.

return {
	Volume = 0.28,
	FadeSeconds = 2,
	-- Seasonal playlists by event id; Default plays when no event has one.
	Playlists = {
		Halloween = {
			111631783838916, -- Spooky cartoon music
			101206861008794, -- Spooky cartoon music, Pt. 3
			115585877205328, -- Spooky cartoon music, Pt. 4
			123383267796300, -- Spooky cartoon music, Pt. 5
			87537452210084, -- Spooky cartoon music, Pt. 6
			132339469996629, -- Halloween skeleton dance
			120032869536494, -- Halloween skeleton dance, Pt. 2
			74910520938989, -- Spooksville
		},
		Default = {
			111631783838916,
			132339469996629,
			74910520938989,
		},
	} :: { [string]: { number } },
}
