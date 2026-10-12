--!strict
-- Weighted random selection.

local Weighted = {}

-- Picks one entry from `entries`, where `weightOf` returns a non-negative
-- weight for each. Returns nil only if every weight is zero.
function Weighted.Pick<T>(entries: { T }, weightOf: (T) -> number, rng: Random?): T?
	local total = 0
	for _, entry in entries do
		total += math.max(0, weightOf(entry))
	end
	if total <= 0 then
		return nil
	end
	local roll = (if rng then rng:NextNumber() else math.random()) * total
	for _, entry in entries do
		local weight = math.max(0, weightOf(entry))
		if roll < weight then
			return entry
		end
		roll -= weight
	end
	return entries[#entries]
end

return Weighted
