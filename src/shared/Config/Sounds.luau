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
	Reward = 85150479795865,
	Coins = 119665346551949,
	Fanfare = 110662878792964,
	Alarm = 100786123828377,
	Pop = 123444471737331,
	ThiefArrive1 = 103004330477192,
	ThiefArrive2 = 131043160933342,
	ThiefSneak1 = 86102497978952,
	ThiefSneak2 = 71837951338228,
	ThiefGrab1 = 102327830890361,
	ThiefGrab2 = 96738238462665,
	ThiefRun1 = 121764081309850,
	ThiefRun2 = 133522693567550,
	ThiefRun3 = 86174659996136,
	ThiefLocked1 = 91939142509120,
	ThiefLocked2 = 96667746917341,
	ThiefBonked1 = 73756764595840,
	ThiefBonked2 = 92216549898570,
	ThiefEscaped1 = 113704176243540,
}

-- Source file in assets/sfx for each key (used by the upload script).
local Files: { [string]: string } = {
	Merge = "merge",
	Boing = "boing",
	Cash = "cash",
	Rare = "rare",
	Bonk = "bonk",
	Whoosh = "whoosh",
	Reward = "reward",
	Coins = "coins",
	Fanfare = "fanfare",
	Alarm = "alarm",
	Pop = "pop",
	ThiefArrive1 = "thief_arrive1",
	ThiefArrive2 = "thief_arrive2",
	ThiefSneak1 = "thief_sneak1",
	ThiefSneak2 = "thief_sneak2",
	ThiefGrab1 = "thief_grab1",
	ThiefGrab2 = "thief_grab2",
	ThiefRun1 = "thief_run1",
	ThiefRun2 = "thief_run2",
	ThiefRun3 = "thief_run3",
	ThiefLocked1 = "thief_locked1",
	ThiefLocked2 = "thief_locked2",
	ThiefBonked1 = "thief_bonked1",
	ThiefBonked2 = "thief_bonked2",
	ThiefEscaped1 = "thief_escaped1",
}

local Fallback: { [string]: string } = {
	Merge = "rbxasset://sounds/electronicpingshort.wav",
	Boing = "rbxasset://sounds/action_jump.mp3",
	Cash = "rbxasset://sounds/electronicpingshort.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Bonk = "rbxasset://sounds/collide.wav",
	Whoosh = "rbxasset://sounds/swordlunge.wav",
	Reward = "rbxasset://sounds/electronicpingshort.wav",
	Coins = "rbxasset://sounds/electronicpingshort.wav",
	Fanfare = "rbxasset://sounds/electronicpingshort.wav",
	Alarm = "rbxasset://sounds/button.wav",
	Pop = "rbxasset://sounds/button.wav",
	-- Thief voice lines: silent until uploaded.
	ThiefArrive1 = "",
	ThiefArrive2 = "",
	ThiefSneak1 = "",
	ThiefSneak2 = "",
	ThiefGrab1 = "",
	ThiefGrab2 = "",
	ThiefRun1 = "",
	ThiefRun2 = "",
	ThiefRun3 = "",
	ThiefLocked1 = "",
	ThiefLocked2 = "",
	ThiefBonked1 = "",
	ThiefBonked2 = "",
	ThiefEscaped1 = "",
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
