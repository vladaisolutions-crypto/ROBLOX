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

local function onMerge(data: { [string]: any })
	local to = data.To
	if typeof(to) ~= "Vector3" then
		return
	end
	local color: Color3 = if typeof(data.Color) == "Color3" then data.Color else Color3.new(1, 1, 1)
	local halloween = data.Halloween == true
	local orbColor = if halloween then Color3.fromRGB(120, 255, 90) else color
	local from = if type(data.From) == "table" then data.From else {}
	for _, position in from do
		if typeof(position) == "Vector3" then
			local orb = anchoredPart(Vector3.one * 1.4, orbColor)
			orb.Shape = Enum.PartType.Ball
			orb.Position = position
			local light = Instance.new("PointLight")
			light.Color = orbColor
			light.Range = 10
			light.Brightness = 2
			light.Parent = orb
			local trail = Instance.new("Trail")
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 0.5, 0), Vector3.new(0, -0.5, 0)
			a0.Parent, a1.Parent = orb, orb
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Color = ColorSequence.new(orbColor)
			trail.LightEmission = 1
			trail.Lifetime = 0.25
			trail.Parent = orb
			local mid = (position + to) / 2 + Vector3.new(0, 6, 0)
			-- Arc over: up to the midpoint, then down into the cauldron spot.
			TweenService:Create(orb, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Position = mid,
			}):Play()
			task.delay(0.25, function()
				TweenService:Create(orb, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = to,
					Size = Vector3.one * 0.4,
				}):Play()
			end)
			Debris:AddItem(orb, 0.5)
		end
	end
	task.delay(0.48, function()
		play(Sounds.Merge, to, 1)
		burst(to, orbColor, 70, 30, 1.4)
		if halloween then
			burst(to, Color3.fromRGB(60, 200, 60), 30, 8, 3.5, "rbxasset://textures/particles/smoke_main.dds")
		end
		shockwave(to - Vector3.new(0, 1.5, 0), orbColor, 16)
		local name = if type(data.Name) == "string" then data.Name else "MERGED!"
		popText(to + Vector3.new(0, 4, 0), string.upper(name) .. "!", color, if data.Special then 1.4 else 1.1)
		if data.Owner == player.UserId then
			shake(0.03, 0.35)
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
local function onSwing(data: { [string]: any })
	local character = characterOf(data.Attacker)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - camera.CFrame.Position).Magnitude > 120 then
		return
	end
	play(Sounds.Whoosh, root.Position, 0.6, 0.9 + math.random() * 0.25)
	local trail = character:FindFirstChild("SwingTrail", true)
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(0.35, function()
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
	if not pass or pass.Id == 0 or Store.HasPass(pass.Key) or os.clock() - lastOffer < 90 then
		return
	end
	lastOffer = os.clock()
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 120)
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
	text.Text = pass.Icon .. " " .. (if type(data.Text) == "string" then data.Text else pass.Description)
	text.Parent = card
	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Size = UDim2.fromOffset(160, 58)
	buy.BackgroundColor3 = Color3.fromRGB(0, 176, 80)
	buy.Font = Enum.Font.FredokaOne
	buy.TextScaled = true
	buy.TextColor3 = Color3.new(1, 1, 1)
	buy.Text = "GET " .. string.upper(pass.Name) .. "\nR$ " .. pass.SuggestedPrice
	buy.Parent = card
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 10)
	buyCorner.Parent = buy
	buy.Activated:Connect(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)
	-- Buy button pulses so it catches the eye.
	TweenService:Create(
		buy,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundColor3 = Color3.fromRGB(40, 220, 110) }
	):Play()
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -110),
	}):Play()
	task.delay(9, function()
		TweenService:Create(card, TweenInfo.new(0.35), { Position = UDim2.new(0.5, 0, 1, 120) }):Play()
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
