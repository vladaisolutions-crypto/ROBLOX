--!strict
-- Rarity tiers, ordered from most common to rarest. Weight is the relative
-- chance of a conveyor spawn landing on that tier (before luck is applied).

export type Rarity = {
	Name: string,
	Order: number,
	Weight: number,
	Color: Color3,
	Lucky: boolean, -- affected by server luck boosts
	Announce: boolean, -- tell the whole server when one spawns
}

local Rarities: { Rarity } = {
	{ Name = "Common", Order = 1, Weight = 600, Color = Color3.fromRGB(200, 200, 200), Lucky = false, Announce = false },
	{ Name = "Uncommon", Order = 2, Weight = 260, Color = Color3.fromRGB(95, 225, 95), Lucky = false, Announce = false },
	{ Name = "Rare", Order = 3, Weight = 100, Color = Color3.fromRGB(70, 155, 255), Lucky = true, Announce = false },
	{ Name = "Epic", Order = 4, Weight = 30, Color = Color3.fromRGB(185, 85, 255), Lucky = true, Announce = false },
	{ Name = "Legendary", Order = 5, Weight = 8, Color = Color3.fromRGB(255, 195, 40), Lucky = true, Announce = true },
	{ Name = "Mythic", Order = 6, Weight = 2, Color = Color3.fromRGB(255, 60, 95), Lucky = true, Announce = true },
	{ Name = "Secret", Order = 7, Weight = 0.4, Color = Color3.fromRGB(30, 255, 220), Lucky = true, Announce = true },
}

local byName: { [string]: Rarity } = {}
for _, rarity in Rarities do
	byName[rarity.Name] = rarity
end

return {
	List = Rarities,
	ByName = byName,
}
