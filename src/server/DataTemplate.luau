--!strict
-- Shape of a player's saved data. New fields added here are filled in for
-- existing players automatically when their data loads.

local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy)

export type SlotData = {
	Slot: number, -- pedestal index in the base
	Id: string, -- slime id
	Mutation: string, -- "" for none
	Stored: number, -- uncollected cash on this pedestal
}

export type PlayerData = {
	Version: number,
	Cash: number,
	TotalEarned: number,
	Rebirths: number,
	Slots: { SlotData },
	Index: { [string]: { [string]: boolean } }, -- slimeId -> mutation ("Normal" for none) -> true
	Daily: { LastDay: number, Streak: number },
	LastOnline: number,
	TutorialStep: number,
	Stats: {
		Steals: number,
		StolenFrom: number,
		SlimesBought: number,
		PlaySeconds: number,
		RobuxSpent: number,
	},
	Receipts: { string },
	Funnel: { [string]: boolean }, -- onboarding analytics steps already logged
	Codes: { [string]: boolean }, -- redeemed codes
}

local DataTemplate = {}

function DataTemplate.New(): PlayerData
	return {
		Version = 1,
		Cash = Economy.StartingCash,
		TotalEarned = 0,
		Rebirths = 0,
		Slots = {},
		Index = {},
		Daily = { LastDay = 0, Streak = 0 },
		LastOnline = 0,
		TutorialStep = 1,
		Stats = { Steals = 0, StolenFrom = 0, SlimesBought = 0, PlaySeconds = 0, RobuxSpent = 0 },
		Receipts = {},
		Funnel = {},
		Codes = {},
	}
end

-- Fills any missing keys in `data` from `template`, recursively. Lists
-- (Slots, Receipts) are left alone if present.
local function reconcile(data: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(data[key], value)
		end
	end
end

function DataTemplate.Reconcile(raw: { [string]: any }): PlayerData
	reconcile(raw, DataTemplate.New() :: any)
	return (raw :: any) :: PlayerData
end

return DataTemplate
