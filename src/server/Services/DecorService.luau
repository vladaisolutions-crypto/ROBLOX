--!strict
-- Seasonal map dressing, so the world matches the event thumbnails.
-- Halloween: dusk lighting and glowing jack-o'-lanterns along the belt.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)

local EventService = require(script.Parent.EventService)

local DecorService = {}

local function piece(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, ball: boolean?): Part
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
		piece(model, Vector3.new(0.6, 0.6, 0.2) * scale, base * CFrame.new(side * 0.7 * scale, 0.35 * scale, -1.6 * scale), glow, Enum.Material.Neon)
	end
	piece(model, Vector3.new(1.6, 0.35, 0.2) * scale, base * CFrame.new(0, -0.45 * scale, -1.6 * scale), glow, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = body
	model.Parent = parent
end

local function halloween()
	Lighting.ClockTime = 17.9
	Lighting.Ambient = Color3.fromRGB(120, 90, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 100, 150)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = Color3.fromRGB(255, 170, 120)
		atmosphere.Decay = Color3.fromRGB(120, 60, 140)
	end

	local map = workspace:WaitForChild("Map")
	local folder = Instance.new("Folder")
	folder.Name = "HalloweenDecor"
	folder.Parent = map
	local rng = Random.new(31)
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
