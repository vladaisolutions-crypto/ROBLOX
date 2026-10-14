--!strict
-- Game pass ownership, checked once on join and updated on in-game purchase.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Monetization = require(Shared.Config.Monetization)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)

-- Set true to test pass perks in Studio without buying them.
local STUDIO_GRANT_ALL = false

local PassService = {}
PassService.Changed = Signal.new() -- (player, passKey)

local owned: { [Player]: { [string]: boolean } } = {}

function PassService.Has(player: Player, passKey: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[passKey] == true
end

function PassService.Owned(player: Player): { [string]: boolean }
	return owned[player] or {}
end

local function grant(player: Player, passKey: string)
	local passes = owned[player]
	if not passes or passes[passKey] then
		return
	end
	passes[passKey] = true
	-- Lets clients show perks of other players (e.g. the VIP chat tag).
	player:SetAttribute("Pass_" .. passKey, true)
	PassService.Changed:Fire(player, passKey)
end

local function load(player: Player)
	owned[player] = {}
	for _, pass in Monetization.Passes do
		if STUDIO_GRANT_ALL and RunService:IsStudio() then
			grant(player, pass.Key)
		elseif pass.Id ~= 0 then
			task.spawn(function()
				local ok, has = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				if ok and has then
					grant(player, pass.Key)
				end
			end)
		end
	end
end

-- Every pass, free (a secret code); kept in saved data so it lasts.
function PassService.GrantAll(player: Player)
	for _, pass in Monetization.Passes do
		grant(player, pass.Key)
	end
end

function PassService.Init()
	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		if data.CompPasses then
			PassService.GrantAll(player)
		end
	end)
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		load(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local pass = Monetization.PassById[passId]
			if purchased and pass then
				grant(player, pass.Key)
			end
		end
	)
end

return PassService
