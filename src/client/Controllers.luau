--!strict
-- Small client behaviours that are not UI panels.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local Controllers = {}

-- Steal prompts only show on other people's unlocked slimes; Sell prompts
-- only on your own. The server re-checks everything on trigger.
local function plotLocked(plotIndex: number?): boolean
	if not plotIndex then
		return false
	end
	local map = workspace:FindFirstChild("Map")
	local plot = map and map:FindFirstChild("Plot" .. plotIndex)
	return plot ~= nil and plot:GetAttribute("Locked") == true
end

local function updatePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local mine = prompt:GetAttribute("OwnerUserId") == player.UserId
	if CollectionService:HasTag(prompt, "StealPrompt") then
		local plotIndex = prompt:GetAttribute("PlotIndex")
		prompt.Enabled = not mine and not plotLocked(if type(plotIndex) == "number" then plotIndex else nil)
	elseif CollectionService:HasTag(prompt, "SellPrompt") then
		prompt.Enabled = mine
	end
end

local function watchPrompts()
	for _, tag in { "StealPrompt", "SellPrompt" } do
		for _, prompt in CollectionService:GetTagged(tag) do
			updatePrompt(prompt)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(updatePrompt)
	end
	-- Plot lock changes flip steal prompts on/off.
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		for _, plot in map:GetChildren() do
			if plot:IsA("Model") then
				plot:GetAttributeChangedSignal("Locked"):Connect(function()
					for _, prompt in CollectionService:GetTagged("StealPrompt") do
						updatePrompt(prompt)
					end
				end)
			end
		end
	end)
end

-- Jelly squish on nearby slimes, and colour cycling for Rainbow mutations.
local function animateSlimes()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock() - t0
		local camPos = camera.CFrame.Position
		for _, body in CollectionService:GetTagged("SlimeBody") do
			if body:IsA("BasePart") and (body.Position - camPos).Magnitude < 90 then
				local mesh = body:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					local phase = t * 4 + body.Position.X * 0.3 + body.Position.Z * 0.2
					local squish = math.sin(phase) * 0.06
					mesh.Scale = Vector3.new(1 + squish, 1 - squish, 1 + squish)
				end
			end
		end
		for _, body in CollectionService:GetTagged("RainbowSlime") do
			if body:IsA("BasePart") then
				body.Color = Color3.fromHSV((t * 0.25 + body.Position.X * 0.01) % 1, 0.75, 1)
			end
		end
	end)
end

-- The server tells us when we get bonked; we own our character's physics.
local function listenKnockback()
	Remotes.Get("Knockback").OnClientEvent:Connect(function(velocity: Vector3, stun: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid then
			return
		end
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		root.AssemblyLinearVelocity = velocity
		task.delay(stun, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)
end

-- Tutorial: a glowing beam from the player to the current goal, plus text.
local function tutorial(textLabel: TextLabel)
	local beam: Beam? = nil
	local targetAttachment: Attachment? = nil
	local playerAttachment: Attachment? = nil

	local function clear()
		if beam then
			beam:Destroy()
			beam = nil
		end
		if targetAttachment then
			targetAttachment:Destroy()
			targetAttachment = nil
		end
	end

	local function ensurePlayerAttachment(): Attachment?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		if not playerAttachment or playerAttachment.Parent ~= root then
			local attachment = Instance.new("Attachment")
			attachment.Name = "TutorialAttachment"
			attachment.Parent = root
			playerAttachment = attachment
		end
		return playerAttachment
	end

	Remotes.Get("Tutorial").OnClientEvent:Connect(function(step: number, text: string?, target: Instance?)
		clear()
		textLabel.Visible = step > 0 and text ~= nil
		textLabel.Text = text or ""
		local part: BasePart? = nil
		if target and target:IsA("Model") then
			part = target.PrimaryPart
		elseif target and target:IsA("BasePart") then
			part = target
		end
		local from = ensurePlayerAttachment()
		if not part or not from then
			return
		end
		local to = Instance.new("Attachment")
		to.Parent = part
		targetAttachment = to
		local newBeam = Instance.new("Beam")
		newBeam.Attachment0 = from
		newBeam.Attachment1 = to
		newBeam.Color = ColorSequence.new(Color3.fromRGB(255, 240, 90))
		newBeam.LightEmission = 1
		newBeam.Width0 = 0.6
		newBeam.Width1 = 0.6
		newBeam.FaceCamera = true
		newBeam.Parent = from
		beam = newBeam
	end)
end

function Controllers.Start(tutorialLabel: TextLabel)
	watchPrompts()
	animateSlimes()
	listenKnockback()
	tutorial(tutorialLabel)
end

return Controllers
