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
		{ Text = "Heh heh heh... time to go shopping 😏", Sound = "ThiefArrive1" },
		{ Text = "Ooh, what a nice base!", Sound = "ThiefArrive2" },
		{ Text = "Psst... this way. Nobody's looking.", Sound = "ThiefArrive3" },
	},
	Sneak = {
		{ Text = "Tiptoe, tiptoe... 🤫", Sound = "ThiefSneak1" },
		{ Text = "Nobody's home... right?", Sound = "ThiefSneak2" },
	},
	Scout = {
		{ Text = "Let me check the coast is clear... 👀", Sound = "ThiefScout1" },
		{ Text = "Hmm... which one should I take?", Sound = "ThiefScout2" },
	},
	Grab = {
		{ Text = "YOINK! 😈", Sound = "ThiefGrab1" },
		{ Text = "Shiny! Thanks! ✨", Sound = "ThiefGrab2" },
		{ Text = "Got one! Got one!", Sound = "ThiefGrab3" },
	},
	Run = {
		{ Text = "Can't catch me! 😜", Sound = "ThiefRun1" },
		{ Text = "Too slow!", Sound = "ThiefRun2" },
		{ Text = "Nyeh nyeh! 😝", Sound = "ThiefRun3" },
		{ Text = "Byeee! 👋", Sound = "ThiefRun4" },
	},
	Spotted = {
		{ Text = "Uh oh, they saw me! 😱", Sound = "ThiefSpotted1" },
		{ Text = "Run for it!", Sound = "ThiefSpotted2" },
	},
	Chased = {
		{ Text = "Leave me alone! 😤", Sound = "ThiefChased1" },
		{ Text = "This slime is mine now!", Sound = "ThiefChased2" },
	},
	Locked = {
		{ Text = "Aww, it's locked! 😤", Sound = "ThiefLocked1" },
		{ Text = "Hey! No fair! 😠", Sound = "ThiefLocked2" },
	},
	Pick = {
		{ Text = "Locks can't stop me! 🔓", Sound = "" },
		{ Text = "Click... click... almost there...", Sound = "" },
	},
	Picked = {
		{ Text = "I'm in! 😈", Sound = "" },
		{ Text = "Too easy! Ha!", Sound = "" },
	},
	Hurt = {
		{ Text = "Is that all you got?! 😤", Sound = "" },
		{ Text = "Ow! Now I'm MAD! 😡", Sound = "" },
		{ Text = "That tickled! 😏", Sound = "" },
	},
	Bonked = {
		{ Text = "OUCH! 😵", Sound = "ThiefBonked1" },
		{ Text = "Not the bat! 😭", Sound = "ThiefBonked2" },
	},
	Escaped = {
		{ Text = "Hehe, see ya! 💨", Sound = "ThiefEscaped1" },
		{ Text = "Too easy! 😎", Sound = "ThiefEscaped2" },
	},
	Shove = {
		{ Text = "Back off! 😠", Sound = "ThiefShove1" },
		{ Text = "Outta my way!", Sound = "ThiefShove2" },
	},
}

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local SlimeBuilder = require(Shared.SlimeBuilder)
local SlimeInfo = require(Shared.SlimeInfo)
local Sounds = require(Shared.Config.Sounds).Ids

local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local TelemetryService = require(script.Parent.TelemetryService)
local WorldService = require(script.Parent.WorldService)

type Thief = {
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Slot: number,
	Carry: Model?,
	Done: boolean,
	Bubble: TextLabel?,
	Speed: number, -- this thief's speed multiplier
	LastShove: number,
	Spotted: boolean,
	LastChased: number,
	DodgeUntil: number,
	DodgeDir: Vector3,
	Picked: boolean, -- picked this base's lock: walks through the barrier
	Hits: number, -- bat hits left before he goes down
	HitAt: number,
	Hearts: TextLabel?,
}

-- Lock picking: metal clicks while he works (bundled with the Roblox client).
local PICK_SOUND = "rbxasset://sounds/clickfast.wav"

local ThiefService = {}

ThiefService.Bonked = Signal.new() -- (hero: Player) a thief was bonked by this player

-- Raid Shield purchases: thieves skip these bases until the time runs out.
local shieldUntil: { [Player]: number } = {}
function ThiefService.Shield(player: Player, seconds: number)
	shieldUntil[player] = math.max(shieldUntil[player] or 0, os.clock()) + seconds
end
local function shielded(player: Player): boolean
	return os.clock() < (shieldUntil[player] or 0)
end

-- The thieves raiding each player's base right now (a raid is a small gang).
local thieves: { [Player]: { Thief } } = {}
local checkRaidOver: () -> ()

-- The server-wide raid: when the next one starts, and the tally of the
-- current one (thieves still to arrive, caught, escaped, turned away).
local nextRaidAt = os.clock() + Economy.ThiefFirstDelay
local raidActive = false
local raidPending = 0
local raidStats = { Caught = 0, Escaped = 0, Stopped = 0 }

local function randomInterval(): number
	return Random.new():NextNumber(Economy.ThiefMinInterval, Economy.ThiefMaxInterval)
end

-- Every thief is a little different: outfit, skin, hat, size and name.
local NAMES = {
	"Sneaky Sam",
	"Slippery Sid",
	"Grabby Gus",
	"Tiptoe Tim",
	"Sticky Steve",
	"Quick Quinn",
	"Shifty Sal",
	"Pocket Pete",
	"Nimble Nell",
	"Sly Sly",
	"Cheeky Chad",
	"Swipey Sue",
}
local SKINS = {
	Color3.fromRGB(255, 220, 177),
	Color3.fromRGB(235, 200, 160),
	Color3.fromRGB(198, 145, 100),
	Color3.fromRGB(141, 85, 54),
	Color3.fromRGB(92, 58, 40),
}
local SHIRTS = {
	Color3.fromRGB(30, 30, 36), -- classic black
	Color3.fromRGB(40, 40, 70), -- navy
	Color3.fromRGB(70, 30, 80), -- purple
	Color3.fromRGB(90, 20, 30), -- maroon
	Color3.fromRGB(25, 70, 45), -- forest
	Color3.fromRGB(200, 200, 205), -- prison stripes grey
}
local HAT_COLORS = {
	Color3.fromRGB(200, 40, 50),
	Color3.fromRGB(255, 140, 20),
	Color3.fromRGB(40, 120, 220),
	Color3.fromRGB(60, 180, 80),
	Color3.fromRGB(30, 30, 36),
	Color3.fromRGB(240, 200, 40),
}
local HATS = { "Beanie", "Cap", "TopHat", "Bandana", "None" }

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function buildThief(rng: Random): (Model, Humanoid, BasePart, string)
	local description = Instance.new("HumanoidDescription")
	local skin = pick(rng, SKINS)
	local shirt = pick(rng, SHIRTS)
	local pants = shirt:Lerp(Color3.new(0, 0, 0), 0.35)
	description.HeadColor = skin
	description.TorsoColor = shirt
	description.LeftArmColor = shirt
	description.RightArmColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	description.HeightScale = rng:NextNumber(0.85, 1.12)
	description.WidthScale = rng:NextNumber(0.8, 1.2)
	description.DepthScale = description.WidthScale
	description.HeadScale = rng:NextNumber(0.92, 1.12)
	local thiefName = pick(rng, NAMES)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Thief"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Robber's mask and a random hat.
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
		local hatColor = pick(rng, HAT_COLORS)
		local function hatPiece(pieceName: string, size: Vector3, offset: CFrame, color: Color3, cylinder: boolean?)
			local piece = mask:Clone()
			piece.Name = pieceName
			piece.Size = size
			piece.Color = color
			if cylinder then
				piece.Shape = Enum.PartType.Cylinder
			end
			piece.CFrame = head.CFrame * offset
			local pieceWeld = piece:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint
			pieceWeld.Part0, pieceWeld.Part1 = head, piece
			piece.Parent = model
		end
		local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X
		local hat = pick(rng, HATS)
		if hat == "Beanie" then
			hatPiece("Beanie", Vector3.new(1.35, 0.6, 1.35), CFrame.new(0, 0.6, 0), hatColor)
		elseif hat == "Cap" then
			hatPiece("Cap", Vector3.new(1.32, 0.45, 1.32), CFrame.new(0, 0.62, 0), hatColor)
			hatPiece("Brim", Vector3.new(1.1, 0.1, 0.7), CFrame.new(0, 0.42, -0.85), hatColor)
		elseif hat == "TopHat" then
			hatPiece(
				"Brim",
				Vector3.new(0.1, 1.8, 1.8),
				CFrame.new(0, 0.55, 0) * upright,
				Color3.fromRGB(25, 25, 30),
				true
			)
			hatPiece(
				"Crown",
				Vector3.new(1.1, 1.15, 1.15),
				CFrame.new(0, 1.1, 0) * upright,
				Color3.fromRGB(25, 25, 30),
				true
			)
			hatPiece("Band", Vector3.new(0.2, 1.2, 1.2), CFrame.new(0, 0.7, 0) * upright, hatColor, true)
		elseif hat == "Bandana" then
			hatPiece("Bandana", Vector3.new(1.33, 0.35, 1.33), CFrame.new(0, 0.5, 0), hatColor)
			hatPiece("Knot", Vector3.new(0.35, 0.35, 0.5), CFrame.new(0, 0.45, 0.8), hatColor)
		end

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
		label.Text = "😈 " .. thiefName
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
	return model, humanoid, root, thiefName
end

-- The slime a thief goes for: random, never the owner's best one, and not
-- one another thief in the gang is already after.
local function pickSlot(owner: Player, taken: { [number]: boolean }): number?
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
	local free = {}
	for _, entry in slots do
		if not taken[entry.Slot] then
			table.insert(free, entry.Slot)
		end
	end
	return if #free > 0 then free[math.random(1, #free)] else nil
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
		if os.clock() < thief.DodgeUntil then
			goal = root.Position + thief.DodgeDir * 6 + (goal - root.Position).Unit * 2
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
-- The raid ends once every thief has arrived and is gone.
checkRaidOver = function()
	for owner, gang in thieves do
		if #gang == 0 then
			thieves[owner] = nil
		end
	end
	if not raidActive or raidPending > 0 or next(thieves) ~= nil then
		return
	end
	raidActive = false
	workspace:SetAttribute("RaidActive", false) -- clients play the chase music while a raid is on
	nextRaidAt = os.clock() + randomInterval()
	local caught, escaped = raidStats.Caught, raidStats.Escaped
	if caught > 0 and escaped == 0 then
		for _, player in Players:GetPlayers() do
			local amount = EconomyService.FreeRewardCash(player, Economy.RaidVictoryMinutes, Economy.RaidVictoryMinimum)
			EconomyService.AddCash(player, amount, "Reward", "RaidVictory")
			NetService.Notify(player, "🏆 Perfect defense! Nobody got away. +" .. Format.Cash(amount), "Money")
		end
	end
	NetService.Announce(
		string.format(
			"🛡️ Raid over! %d thie%s caught, %d got away.",
			caught,
			if caught == 1 then "f" else "ves",
			escaped
		),
		if escaped == 0 then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 200, 80)
	)
end

local function finish(thief: Thief, outcome: string, by: Player?)
	if thief.Done then
		return
	end
	thief.Done = true
	local gang = thieves[thief.Owner]
	if gang then
		local index = table.find(gang, thief)
		if index then
			table.remove(gang, index)
		end
		if #gang == 0 then
			thieves[thief.Owner] = nil
		end
	end
	if outcome == "Bonked" then
		raidStats.Caught += 1
	elseif outcome == "Escaped" then
		raidStats.Escaped += 1
	elseif outcome == "Locked" then
		raidStats.Stopped += 1
	end
	task.defer(checkRaidOver)
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
		local heroData = DataService.Get(hero)
		if heroData then
			heroData.Stats.ThievesCaught += 1
		end
		ThiefService.Bonked:Fire(hero)
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
			thief.Humanoid.WalkSpeed = Economy.ThiefWalkSpeed * thief.Speed
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

-- One thief of a raid: sneak to the gate, grab `slot`, run for the edge.
-- `lane` spreads the gang out so they don't walk in single file.
local function visit(owner: Player, plot: WorldService.Plot, slot: number, lane: number)
	local cf = plot.CFrame
	local D = World.PlotDepth
	local gateFront = cf:PointToWorldSpace(Vector3.new(0, 3, D / 2 + 6))
	-- He sneaks in from the nearest end of the map, along the belt side.
	-- Thieves come from (and flee to) random spots all around the map: either
	-- end, or anywhere along the back edge behind the bases, so a raid never
	-- arrives from one place. Pathfinding takes them through the gaps.
	local rng = Random.new()
	local rowSign = math.sign(cf.Position.Z)
	local laneZ = rowSign * (World.BeltWidth / 2 + 11 + lane + rng:NextNumber(-2, 2))
	local function randomEdge(): Vector3
		local halfX, halfZ = World.MapSizeX / 2 - 12, World.MapSizeZ / 2 - 12
		local roll = rng:NextNumber()
		if roll < 0.3 then
			-- Either end of the map, at any depth on either side.
			local endSign = if rng:NextNumber() < 0.5 then 1 else -1
			local sideSign = if rng:NextNumber() < 0.75 then rowSign else -rowSign
			return Vector3.new(endSign * halfX, 3, sideSign * rng:NextNumber(10, halfZ))
		elseif roll < 0.5 then
			-- The far side: across the belt, from behind the other row of bases.
			return Vector3.new(rng:NextNumber(-halfX, halfX), 3, -rowSign * halfZ)
		end
		-- The back edge behind this row of bases, anywhere along it.
		return Vector3.new(rng:NextNumber(-halfX, halfX), 3, rowSign * halfZ)
	end
	local edge = randomEdge()
	local escape = randomEdge()

	local model, humanoid, root = buildThief(rng)
	model:PivotTo(CFrame.lookAt(edge, gateFront))
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	local speed = rng:NextNumber(Economy.ThiefSpeedMin, Economy.ThiefSpeedMax)
	local brute = rng:NextNumber() < Economy.ThiefBruteChance
	if brute then
		-- A big one: takes more hits, a touch slower.
		model:ScaleTo(Economy.ThiefBruteScale)
		speed *= 0.92
	end
	humanoid.WalkSpeed = Economy.ThiefWalkSpeed * speed
	local thief: Thief = {
		Owner = owner,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Slot = slot,
		Carry = nil,
		Done = false,
		Speed = speed,
		LastShove = 0,
		Spotted = false,
		LastChased = 0,
		DodgeUntil = 0,
		DodgeDir = Vector3.zero,
		Picked = false,
		Hits = if brute then Economy.ThiefBruteHits else Economy.ThiefHits,
		HitAt = 0,
	}
	-- Hearts over his head: how many more bonks he can take.
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and thief.Hits > 1 then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Hearts"
		gui.Size = UDim2.fromOffset(110, 26)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Text = string.rep("❤️", thief.Hits)
		label.Parent = gui
		gui.Parent = head
		thief.Hearts = label
	end
	local gang = thieves[owner]
	if not gang then
		gang = {}
		thieves[owner] = gang
	end
	table.insert(gang, thief)
	say(thief, "Arrive")

	-- Eyes and ears: react to players coming close.
	task.spawn(function()
		while not thief.Done and thief.Model.Parent do
			task.wait(0.4)
			local nearest, nearestRoot = math.huge, nil :: BasePart?
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoidOf = character and character:FindFirstChildOfClass("Humanoid")
				local pr = character and character:FindFirstChild("HumanoidRootPart")
				if humanoidOf and humanoidOf.Health > 0 and pr and pr:IsA("BasePart") then
					local d = (pr.Position - root.Position).Magnitude
					if d < nearest then
						nearest, nearestRoot = d, pr
					end
				end
			end
			local now = os.clock()
			if not thief.Carry and not thief.Spotted and nearest < 16 then
				-- Spotted before the grab: he doesn't back off, he rushes it.
				thief.Spotted = true
				say(thief, "Spotted")
				humanoid.WalkSpeed = Economy.ThiefWalkSpeed * thief.Speed * Economy.ThiefRushMultiplier
			elseif
				nearestRoot
				and nearest < Economy.ThiefDodgeRange
				and now - thief.LastChased > Economy.ThiefDodgeCooldown
			then
				-- Chased with the slime: shout, sprint and juke sideways.
				thief.LastChased = now
				if thief.Carry then
					say(thief, "Chased")
				end
				local away =
					Vector3.new(root.Position.X - nearestRoot.Position.X, 0, root.Position.Z - nearestRoot.Position.Z)
				local side = if away.Magnitude > 0.1 then away.Unit:Cross(Vector3.yAxis) else root.CFrame.RightVector
				thief.DodgeDir = side * (if rng:NextNumber() < 0.5 then -1 else 1)
				thief.DodgeUntil = now + 0.6
				local base = if thief.Carry then Economy.ThiefCarrySpeed else Economy.ThiefWalkSpeed
				humanoid.WalkSpeed = base * thief.Speed * Economy.ThiefSprintMultiplier
				task.delay(1.2, function()
					if not thief.Done then
						local now2 = if thief.Carry then Economy.ThiefCarrySpeed else Economy.ThiefWalkSpeed
						humanoid.WalkSpeed = now2 * thief.Speed
					end
				end)
			end
		end
	end)

	-- Locked out? He picks the lock at the gate. Bonk him before he's in!
	local function pickLock(): boolean
		say(thief, "Locked")
		humanoid:MoveTo(root.Position)
		task.wait(1)
		if thief.Done then
			return false
		end
		say(thief, "Pick")
		NetService.Notify(owner, "🔓 A thief is PICKING YOUR LOCK! Bonk him!", "Bad")
		NetService.FxTo(owner, "Thief", { Position = root.Position })

		local gui = Instance.new("BillboardGui")
		gui.Name = "LockPick"
		gui.Size = UDim2.fromOffset(120, 16)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(30, 25, 40)
		back.Parent = gui
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		fill.Parent = back
		for _, frame in { back, fill } do
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = frame
		end
		gui.Parent = root
		local click = Instance.new("Sound")
		click.SoundId = PICK_SOUND
		click.Volume = 0.8
		click.RollOffMaxDistance = 60
		click.Parent = root

		local started, nextClick = os.clock(), 0
		while os.clock() - started < Economy.ThiefPickSeconds and PlotService.IsLocked(owner) do
			if thief.Done then
				gui:Destroy()
				click:Destroy()
				return false
			end
			humanoid:MoveTo(root.Position)
			fill.Size = UDim2.fromScale((os.clock() - started) / Economy.ThiefPickSeconds, 1)
			if os.clock() > nextClick then
				click.PlaybackSpeed = rng:NextNumber(0.8, 1.2)
				click:Play()
				nextClick = os.clock() + rng:NextNumber(0.3, 0.8)
			end
			task.wait(0.1)
		end
		gui:Destroy()
		click:Destroy()
		-- He slips through this base's barrier like the owner does.
		thief.Picked = true
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = plot.OwnerGroup
			end
		end
		if PlotService.IsLocked(owner) then
			say(thief, "Picked")
			NetService.Notify(owner, "😱 The thief picked your lock! He's inside!", "Bad")
		end
		return true
	end

	-- Where to stand to grab the slime on `forSlot`.
	local function spotsFor(forSlot: number): (Vector3, Vector3)
		local local_ = cf:PointToObjectSpace(plot.Pedestals[forSlot].Position)
		local aisle = if local_.X > 20 then local_.X - 5 else local_.X + 5
		return cf:PointToWorldSpace(Vector3.new(aisle, 3, D / 2 - 10)),
			cf:PointToWorldSpace(Vector3.new(aisle, 3, local_.Z))
	end

	-- A slime that's still there and nobody is carrying: his own if he can.
	local function target(): boolean
		local current = EconomyService.GetSlot(owner, slot)
		if current and not StealService.IsSlotCarried(owner, slot) then
			return true
		end
		local taken: { [number]: boolean } = {}
		for _, other in thieves[owner] or {} :: { Thief } do
			if other ~= thief then
				taken[other.Slot] = true
			end
		end
		local other = pickSlot(owner, taken)
		if other then
			slot = other
			thief.Slot = other
			return true
		end
		return false
	end

	-- He doesn't give up. A blocked path, a lock, a slime someone else took:
	-- he regroups and goes again, until he's bonked, trapped by the lock or
	-- gets away with a slime. (A long safety cap stops one looping forever.)
	local deadline = os.clock() + Economy.ThiefPersistSeconds
	local attempt = 0
	local function regroup()
		humanoid:MoveTo(root.Position)
		say(thief, "Scout")
		task.wait(rng:NextNumber(0.8, 1.6))
	end
	while not thief.Done do
		attempt += 1
		if os.clock() > deadline or not owner.Parent then
			finish(thief, "Cancelled")
			return
		end
		if not target() then
			-- Nothing to take right now: lurk by the gate and wait for one.
			humanoid:MoveTo(gateFront)
			task.wait(2)
			continue
		end
		local insideSpot, grabSpot = spotsFor(slot)
		local outside = cf:PointToObjectSpace(root.Position).Z > D / 2
		if outside then
			-- To the gate along the lane, then the gate itself.
			if attempt == 1 and not walkTo(thief, Vector3.new(gateFront.X, 3, laneZ), 40) then
				if not thief.Done then
					regroup()
				end
				continue
			end
			if not walkTo(thief, gateFront, 15) then
				if not thief.Done then
					regroup()
				end
				continue
			end
			if PlotService.IsLocked(owner) and not pickLock() then
				return
			end
			if attempt == 1 then
				-- Stop and scout before going in: look left, look right.
				humanoid:MoveTo(root.Position)
				say(thief, "Scout")
				for _, turn in { 50, -100, 50 } do
					task.wait(rng:NextNumber(0.35, 0.6))
					if thief.Done then
						return
					end
					model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(turn), 0))
				end
			end
			say(thief, "Sneak")
			if not walkTo(thief, insideSpot, 12) then
				if not thief.Done then
					regroup()
				end
				continue
			end
		end
		if not walkTo(thief, grabSpot, 12) then
			if not thief.Done then
				regroup()
			end
			continue
		end

		-- Grab it (if nobody beat him to it).
		if not EconomyService.GetSlot(owner, slot) or StealService.IsSlotCarried(owner, slot) then
			continue
		end
		humanoid:MoveTo(root.Position)
		task.wait(Economy.ThiefGrabSeconds)
		if thief.Done then
			return
		end
		local slotData = EconomyService.GetSlot(owner, slot)
		if not slotData or StealService.IsSlotCarried(owner, slot) then
			continue
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
		humanoid.WalkSpeed = Economy.ThiefCarrySpeed * thief.Speed
		-- (Locking now traps him: see the Locked handler in Init.)
		task.spawn(function()
			while not thief.Done do
				task.wait(Random.new():NextNumber(2.5, 4))
				if not thief.Done then
					say(thief, "Run")
				end
			end
		end)
		for _, point in { insideSpot, gateFront, Vector3.new(gateFront.X, 3, laneZ) } do
			if not walkTo(thief, point, 40, true) and thief.Done then
				return
			end
		end
		-- Off the edge of the map: if he gets stuck he keeps trying.
		while not thief.Done do
			if walkTo(thief, escape, 40, true) then
				finish(thief, "Escaped")
				return
			end
			if os.clock() > deadline then
				finish(thief, "Cancelled")
				return
			end
		end
		return
	end
end

-- A raid: a gang of thieves, each after a different slime, a few seconds apart.
-- A random gang size for one base.
local function gangSize(rng: Random): number
	local total = 0
	for _, weight in Economy.ThiefGangWeights do
		total += weight
	end
	local roll = rng:NextNumber(0, total)
	for size, weight in Economy.ThiefGangWeights do
		roll -= weight
		if roll <= 0 then
			return size
		end
	end
	return 1
end

-- Sends a gang of up to `size` thieves at one base. Returns how many.
local function raid(owner: Player, size: number): number
	local plot = PlotService.GetPlot(owner)
	if not plot or shielded(owner) then
		return 0
	end
	local taken: { [number]: boolean } = {}
	local slots: { number } = {}
	local rng = Random.new()
	for _ = 1, size do
		local slot = pickSlot(owner, taken)
		if slot then
			taken[slot] = true
			table.insert(slots, slot)
		end
	end
	if #slots == 0 then
		return 0
	end
	thieves[owner] = thieves[owner] or {}
	NetService.FxTo(owner, "Thief", {})
	NetService.Notify(
		owner,
		if #slots > 1
			then "😈 " .. #slots .. " THIEVES are coming for your base! Bonk them or lock it!"
			else "😈 A THIEF is sneaking to your base! Bonk him or lock it!",
		"Bad"
	)
	NetService.FxTo(owner, "Offer", {
		Product = "InstantLock",
		Text = "Thieves are coming! Lock your base right now.",
		Urgent = true,
	})
	local delay = rng:NextNumber(0, 2)
	for index, slot in slots do
		if index > 1 then
			delay += rng:NextNumber(Economy.ThiefSpacingMin, Economy.ThiefSpacingMax)
		end
		raidPending += 1
		task.delay(delay, function()
			raidPending -= 1
			if owner.Parent and thieves[owner] then
				visit(owner, plot, slot, (index - 1) * 4)
			else
				checkRaidOver()
			end
		end)
	end
	return #slots
end

-- A server-wide raid: every base with enough slimes gets a gang, up to
-- RaidMaxThieves in total, and the whole server is warned.
local function startRaid()
	local rng = Random.new()
	local owners = {}
	for _, player in Players:GetPlayers() do
		if PlotService.GetPlot(player) then
			table.insert(owners, player)
		end
	end
	-- Shuffle so the cap doesn't always favour the same bases.
	for i = #owners, 2, -1 do
		local j = rng:NextInteger(1, i)
		owners[i], owners[j] = owners[j], owners[i]
	end
	raidActive = true
	workspace:SetAttribute("RaidActive", true) -- clients play the chase music while a raid is on
	raidPending = 0
	raidStats = { Caught = 0, Escaped = 0, Stopped = 0 }
	local budget = Economy.RaidMaxThieves
	local sent = 0
	for _, owner in owners do
		if budget <= 0 then
			break
		end
		local n = raid(owner, math.min(gangSize(rng), budget))
		budget -= n
		sent += n
	end
	if sent == 0 then
		raidActive = false
		workspace:SetAttribute("RaidActive", false) -- clients play the chase music while a raid is on
		nextRaidAt = os.clock() + 30 -- nobody has enough slimes yet; check again soon
		return
	end
	NetService.Announce(
		string.format("🚨 THIEF RAID! %d thieves are coming for your slimes! Defend your bases!", sent),
		Color3.fromRGB(255, 70, 70)
	)
end

-- Thieves fight back: a player right in front of one may get shoved over.
local function shoveCheck()
	local now = os.clock()
	for _, gang in thieves do
		for _, thief in gang do
			if not thief.Done and thief.Model.Parent and now - thief.LastShove > Economy.ThiefShoveCooldown then
				local look = thief.Root.CFrame.LookVector
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local offset = root.Position - thief.Root.Position
						local flatOffset = Vector3.new(offset.X, 0, offset.Z)
						if
							flatOffset.Magnitude < Economy.ThiefShoveRange
							and flatOffset.Magnitude > 0.1
							and look:Dot(flatOffset.Unit) > 0.3
						then
							thief.LastShove = now
							if math.random() < Economy.ThiefShoveChance then
								say(thief, "Shove")
								local push = flatOffset.Unit * Economy.ThiefShoveForce
								StealService.Knock(
									player,
									push + Vector3.new(0, Economy.ThiefShoveForce * 0.5, 0),
									Economy.ThiefShoveStun
								)
								NetService.Fx("Bonk", {
									Position = root.Position + Vector3.new(0, 2, 0),
									Victim = player.UserId,
									Dropped = false,
									Golden = false,
									Stun = Economy.ThiefShoveStun,
								})
							end
							break
						end
					end
				end
			end
		end
	end
end

-- Bat hit on an NPC thief: ragdoll him away and end the visit.
local function allThieves(): { Thief }
	local everyone: { Thief } = {}
	for _, gang in thieves do
		for _, thief in gang do
			table.insert(everyone, thief)
		end
	end
	return everyone
end

-- Bonk one thief from `from`: ragdoll him away and end his visit.
local function bonkThief(thief: Thief, attacker: Player, from: Vector3, fallback: Vector3, force: number)
	local offset = thief.Root.Position - from
	local direction = Vector3.new(offset.X, 0, offset.Z)
	direction = if direction.Magnitude > 0.01 then direction.Unit else fallback
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
	task.spawn(function()
		RunService.Heartbeat:Wait()
		for _, part in thief.Model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = part ~= thief.Root
				part.AssemblyLinearVelocity = launch
				part.AssemblyAngularVelocity = -axis * 12
			end
		end
	end)
end

-- A hit he shrugs off: staggers back, loses a heart, then shoves the
-- attacker and sprints off angry. He keeps hold of the slime.
local function hurtThief(thief: Thief, attacker: Player, from: Vector3, fallback: Vector3, force: number)
	local now = os.clock()
	if now - thief.HitAt < 0.45 then
		return
	end
	thief.HitAt = now
	thief.Hits -= 1
	if thief.Hearts then
		thief.Hearts.Text = string.rep("❤️", thief.Hits)
	end
	local offset = thief.Root.Position - from
	local direction = Vector3.new(offset.X, 0, offset.Z)
	direction = if direction.Magnitude > 0.01 then direction.Unit else fallback
	NetService.Fx("Bonk", {
		Position = thief.Root.Position + Vector3.new(0, 2, 0),
		Attacker = attacker.UserId,
		Dropped = false,
		Golden = false,
		Stun = 0.3,
	})
	thief.Root.AssemblyLinearVelocity = direction * force * 0.5 + Vector3.new(0, 18, 0)
	say(thief, "Hurt")
	local humanoid = thief.Humanoid
	local base = if thief.Carry then Economy.ThiefCarrySpeed else Economy.ThiefWalkSpeed
	humanoid.WalkSpeed = base * thief.Speed * Economy.ThiefSprintMultiplier
	task.delay(2, function()
		if not thief.Done then
			local after = if thief.Carry then Economy.ThiefCarrySpeed else Economy.ThiefWalkSpeed
			humanoid.WalkSpeed = after * thief.Speed
		end
	end)
	-- Payback: shove whoever hit him if they're still close.
	task.delay(0.35, function()
		local character = attacker.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if thief.Done or not root or not root:IsA("BasePart") then
			return
		end
		local push = Vector3.new(root.Position.X - thief.Root.Position.X, 0, root.Position.Z - thief.Root.Position.Z)
		if push.Magnitude < 9 and push.Magnitude > 0.1 then
			thief.LastShove = os.clock()
			say(thief, "Shove")
			StealService.Knock(
				attacker,
				push.Unit * Economy.ThiefShoveForce + Vector3.new(0, Economy.ThiefShoveForce * 0.5, 0),
				Economy.ThiefShoveStun
			)
			NetService.Fx("Bonk", {
				Position = root.Position + Vector3.new(0, 2, 0),
				Victim = attacker.UserId,
				Dropped = false,
				Golden = false,
				Stun = Economy.ThiefShoveStun,
			})
		end
	end)
end

-- Bat hit: every thief in reach in front of the swinger loses a heart; the
-- last one bonks him.
local function onSwing(attacker: Player, attackerRoot: BasePart, range: number, force: number)
	for _, thief in allThieves() do
		if not thief.Done and thief.Model.Parent then
			local offset = thief.Root.Position - attackerRoot.Position
			local distance = offset.Magnitude
			local inFront = distance < 3 or attackerRoot.CFrame.LookVector:Dot(offset.Unit) > 0.2
			if distance <= range and inFront then
				if thief.Hits > 1 then
					hurtThief(thief, attacker, attackerRoot.Position, attackerRoot.CFrame.LookVector, force)
				elseif os.clock() - thief.HitAt >= 0.45 then
					bonkThief(thief, attacker, attackerRoot.Position, attackerRoot.CFrame.LookVector, force)
				end
			end
		end
	end
end

function ThiefService.Init()
	StealService.Swung:Connect(onSwing)
	PlotService.Locked:Connect(function(player: Player)
		local plot = PlotService.GetPlot(player)
		for _, thief in table.clone(thieves[player] or {} :: { Thief }) do
			if not thief.Done and plot then
				-- Locking while one is inside traps him; outside, he turns back at the gate.
				local rel = plot.CFrame:PointToObjectSpace(thief.Root.Position)
				if math.abs(rel.X) < World.PlotWidth / 2 + 2 and rel.Z < World.PlotDepth / 2 + 8 then
					finish(thief, "Locked")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, thief in table.clone(thieves[player] or {} :: { Thief }) do
			finish(thief, "Cancelled")
		end
		thieves[player] = nil
		shieldUntil[player] = nil
		task.defer(checkRaidOver)
	end)
end

function ThiefService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			if not raidActive and os.clock() >= nextRaidAt and #Players:GetPlayers() > 0 then
				startRaid()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			shoveCheck()
		end
	end)
end

return ThiefService
