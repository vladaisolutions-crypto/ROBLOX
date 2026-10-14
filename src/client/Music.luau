--!strict
-- Background music: the current event's playlist (Config/Music), looping and
-- crossfading between tracks; during a thief raid (workspace attribute
-- RaidActive) it crossfades to the chase track and back when the raid ends.
-- Music.SetEnabled toggles it (the HUD's 🎵 button).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Music)
local Store = require(script.Parent.Store)

local Music = {}

local enabled = true
local current: Sound? = nil
local mode = "" -- playlist key, or "Raid"
local queue: { number } = {}
local token = 0

local function playlist(): (string, { number })
	local seasonal = Store.Events.Seasonal
	local id = if type(seasonal) == "table" and type(seasonal.Id) == "string" then seasonal.Id else ""
	local list = Config.Playlists[id]
	if list and #list > 0 then
		return id, list
	end
	return "Default", Config.Playlists.Default
end

local function raiding(): boolean
	return workspace:GetAttribute("RaidActive") == true
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(Config.FadeSeconds), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function start(id: number, volume: number, looped: boolean, onEnded: (() -> ())?)
	token += 1
	local myToken = token
	if current then
		fadeOut(current)
		current = nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = 0
	sound.Looped = looped
	sound.Parent = SoundService
	current = sound
	if onEnded then
		sound.Ended:Connect(function()
			if token == myToken then
				onEnded()
			end
		end)
	end
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(Config.FadeSeconds), { Volume = volume }):Play()
end

-- Picks what should be playing now and switches to it if needed.
local function refresh(force: boolean?)
	if not enabled then
		token += 1
		if current then
			fadeOut(current)
			current = nil
		end
		mode = ""
		return
	end
	if raiding() then
		if mode ~= "Raid" or force then
			mode = "Raid"
			start(Config.RaidTrack, Config.RaidVolume, true)
		end
		return
	end
	local key, list = playlist()
	if mode == key and not force and current then
		return
	end
	mode = key
	if #queue == 0 or force then
		queue = table.clone(list)
		for i = #queue, 2, -1 do
			local j = math.random(1, i)
			queue[i], queue[j] = queue[j], queue[i]
		end
	end
	local id = table.remove(queue, 1)
	if id then
		-- A one-track playlist just loops; longer ones move on when a track ends.
		start(
			id,
			Config.Volume,
			#list == 1,
			if #list > 1
				then function()
					refresh(true)
				end
				else nil
		)
	end
end

function Music.SetEnabled(on: boolean)
	if enabled == on then
		return
	end
	enabled = on
	refresh(true)
end

function Music.IsEnabled(): boolean
	return enabled
end

function Music.Start()
	refresh(true)
	workspace:GetAttributeChangedSignal("RaidActive"):Connect(function()
		refresh()
	end)
	Store.Changed:Connect(function(section: string)
		if section == "Events" then
			refresh()
		end
	end)
end

return Music
