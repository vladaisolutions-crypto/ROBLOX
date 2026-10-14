--!strict
-- Global leaderboards on two boards beside the belt: all-time cash earned,
-- and thieves caught. Scores go to OrderedDataStores every couple of
-- minutes; the boards refresh from the top 10.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

type Board = {
	Store: OrderedDataStore?,
	Title: string,
	Color: Color3,
	Value: (Player) -> number?,
	Format: (number) -> string,
	Rows: { TextLabel },
}

local UPDATE_SECONDS = 120
local TOP = 10
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and type(name) == "string" then name else "Player"
	names[userId] = result
	return result
end

local function openStore(name: string): OrderedDataStore?
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, name)
	return if ok then store else nil
end

-- A free-standing board facing the belt.
local function buildBoard(board: Board, position: Vector3, facing: Vector3)
	local map = workspace:WaitForChild("Map")
	local part = Instance.new("Part")
	part.Name = "Leaderboard"
	part.Anchored = true
	part.Size = Vector3.new(18, 13, 0.6)
	part.CFrame = CFrame.lookAt(position, position + facing)
	part.Color = Color3.fromRGB(28, 22, 38)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = map
	for _, side in { -1, 1 } do
		local post = Instance.new("Part")
		post.Anchored = true
		post.Size = Vector3.new(0.8, position.Y + 6.5, 0.8)
		post.CFrame = part.CFrame * CFrame.new(side * 9.4, -(position.Y + 6.5) / 2 + 6.5, 0)
		post.Color = Color3.fromRGB(40, 32, 50)
		post.Material = Enum.Material.Metal
		post.Parent = map
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(540, 390)
	gui.LightInfluence = 0
	gui.Parent = part
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = board.Color
	title.TextStrokeTransparency = 0
	title.Text = board.Title
	title.Parent = gui
	for i = 1, TOP do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(0.92, 0, 0, 31)
		row.Position = UDim2.new(0.04, 0, 0, 60 + (i - 1) * 32)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1
			then Color3.fromRGB(255, 215, 60)
			elseif i == 2 then Color3.fromRGB(220, 225, 235)
			elseif i == 3 then Color3.fromRGB(230, 150, 90)
			else Color3.new(1, 1, 1)
		row.TextStrokeTransparency = 0.3
		row.Text = ""
		row.Parent = gui
		table.insert(board.Rows, row)
	end
end

local boards: { Board } = {}

local function save(player: Player)
	for _, board in boards do
		local value = board.Value(player)
		if board.Store and value and value > 0 then
			pcall(function()
				(board.Store :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

local function refresh(board: Board)
	local store = board.Store
	if not store then
		board.Rows[1].Text = "Leaderboard offline"
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP)
	end)
	if not ok or not pages then
		return
	end
	local entries = pages:GetCurrentPage()
	for i, row in board.Rows do
		local entry = entries[i]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = string.format("#%d  %s  —  %s", i, nameOf(userId), board.Format(entry.value))
		else
			row.Text = ""
		end
	end
end

function LeaderboardService.Start()
	boards = {
		{
			Store = openStore("LB_TotalEarned_v1"),
			Title = "💰 Richest Slimers",
			Color = Color3.fromRGB(255, 215, 60),
			Value = function(player: Player): number?
				local data = DataService.Get(player)
				return if data then data.TotalEarned else nil
			end,
			Format = function(value: number): string
				return Format.Cash(value)
			end,
			Rows = {},
		},
		{
			Store = openStore("LB_ThievesCaught_v1"),
			Title = "🏏 Top Thief Hunters",
			Color = Color3.fromRGB(255, 110, 110),
			Value = function(player: Player): number?
				local data = DataService.Get(player)
				return if data then data.Stats.ThievesCaught else nil
			end,
			Format = function(value: number): string
				return tostring(value) .. " caught"
			end,
			Rows = {},
		},
	}
	-- Between the middle two bases on each side, facing the belt.
	buildBoard(boards[1], Vector3.new(0, 7.5, -34), Vector3.new(0, 0, 1))
	buildBoard(boards[2], Vector3.new(0, 7.5, 34), Vector3.new(0, 0, -1))

	Players.PlayerRemoving:Connect(save)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				save(player)
			end
			for _, board in boards do
				refresh(board)
			end
			task.wait(UPDATE_SECONDS)
		end
	end)
end

return LeaderboardService
