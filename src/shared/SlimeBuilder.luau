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
-- Body proportions per Slimes.Shape ("Drop" also gets a pointed top).
local SHAPES: { [string]: Vector3 } = {
	Round = Vector3.one,
	Tall = Vector3.new(0.88, 1.28, 0.88),
	Flat = Vector3.new(1.15, 0.82, 1.15),
	Chunky = Vector3.new(1.15, 0.95, 1.15),
	Drop = Vector3.one,
}
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
	elseif hat == "Bow" then
		local pink = Color3.fromRGB(255, 70, 150)
		for _, side in { -1, 1 } do
			addPart(
				model,
				root,
				"BowLoop",
				Vector3.new(0.55, 0.4, 0.25) * s,
				CFrame.new(side * 0.35 * s, top + 0.15 * s, -0.2 * s) * CFrame.Angles(0, 0, math.rad(side * 25)),
				pink
			)
		end
		addPart(
			model,
			root,
			"BowKnot",
			Vector3.one * 0.25 * s,
			CFrame.new(0, top + 0.15 * s, -0.2 * s),
			pink,
			nil,
			"Ball"
		)
	elseif hat == "Unihorn" then
		local base = CFrame.new(0, top + 0.1 * s, -0.35 * s) * CFrame.Angles(math.rad(-20), 0, 0)
		addPart(
			model,
			root,
			"Horn",
			Vector3.new(0.35, 0.7, 0.35) * s,
			base,
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon
		)
		addPart(
			model,
			root,
			"HornTip",
			Vector3.new(0.18, 0.55, 0.18) * s,
			base * CFrame.new(0, 0.6 * s, 0),
			Color3.fromRGB(255, 240, 180),
			Enum.Material.Neon
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
	elseif hat == "Sprout" then
		disc(model, root, "Stalk", 0, top + 0.35 * s, 0, 0.7 * s, 0.14 * s, Color3.fromRGB(70, 150, 50))
		for _, side in { -1, 1 } do
			addPart(
				model,
				root,
				"Leaf",
				Vector3.new(0.7, 0.12, 0.42) * s,
				CFrame.new(side * 0.32 * s, top + 0.72 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 25)),
				Color3.fromRGB(110, 210, 70),
				nil,
				"Ball"
			)
		end
	elseif hat == "Cloud" then
		local grey = Color3.fromRGB(110, 115, 135)
		for i, x in { -0.6, 0, 0.6 } do
			addPart(
				model,
				root,
				"Cloud",
				Vector3.one * (if i == 2 then 1.1 else 0.8) * s,
				CFrame.new(x * s, top + 1.1 * s + (if i == 2 then 0.15 * s else 0), 0),
				grey,
				nil,
				"Ball"
			)
		end
		addPart(
			model,
			root,
			"Bolt",
			Vector3.new(0.15, 0.7, 0.15) * s,
			CFrame.new(0.2 * s, top + 0.45 * s, 0) * CFrame.Angles(0, 0, math.rad(25)),
			Color3.fromRGB(255, 240, 80),
			Enum.Material.Neon
		)
	elseif hat == "SunCrown" then
		local sun = Color3.fromRGB(255, 200, 40)
		disc(model, root, "Band", 0, top + 0.05 * s, 0, 0.3 * s, 1.6 * s, sun, Enum.Material.Neon)
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2
			addPart(
				model,
				root,
				"Ray",
				Vector3.new(0.18, 0.9, 0.18) * s,
				CFrame.new(math.cos(angle) * 0.85 * s, top + 0.45 * s, math.sin(angle) * 0.85 * s)
					* CFrame.Angles(math.sin(angle) * math.rad(30), 0, -math.cos(angle) * math.rad(30)),
				sun,
				Enum.Material.Neon
			)
		end
	elseif hat == "Tiara" then
		local silver = Color3.fromRGB(220, 230, 255)
		disc(model, root, "Band", 0, top + 0.05 * s, 0, 0.18 * s, 1.5 * s, silver, Enum.Material.Foil)
		addPart(
			model,
			root,
			"Moon",
			Vector3.one * 0.5 * s,
			CFrame.new(0, top + 0.45 * s, -0.6 * s),
			Color3.fromRGB(200, 220, 255),
			Enum.Material.Neon,
			"Ball"
		)
		for _, side in { -1, 1 } do
			addPart(
				model,
				root,
				"Gem",
				Vector3.one * 0.25 * s,
				CFrame.new(side * 0.45 * s, top + 0.25 * s, -0.5 * s),
				Color3.fromRGB(120, 180, 255),
				Enum.Material.Neon,
				"Ball"
			)
		end
	elseif hat == "StarTop" then
		local gold = Color3.fromRGB(255, 240, 140)
		for i = 0, 4 do
			local angle = (i / 5) * math.pi * 2
			addPart(
				model,
				root,
				"Star",
				Vector3.new(0.2, 0.75, 0.2) * s,
				CFrame.new(0, top + 0.9 * s, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.3 * s, 0),
				gold,
				Enum.Material.Neon
			)
		end
		disc(model, root, "Stalk", 0, top + 0.25 * s, 0, 0.5 * s, 0.12 * s, gold, Enum.Material.Neon)
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

-- Looks: every slime gets a body shape, a face and extras (Config/Slimes),
-- so no two slimes look alike. Body radii are rx, ry, rz; front is -Z.

type Ctx = {
	Model: Model,
	Body: BasePart,
	S: number,
	R: Vector3, -- body radii
	Color: Color3,
	Accent: Color3,
	Material: Enum.Material,
	Rng: Random,
}

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.fromRGB(20, 20, 25)

local function ball(ctx: Ctx, name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?): Part
	return addPart(ctx.Model, ctx.Body, name, size, at, color, material, "Ball")
end

local function block(ctx: Ctx, name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?): Part
	return addPart(ctx.Model, ctx.Body, name, size, at, color, material)
end

-- A point on the front of the body at fractions (xf, yf) of the radii,
-- pushed `out` studs forward of the surface.
local function front(ctx: Ctx, xf: number, yf: number, out: number): CFrame
	local r = ctx.R
	local z = r.Z * math.sqrt(math.max(0.05, 1 - xf * xf - yf * yf))
	return CFrame.new(xf * r.X, yf * r.Y, -(z + out))
end

-- A point on the body surface in direction `dir`, with its Y axis along the
-- surface normal (so things stick straight out of the jelly).
local function onSurface(ctx: Ctx, dir: Vector3, out: number?): CFrame
	local r = ctx.R
	local d = dir.Unit
	local p = Vector3.new(d.X * r.X, d.Y * r.Y, d.Z * r.Z)
	local n = Vector3.new(p.X / (r.X * r.X), p.Y / (r.Y * r.Y), p.Z / (r.Z * r.Z)).Unit
	p += n * (out or 0)
	return CFrame.lookAt(p, p + n) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function eyes(ctx: Ctx, size: number, pupil: number, xf: number, yf: number, glints: number?)
	local s = ctx.S
	for _, side in { -1, 1 } do
		ball(ctx, "Eye", Vector3.one * size * s, front(ctx, side * xf, yf, -size * 0.23 * s), WHITE)
		local at = front(ctx, side * xf, yf - 0.02, size * 0.18 * s)
		ball(ctx, "Pupil", Vector3.one * pupil * s, at, BLACK)
		for i = 1, glints or 0 do
			local glint = at * CFrame.new(-0.12 * s * i + 0.05 * s, 0.1 * s * (2 - i), -pupil * 0.35 * s)
			ball(ctx, "Glint", Vector3.one * (0.16 / i) * s, glint, WHITE, Enum.Material.Neon)
		end
	end
end

local function mouth(ctx: Ctx, width: number, yf: number?)
	block(ctx, "Mouth", Vector3.new(width, 0.12, 0.12) * ctx.S, front(ctx, 0, yf or -0.21, -0.03 * ctx.S), BLACK)
end

local function addFace(ctx: Ctx, face: string)
	local s = ctx.S
	if face == "Cute" then
		eyes(ctx, 0.78, 0.5, 0.38, 0.2, 2)
		for _, side in { -1, 1 } do
			local blush = ball(
				ctx,
				"Blush",
				Vector3.new(0.42, 0.22, 0.1) * s,
				front(ctx, side * 0.62, -0.12, -0.02 * s),
				Color3.fromRGB(255, 130, 170)
			)
			blush.Transparency = 0.25
		end
		mouth(ctx, 0.28, -0.25)
	elseif face == "Angry" then
		eyes(ctx, 0.55, 0.3, 0.36, 0.17)
		for _, side in { -1, 1 } do
			block(
				ctx,
				"Brow",
				Vector3.new(0.6, 0.15, 0.15) * s,
				front(ctx, side * 0.36, 0.45, 0) * CFrame.Angles(0, 0, math.rad(side * 22)),
				BLACK
			)
		end
		mouth(ctx, 0.45, -0.3)
	elseif face == "Sleepy" then
		for _, side in { -1, 1 } do
			block(ctx, "Lid", Vector3.new(0.5, 0.1, 0.1) * s, front(ctx, side * 0.36, 0.18, 0), BLACK)
		end
		ball(ctx, "Mouth", Vector3.new(0.22, 0.26, 0.12) * s, front(ctx, 0, -0.25, -0.02 * s), BLACK)
	elseif face == "Cyclops" then
		ball(ctx, "Eye", Vector3.one * 1.05 * s, front(ctx, 0, 0.2, -0.24 * s), WHITE)
		ball(ctx, "Pupil", Vector3.one * 0.55 * s, front(ctx, 0, 0.18, 0.2 * s), BLACK)
		mouth(ctx, 0.5, -0.32)
	elseif face == "Cool" then
		for _, side in { -1, 1 } do
			local lens =
				block(ctx, "Shades", Vector3.new(0.66, 0.42, 0.14) * s, front(ctx, side * 0.36, 0.2, 0.02 * s), BLACK)
			lens.Reflectance = 0.35
		end
		block(ctx, "Shades", Vector3.new(0.3, 0.09, 0.1) * s, front(ctx, 0, 0.26, 0.02 * s), BLACK)
		mouth(ctx, 0.65, -0.24)
	elseif face == "Fangs" then
		eyes(ctx, 0.6, 0.32, 0.37, 0.21)
		mouth(ctx, 0.6)
		for _, side in { -1, 1 } do
			ball(ctx, "Fang", Vector3.new(0.13, 0.28, 0.1) * s, front(ctx, side * 0.11, -0.31, 0), WHITE)
		end
	elseif face == "Glow" then
		for _, side in { -1, 1 } do
			ball(
				ctx,
				"Eye",
				Vector3.new(0.55, 0.32, 0.2) * s,
				front(ctx, side * 0.36, 0.2, 0) * CFrame.Angles(0, 0, math.rad(side * -12)),
				ctx.Accent,
				Enum.Material.Neon
			)
		end
	elseif face == "Derp" then
		ball(ctx, "Eye", Vector3.one * 0.78 * s, front(ctx, -0.38, 0.24, -0.18 * s), WHITE)
		ball(ctx, "Pupil", Vector3.one * 0.36 * s, front(ctx, -0.45, 0.32, 0.14 * s), BLACK)
		ball(ctx, "Eye", Vector3.one * 0.5 * s, front(ctx, 0.36, 0.16, -0.12 * s), WHITE)
		ball(ctx, "Pupil", Vector3.one * 0.26 * s, front(ctx, 0.33, 0.1, 0.1 * s), BLACK)
		mouth(ctx, 0.5)
		ball(ctx, "Tongue", Vector3.new(0.3, 0.34, 0.12) * s, front(ctx, 0.1, -0.33, 0), Color3.fromRGB(255, 110, 140))
	elseif face == "Sparkle" then
		eyes(ctx, 0.7, 0.45, 0.37, 0.2, 2)
		mouth(ctx, 0.4, -0.26)
	elseif face == "Boo" then
		for _, side in { -1, 1 } do
			ball(ctx, "Eye", Vector3.new(0.42, 0.7, 0.2) * s, front(ctx, side * 0.3, 0.2, 0), BLACK)
		end
		ball(ctx, "Mouth", Vector3.new(0.38, 0.48, 0.15) * s, front(ctx, 0, -0.28, 0), BLACK)
	elseif face == "Jack" then
		local flame = Color3.fromRGB(255, 220, 70)
		for _, side in { -1, 1 } do
			block(
				ctx,
				"Eye",
				Vector3.new(0.42, 0.42, 0.12) * s,
				front(ctx, side * 0.36, 0.2, 0) * CFrame.Angles(0, 0, math.rad(45)),
				flame,
				Enum.Material.Neon
			)
		end
		for i = -2, 2 do
			block(
				ctx,
				"Mouth",
				Vector3.new(0.22, 0.22, 0.1) * s,
				front(ctx, i * 0.12, -0.28 + (if i % 2 == 0 then 0 else 0.05), 0) * CFrame.Angles(0, 0, math.rad(45)),
				flame,
				Enum.Material.Neon
			)
		end
	else -- Happy
		eyes(ctx, 0.6, 0.32, 0.37, 0.21)
		mouth(ctx, 0.55)
	end
	if face ~= "Glow" and face ~= "Boo" and face ~= "Jack" then
		local shine =
			ball(ctx, "Shine", Vector3.one * 0.42 * s, front(ctx, -0.5, 0.5, -0.12 * s), WHITE, Enum.Material.Neon)
		shine.Transparency = 0.35
	end
end

local function emitter(
	ctx: Ctx,
	color: ColorSequence,
	rate: number,
	speed: NumberRange,
	life: NumberRange,
	size: NumberSequence,
	accel: Vector3,
	light: number
): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Color = color
	p.Rate = rate
	p.Speed = speed
	p.Lifetime = life
	p.Size = size
	p.Acceleration = accel
	p.LightEmission = light
	p.SpreadAngle = Vector2.new(35, 35)
	p.EmissionDirection = Enum.NormalId.Top
	p.Parent = ctx.Body
	return p
end

local function addExtra(ctx: Ctx, extra: string)
	local s, r, rng = ctx.S, ctx.R, ctx.Rng
	local accent = ctx.Accent
	if extra == "Spots" then
		for _, dir in
			{
				Vector3.new(0.6, 0.6, 0.3),
				Vector3.new(-0.7, 0.3, 0.5),
				Vector3.new(0.2, 0.8, 0.6),
				Vector3.new(0.8, -0.1, 0.4),
				Vector3.new(-0.5, 0.7, -0.1),
				Vector3.new(-0.3, 0, 0.9),
				Vector3.new(0.9, 0.3, -0.3),
			}
		do
			ball(ctx, "Spot", Vector3.new(0.5, 0.1, 0.5) * s * rng:NextNumber(0.7, 1.2), onSurface(ctx, dir), accent)
		end
	elseif extra == "Sprinkles" then
		local colors = {
			Color3.fromRGB(255, 80, 120),
			Color3.fromRGB(80, 200, 255),
			Color3.fromRGB(255, 230, 80),
			Color3.fromRGB(140, 255, 120),
			Color3.fromRGB(200, 120, 255),
		}
		for i = 1, 14 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.35, 1), rng:NextNumber(-0.2, 1))
			block(
				ctx,
				"Sprinkle",
				Vector3.new(0.1, 0.06, 0.32) * s,
				onSurface(ctx, dir) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				colors[(i % #colors) + 1],
				Enum.Material.Neon
			)
		end
	elseif extra == "Stripes" then
		for _, yf in { -0.35, 0.3 } do
			local d = 2 * r.X * math.sqrt(1 - yf * yf) + 0.06 * s
			addPart(
				ctx.Model,
				ctx.Body,
				"Stripe",
				Vector3.new(0.22 * s, d, d),
				CFrame.new(0, yf * r.Y, 0) * VERTICAL,
				accent,
				ctx.Material,
				"Cylinder"
			)
		end
	elseif extra == "Spikes" then
		for i = 0, 4 do
			local a = math.rad(-10 + i * 30) -- over the top from front-top to back
			local dir = Vector3.new(0, math.cos(a), math.sin(a))
			local spike = block(
				ctx,
				"Spike",
				Vector3.new(0.4, 1.1 - math.abs(i - 1.5) * 0.15, 0.4) * s,
				onSurface(ctx, dir, 0.25 * s) * CFrame.Angles(0, math.rad(45), 0),
				accent,
				if ctx.Material == Enum.Material.Neon then Enum.Material.Neon else Enum.Material.Glass
			)
			spike.Transparency = 0.1
		end
	elseif extra == "Drip" then
		for _, dir in
			{
				Vector3.new(0.7, -0.35, -0.4),
				Vector3.new(-0.8, -0.3, 0.1),
				Vector3.new(0.2, -0.3, 0.9),
				Vector3.new(-0.3, -0.35, -0.8),
			}
		do
			local at = onSurface(ctx, dir)
			ball(
				ctx,
				"Drip",
				Vector3.new(0.4, 0.7, 0.4) * s,
				at * CFrame.new(0, 0, 0) - Vector3.new(0, 0.25 * s, 0),
				ctx.Color,
				ctx.Material
			)
			ball(ctx, "Drop", Vector3.one * 0.3 * s, at - Vector3.new(0, 0.6 * s, 0), ctx.Color, ctx.Material)
		end
	elseif extra == "Wings" then
		for _, side in { -1, 1 } do
			for i, k in { 1, 0.65 } do
				local wing = ball(
					ctx,
					"Wing",
					Vector3.new(0.18, 1.3 * k, 2.3 * k) * s,
					CFrame.new(side * (r.X * 0.85 + 0.35 * s), r.Y * (0.3 - (i - 1) * 0.35), r.Z * 0.45)
						* CFrame.Angles(math.rad(-25 - (i - 1) * 20), side * math.rad(-30), side * math.rad(30)),
					accent,
					if ctx.Material == Enum.Material.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
				)
				wing.Transparency = 0.05
			end
		end
	elseif extra == "Tail" then
		local at = CFrame.new(0, -r.Y * 0.35, r.Z * 0.9)
		for i = 1, 4 do
			local k = 1 - i * 0.18
			at *= CFrame.new(0, 0.25 * s, 0.35 * s)
			ball(ctx, "Tail", Vector3.one * 0.45 * k * s, at, ctx.Color, ctx.Material)
		end
		block(
			ctx,
			"TailTip",
			Vector3.new(0.4, 0.4, 0.12) * s,
			at * CFrame.new(0, 0.3 * s, 0.15 * s) * CFrame.Angles(0, 0, math.rad(45)),
			accent
		)
	elseif extra == "Cape" then
		block(
			ctx,
			"Cape",
			Vector3.new(r.X * 1.7, r.Y * 1.5, 0.12 * s),
			CFrame.new(0, -r.Y * 0.1, r.Z * 0.92) * CFrame.Angles(math.rad(12), 0, 0),
			accent,
			Enum.Material.Fabric
		)
		block(
			ctx,
			"Clasp",
			Vector3.new(0.3, 0.3, 0.3) * s,
			CFrame.new(0, r.Y * 0.62, r.Z * 0.7),
			Color3.fromRGB(255, 200, 40),
			Enum.Material.Foil
		)
	elseif extra == "Ring" then
		local ring = addPart(
			ctx.Model,
			ctx.Body,
			"Ring",
			Vector3.new(0.1 * s, r.X * 3.1, r.X * 3.1),
			CFrame.Angles(math.rad(18), 0, math.rad(8)) * VERTICAL,
			accent,
			Enum.Material.Neon,
			"Cylinder"
		)
		ring.Transparency = 0.35
	elseif extra == "Orbit" then
		for i = 1, 3 do
			local a = i * math.pi * 2 / 3
			local radius = math.max(r.X, r.Z) + 0.9 * s
			ball(
				ctx,
				"Moon",
				Vector3.one * (0.55 - i * 0.08) * s,
				CFrame.new(math.cos(a) * radius, r.Y * (0.5 - i * 0.3), math.sin(a) * radius),
				accent,
				Enum.Material.Neon
			)
		end
	elseif extra == "Core" then
		ball(ctx, "Core", r * 0.9, CFrame.new(0, -r.Y * 0.05, 0), accent, Enum.Material.Neon)
	elseif extra == "Flames" then
		emitter(
			ctx,
			ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 20)),
			14,
			NumberRange.new(2, 4),
			NumberRange.new(0.5, 0.9),
			NumberSequence.new(0.7 * s, 0),
			Vector3.new(0, 4, 0),
			1
		)
	elseif extra == "Snow" then
		local p = emitter(
			ctx,
			ColorSequence.new(WHITE),
			6,
			NumberRange.new(0.5, 1.5),
			NumberRange.new(1.5, 2.5),
			NumberSequence.new(0.2 * s),
			Vector3.new(0, -2, 0),
			0.6
		)
		p.SpreadAngle = Vector2.new(180, 180)
	elseif extra == "Sparks" then
		local p = emitter(
			ctx,
			ColorSequence.new(Color3.fromRGB(255, 250, 150)),
			10,
			NumberRange.new(6, 10),
			NumberRange.new(0.15, 0.3),
			NumberSequence.new(0.18 * s, 0),
			Vector3.zero,
			1
		)
		p.SpreadAngle = Vector2.new(180, 180)
	elseif extra == "Bubbles" then
		local p = emitter(
			ctx,
			ColorSequence.new(accent),
			4,
			NumberRange.new(1, 2),
			NumberRange.new(1.5, 2.5),
			NumberSequence.new(0.3 * s),
			Vector3.new(0, 1, 0),
			0.3
		)
		p.Transparency = NumberSequence.new(0.3, 1)
	elseif extra == "Stars" then
		local p = emitter(
			ctx,
			ColorSequence.new(accent),
			5,
			NumberRange.new(0.5, 1.2),
			NumberRange.new(1, 1.8),
			NumberSequence.new(0.35 * s, 0),
			Vector3.zero,
			1
		)
		p.SpreadAngle = Vector2.new(180, 180)
		p.RotSpeed = NumberRange.new(-90, 90)
	elseif extra == "Smoke" then
		local p = emitter(
			ctx,
			ColorSequence.new(accent),
			5,
			NumberRange.new(0.5, 1.5),
			NumberRange.new(1.5, 2.5),
			NumberSequence.new(0.8 * s, 2 * s),
			Vector3.new(0, 1, 0),
			0
		)
		p.Transparency = NumberSequence.new(0.5, 1)
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
	local shape = if def then SHAPES[def.Shape or "Round"] or Vector3.one else Vector3.one
	return BODY.Y * shape.Y * (if def then def.Size else 1) * (scale or 1) / 2
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
	local bodySize = BODY * (SHAPES[def.Shape or "Round"] or Vector3.one) * s

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
	body.CastShadow = true
	if material == Enum.Material.SmoothPlastic then
		body.Reflectance = 0.12 -- wet jelly sheen under Future lighting
	end
	CollectionService:AddTag(body, "SlimeBody")
	-- The body hangs off the root by a Weld the client animates (hop, squash,
	-- wiggle); everything else is welded to the body so it rides along.
	local bodyWeld = body:FindFirstChildOfClass("WeldConstraint")
	if bodyWeld then
		bodyWeld:Destroy()
	end
	local jelly = Instance.new("Weld")
	jelly.Name = "Jelly"
	jelly.Part0 = root
	jelly.Part1 = body
	jelly.Parent = body

	local ctx: Ctx = {
		Model = model,
		Body = body,
		S = s,
		R = bodySize / 2,
		Color = color,
		Accent = def.Accent or color:Lerp(Color3.new(1, 1, 1), 0.5),
		Material = material,
		Rng = Random.new(#def.Id * 7919 + string.byte(def.Id, 1)),
	}
	addFace(ctx, def.Face or "Happy")
	local top = bodySize.Y / 2
	if def.Shape == "Drop" then
		-- A teardrop point on top.
		for i, k in { 0.75, 0.45, 0.22 } do
			ball(ctx, "Tip", Vector3.one * k * s, CFrame.new(0, top + (i - 1.2) * 0.3 * s, 0), color, material).Transparency =
				transparency
		end
		top += 0.45 * s
	end
	local extras: { string } = def.Extras or {}
	for _, extra in extras do
		addExtra(ctx, extra)
	end

	if def.Hat then
		addHat(model, body, def.Hat, s, top)
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
