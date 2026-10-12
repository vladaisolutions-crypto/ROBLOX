--!strict
-- Mutations roll independently of rarity. They multiply both a slime's price
-- and its income, and change how it looks.

export type Mutation = {
	Id: string,
	Chance: number, -- 0..1 per spawn
	Multiplier: number,
	Color: Color3,
	Event: string?, -- only rolls while this event is active
}

local Mutations: { Mutation } = {
	{ Id = "Gold", Chance = 0.06, Multiplier = 2, Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "Diamond", Chance = 0.02, Multiplier = 3, Color = Color3.fromRGB(120, 235, 255) },
	{ Id = "Haunted", Chance = 0.04, Multiplier = 4, Color = Color3.fromRGB(170, 90, 255), Event = "Halloween" },
	{ Id = "Rainbow", Chance = 0.005, Multiplier = 6, Color = Color3.fromRGB(255, 120, 200) },
}

local byId: { [string]: Mutation } = {}
for _, mutation in Mutations do
	byId[mutation.Id] = mutation
end

local function multiplier(id: string?): number
	if id == nil then
		return 1
	end
	local mutation = byId[id]
	return if mutation then mutation.Multiplier else 1
end

return {
	List = Mutations,
	ById = byId,
	Multiplier = multiplier,
}
