-- Unit tests for configs, formulas and balance. Run from the repo root:
--   lune run tests/unit/run.luau

local Loader = require("./loader")

local Rarities = Loader.get("src/shared/Config/Rarities")
local Slimes = Loader.get("src/shared/Config/Slimes")
local Mutations = Loader.get("src/shared/Config/Mutations")
local Economy = Loader.get("src/shared/Config/Economy")
local Monetization = Loader.get("src/shared/Config/Monetization")
local Events = Loader.get("src/shared/Config/Events")
local Codes = Loader.get("src/shared/Config/Codes")
local Quests = Loader.get("src/shared/Config/Quests")
local World = Loader.get("src/shared/Config/World")
local Format = Loader.get("src/shared/Util/Format")
local Weighted = Loader.get("src/shared/Util/Weighted")
local SlimeInfo = Loader.get("src/shared/SlimeInfo")
local DataTemplate = Loader.get("src/server/DataTemplate")

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end

test("Format.Number", function()
	eq(Format.Number(0), "0")
	eq(Format.Number(999), "999")
	eq(Format.Number(12.5), "12.5")
	eq(Format.Number(142.04), "142")
	eq(Format.Number(0.04), "0")
	eq(Format.Number(-142.04), "-142")
	eq(Format.Number(1000), "1K")
	eq(Format.Number(1234), "1.23K")
	eq(Format.Number(15000000), "15M")
	eq(Format.Number(1.5e9), "1.5B")
	eq(Format.Number(999999), "999K")
	eq(Format.Number(10000), "10K")
	eq(Format.Number(100000), "100K")
	eq(Format.Number(150000), "150K")
	eq(Format.Number(2e6), "2M")
	eq(Format.Number(250e6), "250M")
	eq(Format.Number(500e6), "500M")
	eq(Format.Number(1.05e6), "1.05M")
	eq(Format.Number(-2500), "-2.5K")
	eq(Format.Cash(4e12), "$4T")
end)

test("Format.Time", function()
	eq(Format.Time(0), "0:00")
	eq(Format.Time(75), "1:15")
	eq(Format.Time(3725), "1:02:05")
	eq(Format.Time(-5), "0:00")
end)

test("Weighted.Pick distribution", function()
	local counts = { a = 0, b = 0 }
	local entries = { { id = "a", w = 1 }, { id = "b", w = 3 } }
	for _ = 1, 20000 do
		local pick = Weighted.Pick(entries, function(e)
			return e.w
		end)
		counts[pick.id] += 1
	end
	local share = counts.a / 20000
	assert(share > 0.23 and share < 0.27, "expected ~25% for a, got " .. share)
	eq(
		Weighted.Pick({ { w = 0 } }, function(e)
			return e.w
		end),
		nil,
		"all-zero weights"
	)
end)

test("every rarity has standard slimes", function()
	for _, rarity in Rarities.List do
		local count = 0
		for _, def in Slimes.List do
			if def.Rarity == rarity.Name and def.Event == nil then
				count += 1
			end
		end
		assert(count > 0, rarity.Name .. " has no standard slimes")
	end
end)

test("slimes reference real rarities, hats and mutation-safe values", function()
	local hats = {
		Leaf = true,
		Antenna = true,
		Wizard = true,
		WitchHat = true,
		Crown = true,
		Halo = true,
		Horns = true,
		Pumpkin = true,
		Bow = true,
		Unihorn = true,
	}
	for _, def in Slimes.List do
		assert(Rarities.ByName[def.Rarity], def.Id .. " has unknown rarity " .. def.Rarity)
		assert(def.Hat == nil or hats[def.Hat], def.Id .. " has unknown hat " .. tostring(def.Hat))
		assert(def.Price > 0 and def.Income > 0 and def.Size > 0, def.Id .. " has a non-positive stat")
	end
end)

test("higher rarities are strictly more valuable", function()
	for i = 1, #Rarities.List - 1 do
		local lower, higher = Rarities.List[i].Name, Rarities.List[i + 1].Name
		local maxLower, minHigher = 0, math.huge
		for _, def in Slimes.List do
			if def.Event == nil then
				if def.Rarity == lower then
					maxLower = math.max(maxLower, def.Income)
				elseif def.Rarity == higher then
					minHigher = math.min(minHigher, def.Income)
				end
			end
		end
		assert(maxLower < minHigher, lower .. " out-earns " .. higher)
	end
end)

test("payback time grows with rarity", function()
	local previous = 0
	for _, rarity in Rarities.List do
		local total, n = 0, 0
		for _, def in Slimes.List do
			if def.Rarity == rarity.Name and def.Event == nil then
				total += def.Price / def.Income
				n += 1
			end
		end
		local average = total / n
		assert(average >= previous, rarity.Name .. " pays back faster than the tier below")
		previous = average
	end
end)

test("mutation chances leave room for no mutation", function()
	local sum = 0
	for _, mutation in Mutations.List do
		sum += mutation.Chance
		assert(mutation.Multiplier > 1, mutation.Id .. " multiplier must be > 1")
	end
	assert(sum < 0.5, "mutations too common: " .. sum)
end)

test("slot math fits the plot layout", function()
	eq(Economy.MaxSlots(0, false), 8)
	eq(Economy.MaxSlots(5, false), 18)
	eq(Economy.MaxSlots(50, true), Economy.AbsoluteMaxSlots)
	-- WorldService lays pedestals out in 4 rows.
	assert(Economy.AbsoluteMaxSlots <= World.PedestalColumns * 4, "more slots than pedestal rows")
end)

test("rebirth costs", function()
	eq(Economy.RebirthCost(0), 2e6)
	eq(Economy.RebirthCost(1), 16e6)
end)

test("monetization config is consistent", function()
	local keys = {}
	for _, item in Monetization.Passes do
		assert(not keys[item.Key], "duplicate key " .. item.Key)
		keys[item.Key] = true
	end
	for _, item in Monetization.Products do
		assert(not keys[item.Key], "duplicate key " .. item.Key)
		keys[item.Key] = true
		if item.Kind == "BeltSlime" then
			assert(item.Rarity and Rarities.ByName[item.Rarity], item.Key .. " has bad rarity")
		end
	end
	for _, key in { "DoubleCash", "VIP", "AutoCollect", "ExtraSlots", "LongLock", "SpeedBoots", "GoldenBat" } do
		assert(Monetization.PassByKey[key], "missing pass used by code: " .. key)
	end
	assert(Monetization.ProductByKey.InstantLock, "missing InstantLock product")
end)

test("events and codes", function()
	eq(#Events.GiftMinutes, 6, "gift times")
	eq(#Events.Gifts, 6, "a reward for every gift time")
	eq(#Events.DailyIncomeMinutes, 7)
	eq(#Events.DailyMinimumCash, 7)
	for _, code in Codes.List do
		if code.Kind == "Slime" then
			assert(code.SlimeId and Slimes.ById[code.SlimeId], code.Code .. " gives an unknown slime")
		end
	end
	assert(Codes.ByCode.RELEASE, "codes are looked up upper-case")
end)

test("SlimeInfo values", function()
	eq(SlimeInfo.Income("goo", ""), 1)
	eq(SlimeInfo.Income("goo", "Gold"), 2)
	eq(SlimeInfo.Price("king", "Rainbow"), 900e3 * 6)
	eq(SlimeInfo.DisplayName("goo", "Diamond"), "Diamond Goo")
	eq(SlimeInfo.Income("nope", ""), 0)
end)

test("DataTemplate.Reconcile fills new fields and keeps old ones", function()
	local data = DataTemplate.Reconcile({
		Cash = 5,
		Stats = { Steals = 2 },
		Slots = { { Slot = 1, Id = "goo", Mutation = "", Stored = 0 } },
	})
	eq(data.Cash, 5)
	eq(data.Stats.Steals, 2)
	eq(data.Stats.PlaySeconds, 0)
	eq(#data.Slots, 1)
	eq(data.TutorialStep, 1)
	assert(type(data.Codes) == "table" and type(data.Funnel) == "table", "new tables added")
	local fresh = DataTemplate.New()
	eq(fresh.Cash, Economy.StartingCash)
end)

-- Balance simulation: a solo player greedily buying the best slime they can
-- afford from the belt (no stealing, no competition). Prints minutes to the
-- first rebirth so balance changes can be judged at a glance.
-- Deterministic stand-in for Roblox's Random (not available under Lune).
local function seededRandom(seed: number)
	local state = seed
	local rng = {}
	function rng.NextNumber(_self, min: number?, max: number?): number
		state = (state * 1103515245 + 12345) % 2147483648
		local unit = state / 2147483648
		return (min or 0) + unit * ((max or 1) - (min or 0))
	end
	function rng.NextInteger(self, min: number, max: number): number
		return math.min(max, min + math.floor(self:NextNumber() * (max - min + 1)))
	end
	return rng
end

test("merging and growth", function()
	-- Merge tiers pay more than the slimes that went in (three of a kind).
	for i = 2, #Economy.MergeTiers do
		local tier = Economy.MergeTiers[i]
		local prev = Economy.MergeTiers[i - 1]
		assert(tier.Income > prev.Income * Economy.MergeCount, "tier " .. i .. " pays less than its inputs")
		assert(tier.Size > prev.Size, "tier " .. i .. " is not bigger")
	end
	-- Growth: nothing at first, full bonus at GrowSeconds, capped after.
	assert(SlimeInfo.Growth(0) == 0 and SlimeInfo.Growth(Economy.GrowSeconds) == 1, "growth range")
	assert(SlimeInfo.Growth(Economy.GrowSeconds * 5) == 1, "growth caps")
	local base = SlimeInfo.Income("goo", "")
	assert(SlimeInfo.Income("goo", "", 1, Economy.GrowSeconds) == base * (1 + Economy.GrowIncomeBonus), "grown income")
	assert(SlimeInfo.Income("goo", "", 2) == base * Economy.MergeTiers[2].Income, "giant income")
	assert(SlimeInfo.DisplayName("goo", "", 2) == "Giant Goo", "giant name")
	-- Merge recipes point at merge-only slimes, which never spawn on the belt.
	for _, def in Slimes.List do
		if def.MergeInto then
			local target = Slimes.ById[def.MergeInto]
			assert(target and target.MergeOnly, def.Id .. " merges into a missing or belt slime")
			assert(target.Income > def.Income * Economy.MergeCount, def.Id .. " recipe pays less than its inputs")
		end
	end
end)

test("balance: time to first rebirth is reasonable", function()
	local rng = seededRandom(7)
	local cash = Economy.StartingCash
	local slots: { number } = {} -- incomes
	local t = 0
	local target = Economy.RebirthCost(0)
	while cash < target and t < 6 * 3600 do
		t += World.SpawnEverySeconds
		-- income since last spawn
		local income = 0
		for _, value in slots do
			income += value
		end
		cash += income * World.SpawnEverySeconds
		-- one spawn
		local rarity = Weighted.Pick(Rarities.List, function(r)
			return r.Weight
		end, rng)
		local pool = {}
		for _, def in Slimes.List do
			if def.Rarity == rarity.Name and def.Event == nil then
				table.insert(pool, def)
			end
		end
		local def = pool[rng:NextInteger(1, #pool)]
		if def.Price <= cash then
			if #slots < Economy.BaseSlots then
				cash -= def.Price
				table.insert(slots, def.Income)
			else
				table.sort(slots)
				if def.Income > slots[1] * 2 then
					cash -= def.Price
					cash += slots[1] * 10 * Economy.SellRefund -- rough sell value
					slots[1] = def.Income
				end
			end
		end
	end
	local minutes = t / 60
	print(string.format("      balance: first rebirth after ~%.0f min of solo play", minutes))
	assert(minutes > 15 and minutes < 180, "first rebirth at " .. minutes .. " min is outside 15-180")
end)

test("paid cash always beats free rewards, and bigger packs are better value", function()
	local function cash(perSecond: number, minutes: number, minimum: number): number
		return math.max(minimum, math.floor(perSecond * minutes * 60))
	end
	local products = Monetization.ProductByKey
	for _, perSecond in { 0, 2, 20, 200, 2000, 20000, 200000 } do
		-- Best single free payout at this income (free rewards use base income).
		local free = 0
		for day, minutes in Events.DailyIncomeMinutes do
			free = math.max(free, cash(perSecond, minutes, Events.DailyMinimumCash[day]))
		end
		for _, gift in Events.Gifts do
			if gift.Kind == "Cash" then
				free = math.max(free, cash(perSecond, gift.Minutes or 0, gift.Minimum or 0))
			end
		end
		for _, code in Codes.List do
			if code.Kind == "Cash" then
				free = math.max(free, cash(perSecond, code.Minutes or 0, code.Minimum or 0))
			end
		end
		for _, quest in Quests.Pool do
			free = math.max(free, cash(perSecond, quest.RewardMinutes, quest.RewardMinimum))
		end
		free = math.max(free, cash(perSecond, Economy.RaidVictoryMinutes, Economy.RaidVictoryMinimum))
		free = math.max(free, math.floor(perSecond * Economy.OfflineCapSeconds * Economy.OfflineEfficiency))
		-- Paid packs at worst case (no multipliers).
		local function paid(key: string): number
			local p = products[key]
			return cash(perSecond, p.CashMinutes or 0, p.CashMinimum or 0)
		end
		local small, medium, large, starter =
			paid("CashSmall"), paid("CashMedium"), paid("CashLarge"), paid("StarterPack")
		local label = " at $" .. perSecond .. "/s"
		assert(small >= free * 1.5, "Cash Bag " .. small .. " vs best free " .. free .. label)
		assert(starter >= free * 1.5, "Starter Pack " .. starter .. " vs best free " .. free .. label)
		assert(starter > small, "Starter Pack beats the Cash Bag" .. label)
		local function perRobux(key: string, amount: number): number
			return amount / products[key].SuggestedPrice
		end
		assert(perRobux("CashMedium", medium) >= perRobux("CashSmall", small), "Crate better value than Bag" .. label)
		assert(perRobux("CashLarge", large) >= perRobux("CashMedium", medium), "Vault better value than Crate" .. label)
		local mega = paid("CashMega")
		assert(perRobux("CashMega", mega) >= perRobux("CashLarge", large), "Mountain better value than Vault" .. label)
		assert(paid("EpicPack") >= free * 1.5, "Epic Pack beats free" .. label)
		assert(paid("RoyalPack") >= paid("EpicPack"), "Royal Pack beats Epic Pack" .. label)
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("unit tests failed")
end
