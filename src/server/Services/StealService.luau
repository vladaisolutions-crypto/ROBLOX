--!strict
-- Stealing and bonking. A thief holds E on someone else's slime, carries it
-- over their head (slower), and must reach their own base. The owner (or
-- anyone) can bonk the thief with the bat to make them drop it.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PassService = require(script.Parent.PassService)
local PlotService = require(script.Parent.PlotService)
local TelemetryService = require(script.Parent.TelemetryService)
local WorldService = require(script.Parent.WorldService)

type Carry = {
	Owner: Player,
	Slot: number,
	SlimeId: string,
	Mutation: string,
	Model: Model,
	StartedAt: number,
	StartPosition: Vector3,
}

local StealService = {}

local carries: { [Player]: Carry } = {}
local lastBonk: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function StealService.WalkSpeed(player: Player): number
	local boots = PassService.Has(player, "SpeedBoots")
	local speed = if boots then Economy.WalkSpeedBoots else Economy.WalkSpeed
	if carries[player] then
		speed *= if boots then Economy.CarrySpeedFactorBoots else Economy.CarrySpeedFactor
	end
	return speed
end

local function applySpeed(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = StealService.WalkSpeed(player)
	end
end

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

-- Ends a carry. If `delivered` is false the slime goes back to its owner.
local function finish(thief: Player, delivered: boolean, reason: string?)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil
	carry.Model:Destroy()
	if thief.Parent then
		applySpeed(thief)
	end
	local owner = carry.Owner
	local name = SlimeInfo.DisplayName(carry.SlimeId, carry.Mutation)

	if delivered and owner.Parent and thief.Parent then
		local slotData = EconomyService.RemoveSlime(owner, carry.Slot)
		PlotService.SetCarried(owner, carry.Slot, false)
		if slotData then
			local added = EconomyService.AddSlime(thief, slotData.Id, slotData.Mutation, "Steal")
			-- Uncollected cash on the pedestal stays with the owner.
			EconomyService.AddCash(owner, slotData.Stored, "Income")
			if added then
				local thiefData, ownerData = DataService.Get(thief), DataService.Get(owner)
				if thiefData then
					thiefData.Stats.Steals += 1
				end
				if ownerData then
					ownerData.Stats.StolenFrom += 1
				end
				TelemetryService.Onboard(thief, TelemetryService.Onboarding.FirstSteal)
				TelemetryService.Custom(thief, "Steal", SlimeInfo.Price(slotData.Id, slotData.Mutation))
				NetService.Notify(thief, "😈 You stole " .. name .. "!", "Good")
				NetService.Notify(
					owner,
					"💢 " .. thief.DisplayName .. " stole your " .. name .. "! Steal it back!",
					"Bad"
				)
			else
				-- Thief's base filled up during the run: give it back.
				EconomyService.AddSlime(owner, slotData.Id, slotData.Mutation, "Returned", carry.Slot)
				NetService.Notify(thief, "Your base is full! The slime ran home.", "Bad")
			end
		end
		return
	end

	if owner.Parent then
		PlotService.SetCarried(owner, carry.Slot, false)
		NetService.Notify(owner, "✅ Your " .. name .. " is safe!", "Good")
	end
	if thief.Parent and reason then
		NetService.Notify(thief, reason, "Bad")
	end
end

local function startSteal(thief: Player, owner: Player, slot: number)
	if thief == owner or carries[thief] then
		return
	end
	for _, carry in carries do
		if carry.Owner == owner and carry.Slot == slot then
			return -- someone already has it
		end
	end
	if PlotService.IsLocked(owner) then
		NetService.Notify(thief, "🔒 This base is locked!", "Bad")
		return
	end
	local slotData = EconomyService.GetSlot(owner, slot)
	local thiefRoot = rootOf(thief)
	local humanoid = humanoidOf(thief)
	local ownerPlot = PlotService.GetPlot(owner)
	if not slotData or not thiefRoot or not humanoid or humanoid.Health <= 0 or not ownerPlot then
		return
	end
	if not PlotService.GetPlot(thief) then
		return
	end
	if not EconomyService.FreeSlot(thief) then
		NetService.Notify(thief, "Your base is full! Sell a slime first.", "Bad")
		return
	end
	local slimeCFrame = PlotService.SlotCFrame(owner, slot, slotData.Id)
	if not slimeCFrame or (slimeCFrame.Position - thiefRoot.Position).Magnitude > 14 then
		return
	end

	local model = SlimeBuilder.Build(slotData.Id, slotData.Mutation)
	local root = model.PrimaryPart :: BasePart
	local height = SlimeBuilder.HalfHeight(slotData.Id)
	model:PivotTo(thiefRoot.CFrame * CFrame.new(0, 3.5 + height, 0))
	root.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = thiefRoot
	weld.Part1 = root
	weld.Parent = root
	model.Parent = workspace

	carries[thief] = {
		Owner = owner,
		Slot = slot,
		SlimeId = slotData.Id,
		Mutation = slotData.Mutation,
		Model = model,
		StartedAt = os.clock(),
		StartPosition = thiefRoot.Position,
	}
	PlotService.SetCarried(owner, slot, true)
	applySpeed(thief)

	local name = SlimeInfo.DisplayName(slotData.Id, slotData.Mutation)
	NetService.Notify(thief, "🏃 Run back to your base with " .. name .. "!", "Info")
	NetService.Notify(owner, "⚠️ " .. thief.DisplayName .. " is stealing your " .. name .. "! BONK them!", "Bad")
end

local function makeBat(golden: boolean): Tool
	local tool = Instance.new("Tool")
	tool.Name = if golden then "Golden Bat" else "Bonk Bat"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Bonk thieves to make them drop slimes!"
	tool.Grip = CFrame.new(0, 0, -1.6)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.7, 4.2)
	handle.Color = if golden then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(150, 100, 60)
	handle.Material = if golden then Enum.Material.Foil else Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

local function giveBat(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	-- Remove old bats, including one currently held (it lives in the character).
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and (item.Name == "Bonk Bat" or item.Name == "Golden Bat") then
				item:Destroy()
			end
		end
	end
	local golden = PassService.Has(player, "GoldenBat")
	local tool = makeBat(golden)
	tool.Activated:Connect(function()
		StealService.Bonk(player, golden)
	end)
	tool.Parent = backpack
end

function StealService.Bonk(attacker: Player, golden: boolean)
	local t = os.clock()
	if t - (lastBonk[attacker] or 0) < Economy.BonkCooldown then
		return
	end
	lastBonk[attacker] = t
	local attackerRoot = rootOf(attacker)
	if not attackerRoot then
		return
	end
	local character = attacker.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		-- The default Animate script plays a slash when it sees this value.
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		Debris:AddItem(anim, 0.2)
	end

	local range = if golden then Economy.BonkRangeGolden else Economy.BonkRange
	local force = if golden then Economy.BonkForceGolden else Economy.BonkForce
	for _, target in Players:GetPlayers() do
		local targetRoot = rootOf(target)
		if target ~= attacker and targetRoot then
			local offset = targetRoot.Position - attackerRoot.Position
			local distance = offset.Magnitude
			local inFront = distance < 3 or attackerRoot.CFrame.LookVector:Dot(offset.Unit) > 0.2
			if distance <= range and inFront then
				local direction = Vector3.new(offset.X, 0, offset.Z)
				direction = if direction.Magnitude > 0.01 then direction.Unit else attackerRoot.CFrame.LookVector
				Remotes.Get("Knockback")
					:FireClient(target, direction * force + Vector3.new(0, force * 0.45, 0), Economy.BonkStunSeconds)
				if carries[target] then
					finish(target, false, "💥 " .. attacker.DisplayName .. " bonked you! You dropped the slime.")
					NetService.Notify(attacker, "💥 You made " .. target.DisplayName .. " drop it!", "Good")
				end
			end
		end
	end
end

function StealService.Init()
	PlotService.StealRequested:Connect(startSteal)
	Players.PlayerRemoving:Connect(function(player)
		finish(player, false)
		for thief, carry in carries do
			if carry.Owner == player then
				-- Owner left: cancel so the slime can't be duplicated.
				finish(thief, false, "The owner left, so the slime vanished!")
			end
		end
		lastBonk[player] = nil
	end)
	PassService.Changed:Connect(function(player: Player, key: string)
		if key == "GoldenBat" then
			giveBat(player)
		elseif key == "SpeedBoots" then
			applySpeed(player)
		end
	end)
end

-- Called by CharacterService after each spawn.
function StealService.OnCharacter(player: Player)
	finish(player, false)
	giveBat(player)
	applySpeed(player)
end

function StealService.Start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for thief, carry in carries do
				local root = rootOf(thief)
				local humanoid = humanoidOf(thief)
				if not root or not humanoid or humanoid.Health <= 0 then
					finish(thief, false, "You dropped the slime!")
				elseif os.clock() - carry.StartedAt > Economy.CarryTimeoutSeconds then
					finish(thief, false, "Too slow! The slime escaped.")
				else
					local plot = PlotService.GetPlot(thief)
					if plot and WorldService.PlotContains(plot, root.Position) then
						-- Character positions are client-controlled: arriving faster
						-- than anyone can run means a teleport exploit.
						local fastest = (root.Position - carry.StartPosition).Magnitude / (Economy.WalkSpeedBoots * 1.5)
						if os.clock() - carry.StartedAt < fastest then
							finish(thief, false, "The slime slipped away!")
						else
							finish(thief, true)
						end
					end
				end
			end
		end
	end)
end

return StealService
