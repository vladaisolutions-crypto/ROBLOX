--!strict
-- Spawns characters inside their owner's base (CharacterAutoLoads is off),
-- respawns them, and lets owners walk through their own lock barrier.

local Players = game:GetService("Players")

local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local WorldService = require(script.Parent.WorldService)

type Plot = WorldService.Plot

local CharacterService = {}

local function setGroup(instance: Instance, group: string)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = group
	end
end

local function onCharacter(player: Player, character: Model)
	local plot = PlotService.GetPlot(player)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not plot or not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	-- RespawnLocation normally puts them in their base already. If the engine
	-- placed them elsewhere, move them once it has finished spawning.
	task.wait()
	if (root.Position - plot.SpawnCFrame.Position).Magnitude > 25 then
		character:PivotTo(plot.SpawnCFrame)
	end

	for _, descendant in character:GetDescendants() do
		setGroup(descendant, plot.OwnerGroup)
	end
	character.DescendantAdded:Connect(function(descendant)
		setGroup(descendant, plot.OwnerGroup)
	end)

	StealService.OnCharacter(player)

	humanoid.Died:Connect(function()
		task.wait(Players.RespawnTime)
		if player.Parent and player.Character == character then
			player:LoadCharacterAsync()
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

function CharacterService.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PlotService.PlotAssigned:Connect(function(player: Player, plot: Plot)
		if player.Parent then
			player.RespawnLocation = plot.Spawn
			player:LoadCharacterAsync()
		end
	end)
end

return CharacterService
