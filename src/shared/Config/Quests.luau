--!strict
-- Daily quests. Every day each player gets `PerDay` quests drawn from the
-- pool (the same three all day, different tomorrow). Rewards are free cash,
-- paid from base income like every other free reward, so they stay well
-- below what Robux buys (tests/unit checks this).
--
-- Event names are fired by QuestService:
--   BuySlime   a slime bought from the belt
--   BuyRare    a Rare-or-better slime bought from the belt
--   BonkThief  a thief bonked (by you)
--   Merge      a merge done
--   Steal      a slime stolen and brought home
--   Collect    a pedestal collected
--   Minute     a minute played

export type Quest = {
	Id: string,
	Text: string,
	Event: string,
	Goal: number,
	RewardMinutes: number, -- minutes of base income
	RewardMinimum: number,
}

local Pool: { Quest } = {
	{
		Id = "Buy5",
		Text = "Buy 5 slimes from the belt",
		Event = "BuySlime",
		Goal = 5,
		RewardMinutes = 3,
		RewardMinimum = 300,
	},
	{
		Id = "Buy12",
		Text = "Buy 12 slimes from the belt",
		Event = "BuySlime",
		Goal = 12,
		RewardMinutes = 5,
		RewardMinimum = 800,
	},
	{
		Id = "Rare1",
		Text = "Buy a Rare or better slime",
		Event = "BuyRare",
		Goal = 1,
		RewardMinutes = 4,
		RewardMinimum = 500,
	},
	{ Id = "Bonk5", Text = "Bonk 5 thieves", Event = "BonkThief", Goal = 5, RewardMinutes = 4, RewardMinimum = 500 },
	{ Id = "Bonk12", Text = "Bonk 12 thieves", Event = "BonkThief", Goal = 12, RewardMinutes = 5, RewardMinimum = 900 },
	{
		Id = "Merge1",
		Text = "Merge 3 slimes into a bigger one",
		Event = "Merge",
		Goal = 1,
		RewardMinutes = 4,
		RewardMinimum = 600,
	},
	{
		Id = "Merge3",
		Text = "Merge slimes 3 times",
		Event = "Merge",
		Goal = 3,
		RewardMinutes = 5,
		RewardMinimum = 1000,
	},
	{
		Id = "Steal1",
		Text = "Steal a slime and bring it home",
		Event = "Steal",
		Goal = 1,
		RewardMinutes = 4,
		RewardMinimum = 600,
	},
	{
		Id = "Collect20",
		Text = "Collect cash 20 times",
		Event = "Collect",
		Goal = 20,
		RewardMinutes = 3,
		RewardMinimum = 300,
	},
	{
		Id = "Play15",
		Text = "Play for 15 minutes",
		Event = "Minute",
		Goal = 15,
		RewardMinutes = 3,
		RewardMinimum = 300,
	},
	{
		Id = "Play30",
		Text = "Play for 30 minutes",
		Event = "Minute",
		Goal = 30,
		RewardMinutes = 5,
		RewardMinimum = 800,
	},
}

local byId: { [string]: Quest } = {}
for _, quest in Pool do
	assert(byId[quest.Id] == nil, "Duplicate quest id " .. quest.Id)
	byId[quest.Id] = quest
end

return {
	PerDay = 3,
	Pool = Pool,
	ById = byId,
}
