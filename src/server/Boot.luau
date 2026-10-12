--!strict
-- The server boot sequence, as a module so it can be run by something other
-- than the game starting: `tests/smoke.luau` boots the server itself, because
-- Open Cloud Luau execution sessions load the place without running it
-- (RunService:IsRunning() is false there, so no Script ever executes).
--
-- Services are initialised in dependency order, then started. Init() wires up
-- connections; Start() begins loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ORDER = {
	"NetService",
	"DataService",
	"TelemetryService",
	"PassService",
	"WorldService",
	"EventService",
	"DecorService",
	"EconomyService",
	"PlotService",
	"ConveyorService",
	"StealService",
	"CharacterService",
	"MonetizationService",
	"RewardService",
	"TutorialService",
}

type Service = { Init: (() -> ())?, Start: (() -> ())? }

local Boot = {}

Boot.Order = ORDER

-- True once the server has booted, so a second call is a no-op rather than a
-- duplicate set of connections and loops.
function Boot.HasRun(): boolean
	return ReplicatedStorage:FindFirstChild("Remotes") ~= nil
end

function Boot.Run(services: Instance)
	if Boot.HasRun() then
		return
	end
	local loaded: { Service } = {}
	for _, name in ORDER do
		local module = services:FindFirstChild(name)
		assert(module and module:IsA("ModuleScript"), "missing service module " .. name)
		table.insert(loaded, require(module) :: any)
	end
	for _, service in loaded do
		if service.Init then
			service.Init()
		end
	end
	for _, service in loaded do
		if service.Start then
			task.spawn(service.Start)
		end
	end
end

return Boot
