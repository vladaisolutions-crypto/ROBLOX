--!strict
-- Creates (server) or finds (client) every RemoteEvent the game uses.
--
--   State     server -> client  snapshot of the player's progress
--   Index     server -> client  discovered slimes
--   Notify    server -> client  toast message for one player
--   Announce  server -> clients big centre-screen message
--   Events    server -> clients luck / rain / seasonal timers
--   Tutorial  server -> client  current onboarding step + target
--   Action    client -> server  button presses (lock, rebirth, claim...)
--   Knockback server -> client  push your own character after a bonk

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "State", "Index", "Notify", "Announce", "Events", "Tutorial", "Action", "Knockback" }

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		for _, name in NAMES do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(NAMES, name), "Unknown remote " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
