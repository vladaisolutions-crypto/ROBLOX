--!strict
-- Juice: everything that makes the game feel alive.
--
--   Merge  three orbs fly into the merged slime, then a burst, a shockwave
--          ring, a big name pop-up and the cauldron sound (green smoke in
--          the Halloween event). No full-screen flashes anywhere
--          (photosensitive players).
--   Grow   a puff and a boing when a slime grows a size.
--   Cash   a floating "+$" and coins when you collect.
--   Rare   confetti, a fanfare and the rarity name over a rare slime.
--   Jelly  every slime wobbles; a carried (stolen) one wriggles frantically.
--   Haunted Rain  during Halloween, Slime Rain turns the sky dark and ghosts
--          drift down around you.
--   Bats   during Halloween, a flock of bats circles over the map.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)
local Sounds = require(Shared.Config.Sounds).Ids
local Economy = require(Shared.Config.Economy)
local BatSwing = require(script.Parent.BatSwing)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Effects = {}

local folder: Folder
local screenGui: ScreenGui
local lastOffer = -math.huge

local function play(id: string, at: Vector3?, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.7
	sound.PlaybackSpeed = pitch or 1
	if at then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 140
		sound.Parent = holder
		Debris:AddItem(holder, 4)
	else
		sound.Parent = game:GetService("SoundService")
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

local function anchoredPart(size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Parent = folder
	return p
end

local function burst(at: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	p.LightEmission = 0.8
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	p.Transparency = NumberSequence.new(0, 1)
	p.Lifetime = NumberRange.new(0.5, 1.1)
	p.Speed = NumberRange.new(speed * 0.5, speed)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Drag = 3
	p.Acceleration = Vector3.new(0, -12, 0)
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-200, 200)
	if texture then
		p.Texture = texture
	end
	p.Enabled = false
	p.Parent = holder
	p:Emit(count)
	Debris:AddItem(holder, 2.5)
end

-- An expanding ring on the ground.
local function shockwave(at: Vector3, color: Color3, radius: number)
	local ring = anchoredPart(Vector3.new(0.3, 1, 1), color)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.7)
end

-- Big text that pops up over a spot, then floats and fades.
local function popText(at: Vector3, text: string, color: Color3, size: number, rise: number?)
	local anchor = anchoredPart(Vector3.one * 0.1, color)
	anchor.Transparency = 1
	anchor.Position = at
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(360, 90)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size })
		:Play()
	TweenService:Create(
		anchor,
		TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = at + Vector3.new(0, rise or 5, 0) }
	):Play()
	task.delay(1.2, function()
		TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 2)
end

local function shake(amount: number, seconds: number)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > seconds then
			connection:Disconnect()
			return
		end
		local k = amount * (1 - t / seconds)
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

-- The merging player's celebration: a big banner with spinning rays, the
-- income boost, and confetti raining down the screen.
local function mergeBanner(title: string, subtitle: string, color: Color3)
	if not screenGui then
		return
	end
	local holder = Instance.new("Frame")
	holder.Name = "MergeCelebration"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 60
	holder.Parent = screenGui

	-- Spinning light rays behind the title.
	local rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.36)
	rays.Size = UDim2.fromOffset(10, 10)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 60
	rays.Parent = holder
	for i = 1, 12 do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(46, 420)
		ray.Rotation = i * 30
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		ray.BackgroundTransparency = 0.55
		ray.ZIndex = 60
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		fade.Parent = ray
		ray.Parent = rays
	end
	local raysScale = Instance.new("UIScale")
	raysScale.Scale = 0
	raysScale.Parent = rays
	TweenService:Create(raysScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(rays, TweenInfo.new(3.2, Enum.EasingStyle.Linear), { Rotation = 160 }):Play()

	local function bigText(text: string, y: number, size: number, textColor: Color3, delay: number): TextLabel
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromOffset(900, size)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = textColor
		label.ZIndex = 62
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = Color3.fromRGB(25, 15, 35)
		stroke.Parent = label
		local scale = Instance.new("UIScale")
		scale.Scale = 0
		scale.Parent = label
		label.Parent = holder
		task.delay(delay, function()
			TweenService
				:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
			-- A little heartbeat pulse while it is up.
			task.delay(0.5, function()
				TweenService:Create(
					scale,
					TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
					{ Scale = 1.08 }
				):Play()
			end)
		end)
		return label
	end
	local titleLabel = bigText(title, 0.34, 110, color, 0)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.45, color),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.55, color),
		ColorSequenceKeypoint.new(1, color),
	})
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = titleLabel
	task.delay(0.4, function()
		TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Offset = Vector2.new(1, 0) }):Play()
	end)
	bigText(subtitle, 0.47, 54, Color3.fromRGB(140, 255, 140), 0.25)

	-- Confetti raining down the screen.
	local palette = {
		color,
		Color3.fromRGB(255, 220, 60),
		Color3.fromRGB(255, 90, 160),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(140, 255, 120),
	}
	for _ = 1, 70 do
		local bit = Instance.new("Frame")
		bit.BorderSizePixel = 0
		bit.Size = UDim2.fromOffset(math.random(8, 16), math.random(12, 22))
		bit.Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.3, 0)
		bit.BackgroundColor3 = palette[math.random(1, #palette)]
		bit.Rotation = math.random(0, 360)
		bit.ZIndex = 61
		bit.Parent = holder
		local fall = math.random(18, 32) / 10
		TweenService:Create(bit, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(bit.Position.X.Scale + (math.random() - 0.5) * 0.25, 0, 1.1, 0),
			Rotation = bit.Rotation + math.random(-540, 540),
		}):Play()
	end

	task.delay(3, function()
		for _, item in holder:GetDescendants() do
			if item:IsA("TextLabel") then
				TweenService:Create(item, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			elseif item:IsA("UIStroke") then
				TweenService:Create(item, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			elseif item:IsA("Frame") and item ~= holder and item ~= rays then
				TweenService:Create(item, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.wait(0.6)
		holder:Destroy()
	end)
end

-- The slime that was just made, rendered by the server at `at`.
local function slimeNear(at: Vector3): Model?
	local best, bestDistance = nil :: Model?, 6
	for _, model in CollectionService:GetTagged("Slime") do
		if model:IsA("Model") and model:GetAttribute("Carried") ~= true then
			local d = (model:GetPivot().Position - at).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

-- Merge: the three slimes' energy spirals up into a growing core (the camera
-- leans in and trembles for the merger), then SLAM: triple burst, double
-- shockwave, confetti fountain, a light blast, and the new slime jelly-pops
-- out. The merger gets a big banner on top.
local CHARGE = 1.3
local function onMerge(data: { [string]: any })
	local to = data.To
	if typeof(to) ~= "Vector3" then
		return
	end
	if (to - camera.CFrame.Position).Magnitude > 220 then
		return
	end
	local color: Color3 = if typeof(data.Color) == "Color3" then data.Color else Color3.new(1, 1, 1)
	local halloween = data.Halloween == true
	local orbColor = if halloween then Color3.fromRGB(120, 255, 90) else color
	local mine = data.Owner == player.UserId
	local tier = if type(data.Tier) == "number" then data.Tier else 2
	local core = to + Vector3.new(0, 7, 0)

	-- Rising charge-up sound.
	local charge = Instance.new("Sound")
	charge.SoundId = Sounds.Whoosh
	charge.Looped = true
	charge.Volume = 0.5
	charge.PlaybackSpeed = 0.5
	charge.RollOffMaxDistance = 160
	local chargeAt = Instance.new("Attachment")
	chargeAt.WorldPosition = core
	chargeAt.Parent = workspace.Terrain
	charge.Parent = chargeAt
	charge:Play()
	TweenService:Create(charge, TweenInfo.new(CHARGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		PlaybackSpeed = 1.8,
		Volume = 0.9,
	}):Play()
	Debris:AddItem(chargeAt, CHARGE + 0.2)

	-- The growing core of light.
	local glow = anchoredPart(Vector3.one * 0.4, orbColor)
	glow.Shape = Enum.PartType.Ball
	glow.Position = core
	local glowLight = Instance.new("PointLight")
	glowLight.Color = orbColor
	glowLight.Range = 14
	glowLight.Brightness = 1
	glowLight.Parent = glow
	TweenService:Create(glow, TweenInfo.new(CHARGE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.one * 3.4,
	}):Play()
	TweenService:Create(glowLight, TweenInfo.new(CHARGE), { Brightness = 6, Range = 26 }):Play()

	-- Orbs spiral up from the three slimes into the core.
	local orbs: { { Part: Part, From: Vector3, Angle: number } } = {}
	local from = if type(data.From) == "table" then data.From else {}
	for i, position in from do
		if typeof(position) == "Vector3" then
			local orb = anchoredPart(Vector3.one * 1.6, orbColor)
			orb.Shape = Enum.PartType.Ball
			orb.Position = position
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 0.6, 0), Vector3.new(0, -0.6, 0)
			a0.Parent, a1.Parent = orb, orb
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Color = ColorSequence.new(orbColor, Color3.new(1, 1, 1))
			trail.LightEmission = 1
			trail.Lifetime = 0.35
			trail.Parent = orb
			local offset = position - core
			table.insert(orbs, { Part = orb, From = position, Angle = math.atan2(offset.Z, offset.X) + i })
		end
	end
	local fov0 = camera.FieldOfView
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / CHARGE, 1)
		local eased = t * t
		for _, orb in orbs do
			local flat = Vector3.new(orb.From.X - core.X, 0, orb.From.Z - core.Z)
			local radius = flat.Magnitude * (1 - eased)
			local angle = orb.Angle + eased * math.pi * 5
			local height = (orb.From.Y - core.Y) * (1 - eased) + math.sin(t * math.pi) * 3
			orb.Part.Position = core + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		end
		if mine then
			camera.FieldOfView = fov0 - 12 * eased
			local k = 0.012 * eased
			camera.CFrame *= CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
		end
		if t >= 1 then
			connection:Disconnect()
		end
	end)

	task.delay(CHARGE, function()
		for _, orb in orbs do
			orb.Part:Destroy()
		end
		-- SLAM: the core drops into the pedestal and blows.
		TweenService:Create(glow, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = to,
			Size = Vector3.one * 6,
		}):Play()
		task.wait(0.12)
		glow:Destroy()
		play(Sounds.Merge, to, 1.2)
		play(Sounds.Rare, to, 0.8, 1.1)
		if mine then
			play(Sounds.Fanfare, nil, 0.8)
		end
		burst(to, orbColor, 90, 40, 1.6)
		burst(to, Color3.new(1, 1, 1), 40, 26, 1)
		burst(to, Color3.fromRGB(255, 215, 60), 50, 34, 0.8, "rbxasset://textures/particles/sparkles_main.dds")
		if halloween then
			burst(to, Color3.fromRGB(60, 200, 60), 30, 8, 3.5, "rbxasset://textures/particles/smoke_main.dds")
		end
		shockwave(to - Vector3.new(0, 1.5, 0), orbColor, 18)
		task.delay(0.15, function()
			shockwave(to - Vector3.new(0, 1.5, 0), Color3.new(1, 1, 1), 30)
		end)
		-- Confetti fountain.
		local confetti =
			{ orbColor, Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 90, 160), Color3.fromRGB(90, 200, 255) }
		for i = 1, 40 do
			local bit = Instance.new("Part")
			bit.Size = Vector3.new(0.35, 0.05, 0.5)
			bit.Color = confetti[(i % #confetti) + 1]
			bit.Material = Enum.Material.SmoothPlastic
			bit.CanCollide = false
			bit.CanQuery = false
			bit.CanTouch = false
			bit.CFrame = CFrame.new(to + Vector3.new(0, 1, 0))
			bit.Parent = folder
			bit.AssemblyLinearVelocity =
				Vector3.new((math.random() - 0.5) * 30, math.random(30, 50), (math.random() - 0.5) * 30)
			bit.AssemblyAngularVelocity = Vector3.new(math.random(-20, 20), math.random(-20, 20), math.random(-20, 20))
			Debris:AddItem(bit, 3)
		end
		-- A blast of light that lights up the base (a light, not a screen flash).
		local blast = Instance.new("Attachment")
		blast.WorldPosition = to + Vector3.new(0, 3, 0)
		blast.Parent = workspace.Terrain
		local light = Instance.new("PointLight")
		light.Color = orbColor
		light.Range = 40
		light.Brightness = 8
		light.Parent = blast
		TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
		Debris:AddItem(blast, 1.3)

		-- The new slime jelly-pops out: tiny, overshoot, settle.
		local slime = slimeNear(to)
		if slime then
			local base = slime:GetScale()
			local value = Instance.new("NumberValue")
			value.Value = 0.25
			value.Changed:Connect(function(k: number)
				if slime.Parent then
					slime:ScaleTo(base * k)
				end
			end)
			TweenService:Create(value, TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Value = 1,
			}):Play()
			Debris:AddItem(value, 1)
		end

		local name = if type(data.Name) == "string" then data.Name else "MERGED"
		popText(to + Vector3.new(0, 5, 0), string.upper(name) .. "!", color, if data.Special then 1.5 else 1.25, 7)
		if mine then
			shake(0.05, 0.5)
			-- Camera springs back past normal, then settles.
			TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				FieldOfView = fov0 + 6,
			}):Play()
			task.delay(0.25, function()
				TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { FieldOfView = fov0 }):Play()
			end)
			local mergeTier = Economy.MergeTiers[tier]
			local boost = if mergeTier then mergeTier.Income else 1
			local title = if data.Special
				then string.upper(name) .. "!"
				elseif tier >= 3 then "COLOSSAL SLIME!"
				else "GIANT SLIME!"
			local subtitle = if data.Special
				then "✨ A brand new slime! ✨"
				else string.format("x%s INCOME! 💰", (string.format("%.1f", boost):gsub("%.0$", "")))
			mergeBanner(title, subtitle, color)
		end
	end)
end

local function onGrow(data: { [string]: any })
	local at = data.Position
	if typeof(at) ~= "Vector3" then
		return
	end
	if (at - camera.CFrame.Position).Magnitude > 120 then
		return
	end
	play(Sounds.Boing, at, 0.6, 0.9 + math.random() * 0.2)
	burst(at, Color3.fromRGB(150, 255, 150), 16, 10, 0.8)
	popText(at + Vector3.new(0, 3, 0), "🌱 GREW!", Color3.fromRGB(150, 255, 150), 0.6, 3)
end

local function onCash(data: { [string]: any })
	local at = data.Position
	if typeof(at) ~= "Vector3" then
		return
	end
	local amount = if type(data.Amount) == "number" then data.Amount else 0
	play(Sounds.Cash, at, 0.7, 0.95 + math.random() * 0.1)
	burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 60), 14, 14, 0.7)
	popText(at + Vector3.new(0, 3, 0), "+" .. Format.Cash(amount), Color3.fromRGB(120, 255, 120), 0.8, 4)
end

local function onRare(data: { [string]: any })
	local at = data.Position
	if typeof(at) ~= "Vector3" then
		return
	end
	local color: Color3 = if typeof(data.Color) == "Color3" then data.Color else Color3.new(1, 1, 1)
	play(Sounds.Rare, at, 0.9)
	burst(at, color, 50, 35, 1)
	burst(at, Color3.fromRGB(255, 255, 255), 30, 25, 0.6)
	shockwave(at - Vector3.new(0, 1.5, 0), color, 12)
	local rarity = if type(data.Rarity) == "string" then string.upper(data.Rarity) else "RARE"
	popText(at + Vector3.new(0, 4, 0), rarity .. "!", color, 1.2)
	if data.Owner == player.UserId then
	end
end

local function characterOf(userId: any): Model?
	local who = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	return if who then who.Character else nil
end

-- Bat swing: the barrel trail streaks and the air whooshes.
-- The full-body bat swing (see BatSwing): every client poses the
-- attacker's joints each frame with their animations muted.
local SWING_JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
}
local R6_NAMES: { [string]: string } = {
	Root = "RootJoint",
	Neck = "Neck",
	RightShoulder = "Right Shoulder",
	LeftShoulder = "Left Shoulder",
	RightHip = "Right Hip",
	LeftHip = "Left Hip",
}
local restC0: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local swingToken: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- A joint we can bend: Motor6D (old rigs) or AnimationConstraint (current).
local function findJoint(character: Model, name: string): BatSwing.Joint?
	local joint = character:FindFirstChild(name, true)
	if not joint and R6_NAMES[name] then
		joint = character:FindFirstChild(R6_NAMES[name], true)
	end
	if joint and joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
		local motor = joint
		local found: BatSwing.Joint = {
			Key = motor,
			Part0 = motor.Part0 :: BasePart,
			Part1 = motor.Part1 :: BasePart,
			GetA0 = function()
				return motor.C0
			end,
			SetA0 = function(cf: CFrame)
				motor.C0 = cf
			end,
			A1 = motor.C1,
		}
		return found
	elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 and joint.Attachment1 then
		local a0 = joint.Attachment0 :: Attachment
		local a1 = joint.Attachment1 :: Attachment
		local part0, part1 = a0.Parent, a1.Parent
		if part0 and part0:IsA("BasePart") and part1 and part1:IsA("BasePart") then
			local found: BatSwing.Joint = {
				Key = a0,
				Part0 = part0,
				Part1 = part1,
				GetA0 = function()
					return a0.CFrame
				end,
				SetA0 = function(cf: CFrame)
					a0.CFrame = cf
				end,
				A1 = a1.CFrame,
			}
			return found
		end
	end
	return nil
end

-- The bat handle's offset from the right hand (Handle = Hand * grip).
local function gripOf(character: Model): CFrame
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if weld and weld:IsA("JointInstance") then
		return weld.C0 * weld.C1:Inverse()
	end
	local attachment = hand and hand:FindFirstChild("RightGripAttachment")
	local tool = character:FindFirstChildOfClass("Tool")
	local c0 = if attachment and attachment:IsA("Attachment") then attachment.CFrame else CFrame.identity
	return c0 * (if tool then tool.Grip else CFrame.identity):Inverse()
end

local function swingAnimation(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints: { [string]: BatSwing.Joint } = {}
	for _, name in SWING_JOINTS do
		local joint = findJoint(character, name)
		if joint then
			joints[name] = joint
			if not restC0[joint.Key] then
				restC0[joint.Key] = joint.GetA0()
			end
		end
	end
	if not joints.RightShoulder then
		return
	end
	local grip = gripOf(character)
	-- Mute the animations so the pose is ours (idle, walk, tool hold).
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local muted: { AnimationTrack } = {}
	local playedConnection: RBXScriptConnection? = nil
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:AdjustWeight(0.001, 0)
			table.insert(muted, track)
		end
		playedConnection = animator.AnimationPlayed:Connect(function(track: AnimationTrack)
			track:AdjustWeight(0.001, 0)
			table.insert(muted, track)
		end)
	end

	local token = (swingToken[character] or 0) + 1
	swingToken[character] = token
	local start = os.clock()
	local connection
	local function stop(restore: boolean)
		connection:Disconnect()
		if playedConnection then
			playedConnection:Disconnect()
		end
		for _, track in muted do
			if track.IsPlaying then
				track:AdjustWeight(1, 0.15)
			end
		end
		if restore then
			for _, joint in joints do
				local rest = restC0[joint.Key]
				if rest then
					joint.SetA0(rest)
				end
				restC0[joint.Key] = nil
			end
		end
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if swingToken[character] ~= token then
			stop(false) -- a newer swing on this character took over
			return
		end
		if not root.Parent or t >= BatSwing.Length then
			stop(true)
			return
		end
		BatSwing.Pose(joints, restC0, root.CFrame, t, grip)
	end)
end

local function onSwing(data: { [string]: any })
	local character = characterOf(data.Attacker)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - camera.CFrame.Position).Magnitude > 120 then
		return
	end
	swingAnimation(character)
	task.delay(0.2, function()
		play(Sounds.Whoosh, root.Position, 0.6, 0.9 + math.random() * 0.25)
	end)
	local trail = character:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(0.4, function()
			trail.Enabled = false
		end)
	end
end

-- Dizzy stars circling a stunned player's head.
local function dizzy(character: Model, seconds: number)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local stars = {}
	for i = 1, 4 do
		local star = anchoredPart(Vector3.one * 0.45, Color3.fromRGB(255, 230, 60))
		star.Shape = Enum.PartType.Ball
		stars[i] = star
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > seconds or not head.Parent then
			connection:Disconnect()
			for _, star in stars do
				star:Destroy()
			end
			return
		end
		for i, star in stars do
			local angle = t * 7 + i * math.pi / 2
			star.Position = head.Position
				+ Vector3.new(math.cos(angle) * 1.3, 1.2 + math.sin(t * 9 + i) * 0.15, math.sin(angle) * 1.3)
		end
	end)
end

-- Bat hit: BONK pop-up, stars, the cartoon bonk, shakes, and dizzy stars.
local function onBonk(data: { [string]: any })
	local at = data.Position
	if typeof(at) ~= "Vector3" then
		return
	end
	local golden = data.Golden == true
	local color = if golden then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(255, 255, 255)
	play(Sounds.Bonk, at, 1, 0.92 + math.random() * 0.18)
	burst(at, Color3.fromRGB(255, 230, 60), 28, 28, 0.9)
	burst(at, color, 14, 18, 0.6)
	shockwave(at, Color3.fromRGB(255, 240, 150), 7)
	popText(
		at + Vector3.new(0, 2.5, 0),
		if data.Dropped then "BONK! DROPPED IT!" else "BONK!",
		if data.Dropped then Color3.fromRGB(255, 90, 60) else Color3.fromRGB(255, 230, 60),
		if data.Dropped then 1.15 else 0.95
	)
	local victim = characterOf(data.Victim)
	if victim then
		dizzy(victim, if type(data.Stun) == "number" then data.Stun else 1.5)
	end
	if data.Victim == player.UserId then
		shake(0.07, 0.45)
	elseif data.Attacker == player.UserId then
		shake(0.025, 0.18)
	end
end

-- A pass offer at the moment it helps: a card that slides up with a buy
-- button, and goes away on its own. At most one every 90 seconds.
local function onOffer(data: { [string]: any })
	local pass = if type(data.Pass) == "string" then Monetization.PassByKey[data.Pass] else nil
	local product = if type(data.Product) == "string" then Monetization.ProductByKey[data.Product] else nil
	local offer = pass or product
	if not offer or offer.Id == 0 or (pass and Store.HasPass(pass.Key)) then
		return
	end
	if os.clock() - lastOffer < (if data.Urgent == true then 20 else 90) then
		return
	end
	lastOffer = os.clock()
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, 480, 0.2, 0)
	card.Size = UDim2.fromOffset(460, 96)
	card.BackgroundColor3 = Color3.fromRGB(30, 24, 45)
	card.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 3
	stroke.Parent = card
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(14, 8)
	text.Size = UDim2.new(1, -190, 1, -16)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = offer.Icon .. " " .. (if type(data.Text) == "string" then data.Text else offer.Description)
	text.Parent = card
	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Size = UDim2.fromOffset(160, 58)
	buy.BackgroundColor3 = Color3.fromRGB(0, 176, 80)
	buy.Font = Enum.Font.FredokaOne
	buy.TextScaled = true
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Text = "GET " .. string.upper(offer.Name) .. "\nR$ " .. offer.SuggestedPrice
	buy.Parent = card
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buy
	buy.Activated:Connect(function()
		if pass then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		else
			MarketplaceService:PromptProductPurchase(player, offer.Id)
		end
	end)
	-- Buy button pulses so it catches the eye.
	TweenService:Create(
		buy,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundColor3 = Color3.fromRGB(40, 220, 110) }
	):Play()
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -12, 0.2, 0),
	}):Play()
	task.delay(9, function()
		TweenService:Create(card, TweenInfo.new(0.35), { Position = UDim2.new(1, 480, 0.2, 0) }):Play()
		Debris:AddItem(card, 0.4)
	end)
end

-- Jelly wobble: squash and stretch each slime body's mesh (visual only).
local function jelly()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local eye = camera.CFrame.Position
		for _, body in CollectionService:GetTagged("SlimeBody") do
			if body:IsA("BasePart") and (body.Position - eye).Magnitude < 130 then
				local mesh = body:FindFirstChildOfClass("SpecialMesh")
				local model = body.Parent
				if mesh and model then
					local seed = (body.Position.X * 0.37 + body.Position.Z * 0.21) % 6.28
					local carried = model:GetAttribute("Carried") == true
					local speed = if carried then 14 else 3.2
					local amount = if carried then 0.13 else 0.055
					local a = math.sin(t * speed + seed) * amount
					mesh.Scale = Vector3.new(1 + a, 1 - a * 1.4, 1 + a)
				end
			end
		end
	end)
end

-- Haunted Rain (Slime Rain during Halloween): darker sky, drifting ghosts.
local function hauntedRain()
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "GhostSky"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(140, 1, 140)
	emitterPart.Parent = folder
	local ghosts = Instance.new("ParticleEmitter")
	ghosts.Texture = "rbxasset://textures/particles/smoke_main.dds"
	ghosts.Color = ColorSequence.new(Color3.fromRGB(210, 255, 230))
	ghosts.LightEmission = 0.6
	ghosts.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 5) })
	ghosts.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	ghosts.Speed = NumberRange.new(4, 8)
	ghosts.EmissionDirection = Enum.NormalId.Bottom
	ghosts.Lifetime = NumberRange.new(6, 9)
	ghosts.Rate = 18
	ghosts.RotSpeed = NumberRange.new(-30, 30)
	ghosts.Shape = Enum.ParticleEmitterShape.Box
	ghosts.Enabled = false
	ghosts.Parent = emitterPart

	local baseBrightness = Lighting.Brightness
	local baseClock = Lighting.ClockTime
	local active = false
	local function update()
		local events = Store.Events
		local seasonal = events.Seasonal
		local haunted = events.RainActive == true and type(seasonal) == "table" and seasonal.Id == "Halloween"
		if haunted == active then
			return
		end
		active = haunted
		ghosts.Enabled = haunted
		if haunted then
			baseBrightness, baseClock = Lighting.Brightness, Lighting.ClockTime
		end
		TweenService:Create(Lighting, TweenInfo.new(2), {
			Brightness = if haunted then baseBrightness * 0.5 else baseBrightness,
			ClockTime = if haunted then 20.5 else baseClock,
		}):Play()
	end
	Store.Changed:Connect(function(section: string)
		if section == "Events" then
			update()
		end
	end)
	update()
	RunService.RenderStepped:Connect(function()
		if active then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
	end)
end

-- A bat: a body and two flapping wings.
local function makeBat(): (Model, BasePart, BasePart, BasePart)
	local model = Instance.new("Model")
	model.Name = "Bat"
	local dark = Color3.fromRGB(20, 15, 25)
	local body = anchoredPart(Vector3.new(0.8, 0.8, 1.2), dark, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Ball
	body.Parent = model
	local left = anchoredPart(Vector3.new(2.2, 0.15, 1.2), dark, Enum.Material.SmoothPlastic)
	left.Parent = model
	local right = anchoredPart(Vector3.new(2.2, 0.15, 1.2), dark, Enum.Material.SmoothPlastic)
	right.Parent = model
	for _, side in { -1, 1 } do
		local eye = anchoredPart(Vector3.one * 0.18, Color3.fromRGB(255, 60, 40))
		eye.Name = "Eye" .. side
		eye.Parent = model
	end
	model.Parent = folder
	return model, body, left, right
end

local function bats()
	type Bat = {
		Model: Model,
		Body: BasePart,
		Left: BasePart,
		Right: BasePart,
		Radius: number,
		Height: number,
		Speed: number,
		Phase: number,
		Centre: Vector3,
	}
	local flock: { Bat } = {}
	local active = false
	local function setActive(on: boolean)
		if on == active then
			return
		end
		active = on
		if on then
			local rng = Random.new()
			for _ = 1, 14 do
				local model, body, left, right = makeBat()
				table.insert(flock, {
					Model = model,
					Body = body,
					Left = left,
					Right = right,
					Radius = rng:NextNumber(30, 140),
					Height = rng:NextNumber(30, 60),
					Speed = rng:NextNumber(0.25, 0.6) * (if rng:NextNumber() < 0.5 then -1 else 1),
					Phase = rng:NextNumber(0, math.pi * 2),
					Centre = Vector3.new(rng:NextNumber(-120, 120), 0, rng:NextNumber(-60, 60)),
				})
			end
		else
			for _, bat in flock do
				bat.Model:Destroy()
			end
			table.clear(flock)
		end
	end
	local function check()
		local seasonal = Store.Events.Seasonal
		setActive(type(seasonal) == "table" and seasonal.Id == "Halloween")
	end
	Store.Changed:Connect(function(section: string)
		if section == "Events" then
			check()
		end
	end)
	check()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local t = os.clock() - t0
		for _, bat in flock do
			local a = bat.Phase + t * bat.Speed
			local position = bat.Centre
				+ Vector3.new(
					math.cos(a) * bat.Radius,
					bat.Height + math.sin(t * 1.7 + bat.Phase) * 3,
					math.sin(a) * bat.Radius
				)
			local ahead = bat.Centre
				+ Vector3.new(
					math.cos(a + 0.05 * math.sign(bat.Speed)) * bat.Radius,
					bat.Height,
					math.sin(a + 0.05 * math.sign(bat.Speed)) * bat.Radius
				)
			local cf = CFrame.lookAt(position, ahead)
			local flap = math.sin(t * 16 + bat.Phase) * 0.7
			bat.Body.CFrame = cf
			bat.Left.CFrame = cf * CFrame.new(-0.4, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.1, 0, 0)
			bat.Right.CFrame = cf * CFrame.new(0.4, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.1, 0, 0)
			for _, side in { -1, 1 } do
				local eye = bat.Model:FindFirstChild("Eye" .. side)
				if eye and eye:IsA("BasePart") then
					eye.CFrame = cf * CFrame.new(side * 0.2, 0.15, -0.5)
				end
			end
		end
	end)
end

function Effects.Start(screen: ScreenGui)
	screenGui = screen
	folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = workspace
	Remotes.Get("Fx").OnClientEvent:Connect(function(kind: string, data: any)
		if type(data) ~= "table" then
			return
		end
		if kind == "Merge" then
			onMerge(data)
		elseif kind == "Grow" then
			onGrow(data)
		elseif kind == "Cash" then
			onCash(data)
		elseif kind == "Rare" then
			onRare(data)
		elseif kind == "Offer" then
			onOffer(data)
		elseif kind == "Thief" then
			play(Sounds.Alarm, nil, 0.8)
		elseif kind == "ThiefCaught" then
			play(Sounds.Fanfare, nil, 0.8)
		elseif kind == "ThiefPoof" and typeof(data.Position) == "Vector3" then
			burst(data.Position, Color3.fromRGB(120, 110, 140), 18, 14, 0.7)
			play(Sounds.Pop, data.Position, 0.7, 0.8)
		elseif kind == "Swing" then
			onSwing(data)
		elseif kind == "Bonk" then
			onBonk(data)
		end
	end)
	jelly()
	hauntedRain()
	bats()
end

return Effects
