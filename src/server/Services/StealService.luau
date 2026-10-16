--!strict
-- Stealing and bonking. A thief holds E on someone else's slime, carries it
-- over their head (slower), and must reach their own base. The owner (or
-- anyone) can bonk the thief with the bat to make them drop it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
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
	Tier: number?,
	Age: number?,
	Model: Model,
	StartedAt: number,
	StartPosition: Vector3,
}

local StealService = {}

-- (attacker, attackerRoot, range, force) at the moment a bat swing connects,
-- so other things (NPC thieves) can be hit too.
StealService.Swung = Signal.new()

local carries: { [Player]: Carry } = {}
local lastBonk: { [Player]: number } = {}
-- Characters currently ragdolled, with a token so a newer bonk wins.
local ragdolled: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Ragdoll a character for `seconds`: every joint except the root becomes a
-- limited ball socket and the limbs collide, so a bonked player flops and
-- tumbles for real (and everyone sees it). The parts are handed back to the
-- victim's client, which owns its character physics and applies the launch.
local function ragdoll(target: Player, seconds: number): boolean
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false
	end
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	local token = (ragdolled[character] or 0) + 1
	ragdolled[character] = token

	for _, joint in character:GetDescendants() do
		-- Current avatar rigs: kinematic AnimationConstraints, each with a
		-- ball socket beside it. Switching the animated joint off is the ragdoll.
		if joint:IsA("AnimationConstraint") and joint.Name ~= "Root" then
			local a0 = joint.Attachment0
			local a1 = joint.Attachment1
			if a0 and a1 and a1.Parent then
				local part1 = a1.Parent
				local existing = part1:FindFirstChildOfClass("BallSocketConstraint")
				if existing then
					existing.Enabled = true
				else
					local ball = Instance.new("BallSocketConstraint")
					ball.Name = "RagdollSocket" .. joint.Name
					ball.Attachment0, ball.Attachment1 = a0, a1
					ball.LimitsEnabled = true
					ball.UpperAngle = 70
					ball.TwistLimitsEnabled = true
					ball.TwistLowerAngle, ball.TwistUpperAngle = -45, 45
					ball.Parent = part1
				end
				joint.Enabled = false
			end
		end
	end
	for _, motor in character:GetDescendants() do
		if motor:IsA("Motor6D") and motor.Part0 and motor.Part1 and motor.Part0 ~= root and motor.Part1 ~= root then
			local part0, part1 = motor.Part0 :: BasePart, motor.Part1 :: BasePart
			local socket = part1:FindFirstChild("RagdollSocket" .. motor.Name)
			if not socket then
				local a0 = Instance.new("Attachment")
				a0.Name = "RagdollA" .. motor.Name
				a0.CFrame = motor.C0
				a0.Parent = part0
				local a1 = Instance.new("Attachment")
				a1.Name = "RagdollB" .. motor.Name
				a1.CFrame = motor.C1
				a1.Parent = part1
				local ball = Instance.new("BallSocketConstraint")
				ball.Name = "RagdollSocket" .. motor.Name
				ball.Attachment0, ball.Attachment1 = a0, a1
				ball.LimitsEnabled = true
				ball.UpperAngle = if motor.Name:find("Neck") then 35 else 70
				ball.TwistLimitsEnabled = true
				ball.TwistLowerAngle, ball.TwistUpperAngle = -45, 45
				ball.Restitution = 0.1
				ball.Enabled = false
				ball.Parent = part1
				local noCollide = Instance.new("NoCollisionConstraint")
				noCollide.Part0, noCollide.Part1 = part0, part1
				noCollide.Parent = part1
				socket = ball
			end
			if socket and socket:IsA("BallSocketConstraint") then
				socket.Enabled = true
			end
			motor.Enabled = false
		end
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part ~= root and not part:FindFirstAncestorOfClass("Accessory") then
			if part:GetAttribute("RagdollCollide") == nil then
				part:SetAttribute("RagdollCollide", part.CanCollide)
			end
			part.CanCollide = true
		end
	end
	-- Splitting the joints makes new assemblies; give them all to the victim.
	RunService.Heartbeat:Wait()
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored then
			pcall(part.SetNetworkOwner, part, target)
		end
	end

	task.delay(seconds, function()
		if ragdolled[character] ~= token or not character.Parent then
			return
		end
		ragdolled[character] = nil
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") then
				item.Enabled = true
			elseif item:IsA("AnimationConstraint") then
				item.Enabled = true
			elseif item:IsA("BallSocketConstraint") and item.Name:sub(1, 13) == "RagdollSocket" then
				item.Enabled = false
			elseif item:IsA("BasePart") then
				local collide = item:GetAttribute("RagdollCollide")
				if type(collide) == "boolean" then
					item.CanCollide = collide
				end
			end
		end
	end)
	return true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local speedBoost = 1

function StealService.WalkSpeed(player: Player): number
	local boots = PassService.Has(player, "SpeedBoots")
	local speed = if boots then Economy.WalkSpeedBoots else Economy.WalkSpeed
	local carry = carries[player]
	if carry then
		speed *= if boots then Economy.CarrySpeedFactorBoots else Economy.CarrySpeedFactor
		-- A big (grown or merged) slime is heavy: easier to catch.
		if SlimeInfo.Scale(carry.Tier, carry.Age) > 1.3 then
			speed *= Economy.BigCarrySpeedFactor
		end
	end
	return speed * speedBoost
end

local function applySpeed(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = StealService.WalkSpeed(player)
	end
end

-- Server-wide speed multiplier (the Speed Frenzy chaos event).
function StealService.SetSpeedBoost(multiplier: number)
	speedBoost = multiplier
	for _, player in Players:GetPlayers() do
		applySpeed(player)
	end
end

-- Knock a player down (ragdoll + launch), e.g. a thief shoving them.
function StealService.Knock(target: Player, velocity: Vector3, stun: number)
	task.spawn(function()
		ragdoll(target, stun)
		Remotes.Get("Knockback"):FireClient(target, velocity, stun)
	end)
end

function StealService.IsCarrying(player: Player): boolean
	return carries[player] ~= nil
end

-- True if a player thief is carrying this slot's slime right now.
function StealService.IsSlotCarried(owner: Player, slot: number): boolean
	for _, carry in carries do
		if carry.Owner == owner and carry.Slot == slot then
			return true
		end
	end
	return false
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
	local name = SlimeInfo.DisplayName(carry.SlimeId, carry.Mutation, carry.Tier)

	if delivered and owner.Parent and thief.Parent then
		-- Only move the slime if the slot still holds the one being carried.
		local current = EconomyService.GetSlot(owner, carry.Slot)
		if not current or current.Id ~= carry.SlimeId or current.Mutation ~= carry.Mutation then
			PlotService.SetCarried(owner, carry.Slot, false)
			if thief.Parent then
				NetService.Notify(thief, "The slime got away!", "Bad")
			end
			return
		end
		local slotData = EconomyService.RemoveSlime(owner, carry.Slot)
		PlotService.SetCarried(owner, carry.Slot, false)
		if slotData then
			local added = EconomyService.AddSlime(
				thief,
				slotData.Id,
				slotData.Mutation,
				"Steal",
				nil,
				slotData.Tier,
				slotData.Age
			)
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
				EconomyService.AddSlime(
					owner,
					slotData.Id,
					slotData.Mutation,
					"Returned",
					carry.Slot,
					slotData.Tier,
					slotData.Age
				)
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
	local scale = SlimeInfo.Scale(slotData.Tier, slotData.Age)
	local slimeCFrame = PlotService.SlotCFrame(owner, slot, slotData.Id, scale)
	if not slimeCFrame or (slimeCFrame.Position - thiefRoot.Position).Magnitude > 14 then
		return
	end

	local model = SlimeBuilder.Build(slotData.Id, slotData.Mutation, { Tier = slotData.Tier, Age = slotData.Age })
	local root = model.PrimaryPart :: BasePart
	local height = SlimeBuilder.HalfHeight(slotData.Id, scale)
	model:SetAttribute("Carried", true)
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
		Tier = slotData.Tier,
		Age = slotData.Age,
		Model = model,
		StartedAt = os.clock(),
		StartPosition = thiefRoot.Position,
	}
	PlotService.SetCarried(owner, slot, true)
	applySpeed(thief)

	local name = SlimeInfo.DisplayName(slotData.Id, slotData.Mutation, slotData.Tier)
	NetService.Notify(thief, "🏃 Run back to your base with " .. name .. "!", "Info")
	NetService.Notify(owner, "⚠️ " .. thief.DisplayName .. " is stealing your " .. name .. "! BONK them!", "Bad")
end

-- A proper bat: taped grip and knob where the hand is (handle -Z end),
-- tapering into a thick barrel with a rounded cap. The Golden Bat glows.
-- A trail on the barrel tip is switched on by clients during a swing.
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
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local wood = if golden then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(176, 120, 70)
	local material = if golden then Enum.Material.Foil else Enum.Material.Wood
	local tape = if golden then Color3.fromRGB(40, 30, 20) else Color3.fromRGB(35, 35, 40)
	local along = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them along Z
	local function piece(
		name: string,
		size: Vector3,
		z: number,
		color: Color3,
		mat: Enum.Material,
		ball: boolean?
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Cylinder
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = handle.CFrame * CFrame.new(0, 0, z) * (if ball then CFrame.identity else along)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = tool
		return p
	end
	piece("Knob", Vector3.one * 0.5, -2.05, tape, Enum.Material.SmoothPlastic, true)
	piece("Grip", Vector3.new(1.9, 0.34, 0.34), -1.05, tape, Enum.Material.Fabric)
	piece("Taper", Vector3.new(0.9, 0.5, 0.5), 0.25, wood, material)
	local barrel = piece("Barrel", Vector3.new(2.1, 0.8, 0.8), 1.25, wood, material)
	piece("Cap", Vector3.one * 0.8, 2.3, wood, material, true)

	local tip0, tip1 = Instance.new("Attachment"), Instance.new("Attachment")
	tip0.Name, tip1.Name = "TrailTop", "TrailBottom"
	tip0.Position, tip1.Position = Vector3.new(1, 0.35, 0), Vector3.new(1, -0.35, 0)
	tip0.Parent, tip1.Parent = barrel, barrel
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0, trail.Attachment1 = tip0, tip1
	trail.Color = ColorSequence.new(if golden then Color3.fromRGB(255, 230, 120) else Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.18
	trail.Enabled = false
	trail.Parent = barrel
	if golden then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 90)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = barrel
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 120)
		sparkles.Parent = barrel
	end
	return tool
end

-- Bats for NPCs too (the bully in ThiefService).
function StealService.MakeBat(golden: boolean): Tool
	return makeBat(golden)
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
	-- Clients play the full swing; the hit lands as the bat comes round.
	NetService.Fx("Swing", { Attacker = attacker.UserId })
	task.wait(Economy.BonkHitDelay)
	attackerRoot = rootOf(attacker)
	if not attackerRoot then
		return
	end

	local range = if golden then Economy.BonkRangeGolden else Economy.BonkRange
	local force = if golden then Economy.BonkForceGolden else Economy.BonkForce
	StealService.Swung:Fire(attacker, attackerRoot, range, force)
	for _, target in Players:GetPlayers() do
		local targetRoot = rootOf(target)
		if target ~= attacker and targetRoot then
			local offset = targetRoot.Position - attackerRoot.Position
			local distance = offset.Magnitude
			local inFront = distance < 3 or attackerRoot.CFrame.LookVector:Dot(offset.Unit) > 0.2
			if distance <= range and inFront then
				local direction = Vector3.new(offset.X, 0, offset.Z)
				direction = if direction.Magnitude > 0.01 then direction.Unit else attackerRoot.CFrame.LookVector
				local launch = direction * force + Vector3.new(0, force * Economy.BonkLift, 0)
				task.spawn(function()
					ragdoll(target, Economy.BonkStunSeconds)
					Remotes.Get("Knockback"):FireClient(target, launch, Economy.BonkStunSeconds)
				end)
				NetService.Fx("Bonk", {
					Position = targetRoot.Position + Vector3.new(0, 2, 0),
					Attacker = attacker.UserId,
					Victim = target.UserId,
					Dropped = carries[target] ~= nil,
					Golden = golden,
					Stun = Economy.BonkStunSeconds,
				})
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
