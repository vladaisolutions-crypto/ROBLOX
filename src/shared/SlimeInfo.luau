--!strict
-- Value and naming helpers for a (slime, mutation) pair.

local Config = script.Parent.Config
local Slimes = require(Config.Slimes)
local Mutations = require(Config.Mutations)

local SlimeInfo = {}

function SlimeInfo.Income(slimeId: string, mutationId: string?): number
	local def = Slimes.ById[slimeId]
	if not def then
		return 0
	end
	return def.Income * Mutations.Multiplier(mutationId)
end

function SlimeInfo.Price(slimeId: string, mutationId: string?): number
	local def = Slimes.ById[slimeId]
	if not def then
		return 0
	end
	return def.Price * Mutations.Multiplier(mutationId)
end

function SlimeInfo.DisplayName(slimeId: string, mutationId: string?): string
	local def = Slimes.ById[slimeId]
	local name = if def then def.Name else "???"
	if mutationId and mutationId ~= "" then
		return mutationId .. " " .. name
	end
	return name
end

return SlimeInfo
