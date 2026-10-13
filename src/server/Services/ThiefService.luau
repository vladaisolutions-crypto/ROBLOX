--!strict
-- NPC thieves. Every few minutes a sneaky thief walks up to a player's base,
-- grabs one of their slimes and runs for the edge of the map. Bonk him with
-- the bat to make him drop it (and earn a reward), or lock the base: a lock
-- turns him away at the gate, and locking while he is inside traps him.
-- If he reaches the edge, the slime is gone (its stored cash is paid out).
-- He never takes the owner's best slime.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Format = require(Shared.Util.Format)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)

local EconomyService = require(script.Parent.EconomyService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local TelemetryService = require(script.Parent.TelemetryService)

type Thief = {
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Slot: number,
	Carry: Model?,
	Done: boolean,
}

local ThiefService = {}

local thieves: { [Player]: Thief } = {}
local nextVisit: { [Player]: number } = {}

local function randomInterval(): number
	return Random.new():NextNumber(Economy.ThiefMinInterval, Economy.ThiefMaxInterval)
end

local function buildThief(): (Model, Humanoid, BasePart)
	local description = Instance.new("HumanoidDescription")
	local black = Color3.fromRGB(30, 30, 36)
	description.HeadColor = Color3.fromRGB(235, 200, 160)
	description.TorsoColor = black
	description.LeftArmColor = black
	description.RightArmColor = black
	description.LeftLegColor = Color3.fromRGB(45, 45, 55)
	description.RightLegColor = Color3.fromRGB(45, 45, 55)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Thief"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Robber's mask and beanie.
		local mask = Instance.new("Part")
		mask.Name = "Mask"
		mask.Size = Vector3.new(1.3, 0.35, 1.25)
		mask.Color = Color3.fromRGB(15, 15, 20)
		mask.CanCollide = false
		mask.Massless = true
		mask.CFrame = head.CFrame * CFrame.new(0, 0.15, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, mask
		weld.Parent = mask
		mask.Parent = model
		local beanie = mask:Clone()
		beanie.Name = "Beanie"
		beanie.Size = Vector3.new(1.35, 0.6, 1.35)
		beanie.Color = Color3.fromRGB(200, 40, 50)
		beanie.CFrame = head.CFrame * CFrame.new(0, 0.6, 0)
		local beanieWeld = beanie:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
		beanieWeld.Part0, beanieWeld.Part1 = head, beanie
		beanie.Parent = model

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(160, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 250
		gui.LightInfluence = 0
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "😈 THIEF!"
		label.TextColor3 = Color3.fromRGB(255, 70, 70)
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(255, 60, 60)
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent = model
	return model, humanoid, root
end

-- The slime the thief goes for: random, but never the owner's best one.
local function pickSlot(owner: Player): number?
	local slots: { { Slot: number, Income: number } } = {}
	for slot = 1, Economy.AbsoluteMaxSlots do
		local data = EconomyService.GetSlot(owner, slot)
		if data then
			table.insert(slots, { Slot = slot, Income = SlimeInfo.Income(data.Id, data.Mutation, data.Tier, data.Age) })
		end
	end
	if #slots < Economy.ThiefMinSlimes then
		return nil
	end
	table.sort(slots, function(a, b)
		return a.Income > b.Income
	end)
	table.remove(slots, 1)
	return slots[math.random(1, #slots)].Slot
end

-- Walk to a point; false if the thief was stopped or got stuck.
local function walkTo(thief: Thief, target: Vector3, timeout: number): boolean
	local started = os.clock()
	while not thief.Done and os.clock() - started < timeout do
		local flat = Vector3.new(target.X - thief.Root.Position.X, 0, target.Z - thief.Root.Position.Z)
		if flat.Magnitude < 2.5 then
			return true
		end
		thief.Humanoid:MoveTo(target)
		task.wait(0.2)
	end
	return false
end

local function poof(thief: Thief)
	local at = thief.Root.Position
	NetService.Fx("ThiefPoof", { Position = at })
	thief.Model:Destroy()
end

-- End a visit. `outcome`: "Bonked", "Locked", "Escaped" or "Cancelled".
local function finish(thief: Thief, outcome: string, by: Player?)
	if thief.Done then
		return
	end
	thief.Done = true
	if thieves[thief.Owner] == thief then
		thieves[thief.Owner] = nil
	end
	nextVisit[thief.Owner] = os.clock() + randomInterval()
	local owner = thief.Owner
	local carrying = thief.Carry ~= nil
	if thief.Carry then
		thief.Carry:Destroy()
		thief.Carry = nil
	end

	if outcome == "Escaped" and carrying and owner.Parent then
		local slotData = EconomyService.RemoveSlime(owner, thief.Slot)
		PlotService.SetCarried(owner, thief.Slot, false)
		if slotData then
			EconomyService.AddCash(owner, slotData.Stored, "Income")
			local name = SlimeInfo.DisplayName(slotData.Id, slotData.Mutation, slotData.Tier)
			NetService.Notify(
				owner,
				"💀 The thief got away with your " .. name .. "! Lock your base next time!",
				"Bad"
			)
			NetService.FxTo(owner, "Offer", {
				Product = "InstantLock",
				Text = "Thieves are about! Lock your base instantly.",
				Urgent = true,
			})
			TelemetryService.Custom(owner, "ThiefEscaped", SlimeInfo.Price(slotData.Id, slotData.Mutation))
		end
		poof(thief)
		return
	end

	if carrying and owner.Parent then
		PlotService.SetCarried(owner, thief.Slot, false)
	end
	if outcome == "Bonked" then
		local reward = EconomyService.IncomeMinutes(owner, Economy.ThiefRewardMinutes, Economy.ThiefRewardMinimum)
		local hero = by or owner
		EconomyService.AddCash(hero, reward, "Reward", "ThiefCaught")
		NetService.FxTo(hero, "ThiefCaught", { Amount = reward })
		NetService.Notify(hero, "🦸 You bonked the thief! +" .. Format.Cash(reward), "Money")
		if hero ~= owner and owner.Parent then
			NetService.Notify(owner, "🦸 " .. hero.DisplayName .. " bonked the thief! Your slime is safe.", "Good")
		end
		TelemetryService.Custom(owner, "ThiefBonked", reward)
		task.delay(Economy.BonkStunSeconds, function()
			if thief.Model.Parent then
				poof(thief)
			end
		end)
	elseif outcome == "Locked" then
		if owner.Parent then
			NetService.Notify(owner, "🔒 Your lock stopped the thief!", "Good")
		end
		task.spawn(function()
			-- Shrug and walk off.
			thief.Humanoid.WalkSpeed = Economy.ThiefWalkSpeed
			local plot = PlotService.GetPlot(owner)
			if plot then
				local away = thief.Root.Position - plot.CFrame.Position
				thief.Humanoid:MoveTo(thief.Root.Position + Vector3.new(away.X, 0, away.Z).Unit * 40)
			end
			task.wait(3)
			if thief.Model.Parent then
				poof(thief)
			end
		end)
	else
		poof(thief)
	end
end

local function visit(owner: Player)
	local plot = PlotService.GetPlot(owner)
	if not plot or PlotService.IsLocked(owner) then
		nextVisit[owner] = os.clock() + randomInterval()
		return
	end
	local slot = pickSlot(owner)
	if not slot then
		nextVisit[owner] = os.clock() + randomInterval()
		return
	end
	local pedestal = plot.Pedestals[slot]
	local cf = plot.CFrame
	local D = World.PlotDepth
	local pedLocal = cf:PointToObjectSpace(pedestal.Position)
	local aisleX = if pedLocal.X > 20 then pedLocal.X - 5 else pedLocal.X + 5
	local gateFront = cf:PointToWorldSpace(Vector3.new(0, 3, D / 2 + 6))
	local inside = cf:PointToWorldSpace(Vector3.new(aisleX, 3, D / 2 - 10))
	local grabSpot = cf:PointToWorldSpace(Vector3.new(aisleX, 3, pedLocal.Z))
	-- He sneaks in from the nearest end of the map, along the belt side.
	local side = if cf.Position.X >= 0 then 1 else -1
	local laneZ = math.sign(cf.Position.Z) * (World.BeltWidth / 2 + 11)
	local edge = Vector3.new(side * (World.MapSizeX / 2 - 12), 3, laneZ)

	local model, humanoid, root = buildThief()
	model:PivotTo(CFrame.lookAt(edge, gateFront))
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	humanoid.WalkSpeed = Economy.ThiefWalkSpeed
	local thief: Thief = {
		Owner = owner,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Slot = slot,
		Carry = nil,
		Done = false,
	}
	thieves[owner] = thief
	NetService.FxTo(owner, "Thief", { Position = root.Position })
	NetService.Notify(owner, "😈 A THIEF is sneaking to your base! Bonk him or lock it!", "Bad")
	NetService.FxTo(owner, "Offer", {
		Product = "InstantLock",
		Text = "A thief is coming! Lock your base right now.",
		Urgent = true,
	})

	-- To the gate along the lane, then the gate itself.
	if not walkTo(thief, Vector3.new(gateFront.X, 3, laneZ), 40) or not walkTo(thief, gateFront, 15) then
		finish(thief, "Cancelled")
		return
	end
	if PlotService.IsLocked(owner) then
		finish(thief, "Locked")
		return
	end
	if not walkTo(thief, inside, 10) or not walkTo(thief, grabSpot, 10) then
		if not thief.Done then
			finish(thief, if PlotService.IsLocked(owner) then "Locked" else "Cancelled")
		end
		return
	end

	-- Grab it (if it is still there).
	local slotData = EconomyService.GetSlot(owner, slot)
	if not slotData or StealService.IsSlotCarried(owner, slot) then
		finish(thief, "Cancelled")
		return
	end
	humanoid:MoveTo(root.Position)
	task.wait(Economy.ThiefGrabSeconds)
	if thief.Done then
		return
	end
	slotData = EconomyService.GetSlot(owner, slot)
	if not slotData then
		finish(thief, "Cancelled")
		return
	end
	local carry = SlimeBuilder.Build(slotData.Id, slotData.Mutation, { Tier = slotData.Tier, Age = slotData.Age })
	local carryRoot = carry.PrimaryPart :: BasePart
	local height = SlimeBuilder.HalfHeight(slotData.Id, SlimeInfo.Scale(slotData.Tier, slotData.Age))
	carry:SetAttribute("Carried", true)
	carry:PivotTo(root.CFrame * CFrame.new(0, 3.5 + height, 0))
	carryRoot.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, carryRoot
	weld.Parent = carryRoot
	for _, part in carry:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
		end
	end
	carry.Parent = workspace
	thief.Carry = carry
	PlotService.SetCarried(owner, slot, true)
	local name = SlimeInfo.DisplayName(slotData.Id, slotData.Mutation, slotData.Tier)
	NetService.Notify(owner, "🚨 The thief grabbed your " .. name .. "! BONK HIM!", "Bad")
	NetService.FxTo(owner, "Thief", { Position = root.Position })

	-- Run for it.
	humanoid.WalkSpeed = Economy.ThiefCarrySpeed
	-- (Locking now traps him: see the Locked handler in Init.)
	for _, point in { inside, gateFront, Vector3.new(gateFront.X, 3, laneZ), edge } do
		if not walkTo(thief, point, 40) then
			if not thief.Done then
				finish(thief, if PlotService.IsLocked(owner) then "Locked" else "Cancelled")
			end
			return
		end
	end
	finish(thief, "Escaped")
end

-- Bat hit on an NPC thief: ragdoll him away and end the visit.
local function onSwing(attacker: Player, attackerRoot: BasePart, range: number, force: number)
	for _, thief in thieves do
		if not thief.Done and thief.Model.Parent then
			local offset = thief.Root.Position - attackerRoot.Position
			local distance = offset.Magnitude
			local inFront = distance < 3 or attackerRoot.CFrame.LookVector:Dot(offset.Unit) > 0.2
			if distance <= range and inFront then
				local direction = Vector3.new(offset.X, 0, offset.Z)
				direction = if direction.Magnitude > 0.01 then direction.Unit else attackerRoot.CFrame.LookVector
				NetService.Fx("Bonk", {
					Position = thief.Root.Position + Vector3.new(0, 2, 0),
					Attacker = attacker.UserId,
					Dropped = thief.Carry ~= nil,
					Golden = false,
					Stun = Economy.BonkStunSeconds,
				})
				local billboard = thief.Model:FindFirstChildWhichIsA("BillboardGui", true)
				if billboard then
					billboard:Destroy()
				end
				finish(thief, "Bonked", attacker)
				-- Ragdoll: switch off the animated joints, launch every part.
				thief.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
				for _, joint in thief.Model:GetDescendants() do
					if joint:IsA("AnimationConstraint") and joint.Name ~= "Root" then
						joint.Enabled = false
					elseif joint:IsA("Motor6D") and joint.Part0 ~= thief.Root then
						joint.Enabled = false
					end
				end
				local launch = direction * force * 1.2 + Vector3.new(0, force * Economy.BonkLift, 0)
				local axis = direction:Cross(Vector3.yAxis)
				RunService.Heartbeat:Wait()
				for _, part in thief.Model:GetDescendants() do
					if part:IsA("BasePart") then
						part.CanCollide = part ~= thief.Root
						part.AssemblyLinearVelocity = launch
						part.AssemblyAngularVelocity = -axis * 12
					end
				end
			end
		end
	end
end

function ThiefService.Init()
	StealService.Swung:Connect(onSwing)
	PlotService.Locked:Connect(function(player: Player)
		local thief = thieves[player]
		if thief and not thief.Done then
			-- Locking while he is inside traps him; outside, he turns back.
			local plot = PlotService.GetPlot(player)
			if plot then
				local rel = plot.CFrame:PointToObjectSpace(thief.Root.Position)
				if math.abs(rel.X) < World.PlotWidth / 2 + 2 and rel.Z < World.PlotDepth / 2 + 8 then
					finish(thief, "Locked")
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		nextVisit[player] = os.clock() + Economy.ThiefFirstDelay
	end)
	for _, player in Players:GetPlayers() do
		nextVisit[player] = os.clock() + Economy.ThiefFirstDelay
	end
	Players.PlayerRemoving:Connect(function(player)
		local thief = thieves[player]
		if thief then
			finish(thief, "Cancelled")
		end
		nextVisit[player] = nil
	end)
end

function ThiefService.Start()
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, at in nextVisit do
				if now >= at and not thieves[player] and player.Parent then
					nextVisit[player] = now + 9999 -- set properly when the visit ends
					task.spawn(visit, player)
				end
			end
		end
	end)
end

return ThiefService
