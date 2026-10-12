-- Smoke test executed on a real (headless) Roblox server through Open Cloud
-- Luau Execution: `scripts/roblox_cloud.py check`. Errors fail the run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local failures = {}
local function check(condition, message)
	if not condition then
		table.insert(failures, message)
	end
end

-- Server scripts start with the place; give them a moment to build the map.
local map = workspace:WaitForChild("Map", 20)
check(map ~= nil, "Map folder was not generated")
task.wait(4)

if map then
	local plots = 0
	for _, child in map:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotIndex") then
			plots += 1
			check(child:FindFirstChild("Barrier") ~= nil, child.Name .. " has no barrier")
			check(child:FindFirstChild("LockPad") ~= nil, child.Name .. " has no lock pad")
		end
	end
	check(plots == 8, "expected 8 plots, found " .. plots)
end

local beltSlimes = 0
for _, child in workspace:GetChildren() do
	if child:IsA("Model") and child:GetAttribute("SlimeId") then
		beltSlimes += 1
		check(child:FindFirstChild("BuyPrompt", true) ~= nil, child.Name .. " on belt has no buy prompt")
	end
end
check(beltSlimes >= 5, "expected slimes on the belt, found " .. beltSlimes)

check(ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "Remotes folder missing")

-- Every slime model must build without errors.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Slimes = require(Shared.Config.Slimes)
local SlimeBuilder = require(Shared.SlimeBuilder)
for _, def in Slimes.List do
	for _, mutation in { "", "Gold", "Diamond", "Rainbow", "Haunted" } do
		local ok, err = pcall(function()
			SlimeBuilder.Build(def.Id, mutation):Destroy()
		end)
		check(ok, "building " .. def.Id .. "/" .. mutation .. " failed: " .. tostring(err))
	end
end

if #failures > 0 then
	error("SMOKE FAILED:\n- " .. table.concat(failures, "\n- "))
end
return string.format("SMOKE OK: 8 plots, %d belt slimes, %d slime models built", beltSlimes, #Slimes.List * 5)
