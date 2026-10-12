--!strict
-- Every slime in the game. Models are generated from these fields by
-- SlimeBuilder, so adding a slime is just adding a row here.
--
-- Price is in-game cash. Income is cash per second while it sits in a base.
-- Payback (Price / Income) grows with rarity so upgrades always feel earned.

export type SlimeDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number,
	Income: number,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Size: number,
	Hat: string?,
	Glow: boolean?,
	Event: string?, -- only spawns while this event is active
}

local K, M, B = 1e3, 1e6, 1e9

local Slimes: { SlimeDef } = {
	-- Common
	{ Id = "goo", Name = "Goo", Rarity = "Common", Price = 10, Income = 1, Color = Color3.fromRGB(110, 220, 90), Size = 1 },
	{ Id = "bubble", Name = "Bubble", Rarity = "Common", Price = 25, Income = 2, Color = Color3.fromRGB(150, 210, 255), Size = 1, Transparency = 0.25 },
	{ Id = "pebble", Name = "Pebble", Rarity = "Common", Price = 50, Income = 3, Color = Color3.fromRGB(150, 150, 160), Size = 0.9, Material = Enum.Material.Slate },
	{ Id = "mint", Name = "Mint", Rarity = "Common", Price = 90, Income = 5, Color = Color3.fromRGB(160, 255, 200), Size = 1 },

	-- Uncommon
	{ Id = "berry", Name = "Berry", Rarity = "Uncommon", Price = 250, Income = 10, Color = Color3.fromRGB(255, 110, 170), Size = 1.05 },
	{ Id = "lemon", Name = "Lemon", Rarity = "Uncommon", Price = 500, Income = 18, Color = Color3.fromRGB(255, 240, 90), Size = 1.05 },
	{ Id = "moss", Name = "Moss", Rarity = "Uncommon", Price = 900, Income = 30, Color = Color3.fromRGB(70, 140, 60), Size = 1.1, Hat = "Leaf" },
	{ Id = "cocoa", Name = "Cocoa", Rarity = "Uncommon", Price = 1.5 * K, Income = 45, Color = Color3.fromRGB(125, 80, 50), Size = 1.1 },

	-- Rare
	{ Id = "ocean", Name = "Ocean", Rarity = "Rare", Price = 4 * K, Income = 100, Color = Color3.fromRGB(40, 120, 255), Size = 1.15, Material = Enum.Material.Glass, Transparency = 0.2 },
	{ Id = "ember", Name = "Ember", Rarity = "Rare", Price = 8 * K, Income = 170, Color = Color3.fromRGB(255, 120, 40), Size = 1.15, Glow = true },
	{ Id = "frost", Name = "Frost", Rarity = "Rare", Price = 14 * K, Income = 260, Color = Color3.fromRGB(200, 240, 255), Size = 1.2, Material = Enum.Material.Ice },
	{ Id = "thunder", Name = "Thunder", Rarity = "Rare", Price = 22 * K, Income = 380, Color = Color3.fromRGB(255, 230, 0), Size = 1.2, Hat = "Antenna" },

	-- Epic
	{ Id = "crystal", Name = "Crystal", Rarity = "Epic", Price = 60 * K, Income = 900, Color = Color3.fromRGB(190, 120, 255), Size = 1.3, Material = Enum.Material.Glass, Transparency = 0.15 },
	{ Id = "lava", Name = "Lava", Rarity = "Epic", Price = 110 * K, Income = 1.5 * K, Color = Color3.fromRGB(255, 70, 20), Size = 1.3, Material = Enum.Material.Neon },
	{ Id = "toxic", Name = "Toxic", Rarity = "Epic", Price = 180 * K, Income = 2.3 * K, Color = Color3.fromRGB(150, 255, 0), Size = 1.35, Glow = true },
	{ Id = "wizard", Name = "Wizard", Rarity = "Epic", Price = 280 * K, Income = 3.4 * K, Color = Color3.fromRGB(80, 60, 200), Size = 1.35, Hat = "Wizard" },

	-- Legendary
	{ Id = "king", Name = "King", Rarity = "Legendary", Price = 900 * K, Income = 9 * K, Color = Color3.fromRGB(255, 200, 40), Size = 1.5, Hat = "Crown", Material = Enum.Material.Foil },
	{ Id = "angel", Name = "Angel", Rarity = "Legendary", Price = 1.6 * M, Income = 15 * K, Color = Color3.fromRGB(255, 255, 245), Size = 1.5, Hat = "Halo", Glow = true },
	{ Id = "devil", Name = "Devil", Rarity = "Legendary", Price = 2.6 * M, Income = 24 * K, Color = Color3.fromRGB(200, 20, 40), Size = 1.55, Hat = "Horns" },
	{ Id = "phoenix", Name = "Phoenix", Rarity = "Legendary", Price = 4 * M, Income = 35 * K, Color = Color3.fromRGB(255, 140, 0), Size = 1.6, Material = Enum.Material.Neon, Glow = true },

	-- Mythic
	{ Id = "galaxy", Name = "Galaxy", Rarity = "Mythic", Price = 14 * M, Income = 110 * K, Color = Color3.fromRGB(70, 20, 140), Size = 1.75, Material = Enum.Material.Neon, Glow = true },
	{ Id = "prism", Name = "Prism", Rarity = "Mythic", Price = 25 * M, Income = 180 * K, Color = Color3.fromRGB(255, 255, 255), Size = 1.75, Material = Enum.Material.Glass, Transparency = 0.1, Glow = true },
	{ Id = "void", Name = "Void", Rarity = "Mythic", Price = 40 * M, Income = 280 * K, Color = Color3.fromRGB(15, 10, 25), Size = 1.8, Glow = true, Hat = "Horns" },
	{ Id = "celestial", Name = "Celestial", Rarity = "Mythic", Price = 65 * M, Income = 420 * K, Color = Color3.fromRGB(255, 235, 160), Size = 1.85, Material = Enum.Material.Neon, Hat = "Halo", Glow = true },

	-- Secret
	{ Id = "slimegod", Name = "Slime God", Rarity = "Secret", Price = 250 * M, Income = 1.2 * M, Color = Color3.fromRGB(0, 255, 200), Size = 2.3, Material = Enum.Material.Neon, Hat = "Crown", Glow = true },
	{ Id = "glitch", Name = "Glitch", Rarity = "Secret", Price = 500 * M, Income = 2.2 * M, Color = Color3.fromRGB(255, 0, 255), Size = 2.3, Material = Enum.Material.Neon, Hat = "Antenna", Glow = true },
	{ Id = "omega", Name = "Omega", Rarity = "Secret", Price = 1 * B, Income = 4 * M, Color = Color3.fromRGB(255, 255, 255), Size = 2.6, Material = Enum.Material.ForceField, Hat = "Halo", Glow = true },

	-- Halloween (limited: only spawn during the event, kept forever once owned)
	{ Id = "pumpkin", Name = "Pumpkin", Rarity = "Rare", Price = 10 * K, Income = 220, Color = Color3.fromRGB(255, 130, 20), Size = 1.2, Hat = "Pumpkin", Event = "Halloween" },
	{ Id = "ghost", Name = "Ghost", Rarity = "Epic", Price = 150 * K, Income = 2 * K, Color = Color3.fromRGB(240, 240, 255), Size = 1.3, Transparency = 0.45, Event = "Halloween" },
	{ Id = "witch", Name = "Witch", Rarity = "Legendary", Price = 2 * M, Income = 20 * K, Color = Color3.fromRGB(90, 200, 60), Size = 1.5, Hat = "WitchHat", Event = "Halloween" },
	{ Id = "phantom", Name = "Phantom", Rarity = "Mythic", Price = 30 * M, Income = 230 * K, Color = Color3.fromRGB(25, 0, 40), Size = 1.8, Material = Enum.Material.Neon, Glow = true, Hat = "WitchHat", Event = "Halloween" },
}

local byId: { [string]: SlimeDef } = {}
local byRarity: { [string]: { SlimeDef } } = {}
for _, def in Slimes do
	assert(byId[def.Id] == nil, "Duplicate slime id " .. def.Id)
	byId[def.Id] = def
	local bucket = byRarity[def.Rarity]
	if not bucket then
		bucket = {}
		byRarity[def.Rarity] = bucket
	end
	table.insert(bucket, def)
end

return {
	List = Slimes,
	ById = byId,
	ByRarity = byRarity,
}
