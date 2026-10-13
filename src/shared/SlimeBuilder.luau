--!strict
-- Builds slime models out of primitive parts, so the game needs no uploaded
-- meshes. Swap in real models later by changing Build() only.
--
-- The returned model's PrimaryPart ("Root") is anchored and sits at the body
-- centre. Use HalfHeight() to rest a slime on a surface.

local CollectionService = game:GetService("CollectionService")

local Shared = script.Parent
local Slimes = require(Shared.Config.Slimes)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Util.Format)
local SlimeInfo = require(Shared.SlimeInfo)

local BODY = Vector3.new(3, 2.4, 3)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local SlimeBuilder = {}

export type BuildOptions = {
	PriceText: string?, -- extra line, used on the conveyor
	Tier: number?, -- merge tier (Giant, Colossal): bigger and worth more
	Age: number?, -- seconds grown in a base: bigger and worth more
}

local function addPart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: string?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Vertical cylinder centred at `y` with height h and diameter d.
local function disc(
	model: Model,
	root: BasePart,
	name: string,
	x: number,
	y: number,
	z: number,
	h: number,
	d: number,
	color: Color3,
	material: Enum.Material?
): Part
	return addPart(model, root, name, Vector3.new(h, d, d), CFrame.new(x, y, z) * VERTICAL, color, material, "Cylinder")
end

local function addCone(
	model: Model,
	root: BasePart,
	baseY: number,
	s: number,
	color: Color3,
	brim: number,
	height: number
)
	disc(model, root, "Brim", 0, baseY, 0, 0.15 * s, brim * s, color)
	local steps = 5
	for i = 1, steps do
		local t = (i - 1) / steps
		local d = (1 - t) * 1.5 * s + 0.15 * s
		local h = height * s / steps
		disc(model, root, "Cone", 0, baseY + h * (i - 0.5), 0, h, d, color)
	end
end

local function addHat(model: Model, root: BasePart, hat: string, s: number, top: number)
	if hat == "Leaf" then
		addPart(
			model,
			root,
			"Leaf",
			Vector3.new(0.15, 1.1, 0.7) * s,
			CFrame.new(0.15 * s, top + 0.35 * s, 0) * CFrame.Angles(0, 0, math.rad(-25)),
			Color3.fromRGB(60, 170, 60),
			Enum.Material.Grass
		)
	elseif hat == "Antenna" then
		disc(model, root, "Stalk", 0, top + 0.45 * s, 0, 1 * s, 0.14 * s, Color3.fromRGB(40, 40, 40))
		addPart(
			model,
			root,
			"Bulb",
			Vector3.one * 0.5 * s,
			CFrame.new(0, top + 1.05 * s, 0),
			Color3.fromRGB(255, 240, 80),
			Enum.Material.Neon,
			"Ball"
		)
	elseif hat == "Wizard" then
		addCone(model, root, top - 0.05 * s, s, Color3.fromRGB(45, 35, 140), 2.4, 1.8)
		addPart(
			model,
			root,
			"Star",
			Vector3.one * 0.35 * s,
			CFrame.new(0, top + 0.6 * s, -0.55 * s),
			Color3.fromRGB(255, 230, 90),
			Enum.Material.Neon,
			"Ball"
		)
	elseif hat == "WitchHat" then
		addCone(model, root, top - 0.05 * s, s, Color3.fromRGB(25, 20, 30), 2.6, 2.1)
		disc(model, root, "Band", 0, top + 0.25 * s, 0, 0.18 * s, 1.55 * s, Color3.fromRGB(150, 60, 220))
	elseif hat == "Crown" then
		local gold = Color3.fromRGB(255, 200, 40)
		disc(model, root, "Band", 0, top + 0.1 * s, 0, 0.45 * s, 1.7 * s, gold, Enum.Material.Foil)
		for i = 1, 5 do
			local angle = (i / 5) * math.pi * 2
			local x, z = math.cos(angle) * 0.75 * s, math.sin(angle) * 0.75 * s
			addPart(
				model,
				root,
				"Spike",
				Vector3.new(0.3, 0.55, 0.3) * s,
				CFrame.new(x, top + 0.55 * s, z),
				gold,
				Enum.Material.Foil
			)
		end
		addPart(
			model,
			root,
			"Gem",
			Vector3.one * 0.32 * s,
			CFrame.new(0, top + 0.12 * s, -0.85 * s),
			Color3.fromRGB(255, 40, 70),
			Enum.Material.Neon,
			"Ball"
		)
	elseif hat == "Halo" then
		for i = 1, 12 do
			local angle = (i / 12) * math.pi * 2
			local x, z = math.cos(angle) * 0.85 * s, math.sin(angle) * 0.85 * s
			addPart(
				model,
				root,
				"Halo",
				Vector3.one * 0.28 * s,
				CFrame.new(x, top + 0.75 * s, z),
				Color3.fromRGB(255, 240, 120),
				Enum.Material.Neon,
				"Ball"
			)
		end
	elseif hat == "Horns" then
		for _, side in { -1, 1 } do
			local base = CFrame.new(side * 0.65 * s, top - 0.05 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 20))
			addPart(model, root, "Horn", Vector3.new(0.45, 0.6, 0.45) * s, base, Color3.fromRGB(240, 235, 220))
			addPart(
				model,
				root,
				"HornTip",
				Vector3.new(0.25, 0.5, 0.25) * s,
				base * CFrame.new(0, 0.5 * s, 0) * CFrame.Angles(0, 0, math.rad(-side * 15)),
				Color3.fromRGB(240, 235, 220)
			)
		end
	elseif hat == "Pumpkin" then
		disc(model, root, "Stem", 0, top + 0.25 * s, 0, 0.6 * s, 0.32 * s, Color3.fromRGB(90, 120, 40))
		addPart(
			model,
			root,
			"Leaf",
			Vector3.new(0.6, 0.1, 0.35) * s,
			CFrame.new(0.3 * s, top + 0.2 * s, 0) * CFrame.Angles(0, 0, math.rad(-20)),
			Color3.fromRGB(70, 160, 50)
		)
	end
end

local function makeLabel(parent: Instance, name: string, text: string, color: Color3, order: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Size = UDim2.new(1, 0, 0, 18)
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

function SlimeBuilder.HalfHeight(slimeId: string, scale: number?): number
	local def = Slimes.ById[slimeId]
	return BODY.Y * (if def then def.Size else 1) * (scale or 1) / 2
end

function SlimeBuilder.Build(slimeId: string, mutationId: string?, options: BuildOptions?): Model
	local def = Slimes.ById[slimeId]
	assert(def, "Unknown slime " .. tostring(slimeId))
	local rarity = Rarities.ByName[def.Rarity]
	local mutation = if mutationId and mutationId ~= "" then Mutations.ById[mutationId] else nil
	local tier = if options then options.Tier else nil
	local age = if options then options.Age else nil
	local scale = SlimeInfo.Scale(tier, age)
	local s = def.Size * scale
	local bodySize = BODY * s

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("SlimeId", def.Id)
	model:SetAttribute("Mutation", if mutation then mutation.Id else "")
	model:SetAttribute("Tier", tier or 1)
	model:SetAttribute("Scale", scale)
	CollectionService:AddTag(model, "Slime")

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = bodySize
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local color = def.Color
	local material = def.Material or Enum.Material.SmoothPlastic
	local transparency = def.Transparency or 0
	if mutation then
		if mutation.Id == "Gold" then
			color = mutation.Color
			material = Enum.Material.Foil
		elseif mutation.Id == "Diamond" then
			color = mutation.Color
			material = Enum.Material.Glass
			transparency = 0.2
		elseif mutation.Id == "Haunted" then
			color = color:Lerp(mutation.Color, 0.6)
			transparency = math.max(transparency, 0.4)
		end
	end

	local body = addPart(model, root, "Body", bodySize, CFrame.new(), color, material, "Ball")
	body.Transparency = transparency
	CollectionService:AddTag(body, "SlimeBody")

	-- Face (front is -Z)
	local white, black = Color3.new(1, 1, 1), Color3.fromRGB(20, 20, 25)
	for _, side in { -1, 1 } do
		addPart(
			model,
			root,
			"Eye",
			Vector3.one * 0.6 * s,
			CFrame.new(side * 0.55 * s, 0.25 * s, -1.22 * s),
			white,
			nil,
			"Ball"
		)
		addPart(
			model,
			root,
			"Pupil",
			Vector3.one * 0.32 * s,
			CFrame.new(side * 0.55 * s, 0.22 * s, -1.47 * s),
			black,
			nil,
			"Ball"
		)
	end
	addPart(model, root, "Mouth", Vector3.new(0.55, 0.12, 0.12) * s, CFrame.new(0, -0.25 * s, -1.44 * s), black)
	local shine = addPart(
		model,
		root,
		"Shine",
		Vector3.one * 0.45 * s,
		CFrame.new(-0.75 * s, 0.6 * s, -0.95 * s),
		white,
		Enum.Material.Neon,
		"Ball"
	)
	shine.Transparency = 0.35

	if def.Hat then
		addHat(model, root, def.Hat, s, bodySize.Y / 2)
	end

	-- Effects
	if def.Glow or rarity.Order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8 + 4 * s
		light.Brightness = 1.5
		light.Parent = body
	end
	if mutation and mutation.Id == "Diamond" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutation.Color
		sparkles.Parent = body
	end
	if mutation and mutation.Id == "Rainbow" then
		CollectionService:AddTag(body, "RainbowSlime")
	end
	if (mutation and mutation.Id == "Haunted") or rarity.Name == "Secret" then
		local particles = Instance.new("ParticleEmitter")
		particles.Color =
			ColorSequence.new(if mutation and mutation.Id == "Haunted" then mutation.Color else rarity.Color)
		particles.LightEmission = 1
		particles.Rate = 6
		particles.Lifetime = NumberRange.new(1, 2)
		particles.Speed = NumberRange.new(1, 3)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.4 * s, 0)
		particles.Parent = body
	end

	-- Name tag
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(150, if options and options.PriceText then 66 else 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, bodySize.Y / 2 + 2.2, 0)
	gui.MaxDistance = if options and options.PriceText then 60 else 34
	gui.LightInfluence = 0
	gui.Adornee = root
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	makeLabel(
		gui,
		"Name",
		SlimeInfo.DisplayName(def.Id, mutationId, tier),
		if mutation then mutation.Color else Color3.new(1, 1, 1),
		1
	)
	makeLabel(gui, "Rarity", def.Rarity, rarity.Color, 2)
	makeLabel(
		gui,
		"Income",
		Format.Cash(SlimeInfo.Income(def.Id, mutationId, tier, age)) .. "/s",
		Color3.fromRGB(120, 255, 120),
		3
	)
	if options and options.PriceText then
		makeLabel(gui, "Price", options.PriceText, Color3.fromRGB(255, 225, 90), 4)
	end
	gui.Parent = root

	return model
end

return SlimeBuilder
