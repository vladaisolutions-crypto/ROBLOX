--!strict
-- Effect sounds. Generated with ElevenLabs (sources in assets/sfx); once
-- uploaded their audio ids go in Uploaded (scripts/upload_sfx.py fills it
-- in). Until then each falls back to a sound bundled with the Roblox client.

local Uploaded: { [string]: number } = {
	Merge = 85751606608896,
	Boing = 84400207824599,
	Cash = 96404268243461,
	Rare = 81697270155385,
	Bonk = 136154988977012,
	Whoosh = 89877680967761,
}

-- Source file in assets/sfx for each key (used by the upload script).
local Files: { [string]: string } = {
	Merge = "merge",
	Boing = "boing",
	Cash = "cash",
	Rare = "rare",
	Bonk = "bonk",
	Whoosh = "whoosh",
}

local Fallback: { [string]: string } = {
	Merge = "rbxasset://sounds/electronicpingshort.wav",
	Boing = "rbxasset://sounds/action_jump.mp3",
	Cash = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Bonk = "rbxasset://sounds/collide.wav",
	Whoosh = "rbxasset://sounds/swordlunge.wav",
}

local Ids: { [string]: string } = {}
for key, fallback in Fallback do
	local id = Uploaded[key] or 0
	Ids[key] = if id ~= 0 then "rbxassetid://" .. id else fallback
end

return {
	Ids = Ids,
	Files = Files,
}
