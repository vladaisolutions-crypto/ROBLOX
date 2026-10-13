--!strict
-- Seasonal map dressing, so the world matches the event thumbnails.
-- Halloween: a moonlit night with purple fog and darker grass, bare dead
-- trees, gravestones, jack-o'-lanterns along the belt and on every base gate,
-- and the belt glowing orange and purple. (Bats are drawn by the client.)

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)

local EventService = require(script.Parent.EventService)
local WorldService = require(script.Parent.WorldService)

local DecorService = {}

local function piece(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	ball: boolean?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

-- A jack-o'-lantern resting on the ground at `position`, facing `facing`.
local function pumpkin(parent: Instance, position: Vector3, facing: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "Pumpkin"
	local base = CFrame.lookAt(position, position + facing) * CFrame.new(0, 1.4 * scale, 0)
	local body = piece(model, Vector3.new(3.4, 2.8, 3.4) * scale, base, Color3.fromRGB(255, 125, 20), nil, true)
	piece(model, Vector3.new(0.4, 0.8, 0.4) * scale, base * CFrame.new(0, 1.7 * scale, 0), Color3.fromRGB(90, 120, 40))
	local glow = Color3.fromRGB(255, 220, 80)
	for _, side in { -1, 1 } do
		piece(
			model,
			Vector3.new(0.6, 0.6, 0.2) * scale,
			base * CFrame.new(side * 0.7 * scale, 0.35 * scale, -1.6 * scale),
			glow,
			Enum.Material.Neon
		)
	end
	piece(
		model,
		Vector3.new(1.6, 0.35, 0.2) * scale,
		base * CFrame.new(0, -0.45 * scale, -1.6 * scale),
		glow,
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = body
	model.Parent = parent
end

-- A gravestone: a slab with a rounded top, slightly tilted.
local function gravestone(parent: Instance, position: Vector3, rng: Random)
	local tilt =
		CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-6, 6)))
	local base = CFrame.new(position) * tilt
	local grey = Color3.fromRGB(110, 108, 120):Lerp(Color3.fromRGB(70, 80, 70), rng:NextNumber())
	piece(parent, Vector3.new(2.6, 3, 0.7), base * CFrame.new(0, 1.5, 0), grey, Enum.Material.Slate)
	local top = piece(
		parent,
		Vector3.new(0.7, 2.6, 2.6),
		base * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0),
		grey,
		Enum.Material.Slate
	)
	top.Shape = Enum.PartType.Cylinder
	top.CFrame = base * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0)
	-- A little grave mound in front.
	piece(
		parent,
		Vector3.new(2.6, 0.6, 4),
		base * CFrame.new(0, 0.2, -2.4),
		Color3.fromRGB(55, 45, 35),
		Enum.Material.Ground
	)
end

-- Bare branches on the existing trees (their leaves come off for Halloween).
local function deadTrees(map: Instance, rng: Random)
	local scenery = map:FindFirstChild("Scenery")
	if not scenery then
		return
	end
	for _, child in scenery:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Leaves" then
			child:Destroy()
		elseif child:IsA("BasePart") and child.Name == "Trunk" then
			child.Color = Color3.fromRGB(48, 38, 42)
			local height = child.Size.X
			local top = child.Position + Vector3.new(0, height / 2, 0)
			for i = 1, 4 do
				local yaw = i * math.pi / 2 + rng:NextNumber(-0.4, 0.4)
				local length = rng:NextNumber(4, 7)
				local dir = Vector3.new(math.cos(yaw), rng:NextNumber(0.5, 0.9), math.sin(yaw)).Unit
				local startAt = top - Vector3.new(0, rng:NextNumber(0, height * 0.35), 0)
				local mid = startAt + dir * length / 2
				local branch = piece(
					scenery,
					Vector3.new(length, 0.7, 0.7),
					CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.rad(90), 0),
					child.Color,
					Enum.Material.Wood
				)
				branch.Shape = Enum.PartType.Cylinder
				-- A twig off the end.
				local tipAt = startAt + dir * length
				local twigDir = (dir + Vector3.new(rng:NextNumber(-0.6, 0.6), 0.4, rng:NextNumber(-0.6, 0.6))).Unit
				local twigMid = tipAt + twigDir * 1.4
				local twig = piece(
					scenery,
					Vector3.new(2.8, 0.35, 0.35),
					CFrame.lookAt(twigMid, twigMid + twigDir) * CFrame.Angles(0, math.rad(90), 0),
					child.Color,
					Enum.Material.Wood
				)
				twig.Shape = Enum.PartType.Cylinder
			end
		end
	end
end

local ORANGE = Color3.fromRGB(255, 130, 20)
local PURPLE = Color3.fromRGB(170, 70, 255)
local GREEN_GOO = Color3.fromRGB(110, 255, 60)
local IRON = Color3.fromRGB(25, 22, 30)

-- A thin straight segment from a to b.
local function segment(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): Part
	local mid = (a + b) / 2
	return piece(parent, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt(mid, b), color, material)
end

-- A sagging string of orange and purple bulbs from a to b.
local function lights(parent: Instance, a: Vector3, b: Vector3, sag: number, bulbs: number)
	local wire = Color3.fromRGB(20, 20, 25)
	local previous = a
	for i = 1, bulbs do
		local t = i / (bulbs + 1)
		local point = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		segment(parent, previous, point, 0.08, wire)
		previous = point
		local bulb = piece(
			parent,
			Vector3.new(0.45, 0.6, 0.45),
			CFrame.new(point - Vector3.new(0, 0.3, 0)),
			if i % 2 == 0 then ORANGE else PURPLE,
			Enum.Material.Neon,
			true
		)
		if i % 4 == 0 then
			local light = Instance.new("PointLight")
			light.Color = bulb.Color
			light.Range = 8
			light.Brightness = 0.8
			light.Parent = bulb
		end
	end
	segment(parent, previous, b, 0.08, wire)
end

-- A spider web in a corner: strands fanning out from `corner` between the
-- directions `u` and `v`, with rings of thread across them.
local function cobweb(parent: Instance, corner: Vector3, u: Vector3, v: Vector3, size: number)
	local white = Color3.fromRGB(235, 235, 245)
	local strands = 5
	local dirs: { Vector3 } = {}
	for i = 0, strands - 1 do
		local t = i / (strands - 1) * math.pi / 2
		local dir = (u * math.cos(t) + v * math.sin(t)).Unit
		dirs[i + 1] = dir
		segment(parent, corner, corner + dir * size, 0.06, white)
	end
	for ring = 1, 3 do
		local r = size * ring / 3.4
		for i = 1, strands - 1 do
			segment(parent, corner + dirs[i] * r, corner + dirs[i + 1] * r * 0.92, 0.05, white)
		end
	end
end

-- A bubbling witch's cauldron over a fire.
local function cauldron(parent: Instance, position: Vector3)
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X; stand them up
	local pot = piece(
		parent,
		Vector3.new(9, 8, 9),
		CFrame.new(position + Vector3.new(0, 4.8, 0)),
		IRON,
		Enum.Material.Metal,
		true
	)
	pot.CastShadow = true
	local rim = piece(
		parent,
		Vector3.new(0.8, 8.4, 8.4),
		CFrame.new(position + Vector3.new(0, 8.2, 0)) * up,
		Color3.fromRGB(40, 36, 46),
		Enum.Material.Metal
	)
	rim.Shape = Enum.PartType.Cylinder
	local goo = piece(
		parent,
		Vector3.new(0.5, 7.4, 7.4),
		CFrame.new(position + Vector3.new(0, 8.4, 0)) * up,
		GREEN_GOO,
		Enum.Material.Neon
	)
	goo.Shape = Enum.PartType.Cylinder
	local light = Instance.new("PointLight")
	light.Color = GREEN_GOO
	light.Range = 26
	light.Brightness = 2
	light.Parent = goo
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(GREEN_GOO)
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Lifetime = NumberRange.new(1, 2)
	bubbles.Rate = 10
	bubbles.Speed = NumberRange.new(2, 5)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.EmissionDirection = Enum.NormalId.Right -- the standing cylinder's X axis points up
	bubbles.Parent = goo
	local logs = piece(
		parent,
		Vector3.new(6, 0.8, 6),
		CFrame.new(position + Vector3.new(0, 0.4, 0)),
		Color3.fromRGB(70, 45, 30),
		Enum.Material.Wood
	)
	local fire = Instance.new("Fire")
	fire.Color = ORANGE
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Size = 6
	fire.Heat = 4
	fire.Parent = logs
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		local foot = position + Vector3.new(math.cos(a) * 4.6, 0, math.sin(a) * 4.6)
		local knee = position + Vector3.new(math.cos(a) * 3.4, 3.2, math.sin(a) * 3.4)
		segment(parent, foot, knee, 0.7, IRON, Enum.Material.Metal)
	end
end

-- A scarecrow: a post, a crossbar with a shirt, a sack head and a hat.
local function scarecrow(parent: Instance, position: Vector3, facing: Vector3)
	local base = CFrame.lookAt(position, position + facing)
	local wood = Color3.fromRGB(100, 70, 45)
	local straw = Color3.fromRGB(225, 190, 90)
	local hatColor = Color3.fromRGB(40, 30, 25)
	piece(parent, Vector3.new(0.6, 9, 0.6), base * CFrame.new(0, 4.5, 0), wood, Enum.Material.Wood)
	piece(parent, Vector3.new(7, 0.5, 0.5), base * CFrame.new(0, 6.6, 0), wood, Enum.Material.Wood)
	piece(
		parent,
		Vector3.new(4.4, 3.4, 1.4),
		base * CFrame.new(0, 5.6, 0),
		Color3.fromRGB(150, 60, 40),
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		piece(parent, Vector3.one * 1.3, base * CFrame.new(side * 3.2, 6.6, 0), straw, Enum.Material.Fabric)
	end
	piece(
		parent,
		Vector3.new(2.2, 2.4, 2.2),
		base * CFrame.new(0, 8.6, 0),
		Color3.fromRGB(205, 170, 110),
		Enum.Material.Fabric,
		true
	)
	for _, side in { -1, 1 } do
		piece(
			parent,
			Vector3.new(0.4, 0.4, 0.1),
			base * CFrame.new(side * 0.45, 8.9, -1.05),
			ORANGE,
			Enum.Material.Neon
		)
	end
	piece(parent, Vector3.new(1, 0.15, 0.1), base * CFrame.new(0, 8.1, -1.05), Color3.fromRGB(20, 15, 15))
	local brim = piece(
		parent,
		Vector3.new(0.25, 3.4, 3.4),
		base * CFrame.new(0, 9.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		hatColor,
		Enum.Material.Fabric
	)
	brim.Shape = Enum.PartType.Cylinder
	piece(
		parent,
		Vector3.new(1.8, 1.6, 1.8),
		base * CFrame.new(0, 10.6, 0) * CFrame.Angles(0, 0, math.rad(8)),
		hatColor,
		Enum.Material.Fabric
	)
end

-- A hay bale.
local function hay(parent: Instance, cframe: CFrame)
	piece(
		parent,
		Vector3.new(4, 2.4, 2.6),
		cframe * CFrame.new(0, 1.2, 0),
		Color3.fromRGB(215, 175, 80),
		Enum.Material.Grass
	)
end

-- A floating sheet ghost that bobs and turns.
local function ghost(parent: Instance, position: Vector3, rng: Random)
	local white = Color3.fromRGB(245, 245, 255)
	local face = Color3.fromRGB(20, 20, 30)
	local model = Instance.new("Model")
	model.Name = "Ghost"
	local head = piece(model, Vector3.one * 3.2, CFrame.new(position), white, nil, true)
	head.Transparency = 0.1
	piece(model, Vector3.new(3, 2, 3), CFrame.new(position - Vector3.new(0, 1.2, 0)), white).Transparency = 0.15
	for i = 1, 6 do
		local a = i * math.pi / 3
		local puff = piece(
			model,
			Vector3.one * 1.3,
			CFrame.new(position + Vector3.new(math.cos(a) * 1.2, -2.2, math.sin(a) * 1.2)),
			white,
			nil,
			true
		)
		puff.Transparency = 0.25
	end
	for _, side in { -1, 1 } do
		piece(model, Vector3.new(0.5, 0.8, 0.2), CFrame.new(position + Vector3.new(side * 0.6, 0.3, -1.55)), face)
	end
	piece(model, Vector3.new(0.6, 0.6, 0.2), CFrame.new(position + Vector3.new(0, -0.6, -1.55)), face, nil, true)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(190, 200, 255)
	glow.Range = 10
	glow.Brightness = 0.6
	glow.Parent = head
	model.PrimaryPart = head
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = parent
	-- Bob up and down: tween a CFrameValue and pivot the model to it.
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf: CFrame)
		model:PivotTo(cf)
	end)
	value.Parent = model
	TweenService:Create(
		value,
		TweenInfo.new(
			rng:NextNumber(2, 3.2),
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true,
			rng:NextNumber(0, 2)
		),
		{ Value = value.Value * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(25), 0) }
	):Play()
end

local function halloween()
	-- Purple-orange twilight: spooky but bright enough to see everything.
	Lighting.ClockTime = 18.4
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.7
	Lighting.Ambient = Color3.fromRGB(160, 140, 185)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 165, 210)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.25
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(200, 120, 170)
		atmosphere.Decay = Color3.fromRGB(60, 30, 90)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1
	end
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grade then
		grade.TintColor = Color3.fromRGB(235, 225, 255)
		grade.Saturation = 0.15
		grade.Contrast = 0.12
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = 1
		bloom.Threshold = 1.2
	end
	local ground = workspace:FindFirstChild("Baseplate")
	if ground and ground:IsA("BasePart") then
		ground.Color = Color3.fromRGB(70, 88, 58)
	end

	local map = workspace:WaitForChild("Map")
	local folder = Instance.new("Folder")
	folder.Name = "HalloweenDecor"
	folder.Parent = map
	local rng = Random.new(31)

	deadTrees(map, rng)

	-- The belt glows orange and purple.
	local belt = map:FindFirstChild("Belt")
	if belt then
		for _, p in belt:GetChildren() do
			if p:IsA("BasePart") then
				if p.Name == "Rail" then
					p.Color = Color3.fromRGB(255, 120, 20)
				elseif p.Name == "Chevron" then
					p.Color = Color3.fromRGB(170, 70, 255)
				elseif p.Name == "ArchPillar" then
					p.Color = Color3.fromRGB(255, 120, 20)
				elseif p.Name == "ArchTop" then
					p.Color = Color3.fromRGB(60, 30, 80)
				end
			end
		end
	end

	-- Jack-o'-lanterns on every base's gate pillars.
	for _, plot in WorldService.Plots do
		for _, child in plot.Model:GetChildren() do
			if child:IsA("BasePart") and child.Name == "GateLantern" then
				child.Transparency = 1
				local facing = plot.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
				pumpkin(folder, child.Position - Vector3.new(0, 1.1, 0), facing, 0.75)
			end
		end
	end

	-- Gravestones scattered in the open ground around the bases.
	local halfX, halfZ = World.MapSizeX / 2, World.MapSizeZ / 2
	local placed = 0
	local tries = 0
	while placed < 46 and tries < 600 do
		tries += 1
		local position =
			Vector3.new(rng:NextNumber(-halfX + 10, halfX - 10), 0, rng:NextNumber(-halfZ + 10, halfZ - 10))
		local clear = math.abs(position.Z) > World.BeltWidth / 2 + 10
		for _, plot in WorldService.Plots do
			local rel = plot.CFrame:PointToObjectSpace(position)
			if math.abs(rel.X) < World.PlotWidth / 2 + 8 and math.abs(rel.Z) < World.PlotDepth / 2 + 12 then
				clear = false
			end
		end
		if clear then
			gravestone(folder, position, rng)
			placed += 1
		end
	end
	for x = World.BeltStartX + 20, World.BeltEndX - 10, 24 do
		for _, side in { -1, 1 } do
			local position = Vector3.new(x + rng:NextNumber(-4, 4), 0, side * (World.BeltWidth / 2 + 4))
			pumpkin(folder, position, Vector3.new(0, 0, side), rng:NextNumber(0.7, 1.1))
		end
	end

	-- Lamp posts along the belt with strings of orange and purple lights.
	for _, side in { -1, 1 } do
		local z = side * (World.BeltWidth / 2 + 2)
		local previous: Vector3? = nil
		for x = World.BeltStartX + 8, World.BeltEndX, 24 do
			piece(folder, Vector3.new(0.5, 9, 0.5), CFrame.new(x, 4.5, z), IRON, Enum.Material.Metal)
			local top = Vector3.new(x, 9, z)
			piece(folder, Vector3.one, CFrame.new(top + Vector3.new(0, 0.5, 0)), ORANGE, Enum.Material.Neon, true)
			if previous then
				lights(folder, previous, top, 2, 9)
			end
			previous = top
		end
	end

	-- A bubbling cauldron at each end of the belt.
	cauldron(folder, Vector3.new(World.BeltStartX - 14, 0, 0))
	cauldron(folder, Vector3.new(World.BeltEndX + 14, 0, 0))

	-- Every base: lights across the gate, cobwebs in the gate corners,
	-- pumpkins and hay by the entrance.
	local W, D, floorY = World.PlotWidth, World.PlotDepth, World.FloorY
	for _, plot in WorldService.Plots do
		local cf = plot.CFrame
		local function at(x: number, y: number, z: number): Vector3
			return cf:PointToWorldSpace(Vector3.new(x, y, z))
		end
		local front = D / 2 + 1.5
		lights(folder, at(-W / 2 + 1.5, floorY + 12.6, front), at(-13.5, floorY + 12.6, front), 2.2, 7)
		lights(folder, at(13.5, floorY + 12.6, front), at(W / 2 - 1.5, floorY + 12.6, front), 2.2, 7)
		local outward = cf:VectorToWorldSpace(Vector3.new(0, 0, 1))
		for _, side in { -1, 1 } do
			cobweb(
				folder,
				at(side * (W / 2 - 3), floorY + 12.8, front - 0.2),
				cf:VectorToWorldSpace(Vector3.new(-side, 0, 0)),
				cf:VectorToWorldSpace(Vector3.new(0, -1, 0)),
				4.5
			)
			pumpkin(folder, at(side * (W / 2 + 2.5), 0, D / 2 + 3), outward, 1.1)
			pumpkin(folder, at(side * (W / 2 + 4.5), 0, D / 2 + 0.5), outward, 0.7)
			hay(folder, CFrame.new(at(side * (W / 2 + 3), 0, D / 2 - 4)) * cf.Rotation)
			pumpkin(folder, at(side * (W / 2 + 3), 2.4, D / 2 - 4), outward, 0.55)
		end
	end

	-- Pumpkin patches with a scarecrow in the gaps between bases.
	for _, gapX in { -90, 0, 90 } do
		for _, side in { -1, 1 } do
			local centre = Vector3.new(gapX, 0, side * 70)
			scarecrow(folder, centre, Vector3.new(0, 0, -side))
			for _ = 1, 7 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(3, 9)
				pumpkin(
					folder,
					centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
					Vector3.new(0, 0, -side),
					rng:NextNumber(0.5, 1)
				)
			end
			hay(
				folder,
				CFrame.new(centre + Vector3.new(4, 0, side * 6)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			)
		end
	end

	-- Ghosts floating over the open ground and between the bases.
	for _, spot in
		{
			Vector3.new(-90, 12, 40),
			Vector3.new(0, 14, -40),
			Vector3.new(90, 12, 40),
			Vector3.new(-90, 13, -110),
			Vector3.new(90, 13, -110),
			Vector3.new(0, 12, 120),
			Vector3.new(-200, 12, 0),
			Vector3.new(200, 12, 0),
			Vector3.new(-160, 14, 120),
			Vector3.new(160, 14, -120),
		}
	do
		ghost(folder, spot, rng)
	end
end

function DecorService.Start()
	if EventService.SeasonalActive("Halloween") then
		halloween()
	end
end

return DecorService
