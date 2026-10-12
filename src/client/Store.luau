--!strict
-- Client-side copy of everything the server tells us. UI reads from here and
-- re-renders on Changed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

local Store = {}
Store.State = {} :: { [string]: any }
Store.Index = {} :: { [string]: { [string]: boolean } }
Store.Events = {} :: { [string]: any }
Store.Changed = Signal.new() -- (section: "State" | "Index" | "Events")

function Store.Get(key: string, default: any?): any
	local value = Store.State[key]
	if value == nil then
		return default
	end
	return value
end

function Store.HasPass(key: string): boolean
	local passes = Store.State.Passes
	return type(passes) == "table" and passes[key] == true
end

function Store.Init()
	Remotes.Get("State").OnClientEvent:Connect(function(partial: { [string]: any })
		for key, value in partial do
			Store.State[key] = value
		end
		Store.Changed:Fire("State")
	end)
	Remotes.Get("Index").OnClientEvent:Connect(function(index: { [string]: { [string]: boolean } })
		Store.Index = index
		Store.Changed:Fire("Index")
	end)
	Remotes.Get("Events").OnClientEvent:Connect(function(events: { [string]: any })
		Store.Events = events
		Store.Changed:Fire("Events")
	end)
end

function Store.Action(name: string, payload: any?)
	Remotes.Get("Action"):FireServer(name, payload)
end

return Store
