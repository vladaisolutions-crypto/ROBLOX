--!strict
-- The Watcher: every few minutes a tall faceless figure in a black suit
-- appears in the distance, in view, and stares at you. A low drone and a
-- heartbeat swell, colour drains from the world, and he vanishes once you
-- look straight at him, walk towards him, or a few seconds pass.
--
-- Built and played only on this client, so only you ever see him. No
-- jump-scare flashes or screams (photosensitive players, and Roblox audio
-- rules): the sounds are bundled ones pitched down. Tuning: Events.Watcher.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tuning = require(Shared.Config.Events).Watcher
local Sounds = require(Shared.Config.Sounds).Ids

local player = Players.LocalPlayer

local Watcher = {}

local SUIT = Color3.fromRGB(14, 14, 18)
local DRONE = "rbxasset://sounds/action_falling.mp3"

local function piece(model: Model, name: string, size: Vector3, at: CFrame, color: Color3, ball: boolean?): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.Material = if ball then Enum.Material.SmoothPlastic else Enum.Material.Fabric
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = model
	return part
end

-- About 11 studs tall, feet at the origin, facing -Z. Returns the model and its head.
local function build(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Watcher"
	for _, side in { -1, 1 } do
		piece(model, "Leg", Vector3.new(0.7, 5.6, 0.7), CFrame.new(side * 0.45, 2.8, 0), SUIT)
		piece(
			model,
			"Arm",
			Vector3.new(0.5, 5.4, 0.5),
			CFrame.new(side * 1.25, 6.1, 0) * CFrame.Angles(0, 0, math.rad(side * 4)),
			SUIT
		)
		piece(
			model,
			"Hand",
			Vector3.new(0.4, 0.9, 0.3),
			CFrame.new(side * 1.45, 3.15, 0),
			Color3.fromRGB(230, 228, 222)
		)
	end
	piece(model, "Torso", Vector3.new(2, 3.3, 0.95), CFrame.new(0, 7.25, 0), SUIT)
	piece(model, "Shirt", Vector3.new(0.5, 3, 0.1), CFrame.new(0, 7.35, -0.48), Color3.fromRGB(235, 235, 235))
	piece(model, "Tie", Vector3.new(0.22, 2.4, 0.08), CFrame.new(0, 7.45, -0.54), Color3.fromRGB(90, 10, 15))
	local head =
		piece(model, "Head", Vector3.new(1.45, 1.95, 1.45), CFrame.new(0, 9.95, 0), Color3.fromRGB(238, 236, 230), true)
	return model, head
end

-- A spot on the ground in front of the camera, in plain view.
local function findSpot(camera: Camera, root: BasePart): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.2 then
		return nil
	end
	flat = flat.Unit
	local rng = Random.new()
	for _ = 1, 14 do
		local dir = CFrame.Angles(0, math.rad(rng:NextNumber(-32, 32)), 0):VectorToWorldSpace(flat)
		local spot = root.Position + dir * rng:NextNumber(Tuning.MinDistance, Tuning.MaxDistance)
		local down = workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), params)
		if down and down.Normal.Y > 0.8 then
			local feet = down.Position
			-- Nothing between the camera and his head.
			local eye = camera.CFrame.Position
			local headAt = feet + Vector3.new(0, 9.5, 0)
			local sight = workspace:Raycast(eye, headAt - eye, params)
			if not sight or (sight.Position - headAt).Magnitude < 2 then
				return feet
			end
		end
	end
	return nil
end

local function sound(id: string, speed: number, volume: number, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Looped = looped == true
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 4
	reverb.WetLevel = 0
	reverb.Parent = s
	s.Parent = workspace.CurrentCamera
	return s
end

local busy = false

local function appear()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if busy or not camera or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	local feet = findSpot(camera, root)
	if not feet then
		return
	end
	busy = true

	local model, head = build()
	local function face()
		local toward = Vector3.new(root.Position.X, feet.Y, root.Position.Z)
		return CFrame.lookAt(feet, toward)
	end
	local body = face()
	model:PivotTo(body)
	model.Parent = workspace

	-- A low drone swells, then a slow heartbeat.
	local drone = sound(DRONE, 0.32, 0, true)
	drone:Play()
	TweenService:Create(drone, TweenInfo.new(1.5), { Volume = 1.6 }):Play()
	local beat = sound(Sounds.Bonk, 0.35, 0.9)

	-- The world goes grey and the view tightens a little.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WatcherGrade"
	grade.Parent = Lighting
	TweenService:Create(grade, TweenInfo.new(1.2), {
		Saturation = -0.75,
		Contrast = 0.2,
		TintColor = Color3.fromRGB(235, 215, 215),
	}):Play()
	local fov = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { FieldOfView = fov - 8 }):Play()

	local started = os.clock()
	local seenFor = 0
	local nextBeat = os.clock() + 0.6
	local nextTwitch = os.clock() + 0.5
	local twitch = CFrame.identity
	local last = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local age = now - started
		body = face()
		-- Every so often he twitches in place, like a bad signal.
		if now > nextTwitch then
			twitch = CFrame.new(math.random() * 0.3 - 0.15, 0, 0) * CFrame.Angles(0, 0, math.rad(math.random(-3, 3)))
			nextTwitch = now + 0.2 + math.random() * 0.9
		end
		model:PivotTo(body * twitch)
		-- His head follows your camera, cocked to one side.
		head.CFrame = CFrame.lookAt(head.Position, camera.CFrame.Position) * CFrame.Angles(0, 0, math.rad(14))
		if now > nextBeat then
			beat:Play()
			nextBeat = now + math.max(0.45, 1.1 - age * 0.12)
		end

		local toHead = head.Position - camera.CFrame.Position
		if camera.CFrame.LookVector:Dot(toHead.Unit) > 0.985 then
			seenFor += dt
		end
		local close = Vector3.new(root.Position.X - feet.X, 0, root.Position.Z - feet.Z).Magnitude
		local gone = age > Tuning.StareSeconds
			or (age > 1.5 and seenFor > Tuning.SeenSeconds)
			or close < Tuning.VanishDistance
			or not root.Parent
		if gone then
			connection:Disconnect()
			model:Destroy()
			drone:Stop()
			drone:Destroy()
			beat:Destroy()
			local whoosh = sound(Sounds.Whoosh, 0.45, 0.8)
			whoosh:Play()
			task.delay(4, function()
				whoosh:Destroy()
			end)
			TweenService:Create(camera, TweenInfo.new(1), { FieldOfView = fov }):Play()
			local fade = TweenService:Create(grade, TweenInfo.new(2), {
				Saturation = 0,
				Contrast = 0,
				TintColor = Color3.new(1, 1, 1),
			})
			fade.Completed:Connect(function()
				grade:Destroy()
			end)
			fade:Play()
			busy = false
		end
	end)
end

function Watcher.Start()
	task.spawn(function()
		task.wait(Tuning.FirstDelay)
		local rng = Random.new()
		while true do
			appear()
			task.wait(rng:NextNumber(Tuning.MinInterval, Tuning.MaxInterval))
		end
	end)
end

return Watcher
