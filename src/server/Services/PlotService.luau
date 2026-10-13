--!strict
-- Base ownership: assigns each player a plot, shows their slimes on the
-- pedestals (sized by merge tier and growth), handles collect pads, selling,
-- merging (three of a kind -> Giant -> Colossal) and the base lock.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Slimes = require(Shared.Config.Slimes)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)

local DataTemplate = require(script.Parent.Parent.DataTemplate)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PassService = require(script.Parent.PassService)
local TelemetryService = require(script.Parent.TelemetryService)
local WorldService = require(script.Parent.WorldService)
local EventService = require(script.Parent.EventService)

type Plot = WorldService.Plot
type PlayerData = DataTemplate.PlayerData

local PlotService = {}
PlotService.PlotAssigned = Signal.new() -- (player, plot)
PlotService.StealRequested = Signal.new() -- (thief, owner, slot)
PlotService.Locked = Signal.new() -- (player)

type LockState = { EndsAt: number, ReadyAt: number }

local ownerOf: { [Plot]: Player } = {}
local plotOf: { [Player]: Plot } = {}
local rendered: { [Player]: { [number]: Model } } = {}
local carried: { [Player]: { [number]: boolean } } = {}
local locks: { [Player]: LockState } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function PlotService.GetPlot(player: Player): Plot?
	return plotOf[player]
end

function PlotService.GetOwner(plot: Plot): Player?
	return ownerOf[plot]
end

function PlotService.IsLocked(player: Player): boolean
	local lock = locks[player]
	return lock ~= nil and now() < lock.EndsAt
end

function PlotService.SlotCFrame(player: Player, slot: number, slimeId: string, scale: number?): CFrame?
	local plot = plotOf[player]
	if not plot or not plot.Pedestals[slot] then
		return nil
	end
	return WorldService.PedestalTop(plot, slot) + Vector3.new(0, SlimeBuilder.HalfHeight(slimeId, scale), 0)
end

local function pushLockState(player: Player)
	local lock = locks[player]
	NetService.SendState(player, {
		LockEndsAt = if lock then lock.EndsAt else 0,
		LockReadyAt = if lock then lock.ReadyAt else 0,
	})
end

local doMerge: (Player, number) -> ()

local function addPrompts(
	model: Model,
	owner: Player,
	plot: Plot,
	slot: number,
	slimeId: string,
	mutation: string,
	tier: number?
)
	local root = model.PrimaryPart :: BasePart
	local name = SlimeInfo.DisplayName(slimeId, mutation, tier)

	-- Merge: only shown to the owner, and only when they have three alike.
	local merge = Instance.new("ProximityPrompt")
	merge.Name = "MergePrompt"
	merge.ActionText = "MERGE x3"
	merge.ObjectText = name
	merge.HoldDuration = 0.4
	merge.MaxActivationDistance = 9
	merge.RequiresLineOfSight = false
	merge.KeyboardKeyCode = Enum.KeyCode.R
	merge.UIOffset = Vector2.new(0, 90)
	merge:SetAttribute("OwnerUserId", owner.UserId)
	merge:SetAttribute("CanMerge", false)
	CollectionService:AddTag(merge, "MergePrompt")
	merge.Parent = root
	merge.Triggered:Connect(function(who: Player)
		if who == owner then
			doMerge(owner, slot)
		end
	end)

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Steal"
	steal.ObjectText = name
	steal.HoldDuration = Economy.StealHoldSeconds
	steal.MaxActivationDistance = 9
	steal.RequiresLineOfSight = false
	steal.KeyboardKeyCode = Enum.KeyCode.E
	steal:SetAttribute("OwnerUserId", owner.UserId)
	steal:SetAttribute("PlotIndex", plot.Index)
	CollectionService:AddTag(steal, "StealPrompt")
	steal.Parent = root
	steal.Triggered:Connect(function(thief: Player)
		PlotService.StealRequested:Fire(thief, owner, slot)
	end)

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell " .. Format.Cash(SlimeInfo.Price(slimeId, mutation, tier) * Economy.SellRefund)
	sell.ObjectText = name
	sell.HoldDuration = 1.5
	sell.MaxActivationDistance = 9
	sell.RequiresLineOfSight = false
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell:SetAttribute("OwnerUserId", owner.UserId)
	CollectionService:AddTag(sell, "SellPrompt")
	sell.Parent = root
	sell.Triggered:Connect(function(who: Player)
		if who == owner and not (carried[owner] and carried[owner][slot]) then
			EconomyService.Sell(owner, slot)
		end
	end)
end

-- Brings the plot's pedestals and slime models in line with saved data.
function PlotService.Render(player: Player)
	local plot = plotOf[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local models = rendered[player]
	if not models then
		models = {}
		rendered[player] = models
	end
	local maxSlots = EconomyService.MaxSlots(player)
	local bySlot: { [number]: DataTemplate.SlotData } = {}
	for _, slotData in data.Slots do
		bySlot[slotData.Slot] = slotData
	end
	local carriedSlots = carried[player] or {}

	for slot = 1, #plot.Pedestals do
		local unlocked = slot <= maxSlots
		plot.Pedestals[slot].Transparency = if unlocked then 0 else 0.8
		plot.CollectPads[slot].Transparency = if unlocked then 0 else 1

		local want = bySlot[slot]
		local model: Model? = models[slot]
		local wantVisible = want ~= nil and not carriedSlots[slot]
		local matches = model ~= nil
			and want ~= nil
			and model:GetAttribute("SlimeId") == want.Id
			and model:GetAttribute("Mutation") == want.Mutation
			and model:GetAttribute("Tier") == (want.Tier or 1)
			and math.abs((model:GetAttribute("Scale") :: number? or 1) - SlimeInfo.Scale(want.Tier, want.Age))
				< 0.06
		if wantVisible and matches then
			continue
		end
		-- Same slime and tier, just bigger: it grew (not a merge or a swap).
		local grew = model ~= nil
			and want ~= nil
			and model:GetAttribute("SlimeId") == want.Id
			and model:GetAttribute("Tier") == (want.Tier or 1)
		if model then
			model:Destroy()
			models[slot] = nil
		end
		if wantVisible and want then
			local newModel = SlimeBuilder.Build(want.Id, want.Mutation, { Tier = want.Tier, Age = want.Age })
			local target = PlotService.SlotCFrame(player, slot, want.Id, newModel:GetAttribute("Scale") :: number? or 1)
			if target then
				newModel:PivotTo(target)
			end
			addPrompts(newModel, player, plot, slot, want.Id, want.Mutation, want.Tier)
			newModel.Parent = plot.Model
			if grew and target then
				-- Same slime, bigger: it grew a size.
				NetService.Fx("Grow", { Position = target.Position, Scale = newModel:GetAttribute("Scale") })
			end
			models[slot] = newModel
		end
	end
	-- Which slimes can merge right now (the owner sees a MERGE prompt).
	for slot, model in models do
		local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("MergePrompt")
		if prompt then
			prompt:SetAttribute("CanMerge", EconomyService.MergePartners(player, slot, carriedSlots) ~= nil)
		end
	end
end

doMerge = function(player: Player, slot: number)
	local plot = plotOf[player]
	local target = EconomyService.GetSlot(player, slot)
	if not plot or not target or (carried[player] and carried[player][slot]) then
		return
	end
	local fromIds = target.Id
	local from = {}
	local partners = EconomyService.MergePartners(player, slot, carried[player])
	if not partners then
		NetService.Notify(player, "You need 3 of the same slime to merge!", "Bad")
		return
	end
	for _, other in partners do
		local cf = PlotService.SlotCFrame(player, other.Slot, other.Id, SlimeInfo.Scale(other.Tier, other.Age))
		if cf then
			table.insert(from, cf.Position)
		end
	end
	local consumed, special = EconomyService.Merge(player, slot, carried[player])
	if not consumed then
		return
	end
	PlotService.Render(player)
	local merged = EconomyService.GetSlot(player, slot)
	if not merged then
		return
	end
	local scale = SlimeInfo.Scale(merged.Tier, merged.Age)
	local to = PlotService.SlotCFrame(player, slot, merged.Id, scale)
	local name = SlimeInfo.DisplayName(merged.Id, merged.Mutation, merged.Tier)
	local def = Slimes.ById[merged.Id]
	local rarity = def and Rarities.ByName[def.Rarity]
	NetService.Fx("Merge", {
		From = from,
		To = if to then to.Position else nil,
		Name = name,
		Color = if rarity then rarity.Color else Color3.new(1, 1, 1),
		Special = special,
		Halloween = EventService.SeasonalActive("Halloween"),
		Owner = player.UserId,
	})
	if special or (merged.Tier or 1) >= 3 then
		NetService.Announce(
			"🧪 " .. player.DisplayName .. " brewed a " .. name .. "!",
			if rarity then rarity.Color else Color3.new(1, 1, 1)
		)
	else
		NetService.Notify(player, "🧪 Merged into " .. name .. "!", "Good")
	end
	if not PassService.Has(player, "AutoCollect") then
		task.delay(2.5, function()
			if player.Parent then
				NetService.FxTo(player, "Offer", {
					Pass = "AutoCollect",
					Text = "Your " .. name .. " makes a lot! Auto Collect sends it straight to your wallet.",
				})
			end
		end)
	end
	local _ = fromIds
end

-- Hides a slot's slime while a thief carries it (true) or shows it again.
function PlotService.SetCarried(player: Player, slot: number, isCarried: boolean)
	local set = carried[player]
	if not set then
		set = {}
		carried[player] = set
	end
	if isCarried then
		set[slot] = true
	else
		set[slot] = nil
	end
	PlotService.Render(player)
end

local function setBarrier(plot: Plot, locked: boolean)
	plot.Barrier.Transparency = if locked then 0.35 else 1
	plot.Barrier.CanCollide = locked
	plot.Model:SetAttribute("Locked", locked)
end

-- Locks the player's base. `force` skips the cooldown (Instant Lock).
function PlotService.Lock(player: Player, force: boolean?): boolean
	local plot = plotOf[player]
	if not plot then
		return false
	end
	local t = now()
	local lock = locks[player]
	if lock and t < lock.EndsAt and not force then
		NetService.Notify(player, "Your base is already locked!", "Info")
		return false
	end
	if lock and t < lock.ReadyAt and not force then
		NetService.Notify(player, "Lock recharging: " .. Format.Time(lock.ReadyAt - t), "Bad")
		return false
	end
	local duration = if PassService.Has(player, "LongLock") then Economy.LockSecondsLongPass else Economy.LockSeconds
	-- A forced lock while already locked extends the current lock.
	local startsAt = if lock and t < lock.EndsAt then lock.EndsAt else t
	local newLock = { EndsAt = startsAt + duration, ReadyAt = startsAt + duration + Economy.LockCooldownSeconds }
	locks[player] = newLock
	setBarrier(plot, true)
	pushLockState(player)
	NetService.Notify(player, "🔒 Base locked for " .. duration .. "s!", "Good")
	TelemetryService.Onboard(player, TelemetryService.Onboarding.LockedBase)
	PlotService.Locked:Fire(player)

	task.delay(newLock.EndsAt - t, function()
		if locks[player] == newLock and plotOf[player] == plot then
			setBarrier(plot, false)
			NetService.Notify(player, "🔓 Your base is unlocked!", "Bad")
		end
	end)
	return true
end

local function assign(player: Player, _data: PlayerData)
	local free: Plot? = nil
	for _, plot in WorldService.Plots do
		if not ownerOf[plot] then
			free = plot
			break
		end
	end
	if not free then
		player:Kick("This server is full, please join another one!")
		return
	end
	local plot = free :: Plot
	ownerOf[plot] = player
	plotOf[player] = plot
	plot.OwnerLabel.Text = player.DisplayName .. "'s Base"
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	setBarrier(plot, false)
	PlotService.Render(player)
	pushLockState(player)
	PlotService.PlotAssigned:Fire(player, plot)
end

local function release(player: Player)
	local plot = plotOf[player]
	if plot then
		ownerOf[plot] = nil
		plot.OwnerLabel.Text = "Empty Base"
		plot.StatusLabel.Text = ""
		plot.Model:SetAttribute("OwnerUserId", nil)
		setBarrier(plot, false)
		for slot, label in plot.PadLabels do
			label.Text = ""
			plot.Pedestals[slot].Transparency = 0
			plot.CollectPads[slot].Transparency = 0
		end
	end
	local models = rendered[player]
	if models then
		for _, model in models do
			model:Destroy()
		end
	end
	rendered[player] = nil
	carried[player] = nil
	locks[player] = nil
	plotOf[player] = nil
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

local function connectPads(plot: Plot)
	for slot, pad in plot.CollectPads do
		pad.CanTouch = true
		pad.Touched:Connect(function(hit: BasePart)
			local player = playerFromHit(hit)
			if player and ownerOf[plot] == player then
				local amount = EconomyService.Collect(player, slot)
				if amount > 0 then
					plot.PadLabels[slot].Text = ""
					NetService.FxTo(player, "Cash", { Position = pad.Position, Amount = amount })
				end
			end
		end)
	end
	plot.LockPad.CanTouch = true
	plot.LockPad.Touched:Connect(function(hit: BasePart)
		local player = playerFromHit(hit)
		local lock = player and locks[player]
		if player and ownerOf[plot] == player and not (lock and now() < lock.ReadyAt) then
			PlotService.Lock(player)
		end
	end)
end

local function updateLabels()
	local t = now()
	for plot, player in ownerOf do
		local data = DataService.Get(player)
		if data then
			local auto = PassService.Has(player, "AutoCollect")
			local stored: { [number]: number } = {}
			for _, slotData in data.Slots do
				stored[slotData.Slot] = slotData.Stored
			end
			for slot, label in plot.PadLabels do
				local amount = stored[slot]
				if amount == nil then
					label.Text = ""
				elseif auto then
					label.Text = "AUTO"
				else
					label.Text = Format.Cash(amount)
				end
			end
		end
		local lock = locks[player]
		if lock and t < lock.EndsAt then
			plot.StatusLabel.Text = "🔒 LOCKED " .. Format.Time(lock.EndsAt - t)
		else
			plot.StatusLabel.Text = ""
		end
	end
end

function PlotService.Init()
	for _, plot in WorldService.Plots do
		connectPads(plot)
	end
	DataService.ProfileLoaded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	EconomyService.SlotsChanged:Connect(function(player: Player)
		PlotService.Render(player)
	end)
	EconomyService.Collected:Connect(function(player: Player)
		TelemetryService.Onboard(player, TelemetryService.Onboarding.CollectedCash)
	end)
	-- A rare slime landing in a base gets a celebration everyone sees.
	EconomyService.SlimeAdded:Connect(function(player: Player, slotData, source: string)
		local def = Slimes.ById[slotData.Id]
		local rarity = def and Rarities.ByName[def.Rarity]
		if rarity and rarity.Order >= 4 and source ~= "Returned" then
			local cf = PlotService.SlotCFrame(player, slotData.Slot, slotData.Id)
			NetService.Fx("Rare", {
				Position = if cf then cf.Position else nil,
				Name = SlimeInfo.DisplayName(slotData.Id, slotData.Mutation, slotData.Tier),
				Rarity = rarity.Name,
				Color = rarity.Color,
				Owner = player.UserId,
			})
		end
	end)
	NetService.OnAction("Lock", function(player: Player)
		PlotService.Lock(player)
	end)
end

function PlotService.Start()
	task.spawn(function()
		while true do
			updateLabels()
			task.wait(0.5)
		end
	end)
	-- Slimes grow: resize the ones that have grown a step, and keep their
	-- income tags current.
	task.spawn(function()
		while true do
			task.wait(5)
			for player in plotOf do
				PlotService.Render(player)
				local models = rendered[player]
				if models then
					for slot, model in models do
						local slotData = EconomyService.GetSlot(player, slot)
						local info = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info")
						local income = info and info:FindFirstChild("Income")
						if slotData and income and income:IsA("TextLabel") then
							local value = SlimeInfo.Income(slotData.Id, slotData.Mutation, slotData.Tier, slotData.Age)
							local grown = math.floor(SlimeInfo.Growth(slotData.Age) * 100)
							income.Text = Format.Cash(value)
								.. "/s"
								.. (if grown > 0 then "  🌱" .. grown .. "%" else "")
						end
					end
				end
			end
		end
	end)
end

return PlotService
