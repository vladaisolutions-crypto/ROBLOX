--!strict
-- Makes every slime feel alive (visual only, runs on each client):
--
--   Breathe  a slow squash and stretch.
--   Hop      every few seconds a slime crouches, springs up stretched, and
--            lands with a squash. Its real shadow follows it.
--   Blink    eyes snap shut now and then.
--   Wriggle  a carried (stolen) slime squirms and tilts frantically.
--   Rainbow  Rainbow mutations cycle their colour.
--
-- SlimeBuilder hangs the body off the anchored root by a Weld named "Jelly"
-- and welds the face and hat to the body, so moving Jelly.C0 here moves the
-- whole slime without touching anything the server owns.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SlimeAnim = {}

local RANGE = 110 -- studs from the camera; farther slimes stay still
local HOP_TIME = 0.6
local BLINK_TIME = 0.16

type State = {
	Weld: Weld,
	Mesh: SpecialMesh?,
	Eyes: { SpecialMesh },
	Seed: number,
	NextHop: number,
	HopAt: number,
	NextBlink: number,
	BlinkAt: number,
	Rng: Random,
}

local states: { [BasePart]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(body: BasePart, now: number): State?
	local state = states[body]
	if state then
		return state
	end
	local weld = body:FindFirstChild("Jelly")
	local model = body.Parent
	if not (weld and weld:IsA("Weld") and model) then
		return nil
	end
	local eyes = {}
	for _, child in model:GetChildren() do
		if child.Name == "Eye" or child.Name == "Pupil" then
			local mesh = child:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				table.insert(eyes, mesh)
			end
		end
	end
	local seed = (body.Position.X * 0.37 + body.Position.Z * 0.21) % 6.28
	local rng = Random.new(math.floor(seed * 1000))
	state = {
		Weld = weld,
		Mesh = body:FindFirstChildOfClass("SpecialMesh"),
		Eyes = eyes,
		Seed = seed,
		NextHop = now + rng:NextNumber(0.5, 5),
		HopAt = -math.huge,
		NextBlink = now + rng:NextNumber(0.5, 4),
		BlinkAt = -math.huge,
		Rng = rng,
	}
	states[body] = state
	return state
end

-- Hop curve for p in [0, 1]: returns (height fraction of body, vertical scale).
local function hop(p: number): (number, number)
	if p < 0.18 then -- crouch
		local q = p / 0.18
		return 0, 1 - 0.22 * math.sin(q * math.pi / 2)
	elseif p < 0.72 then -- airborne, stretched on the way up
		local q = (p - 0.18) / 0.54
		return math.sin(q * math.pi) * 0.55, 1.14 - 0.14 * q
	else -- land: squash, then a little wobble back to round
		local q = (p - 0.72) / 0.28
		return 0, 1 - 0.24 * math.exp(-4 * q) * math.cos(q * math.pi * 2.5)
	end
end

local function animate(body: BasePart, state: State, now: number)
	local height = body.Size.Y
	local model = body.Parent
	local carried = model ~= nil and model:GetAttribute("Carried") == true

	local stretch, lift, tilt = 1, 0, CFrame.identity
	if carried then
		stretch = 1 + math.sin(now * 14 + state.Seed) * 0.13
		tilt = CFrame.Angles(math.sin(now * 9 + state.Seed) * 0.2, 0, math.sin(now * 11 + state.Seed) * 0.3)
	else
		if now >= state.NextHop then
			state.HopAt = now
			state.NextHop = now + HOP_TIME + state.Rng:NextNumber(2.5, 7)
		end
		local p = (now - state.HopAt) / HOP_TIME
		if p >= 0 and p < 1 then
			local h
			h, stretch = hop(p)
			lift = h * height
			tilt = CFrame.Angles(-math.sin(p * math.pi) * 0.12, 0, 0)
		else
			stretch = 1 + math.sin(now * 3.2 + state.Seed) * 0.045
		end
	end

	-- Keep volume roughly constant and the bottom on the ground.
	local wide = 1 + (1 - stretch) * 0.6
	if state.Mesh then
		state.Mesh.Scale = Vector3.new(wide, stretch, wide)
	end
	state.Weld.C0 = CFrame.new(0, lift - (1 - stretch) * height / 2, 0) * tilt

	if now >= state.NextBlink then
		state.BlinkAt = now
		state.NextBlink = now + state.Rng:NextNumber(1.8, 5.5)
	end
	local blink = (now - state.BlinkAt) / BLINK_TIME
	local open = if blink >= 0 and blink < 1 then 0.1 + 0.9 * math.abs(blink * 2 - 1) else 1
	if #state.Eyes > 0 and state.Eyes[1].Scale.Y ~= open then
		for _, mesh in state.Eyes do
			mesh.Scale = Vector3.new(1, open, 1)
		end
	end
end

function SlimeAnim.Start()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock() - t0
		local eye = camera.CFrame.Position
		for _, body in CollectionService:GetTagged("SlimeBody") do
			if body:IsA("BasePart") and (body.Position - eye).Magnitude < RANGE then
				local state = stateOf(body, now)
				if state then
					animate(body, state, now)
				end
			end
		end
		for _, body in CollectionService:GetTagged("RainbowSlime") do
			if body:IsA("BasePart") then
				body.Color = Color3.fromHSV((now * 0.25 + body.Position.X * 0.01) % 1, 0.75, 1)
			end
		end
	end)
end

return SlimeAnim
