--!strict
-- Server entry point. Services are initialised in dependency order, then
-- started. Init() wires up connections; Start() begins loops.

local Services = script.Services

local ORDER = {
	"NetService",
	"DataService",
	"TelemetryService",
	"PassService",
	"WorldService",
	"EventService",
	"EconomyService",
	"PlotService",
	"ConveyorService",
	"StealService",
	"CharacterService",
	"MonetizationService",
	"RewardService",
	"TutorialService",
}

local loaded: { { Init: (() -> ())?, Start: (() -> ())? } } = {}
for _, name in ORDER do
	table.insert(loaded, require(Services:FindFirstChild(name) :: ModuleScript) :: any)
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
