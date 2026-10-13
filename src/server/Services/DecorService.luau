--!strict
-- Seasonal map dressing, so the world matches the event thumbnails.
-- Halloween: a moonlit night with purple fog and darker grass, bare dead
-- trees, gravestones, jack-o'-lanterns along the belt and on every base gate,
-- and the belt glowing orange and purple. (Bats are drawn by the client.)

local Lighting = game:GetService("Lighting")

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

local function halloween()
	-- Moonlit night: dark purple fog, the neon and lanterns doing the lighting.
	Lighting.ClockTime = 0
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.5
	Lighting.Ambient = Color3.fromRGB(135, 115, 165)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 140, 195)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(120, 90, 170)
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
end

function DecorService.Start()
	if EventService.SeasonalActive("Halloween") then
		halloween()
	end
end

return DecorService
