--!strict
-- Chaos events: every few minutes something random happens to the whole
-- server so it never gets boring (tuning: Events.Chaos).
--
--   CashRain     coins fall all over the map; touch one to collect it.
--   Meteors      red circles warn, then a meteor crashes there, knocks
--                people back and leaves a cash crystal.
--   LowGravity   moon jumps.
--   SpeedFrenzy  everyone runs faster.
--   LuckyStorm   extra belt luck.
--   Blackout     the lights go out (clients darken the world; the Watcher
--                shows up).
--
-- Never during a thief raid or Slime Rain. Clients read the workspace
-- attributes Chaos / ChaosEndsAt for their visuals (client/Chaos.luau).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Events = require(Shared.Config.Events)
local World = require(Shared.Config.World)

local EconomyService = require(script.Parent.EconomyService)
local EventService = require(script.Parent.EventService)
local NetService = require(script.Parent.NetService)
local StealService = require(script.Parent.StealService)

local Tuning = Events.Chaos

local ChaosService = {}

local folder: Folder
local rng = Random.new()
local NORMAL_GRAVITY = workspace.Gravity

local function playerOf(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

-- A random spot on the ground: near a random player half the time, so
-- everyone gets some action, otherwise anywhere on the map.
local function randomSpot(): Vector3
	local players = Players:GetPlayers()
	if #players > 0 and rng:NextNumber() < 0.5 then
		local character = players[rng:NextInteger(1, #players)].Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local offset = Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
			return Vector3.new(root.Position.X, 0, root.Position.Z) + offset
		end
	end
	local halfX, halfZ = World.MapSizeX / 2 - 15, World.MapSizeZ / 2 - 15
	return Vector3.new(rng:NextNumber(-halfX, halfX), 0, rng:NextNumber(-halfZ, halfZ))
end

local function groundAt(spot: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(spot + Vector3.new(0, 120, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else spot
end

-- A pickup: touch it to get `minutes` of your base income.
local function pickup(part: BasePart, minutes: number, minimum: number)
	local taken = false
	part.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = playerOf(hit)
		if not player then
			return
		end
		taken = true
		local amount = EconomyService.FreeRewardCash(player, minutes, minimum)
		EconomyService.AddCash(player, amount, "Reward", "Chaos")
		NetService.FxTo(player, "Cash", { Position = part.Position, Amount = amount })
		part:Destroy()
	end)
end

local function coin()
	local spot = randomSpot()
	local part = Instance.new("Part")
	part.Name = "Coin"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.4, 2.4, 2.4)
	part.Color = Color3.fromRGB(255, 205, 50)
	part.Material = Enum.Material.Neon
	part.CFrame = CFrame.new(spot + Vector3.new(0, 70, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(90))
	part.CanCollide = true
	part.CanQuery = false
	part.CollisionGroup = "Default"
	part.Parent = folder
	part:SetNetworkOwner(nil)
	part.AssemblyAngularVelocity = Vector3.new(0, 6, 0)
	pickup(part, Tuning.CoinMinutes, Tuning.CoinMinimum)
	Debris:AddItem(part, 14)
end

local function meteor()
	local ground = groundAt(randomSpot())
	local radius = Tuning.MeteorRadius
	-- Warning circle on the ground.
	local ring = Instance.new("Part")
	ring.Name = "MeteorWarning"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 40, 30)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.55
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(Tuning.MeteorWarnSeconds, Enum.EasingStyle.Linear), {
		Transparency = 0.15,
	}):Play()

	local rock = Instance.new("Part")
	rock.Name = "Meteor"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 5
	rock.Color = Color3.fromRGB(255, 90, 20)
	rock.Material = Enum.Material.Neon
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false
	local from = ground + Vector3.new(rng:NextNumber(-40, 40), 160, rng:NextNumber(-40, 40))
	rock.CFrame = CFrame.new(from)
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 20
	fire.Parent = rock
	rock.Parent = folder
	TweenService
		:Create(rock, TweenInfo.new(Tuning.MeteorWarnSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)),
		})
		:Play()

	task.delay(Tuning.MeteorWarnSeconds, function()
		ring:Destroy()
		rock:Destroy()
		NetService.Fx("Meteor", { Position = ground + Vector3.new(0, 1, 0) })
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local away = root.Position - ground
				local flat = Vector3.new(away.X, 0, away.Z)
				if away.Magnitude < radius then
					local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
					StealService.Knock(player, dir * 45 + Vector3.new(0, 40, 0), 1)
				end
			end
		end
		-- The crystal it leaves behind.
		local crystal = Instance.new("Part")
		crystal.Name = "MeteorCrystal"
		crystal.Size = Vector3.new(1.6, 2.6, 1.6)
		crystal.CFrame = CFrame.new(ground + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(45), math.rad(10))
		crystal.Color = Color3.fromRGB(120, 230, 255)
		crystal.Material = Enum.Material.Neon
		crystal.Anchored = true
		crystal.CanCollide = false
		crystal.CanQuery = false
		crystal.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = crystal.Color
		light.Range = 12
		light.Parent = crystal
		pickup(crystal, Tuning.CrystalMinutes, Tuning.CrystalMinimum)
		Debris:AddItem(crystal, 25)
	end)
end

local function blocked(): boolean
	return workspace:GetAttribute("RaidActive") == true or EventService.RainActive()
end

local function run(event: { Id: string, Seconds: number, Text: string })
	local endsAt = workspace:GetServerTimeNow() + event.Seconds
	workspace:SetAttribute("Chaos", event.Id)
	workspace:SetAttribute("ChaosEndsAt", endsAt)
	NetService.Announce(event.Text, Color3.fromRGB(255, 220, 90))

	if event.Id == "LowGravity" then
		workspace.Gravity = Tuning.LowGravity
	elseif event.Id == "SpeedFrenzy" then
		StealService.SetSpeedBoost(Tuning.SpeedMultiplier)
	elseif event.Id == "LuckyStorm" then
		EventService.BoostLuck(Tuning.Luck, event.Seconds)
	end

	local stopAt = os.clock() + event.Seconds
	while os.clock() < stopAt do
		if event.Id == "CashRain" then
			coin()
			task.wait(Tuning.CoinEvery)
		elseif event.Id == "Meteors" then
			meteor()
			task.wait(Tuning.MeteorEvery * rng:NextNumber(0.6, 1.3))
		else
			task.wait(0.5)
		end
	end

	workspace.Gravity = NORMAL_GRAVITY
	StealService.SetSpeedBoost(1)
	workspace:SetAttribute("Chaos", "")
	NetService.Announce("✅ The chaos is over... for now.", Color3.fromRGB(200, 200, 220))
end

local function pick(): { Id: string, Seconds: number, Text: string, Weight: number }
	local total = 0
	for _, event in Tuning.List do
		total += event.Weight
	end
	local roll = rng:NextNumber(0, total)
	for _, event in Tuning.List do
		roll -= event.Weight
		if roll <= 0 then
			return event
		end
	end
	return Tuning.List[1]
end

function ChaosService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Chaos"
	folder.Parent = workspace
	workspace:SetAttribute("Chaos", "")
end

function ChaosService.Start()
	task.spawn(function()
		task.wait(Tuning.FirstDelay)
		local last = ""
		while true do
			while blocked() or #Players:GetPlayers() == 0 do
				task.wait(5)
			end
			local event = pick()
			if event.Id == last then
				event = pick() -- try not to repeat
			end
			last = event.Id
			run(event)
			task.wait(rng:NextNumber(Tuning.MinInterval, Tuning.MaxInterval))
		end
	end)
end

return ChaosService
