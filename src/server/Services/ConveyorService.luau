--!strict
-- The Slime Belt: random slimes ride down the middle of the map and any
-- player can buy one with cash (E) or, for Epic and above, with Robux (F).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Monetization = require(Shared.Config.Monetization)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Slimes = require(Shared.Config.Slimes)
local World = require(Shared.Config.World)
local Format = require(Shared.Util.Format)
local Weighted = require(Shared.Util.Weighted)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local NetService = require(script.Parent.NetService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)

-- A slime stays paused on the belt while its buyer's purchase dialog is
-- open, up to this long. The buyer still gets exactly what they saw even if
-- the receipt arrives after the hold ends.
local HOLD_SECONDS = 120
local FLY_SECONDS = 0.8
local MAX_BUY_DISTANCE = 20

type BeltSlime = {
	SlimeId: string,
	Mutation: string,
	Price: number,
	Model: Model,
	Tween: Tween,
	ReservedBy: Player?,
	Gone: boolean,
}

type Pending = {
	Entry: BeltSlime,
	SlimeId: string,
	Mutation: string,
	Rarity: string,
	HoldUntil: number,
}

local ConveyorService = {}

local belt: { BeltSlime } = {}
local pendingRobux: { [Player]: Pending } = {}
local rng = Random.new()

local function rollRarity(): Rarities.Rarity
	local luck = EventService.Luck()
	local picked = Weighted.Pick(Rarities.List, function(rarity: Rarities.Rarity)
		return rarity.Weight * (if rarity.Lucky then luck else 1)
	end, rng)
	return picked or Rarities.List[1]
end

local function eligible(event: string?): boolean
	return event == nil or EventService.SeasonalActive(event)
end

local function rollSlime(rarity: Rarities.Rarity): Slimes.SlimeDef
	local pool = {}
	for _, def in Slimes.List do
		if def.Rarity == rarity.Name and eligible(def.Event) and not def.MergeOnly and not def.RobuxOnly then
			table.insert(pool, def)
		end
	end
	if #pool == 0 then
		return Slimes.List[1]
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function rollMutation(): string
	local roll = rng:NextNumber()
	for _, mutation in Mutations.List do
		if eligible(mutation.Event) then
			if roll < mutation.Chance then
				return mutation.Id
			end
			roll -= mutation.Chance
		end
	end
	return ""
end

local function removeFromBelt(entry: BeltSlime)
	entry.Gone = true
	entry.Tween:Cancel()
	local index = table.find(belt, entry)
	if index then
		table.remove(belt, index)
	end
end

local function releaseReservation(entry: BeltSlime)
	entry.ReservedBy = nil
	if not entry.Gone then
		entry.Tween:Play()
	end
end

-- Ends the belt hold for a pending Robux purchase (if it still holds it).
local function releaseHold(player: Player, pending: Pending)
	if pending.Entry.ReservedBy == player then
		releaseReservation(pending.Entry)
	end
end

-- Prompts can be triggered from anywhere by exploiters; check distance.
local function nearEntry(player: Player, entry: BeltSlime): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local slimeRoot = entry.Model.PrimaryPart
	return root ~= nil
		and root:IsA("BasePart")
		and slimeRoot ~= nil
		and (root.Position - slimeRoot.Position).Magnitude <= MAX_BUY_DISTANCE
end

-- Moves the belt model into the buyer's base with a short flight, while the
-- real pedestal model stays hidden until it lands.
local function flyToBase(player: Player, entry: BeltSlime, slot: number)
	removeFromBelt(entry)
	local model = entry.Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		end
	end
	local target = PlotService.SlotCFrame(player, slot, entry.SlimeId)
	local root = model.PrimaryPart
	if not target or not root then
		model:Destroy()
		return
	end
	PlotService.SetCarried(player, slot, true)
	local start = root.CFrame
	local apex = start:Lerp(target, 0.5) + Vector3.new(0, 25, 0)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < FLY_SECONDS and model.Parent do
			local alpha = (os.clock() - t0) / FLY_SECONDS
			local a = start:Lerp(apex, alpha)
			local b = apex:Lerp(target, alpha)
			root.CFrame = a:Lerp(b, alpha)
			task.wait()
		end
		model:Destroy()
		if player.Parent then
			PlotService.SetCarried(player, slot, false)
		end
	end)
end

local function recordPurchase(player: Player, slimeId: string, mutation: string, price: number, how: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.Stats.SlimesBought += 1
	if data.Stats.SlimesBought == 1 then
		TelemetryService.Onboard(player, TelemetryService.Onboarding.BoughtFirstSlime)
	elseif data.Stats.SlimesBought == 2 then
		TelemetryService.Onboard(player, TelemetryService.Onboarding.BoughtSecondSlime)
	end
	local def = Slimes.ById[slimeId]
	local rarity = Rarities.ByName[def.Rarity]
	if rarity.Announce then
		NetService.Announce(
			player.DisplayName
				.. " got a "
				.. string.upper(def.Rarity)
				.. " "
				.. SlimeInfo.DisplayName(slimeId, mutation)
				.. "!",
			rarity.Color
		)
	end
	TelemetryService.Custom(player, "SlimeBought_" .. how, price)
end

local function buyWithCash(player: Player, entry: BeltSlime)
	if entry.Gone or not nearEntry(player, entry) then
		return
	end
	if entry.ReservedBy and entry.ReservedBy ~= player then
		NetService.Notify(player, "Someone is buying this one!", "Bad")
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local slot = EconomyService.FreeSlot(player)
	if not slot then
		NetService.Notify(player, "Your base is full! Sell a slime (hold F) or get more slots.", "Bad")
		if not PassService.Has(player, "ExtraSlots") then
			NetService.FxTo(
				player,
				"Offer",
				{ Pass = "ExtraSlots", Text = "Base full! +6 slots so you never miss a slime." }
			)
		end
		return
	end
	if not EconomyService.SpendCash(player, entry.Price, "BuySlime", entry.SlimeId) then
		NetService.Notify(player, "You need " .. Format.Cash(entry.Price - data.Cash) .. " more!", "Bad")
		return
	end
	local added = EconomyService.AddSlime(player, entry.SlimeId, entry.Mutation, "Belt", slot)
	if not added then
		-- Should not happen (slot checked above), but never take cash for nothing.
		EconomyService.AddCash(player, entry.Price, "Refund")
		return
	end
	local pending = pendingRobux[player]
	if pending and pending.Entry == entry then
		pendingRobux[player] = nil
	end
	recordPurchase(player, entry.SlimeId, entry.Mutation, entry.Price, "Cash")
	flyToBase(player, entry, added.Slot)
end

local function startRobuxPurchase(player: Player, entry: BeltSlime)
	local def = Slimes.ById[entry.SlimeId]
	local product = Monetization.BeltProductByRarity[def.Rarity]
	if entry.Gone or not product or product.Id == 0 or not nearEntry(player, entry) then
		return
	end
	if entry.ReservedBy and entry.ReservedBy ~= player then
		NetService.Notify(player, "Someone is buying this one!", "Bad")
		return
	end
	if not EconomyService.FreeSlot(player) then
		NetService.Notify(player, "Your base is full! Sell a slime (hold F) first.", "Bad")
		return
	end
	local previous = pendingRobux[player]
	if previous and previous.Entry ~= entry then
		releaseHold(player, previous)
	end
	entry.ReservedBy = player
	entry.Tween:Pause()
	pendingRobux[player] = {
		Entry = entry,
		SlimeId = entry.SlimeId,
		Mutation = entry.Mutation,
		Rarity = def.Rarity,
		HoldUntil = os.clock() + HOLD_SECONDS,
	}
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

local function addPrompts(entry: BeltSlime)
	local root = entry.Model.PrimaryPart :: BasePart
	local def = Slimes.ById[entry.SlimeId]
	local name = SlimeInfo.DisplayName(entry.SlimeId, entry.Mutation)

	local buy = Instance.new("ProximityPrompt")
	buy.Name = "BuyPrompt"
	buy.ActionText = "Buy " .. Format.Cash(entry.Price)
	buy.ObjectText = name
	buy.HoldDuration = 0
	buy.MaxActivationDistance = 14
	buy.RequiresLineOfSight = false
	buy.KeyboardKeyCode = Enum.KeyCode.E
	buy.Parent = root
	buy.Triggered:Connect(function(player: Player)
		buyWithCash(player, entry)
	end)

	local product = Monetization.BeltProductByRarity[def.Rarity]
	if product and product.Id ~= 0 then
		local robux = Instance.new("ProximityPrompt")
		robux.Name = "RobuxPrompt"
		robux.ActionText = "Instant Buy  R$" .. product.SuggestedPrice
		robux.ObjectText = name
		robux.HoldDuration = 0
		robux.MaxActivationDistance = 14
		robux.RequiresLineOfSight = false
		robux.KeyboardKeyCode = Enum.KeyCode.F
		robux.UIOffset = Vector2.new(0, 70)
		robux.Parent = root
		robux.Triggered:Connect(function(player: Player)
			startRobuxPurchase(player, entry)
		end)
	end
end

-- Slimes face the north plots so their faces are visible from the walkway.
local FACING = Vector3.new(0, 0, -1)

local function spawnSlime(forcedRarity: string?, startX: number?)
	if #belt >= World.MaxBeltSlimes then
		return
	end
	local rarity = if forcedRarity then Rarities.ByName[forcedRarity] else rollRarity()
	local def = rollSlime(rarity)
	local mutation = rollMutation()
	local price = SlimeInfo.Price(def.Id, mutation)

	local model = SlimeBuilder.Build(def.Id, mutation, { PriceText = Format.Cash(price) })
	local y = World.BeltY + SlimeBuilder.HalfHeight(def.Id)
	local startPos = Vector3.new(startX or World.BeltStartX + 2, y, 0)
	local endPos = Vector3.new(World.BeltEndX - 2, y, 0)
	model:PivotTo(CFrame.lookAt(startPos, startPos + FACING))
	model.Parent = workspace

	local root = model.PrimaryPart :: BasePart
	local duration = math.max(1, (endPos - startPos).Magnitude / World.BeltSpeed)
	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(endPos, endPos + FACING) }
	)
	local entry: BeltSlime = {
		SlimeId = def.Id,
		Mutation = mutation,
		Price = price,
		Model = model,
		Tween = tween,
		ReservedBy = nil,
		Gone = false,
	}
	table.insert(belt, entry)
	addPrompts(entry)
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not entry.Gone and not entry.ReservedBy then
			removeFromBelt(entry)
			model:Destroy()
		end
	end)
	tween:Play()

	if rarity.Announce then
		local prefix = if rarity.Name == "Secret" then "‼️ A SECRET" else "A " .. string.upper(rarity.Name)
		NetService.Announce(
			prefix .. " " .. SlimeInfo.DisplayName(def.Id, mutation) .. " is on the belt!",
			rarity.Color
		)
	end
end

-- Called by MonetizationService when a belt product receipt arrives.
-- Returns a description of what was granted, or nil if the player's data is
-- not available (receipt will be retried).
function ConveyorService.GrantBeltProduct(player: Player, rarityName: string): string?
	if not DataService.Get(player) then
		return nil
	end
	local pending = pendingRobux[player]
	local entry: BeltSlime? = nil
	local slimeId, mutation
	if pending and pending.Rarity == rarityName then
		-- Grant exactly what the player saw, even if the belt hold ended.
		slimeId, mutation = pending.SlimeId, pending.Mutation
		if not pending.Entry.Gone and pending.Entry.ReservedBy == player then
			entry = pending.Entry
		end
	else
		-- No matching purchase on record (e.g. the server restarted mid
		-- purchase): grant the first standard slime of the purchased rarity,
		-- never a random one.
		if pending then
			releaseHold(player, pending)
		end
		local fallback = Slimes.List[1]
		for _, def in Slimes.List do
			if def.Rarity == rarityName and def.Event == nil and not def.MergeOnly and not def.RobuxOnly then
				fallback = def
				break
			end
		end
		slimeId, mutation = fallback.Id, ""
	end
	pendingRobux[player] = nil

	local added = EconomyService.AddSlime(player, slimeId, mutation, "Robux")
	if not added then
		local value = SlimeInfo.Price(slimeId, mutation)
		EconomyService.AddCash(player, value, "RobuxFallback", slimeId)
		NetService.Notify(player, "Your base was full, so you got " .. Format.Cash(value) .. " instead!", "Money")
		if entry then
			releaseReservation(entry)
		end
		return "cash:" .. slimeId
	end
	recordPurchase(player, slimeId, mutation, SlimeInfo.Price(slimeId, mutation), "Robux")
	if entry then
		flyToBase(player, entry, added.Slot)
	end
	return slimeId
end

-- The cheapest belt slime the player can afford, for the tutorial arrow.
function ConveyorService.CheapestAffordable(cash: number): Model?
	local best: BeltSlime? = nil
	for _, entry in belt do
		if
			not entry.Gone
			and not entry.ReservedBy
			and entry.Price <= cash
			and (best == nil or entry.Price < best.Price)
		then
			best = entry
		end
	end
	return if best then best.Model else nil
end

function ConveyorService.SpawnRarity(rarityName: string)
	spawnSlime(rarityName)
end

function ConveyorService.Init()
	MarketplaceService.PromptProductPurchaseFinished:Connect(
		function(userId: number, productId: number, purchased: boolean)
			local player = Players:GetPlayerByUserId(userId)
			local product = Monetization.ProductById[productId]
			if not player or not product or product.Kind ~= "BeltSlime" then
				return
			end
			local pending = pendingRobux[player]
			if pending and not purchased then
				pendingRobux[player] = nil
				releaseHold(player, pending)
			end
		end
	)
	Players.PlayerRemoving:Connect(function(player)
		local pending = pendingRobux[player]
		if pending then
			pendingRobux[player] = nil
			releaseHold(player, pending)
		end
	end)
end

function ConveyorService.Start()
	-- Pre-fill the belt so the first thing new players see is slimes to buy,
	-- with a few cheap ones guaranteed for the tutorial.
	local spacing = (World.BeltEndX - World.BeltStartX - 20) / 12
	for i = 1, 12 do
		spawnSlime(if i % 3 == 0 then "Common" else nil, World.BeltStartX + 2 + (i - 1) * spacing)
	end

	task.spawn(function()
		while true do
			task.wait(World.SpawnEverySeconds / EventService.SpawnSpeedup())
			spawnSlime()
			-- Let held slimes move on if a purchase dialog stays open too long.
			-- The pending record stays, so a late receipt still grants it.
			local t = os.clock()
			for player, pending in pendingRobux do
				if t > pending.HoldUntil then
					releaseHold(player, pending)
				end
			end
			-- Parked slimes at the end of the belt whose reservation ended.
			for _, entry in table.clone(belt) do
				if not entry.ReservedBy and entry.Tween.PlaybackState == Enum.PlaybackState.Completed then
					removeFromBelt(entry)
					entry.Model:Destroy()
				end
			end
		end
	end)
end

return ConveyorService
