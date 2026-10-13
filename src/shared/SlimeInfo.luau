--!strict
-- Value and naming helpers for a slime: its kind, mutation, merge tier
-- (1 normal, 2 Giant, 3 Colossal) and age in a base (it grows).

local Config = script.Parent.Config
local Slimes = require(Config.Slimes)
local Mutations = require(Config.Mutations)
local Economy = require(Config.Economy)

local SlimeInfo = {}

function SlimeInfo.Tier(tier: number?): { Name: string, Income: number, Size: number }
	local tiers = Economy.MergeTiers
	return tiers[math.clamp(tier or 1, 1, #tiers)]
end

-- 0 when new, 1 when fully grown.
function SlimeInfo.Growth(age: number?): number
	return math.clamp((age or 0) / Economy.GrowSeconds, 0, 1)
end

-- Visual size multiplier from tier and growth.
function SlimeInfo.Scale(tier: number?, age: number?): number
	return SlimeInfo.Tier(tier).Size * (1 + SlimeInfo.Growth(age) * Economy.GrowSizeBonus)
end

function SlimeInfo.Income(slimeId: string, mutationId: string?, tier: number?, age: number?): number
	local def = Slimes.ById[slimeId]
	if not def then
		return 0
	end
	return def.Income
		* Mutations.Multiplier(mutationId)
		* SlimeInfo.Tier(tier).Income
		* (1 + SlimeInfo.Growth(age) * Economy.GrowIncomeBonus)
end

function SlimeInfo.Price(slimeId: string, mutationId: string?, tier: number?): number
	local def = Slimes.ById[slimeId]
	if not def then
		return 0
	end
	return def.Price * Mutations.Multiplier(mutationId) * SlimeInfo.Tier(tier).Income
end

function SlimeInfo.DisplayName(slimeId: string, mutationId: string?, tier: number?): string
	local def = Slimes.ById[slimeId]
	local name = if def then def.Name else "???"
	local tierName = SlimeInfo.Tier(tier).Name
	if tierName ~= "" then
		name = tierName .. " " .. name
	end
	if mutationId and mutationId ~= "" then
		return mutationId .. " " .. name
	end
	return name
end

return SlimeInfo
