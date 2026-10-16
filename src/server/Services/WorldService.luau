--!strict
-- Generates the whole map from Config/World at server start: the slime belt
-- in the middle and eight bases (plots) facing it.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Economy = require(Shared.Config.Economy)

export type Plot = {
	Index: number,
	CFrame: CFrame,
	Model: Model,
	Barrier: BasePart,
	LockPad: BasePart,
	ExpandPad: BasePart,
	ExpandLabel: TextLabel,
	OwnerLabel: TextLabel,
	StatusLabel: TextLabel,
	SpawnCFrame: CFrame,
	Spawn: SpawnLocation,
	Pedestals: { BasePart },
	CollectPads: { BasePart },
	PadLabels: { TextLabel },
	BarrierGroup: string,
	OwnerGroup: string,
}

local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(255, 180, 90),
	Color3.fromRGB(255, 230, 100),
	Color3.fromRGB(130, 220, 120),
	Color3.fromRGB(110, 200, 255),
	Color3.fromRGB(150, 140, 255),
	Color3.fromRGB(230, 130, 255),
	Color3.fromRGB(255, 140, 200),
}

local WorldService = {}
WorldService.Plots = {} :: { Plot }

local mapFolder: Folder

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

local function billboard(adornee: BasePart, offset: Vector3, size: UDim2, maxDistance: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Parent = adornee
	return gui
end

local function label(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position or UDim2.new()
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Parent = parent
	return l
end

local function setupLighting()
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1
	atmosphere.Color = Color3.fromRGB(200, 220, 255)
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.2
	color.Contrast = 0.05
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.7
	rays.Parent = Lighting

	-- Soft shadows and PBR reflections so the slimes look glossy.
	Lighting.ShadowSoftness = 0.3
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 250, 255)
	clouds.Parent = workspace.Terrain
end

local function buildBelt()
	local folder = Instance.new("Folder")
	folder.Name = "Belt"
	folder.Parent = mapFolder

	local length = World.BeltEndX - World.BeltStartX
	local centerX = (World.BeltStartX + World.BeltEndX) / 2
	part({
		Name = "Belt",
		Size = Vector3.new(length, World.BeltY, World.BeltWidth),
		CFrame = CFrame.new(centerX, World.BeltY / 2, 0),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.DiamondPlate,
		Parent = folder,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(length, 1, 1),
			CFrame = CFrame.new(centerX, World.BeltY + 0.5, side * (World.BeltWidth / 2 + 0.5)),
			Color = Color3.fromRGB(0, 200, 255),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	-- Direction chevrons
	for x = World.BeltStartX + 10, World.BeltEndX - 10, 14 do
		for _, side in { -1, 1 } do
			part({
				Name = "Chevron",
				Size = Vector3.new(0.6, 0.1, 4),
				CFrame = CFrame.new(x, World.BeltY + 0.05, side * 2) * CFrame.Angles(0, math.rad(side * 35), 0),
				Color = Color3.fromRGB(255, 210, 60),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
		end
	end
	-- Entry arch
	local archX = World.BeltStartX + 4
	for _, side in { -1, 1 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(3, 18, 3),
			CFrame = CFrame.new(archX, 9, side * (World.BeltWidth / 2 + 2)),
			Color = Color3.fromRGB(120, 255, 120),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	local top = part({
		Name = "ArchTop",
		Size = Vector3.new(3, 4, World.BeltWidth + 7),
		CFrame = CFrame.new(archX, 19, 0),
		Color = Color3.fromRGB(60, 200, 80),
		Parent = folder,
	})
	local gui = billboard(top, Vector3.new(0, 5, 0), UDim2.fromOffset(400, 90), 400)
	label(gui, "🟢 SLIME BELT 🟢", Color3.fromRGB(150, 255, 150), UDim2.fromScale(1, 1))
end

local function buildPlot(index: number, cframe: CFrame): Plot
	local W, D, floorY = World.PlotWidth, World.PlotDepth, World.FloorY
	local color = PLOT_COLORS[index]
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("PlotIndex", index)
	model.Parent = mapFolder

	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	part({
		Name = "Floor",
		Size = Vector3.new(W, 1, D),
		CFrame = at(0, floorY - 0.5, 0),
		Color = color:Lerp(Color3.fromRGB(45, 42, 55), 0.7),
		Material = Enum.Material.Slate,
		Parent = model,
	})
	-- Glowing trim around the floor so each base reads clearly, day or night.
	for _, edge in
		{
			{ Vector3.new(W, 0.3, 0.6), Vector3.new(0, 0, D / 2 - 0.3) },
			{ Vector3.new(W, 0.3, 0.6), Vector3.new(0, 0, -D / 2 + 0.3) },
			{ Vector3.new(0.6, 0.3, D), Vector3.new(W / 2 - 0.3, 0, 0) },
			{ Vector3.new(0.6, 0.3, D), Vector3.new(-W / 2 + 0.3, 0, 0) },
		}
	do
		part({
			Name = "Trim",
			Size = edge[1],
			CFrame = at(edge[2].X, floorY + 0.15, edge[2].Z),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
	end
	-- Walls on three sides (invisible colliders), dressed as a spiked iron
	-- fence with a glowing rail. The entrance faces the belt (+Z local).
	local iron = Color3.fromRGB(30, 28, 36)
	local function fence(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local mid = (from + to) / 2
		local alongX = math.abs(dir.X) > 0.5
		part({
			Name = "Wall",
			Size = if alongX
				then Vector3.new(length, World.WallHeight, 1)
				else Vector3.new(1, World.WallHeight, length),
			CFrame = at(mid.X, floorY + World.WallHeight / 2, mid.Z),
			Color = iron,
			Transparency = 1,
			Parent = model,
		})
		for _, y in { 2.2, 5.6 } do
			part({
				Name = "Rail",
				Size = if alongX then Vector3.new(length, 0.35, 0.35) else Vector3.new(0.35, 0.35, length),
				CFrame = at(mid.X, floorY + y, mid.Z),
				Color = iron,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = model,
			})
		end
		part({
			Name = "Glow",
			Size = if alongX then Vector3.new(length, 0.2, 0.2) else Vector3.new(0.2, 0.2, length),
			CFrame = at(mid.X, floorY + 5.95, mid.Z),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
		local posts = math.max(2, math.floor(length / 3.2))
		for i = 0, posts do
			local p = from + (to - from) * (i / posts)
			part({
				Name = "Post",
				Size = Vector3.new(0.4, 7, 0.4),
				CFrame = at(p.X, floorY + 3.5, p.Z),
				Color = iron,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = model,
			})
			part({
				Name = "Spike",
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = at(p.X, floorY + 7.2, p.Z) * CFrame.Angles(0, math.rad(45), math.rad(45)),
				Color = iron,
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = model,
			})
		end
	end
	fence(Vector3.new(-W / 2, 0, -D / 2), Vector3.new(W / 2, 0, -D / 2))
	fence(Vector3.new(-W / 2, 0, -D / 2), Vector3.new(-W / 2, 0, D / 2))
	fence(Vector3.new(W / 2, 0, -D / 2), Vector3.new(W / 2, 0, D / 2))

	local barrierGroup = "Barrier" .. index
	local ownerGroup = "Owner" .. index
	PhysicsService:RegisterCollisionGroup(barrierGroup)
	PhysicsService:RegisterCollisionGroup(ownerGroup)
	PhysicsService:CollisionGroupSetCollidable(barrierGroup, ownerGroup, false)

	local barrier = part({
		Name = "Barrier",
		Size = Vector3.new(W, World.BarrierHeight, 1),
		CFrame = at(0, floorY + World.BarrierHeight / 2, D / 2),
		Color = Color3.fromRGB(255, 50, 50),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	barrier.CollisionGroup = barrierGroup

	-- Entrance gate: two stone pillars (lanterns on top) and an arch carrying
	-- the owner's sign, facing the belt.
	local stone = Color3.fromRGB(78, 74, 88)
	for _, side in { -1, 1 } do
		part({
			Name = "GatePillar",
			Size = Vector3.new(3, 15, 3),
			CFrame = at(side * (W / 2 - 1.5), floorY + 7.5, D / 2),
			Color = stone,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
		local lantern = part({
			Name = "GateLantern",
			Size = Vector3.one * 2.2,
			CFrame = at(side * (W / 2 - 1.5), floorY + 16.2, D / 2),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 22
		light.Brightness = 1.4
		light.Parent = lantern
	end
	local arch = part({
		Name = "GateArch",
		Size = Vector3.new(W, 2.4, 2.4),
		CFrame = at(0, floorY + 14, D / 2),
		Color = stone,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
		Parent = model,
	})
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(26, 5, 0.6),
		CFrame = at(0, floorY + 11, D / 2 + 0.9),
		Color = Color3.fromRGB(28, 24, 36),
		Material = Enum.Material.Wood,
		CanCollide = false,
		Parent = model,
	})
	local _ = arch
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back -- the side facing the belt (+Z local)
	signGui.LightInfluence = 0
	signGui.CanvasSize = Vector2.new(520, 100)
	signGui.Parent = sign
	local ownerLabel = label(signGui, "Empty Base", color:Lerp(Color3.new(1, 1, 1), 0.3), UDim2.fromScale(1, 0.62))
	local statusLabel =
		label(signGui, "", Color3.fromRGB(255, 90, 90), UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.62))

	local lockPad = part({
		Name = "LockPad",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = at(W / 2 - 6, floorY + 0.15, D / 2 - 6),
		Color = Color3.fromRGB(255, 60, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local lockGui = billboard(lockPad, Vector3.new(0, 3, 0), UDim2.fromOffset(140, 50), 60)
	label(lockGui, "🔒 LOCK BASE", Color3.new(1, 1, 1), UDim2.fromScale(1, 1))

	-- Expand pad: buy one more slot with cash (prompt wired up in PlotService).
	local expandPad = part({
		Name = "ExpandPad",
		Size = Vector3.new(4.5, 0.3, 4.5),
		CFrame = at(-W / 2 + 6, floorY + 0.15, D / 2 - 11.5),
		Color = Color3.fromRGB(80, 170, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local expandGui = billboard(expandPad, Vector3.new(0, 3, 0), UDim2.fromOffset(150, 50), 50)
	local expandLabel = label(expandGui, "🏗️ EXPAND BASE", Color3.new(1, 1, 1), UDim2.fromScale(1, 1))

	-- Pedestals: first row nearest the entrance so new players see slimes up close.
	local pedestals: { BasePart } = {}
	local pads: { BasePart } = {}
	local padLabels: { TextLabel } = {}
	for slot = 1, Economy.AbsoluteMaxSlots do
		local column = (slot - 1) % World.PedestalColumns
		local row = (slot - 1) // World.PedestalColumns + 1
		local x = (column - (World.PedestalColumns - 1) / 2) * World.PedestalSpacingX
		local z = D / 2 - 21 - (row - 1) * World.PedestalSpacingZ
		local pedestal = part({
			Name = "Pedestal" .. slot,
			Size = Vector3.new(1.6, 6, 6),
			CFrame = at(x, floorY + 0.8, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(92, 88, 104),
			Material = Enum.Material.Slate,
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})
		part({
			Name = "PedestalRing",
			Size = Vector3.new(0.4, 6.5, 6.5),
			CFrame = at(x, floorY + 1, z) * CFrame.Angles(0, 0, math.rad(90)), -- a band round the side, below the top (no z-fighting)
			Color = color,
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
		pedestal:SetAttribute("Slot", slot)
		table.insert(pedestals, pedestal)

		local pad = part({
			Name = "CollectPad" .. slot,
			Size = Vector3.new(5, 0.3, 2.6),
			CFrame = at(x, floorY + 0.15, z + 5),
			Color = Color3.fromRGB(70, 230, 100),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = model,
		})
		pad:SetAttribute("Slot", slot)
		table.insert(pads, pad)
		local padGui = billboard(pad, Vector3.new(0, 1.6, 0), UDim2.fromOffset(100, 26), 35)
		table.insert(padLabels, label(padGui, "", Color3.fromRGB(150, 255, 150), UDim2.fromScale(1, 1)))
	end

	-- Facing the belt so the first thing a new player sees is slimes for sale.
	local spawnPosition = at(-W / 2 + 8, floorY + 3, D / 2 - 6).Position
	local facing = cframe:VectorToWorldSpace(Vector3.new(0, 0, 1))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.lookAt(
		Vector3.new(spawnPosition.X, floorY + 0.5, spawnPosition.Z),
		Vector3.new(spawnPosition.X, floorY + 0.5, spawnPosition.Z) + facing
	)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	return {
		Index = index,
		CFrame = cframe,
		Model = model,
		Barrier = barrier,
		LockPad = lockPad,
		ExpandPad = expandPad,
		ExpandLabel = expandLabel,
		OwnerLabel = ownerLabel,
		StatusLabel = statusLabel,
		SpawnCFrame = CFrame.lookAt(spawnPosition, spawnPosition + facing),
		Spawn = spawn,
		Pedestals = pedestals,
		CollectPads = pads,
		PadLabels = padLabels,
		BarrierGroup = barrierGroup,
		OwnerGroup = ownerGroup,
	}
end

local function buildScenery()
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = mapFolder
	local rng = Random.new(42)
	local halfX, halfZ = World.MapSizeX / 2, World.MapSizeZ / 2

	-- Invisible boundary so nobody falls off the edge.
	for _, data in
		{
			{ Vector3.new(World.MapSizeX, 60, 2), Vector3.new(0, 30, halfZ) },
			{ Vector3.new(World.MapSizeX, 60, 2), Vector3.new(0, 30, -halfZ) },
			{ Vector3.new(2, 60, World.MapSizeZ), Vector3.new(halfX, 30, 0) },
			{ Vector3.new(2, 60, World.MapSizeZ), Vector3.new(-halfX, 30, 0) },
		}
	do
		part({
			Name = "Boundary",
			Size = data[1],
			CFrame = CFrame.new(data[2]),
			Color = Color3.new(1, 1, 1),
			Transparency = 1,
			Parent = folder,
		})
	end

	-- Trees along the edges
	for _ = 1, 40 do
		local onLongSide = rng:NextNumber() < 0.7
		local x, z
		if onLongSide then
			x = rng:NextNumber(-halfX + 8, halfX - 8)
			z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(halfZ - 30, halfZ - 6)
		else
			x = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(halfX - 30, halfX - 6)
			z = rng:NextNumber(-halfZ + 8, halfZ - 8)
		end
		local height = rng:NextNumber(10, 18)
		part({
			Name = "Trunk",
			Size = Vector3.new(height, 2.5, 2.5),
			CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			Shape = Enum.PartType.Cylinder,
			Parent = folder,
		})
		local leafSize = rng:NextNumber(9, 14)
		part({
			Name = "Leaves",
			Size = Vector3.one * leafSize,
			CFrame = CFrame.new(x, height + leafSize * 0.3, z),
			Color = Color3.fromRGB(60, rng:NextInteger(150, 200), 70),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			Parent = folder,
		})
	end
end

function WorldService.Init()
	-- The ground's top face must sit just below y = 0, under the belt and
	-- floors. (Rojo does not apply a part's Position, so set it and the
	-- fallback spawn here.)
	local ground = workspace:FindFirstChild("Baseplate")
	if ground and ground:IsA("BasePart") then
		ground.CFrame = CFrame.new(0, -ground.Size.Y / 2 - 0.05, 0)
	end
	local spawnLocation = workspace:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("BasePart") then
		spawnLocation.CFrame = CFrame.new(0, 0.5, 115)
	end
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace

	setupLighting()
	buildBelt()
	for index, cframe in World.PlotCFrames do
		table.insert(WorldService.Plots, buildPlot(index, cframe))
	end
	buildScenery()
end

-- True if `position` is inside the plot's walls (including its entrance).
function WorldService.PlotContains(plot: Plot, position: Vector3): boolean
	local relative = plot.CFrame:PointToObjectSpace(position)
	return math.abs(relative.X) <= World.PlotWidth / 2
		and math.abs(relative.Z) <= World.PlotDepth / 2 + 1
		and relative.Y < World.BarrierHeight + 10
end

-- World CFrame where a slime should rest on a pedestal (bottom of the slime).
function WorldService.PedestalTop(plot: Plot, slot: number): CFrame
	local pedestal = plot.Pedestals[slot]
	local facing = plot.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2, 0)
	-- Slimes face the entrance (a model's front is its LookVector).
	return CFrame.lookAt(top, top + facing)
end

return WorldService
