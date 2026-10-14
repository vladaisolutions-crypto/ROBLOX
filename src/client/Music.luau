--!strict
-- Background music: shuffles the current event's playlist (Config/Music),
-- fading between tracks. Music.SetEnabled toggles it (the HUD's 🎵 button).

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Music)
local Store = require(script.Parent.Store)

local Music = {}

local enabled = true
local current: Sound? = nil
local playlistKey = ""
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

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(Config.FadeSeconds), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function nextTrack()
	token += 1
	local myToken = token
	if current then
		fadeOut(current)
		current = nil
	end
	if not enabled then
		return
	end
	local key, list = playlist()
	if key ~= playlistKey or #queue == 0 then
		playlistKey = key
		queue = table.clone(list)
		for i = #queue, 2, -1 do
			local j = math.random(1, i)
			queue[i], queue[j] = queue[j], queue[i]
		end
	end
	local id = table.remove(queue, 1)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "BackgroundMusic"
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = 0
	sound.Parent = SoundService
	current = sound
	sound.Ended:Connect(function()
		if token == myToken then
			nextTrack()
		end
	end)
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(Config.FadeSeconds), { Volume = Config.Volume }):Play()
end

function Music.SetEnabled(on: boolean)
	if enabled == on then
		return
	end
	enabled = on
	nextTrack() -- starts a track, or fades the current one out
end

function Music.IsEnabled(): boolean
	return enabled
end

function Music.Start()
	nextTrack()
	-- Switch playlists when a seasonal event starts or ends.
	Store.Changed:Connect(function(section: string)
		if section == "Events" and enabled then
			local key = playlist()
			if key ~= playlistKey then
				queue = {}
				nextTrack()
			end
		end
	end)
end

return Music
