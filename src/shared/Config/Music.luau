--!strict
-- Background music (played client-side). Tracks were made for the game and
-- normalised to -20 LUFS before upload, so these volumes sit well under the
-- voices and effects.

return {
	Volume = 0.32, -- background loop
	RaidVolume = 0.36, -- the chase track, a touch more present
	FadeSeconds = 2,
	-- Plays while a thief raid is on (workspace attribute RaidActive).
	RaidTrack = 111138172796277, -- Candy Capers Chase
	-- Seasonal playlists by event id; Default plays when no event has one.
	Playlists = {
		Halloween = {
			103413214979988, -- Moonlit Pumpkin Parade
		},
		Default = {
			103413214979988,
		},
	} :: { [string]: { number } },
}
