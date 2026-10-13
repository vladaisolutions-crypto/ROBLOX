--!strict
-- NPC thieves. Every few minutes a sneaky thief walks up to a player's base,
-- grabs one of their slimes and runs for the edge of the map. Bonk him with
-- the bat to make him drop it (and earn a reward), or lock the base: a lock
-- turns him away at the gate, and locking while he is inside traps him.
-- If he reaches the edge, the slime is gone (its stored cash is paid out).
-- He never takes the owner's best slime.

local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Roblox's default R15 animations, so the thief walks, runs and jumps.
local ANIMATIONS: { [string]: string } = {
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
}

-- What he says (speech bubble over his head).
local LINES: { [string]: { { Text: string, Sound: string } } } = {
	Arrive = {
		{ Text = "Heh heh heh... 😏", Sound = "ThiefArrive1" },
		{ Text = "Ooh, what a nice base!", Sound = "ThiefArrive2" },
	},
	Sneak = {
		{ Text = "Tiptoe, tiptoe... 🤫", Sound = "ThiefSneak1" },
		{ Text = "Nobody's home... right?", Sound = "ThiefSneak2" },
	},
	Grab = {
		{ Text = "YOINK! 😈", Sound = "ThiefGrab1" },
		{ Text = "Shiny! Thanks! ✨", Sound = "ThiefGrab2" },
	},
	Run = {
		{ Text = "Can't catch me! 😜", Sound = "ThiefRun1" },
		{ Text = "Too slow!", Sound = "ThiefRun2" },
		{ Text = "Nyeh nyeh! 😝", Sound = "ThiefRun3" },
	},
	Locked = {
		{ Text = "Aww, it's locked! 😤", Sound = "ThiefLocked1" },
		{ Text = "Hey! No fair! 😠", Sound = "ThiefLocked2" },
	},
	Bonked = {
		{ Text = "OUCH! 😵", Sound = "ThiefBonked1" },
		{ Text = "Not the bat! 😭", Sound = "ThiefBonked2" },
	},
	Escaped = {
		{ Text = "Hehe, see ya! 💨", Sound = "ThiefEscaped1" },
	},
}

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Format = require(Shared.Util.Format)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)
local Sounds = require(Shared.Config.Sounds).Ids

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
	Bubble: TextLabel?,
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
	-- Animations: walk/run while moving, idle when still, jump and fall.
	local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = name ~= "Jump"
			tracks[name] = track
		end
	end
	local current: AnimationTrack? = nil
	local function play(name: string, speed: number?)
		local track = tracks[name]
		if not track then
			return
		end
		if current ~= track then
			if current then
				current:Stop(0.15)
			end
			track:Play(0.15)
			current = track
		end
		track:AdjustSpeed(speed or 1)
	end
	humanoid.Running:Connect(function(speed: number)
		if speed > 15 then
			play("Run", speed / 16)
		elseif speed > 0.5 then
			play("Walk", speed / 12)
		else
			play("Idle")
		end
	end)
	humanoid.Jumping:Connect(function(active: boolean)
		if active then
			play("Jump")
		end
	end)
	humanoid.FreeFalling:Connect(function(active: boolean)
		if active then
			play("Fall")
		end
	end)
	play("Idle")

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
-- A speech bubble over his head for a few seconds.
local function say(thief: Thief, kind: string)
	local lines = LINES[kind]
	local head = thief.Model:FindFirstChild("Head")
	if not lines or not head or not head:IsA("BasePart") then
		return
	end
	local line = lines[math.random(1, #lines)]
	local text = line.Text
	-- His voice, from his head so you hear where he is.
	local soundId = Sounds[line.Sound]
	if soundId and soundId ~= "" then
		local voice = Instance.new("Sound")
		voice.SoundId = soundId
		voice.Volume = 1.2
		voice.RollOffMinDistance = 12
		voice.RollOffMaxDistance = 110
		voice.Parent = head
		voice:Play()
		Debris:AddItem(voice, 4)
	end
	local bubble = thief.Bubble
	if not bubble or not bubble.Parent then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Speech"
		gui.Size = UDim2.fromOffset(220, 46)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
		gui.MaxDistance = 120
		gui.LightInfluence = 0
		gui.Parent = head
		local frame = Instance.new("TextLabel")
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.fromScale(0.5, 1)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.Size = UDim2.fromScale(0, 1)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.Font = Enum.Font.FredokaOne
		frame.TextSize = 22
		frame.TextColor3 = Color3.fromRGB(30, 25, 40)
		frame.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = frame
		bubble = frame
		thief.Bubble = frame
	end
	local label = bubble :: TextLabel
	label.Text = text
	label.Visible = true
	task.delay(2.5, function()
		if label.Parent and label.Text == text then
			label.Visible = false
		end
	end)
end

-- Walk to a point along a computed path. Gets himself unstuck: if he has
-- not moved for a second he jumps and sidesteps, then re-plans the path,
-- and as a last resort hops a few studs on. False if stopped or timed out.
local function walkTo(thief: Thief, target: Vector3, timeout: number, hops: boolean?): boolean
	local root, humanoid = thief.Root, thief.Humanoid
	local started = os.clock()
	local rng = Random.new()
	local function plan(): { PathWaypoint }?
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 5,
		})
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			return path:GetWaypoints()
		end
		return nil
	end
	local waypoints = plan()
	local index = 2
	local lastPosition, lastCheck, stuck = root.Position, os.clock(), 0
	local nextHop = os.clock() + rng:NextNumber(1.5, 3)
	while not thief.Done and os.clock() - started < timeout do
		local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		if flat.Magnitude < 2.5 then
			return true
		end
		local goal = target
		if waypoints and waypoints[index] then
			local waypoint = waypoints[index]
			goal = waypoint.Position
			local toWaypoint = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
			if toWaypoint.Magnitude < 2.5 then
				index += 1
				if waypoints[index] and waypoints[index].Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
			end
		end
		humanoid:MoveTo(goal)
		-- A cheeky hop now and then while running away.
		if hops and os.clock() > nextHop then
			humanoid.Jump = true
			nextHop = os.clock() + rng:NextNumber(1.5, 3)
		end
		if os.clock() - lastCheck > 1 then
			if (root.Position - lastPosition).Magnitude < 1.5 then
				stuck += 1
				humanoid.Jump = true
				local sideways = root.CFrame.RightVector * (if rng:NextNumber() < 0.5 then -6 else 6)
				humanoid:MoveTo(root.Position + sideways)
				task.wait(0.35)
				if stuck >= 2 then
					waypoints = plan()
					index = 2
				end
				if stuck >= 4 then
					local step = if flat.Magnitude > 0.01 then flat.Unit * math.min(5, flat.Magnitude) else Vector3.zero
					root.CFrame = CFrame.new(root.Position + step + Vector3.new(0, 2, 0)) * root.CFrame.Rotation
					stuck = 0
				end
			else
				stuck = 0
			end
			lastPosition, lastCheck = root.Position, os.clock()
		end
		task.wait(0.12)
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

	if outcome ~= "Cancelled" then
		say(thief, outcome)
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
		local reward = EconomyService.FreeRewardCash(owner, Economy.ThiefRewardMinutes, Economy.ThiefRewardMinimum)
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
	say(thief, "Arrive")
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
	say(thief, "Sneak")
	if not walkTo(thief, inside, 12) or not walkTo(thief, grabSpot, 12) then
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
	say(thief, "Grab")
	NetService.Notify(owner, "🚨 The thief grabbed your " .. name .. "! BONK HIM!", "Bad")
	NetService.FxTo(owner, "Thief", { Position = root.Position })

	-- Run for it.
	humanoid.WalkSpeed = Economy.ThiefCarrySpeed
	-- (Locking now traps him: see the Locked handler in Init.)
	task.spawn(function()
		while not thief.Done do
			task.wait(Random.new():NextNumber(2.5, 4))
			if not thief.Done then
				say(thief, "Run")
			end
		end
	end)
	for _, point in { inside, gateFront, Vector3.new(gateFront.X, 3, laneZ), edge } do
		if not walkTo(thief, point, 40, true) then
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
