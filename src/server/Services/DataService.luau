--!strict
-- Loads and saves player data with a session lock so the same account can
-- never be loaded on two servers at once (prevents duplication exploits).
--
-- In Studio without API access, data runs in memory and is not saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)
local DataTemplate = require(script.Parent.Parent.DataTemplate)

type PlayerData = DataTemplate.PlayerData

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 60
local LOCK_EXPIRE_SECONDS = 300
local LOAD_ATTEMPTS = 6
local MAX_RECEIPTS = 50

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.ProfileReleasing = Signal.new() -- (player, data), just before the final save

local profiles: { [Player]: PlayerData } = {}
-- UserIds whose final save is in flight. Autosaves skip them, and a rejoin
-- to this same server waits so it never loads data older than that save.
local releasing: { [number]: boolean } = {}
local memoryOnly = false
local store: DataStore? = nil

local function key(userId: number): string
	return "u_" .. userId
end

local function jobId(): string
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function loadRaw(userId: number): { [string]: any }?
	if memoryOnly or not store then
		return {}
	end
	local dataStore = store :: DataStore
	for attempt = 1, LOAD_ATTEMPTS do
		local forceSteal = attempt == LOAD_ATTEMPTS
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key(userId), function(old: { [string]: any }?)
				local data: { [string]: any } = old or {}
				local lock = data.SessionLock
				if
					not forceSteal
					and type(lock) == "table"
					and lock.JobId ~= jobId()
					and os.time() - (lock.Time or 0) < LOCK_EXPIRE_SECONDS
				then
					return nil -- someone else holds the lock; cancel the write
				end
				data.SessionLock = { JobId = jobId(), Time = os.time() }
				return data
			end)
		end)
		if ok then
			local data = result :: { [string]: any }?
			if data and type(data.SessionLock) == "table" and data.SessionLock.JobId == jobId() then
				return data
			end
		else
			warn("[DataService] Load failed for", userId, result)
			if RunService:IsStudio() then
				warn("[DataService] Enable 'Studio Access to API Services' to test saving. Using memory-only data.")
				memoryOnly = true
				return {}
			end
		end
		task.wait(attempt * 2)
	end
	return nil
end

local function saveRaw(player: Player, data: PlayerData, release: boolean): boolean
	if memoryOnly or not store then
		return true
	end
	local dataStore = store :: DataStore
	data.LastOnline = os.time()
	local payload = table.clone(data) :: any
	local ok, err = pcall(function()
		dataStore:UpdateAsync(key(player.UserId), function(old: { [string]: any }?)
			local lock = old and old.SessionLock
			if type(lock) == "table" and lock.JobId ~= jobId() then
				return nil -- another server took over; never overwrite its data
			end
			if not release and (releasing[player.UserId] or profiles[player] ~= data) then
				return nil -- a late autosave must not re-lock after the final save
			end
			payload.SessionLock = if release then nil else { JobId = jobId(), Time = os.time() }
			return payload
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.UserId, err)
	end
	return ok
end

function DataService.Get(player: Player): PlayerData?
	return profiles[player]
end

-- Yields until the player's data is loaded. Returns nil if they leave first.
function DataService.WaitFor(player: Player): PlayerData?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.SaveNow(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	return saveRaw(player, data, false)
end

-- Returns true if this receipt was already granted, otherwise records it.
function DataService.ClaimReceipt(data: PlayerData, purchaseId: string): boolean
	if table.find(data.Receipts, purchaseId) then
		return true
	end
	table.insert(data.Receipts, purchaseId)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	return false
end

function DataService.UnclaimReceipt(data: PlayerData, purchaseId: string)
	local index = table.find(data.Receipts, purchaseId)
	if index then
		table.remove(data.Receipts, index)
	end
end

function DataService.IsMemoryOnly(): boolean
	return memoryOnly
end

local function onPlayerAdded(player: Player)
	while releasing[player.UserId] and player.Parent do
		task.wait(0.2)
	end
	local raw = loadRaw(player.UserId)
	if not player.Parent then
		if raw then
			-- They left while loading: release the lock we just took.
			saveRaw(player, DataTemplate.Reconcile(raw), true)
		end
		return
	end
	if not raw then
		player:Kick("Your data couldn't load. Please rejoin in a minute!")
		return
	end
	raw.SessionLock = nil
	local data = DataTemplate.Reconcile(raw)
	profiles[player] = data
	DataService.ProfileLoaded:Fire(player, data)
end

-- Final save + lock release. Safe to call twice (leave and shutdown race).
local function release(player: Player, data: PlayerData)
	local userId = player.UserId
	if releasing[userId] then
		return
	end
	releasing[userId] = true
	DataService.ProfileReleasing:Fire(player, data)
	task.wait() -- let releasing handlers write their final changes
	saveRaw(player, data, true)
	if profiles[player] == data then
		profiles[player] = nil
	end
	releasing[userId] = nil
end

local function onPlayerRemoving(player: Player)
	local data = profiles[player]
	if data then
		release(player, data)
	end
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable:", result)
		memoryOnly = true
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, data in profiles do
				if not releasing[player.UserId] then
					task.spawn(saveRaw, player, data, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		for player, data in profiles do
			task.spawn(release, player, data)
		end
		local deadline = os.clock() + 25
		while next(releasing) ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
