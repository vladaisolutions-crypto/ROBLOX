--!strict
-- Thin wrapper over the remotes: messages to players and rate-limited
-- client actions.

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local ACTION_MIN_INTERVAL = 0.25

export type NotifyKind = "Info" | "Good" | "Bad" | "Money"

local NetService = {}

local actionHandlers: { [string]: (Player, any) -> () } = {}
local lastAction: { [Player]: { [string]: number } } = {}

function NetService.Notify(player: Player, text: string, kind: NotifyKind?)
	Remotes.Get("Notify"):FireClient(player, text, kind or "Info")
end

function NetService.Announce(text: string, color: Color3?)
	Remotes.Get("Announce"):FireAllClients(text, color or Color3.new(1, 1, 1))
end

function NetService.SendState(player: Player, state: { [string]: any })
	Remotes.Get("State"):FireClient(player, state)
end

function NetService.SendIndex(player: Player, index: { [string]: { [string]: boolean } })
	Remotes.Get("Index"):FireClient(player, index)
end

function NetService.SendTutorial(player: Player, step: number, text: string?, target: Instance?)
	Remotes.Get("Tutorial"):FireClient(player, step, text, target)
end

function NetService.BroadcastEvents(state: { [string]: any })
	Remotes.Get("Events"):FireAllClients(state)
end

function NetService.SendEvents(player: Player, state: { [string]: any })
	Remotes.Get("Events"):FireClient(player, state)
end

-- Registers a handler for Action:FireServer(name, payload).
-- Visual/sound effect for everyone (`kind` + a data table).
function NetService.Fx(kind: string, data: { [string]: any })
	Remotes.Get("Fx"):FireAllClients(kind, data)
end

function NetService.FxTo(player: Player, kind: string, data: { [string]: any })
	Remotes.Get("Fx"):FireClient(player, kind, data)
end

function NetService.OnAction(name: string, handler: (Player, any) -> ())
	actionHandlers[name] = handler
end

function NetService.Init()
	Remotes.Get("Action").OnServerEvent:Connect(function(player: Player, name: unknown, payload: unknown)
		if type(name) ~= "string" then
			return
		end
		local handler = actionHandlers[name]
		if not handler then
			return
		end
		local times = lastAction[player]
		if not times then
			times = {}
			lastAction[player] = times
		end
		local now = os.clock()
		if now - (times[name] or 0) < ACTION_MIN_INTERVAL then
			return
		end
		times[name] = now
		handler(player, payload)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return NetService
