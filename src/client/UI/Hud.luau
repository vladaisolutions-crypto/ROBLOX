--!strict
-- Always-visible HUD: cash, income, event timers, menu buttons, base lock,
-- playtime gift, toasts and announcements.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Music = require(script.Parent.Parent.Music)
local Store = require(script.Parent.Parent.Store)
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer

local Hud = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

export type Menus = {
	Shop: Kit.Panel,
	Index: Kit.Panel,
	Rebirth: Kit.Panel,
	Daily: Kit.Panel,
	Codes: Kit.Panel,
	Quests: Kit.Panel,
}

function Hud.Create(screen: ScreenGui, menus: Menus)
	-- Cash
	local cashFrame = Kit.Frame(screen, UDim2.fromScale(0.22, 0.085), UDim2.fromScale(0.39, 0.015), Kit.Colors.Panel)
	Kit.Stroke(cashFrame, 3)
	local cashLabel =
		Kit.Label(cashFrame, "$0", UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.03, 0.04), Kit.Colors.Gold)
	local incomeLabel = Kit.Label(
		cashFrame,
		"+$0/s",
		UDim2.fromScale(0.94, 0.32),
		UDim2.fromScale(0.03, 0.64),
		Color3.fromRGB(140, 255, 140)
	)

	-- Event banner under the cash
	local banner =
		Kit.Label(screen, "", UDim2.fromScale(0.4, 0.035), UDim2.fromScale(0.3, 0.105), Color3.fromRGB(150, 230, 255))

	-- Left menu buttons
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.fromScale(0.1, 0.68)
	left.Position = UDim2.fromScale(0.01, 0.18)
	left.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.015, 0)
	list.Parent = left

	local dailyDot: Frame? = nil
	local function menuButton(text: string, color: Color3, onClick: () -> ()): TextButton
		local button = Kit.Button(left, text, UDim2.fromScale(1, 0.125), nil, color, onClick)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1.25
		ratio.DominantAxis = Enum.DominantAxis.Height -- 7 buttons always fit the menu's height
		ratio.Parent = button
		return button
	end
	menuButton("🛒\nShop", Kit.Colors.Gold, function()
		Kit.Toggle(menus.Shop)
	end)
	menuButton("📖\nIndex", Kit.Colors.Blue, function()
		Kit.Toggle(menus.Index)
	end)
	menuButton("✨\nRebirth", Kit.Colors.Purple, function()
		Kit.Toggle(menus.Rebirth)
	end)
	local dailyButton = menuButton("📅\nDaily", Kit.Colors.Green, function()
		Kit.Toggle(menus.Daily)
	end)
	local questButton = menuButton("🎯\nQuests", Color3.fromRGB(255, 170, 60), function()
		Kit.Toggle(menus.Quests)
	end)
	local questDot = Kit.Frame(questButton, UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.8, -0.1), Kit.Colors.Red)
	Kit.Corner(questDot, 100)
	questDot.Visible = false
	Store.Changed:Connect(function(section: string)
		if section ~= "State" then
			return
		end
		local ready = false
		for _, quest in Store.Get("Quests", {}) do
			if quest.Progress >= quest.Goal and not quest.Claimed then
				ready = true
			end
		end
		questDot.Visible = ready
	end)
	menuButton("🎟️\nCodes", Color3.fromRGB(255, 150, 60), function()
		Kit.Toggle(menus.Codes)
	end)
	-- Music on/off, small in the bottom-left corner.
	local musicButton: TextButton
	musicButton = Kit.Button(
		screen,
		"🎵",
		UDim2.fromOffset(40, 40),
		UDim2.new(0.01, 0, 0.18, -48),
		Kit.Colors.Purple,
		function()
			Music.SetEnabled(not Music.IsEnabled())
			musicButton.Text = if Music.IsEnabled() then "🎵" else "🔇"
		end
	)
	menuButton("👥\nInvite", Color3.fromRGB(255, 120, 170), function()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end)
	local dot = Kit.Frame(dailyButton, UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.8, -0.1), Kit.Colors.Red)
	Kit.Corner(dot, 100)
	dot.Visible = false
	dailyDot = dot

	-- Lock button (bottom centre, above the backpack hotbar)
	local lockButton = Kit.Button(
		screen,
		"🔒 LOCK BASE",
		UDim2.fromScale(0.2, 0.07),
		UDim2.fromScale(0.4, 0.75),
		Kit.Colors.Red,
		function()
			local readyAt = Store.Get("LockReadyAt", 0)
			local endsAt = Store.Get("LockEndsAt", 0)
			local t = now()
			if t >= endsAt and t < readyAt then
				local product = Monetization.ProductByKey.InstantLock
				if product and product.Id ~= 0 then
					MarketplaceService:PromptProductPurchase(player, product.Id)
					return
				end
			end
			Store.Action("Lock")
		end
	)

	-- Playtime gift (right side)
	local giftButton = Kit.Button(
		screen,
		"🎁",
		UDim2.fromScale(0.09, 0.08),
		UDim2.fromScale(0.9, 0.33), -- below the offer card (y 0.2-0.31)
		Kit.Colors.Purple,
		function()
			Store.Action("ClaimGift")
		end
	)

	-- Toasts (right, under gift) and announcements (centre-top)
	local toasts = Instance.new("Frame")
	toasts.BackgroundTransparency = 1
	toasts.Size = UDim2.fromScale(0.3, 0.4)
	toasts.Position = UDim2.fromScale(0.69, 0.42)
	toasts.Parent = screen
	local toastList = Instance.new("UIListLayout")
	toastList.Padding = UDim.new(0, 6)
	toastList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastList.SortOrder = Enum.SortOrder.LayoutOrder
	toastList.Parent = toasts
	local toastCount = 0

	-- Announcement banner: a dark pill that drops in from the top with a
	-- bounce, a shine sweeps across the text, then it slides back up.
	-- Announcements queue up so none are lost or overwritten.
	local announceQueue: { { Text: string, Color: Color3 } } = {}
	local announcing = false
	local function showAnnouncement(text: string, color: Color3)
		local holder = Instance.new("Frame")
		holder.Name = "Announcement"
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, -80)
		holder.Size = UDim2.fromOffset(0, 46)
		holder.AutomaticSize = Enum.AutomaticSize.X
		holder.BackgroundColor3 = Color3.fromRGB(18, 14, 28)
		holder.BackgroundTransparency = 0.15
		holder.ZIndex = 50
		holder.Parent = screen
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = holder
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 26)
		padding.PaddingRight = UDim.new(0, 26)
		padding.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = color
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = holder
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = holder

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromScale(0, 1)
		label.Font = Kit.Font
		label.Text = text
		label.TextSize = 26
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = 51
		label.Parent = holder
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 2
		textStroke.Color = Color3.new(0, 0, 0)
		textStroke.Parent = label
		-- Text tinted in the rarity colour, with a white shine band.
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color),
			ColorSequenceKeypoint.new(0.42, color),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.58, color),
			ColorSequenceKeypoint.new(1, color),
		})
		shine.Offset = Vector2.new(-1, 0)
		shine.Parent = label

		local inInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(holder, inInfo, { Position = UDim2.new(0.5, 0, 0.15, 0) }):Play()
		TweenService:Create(scale, inInfo, { Scale = 1 }):Play()
		task.delay(0.35, function()
			TweenService:Create(
				shine,
				TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Offset = Vector2.new(1, 0) }
			):Play()
		end)
		-- Gentle pulse of the border while it is up.
		TweenService:Create(
			stroke,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Thickness = 5 }
		):Play()

		task.wait(3.2)
		local outInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		TweenService:Create(holder, outInfo, { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		TweenService:Create(scale, outInfo, { Scale = 0.7 }):Play()
		task.wait(0.35)
		holder:Destroy()
	end
	local function pumpAnnouncements()
		if announcing then
			return
		end
		announcing = true
		task.spawn(function()
			while #announceQueue > 0 do
				local item = table.remove(announceQueue, 1) :: { Text: string, Color: Color3 }
				showAnnouncement(item.Text, item.Color)
			end
			announcing = false
		end)
	end

	local KIND_COLORS: { [string]: Color3 } = {
		Info = Kit.Colors.PanelLight,
		Good = Color3.fromRGB(40, 140, 70),
		Bad = Color3.fromRGB(160, 40, 55),
		Money = Color3.fromRGB(150, 115, 20),
	}
	local Sounds = require(game:GetService("ReplicatedStorage").Shared.Config.Sounds).Ids
	local function uiSound(id: string, volume: number)
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume
		sound.Parent = game:GetService("SoundService")
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		sound:Play()
		task.delay(6, function()
			sound:Destroy()
		end)
	end
	local NOTIFY_SOUNDS: { [string]: string } = {
		Money = Sounds.Coins,
		Good = Sounds.Reward,
		Info = Sounds.Pop,
	}
	Remotes.Get("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		local sound = NOTIFY_SOUNDS[kind]
		if sound then
			uiSound(sound, if kind == "Info" then 0.4 else 0.6)
		end
		toastCount += 1
		local toast = Kit.Frame(toasts, UDim2.new(1, 0, 0, 40), nil, KIND_COLORS[kind] or KIND_COLORS.Info)
		toast.LayoutOrder = -toastCount
		Kit.Stroke(toast, 2)
		Kit.Label(toast, text, UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
		task.delay(4, function()
			toast:Destroy()
		end)
		-- Keep at most 5 on screen; newest have the lowest LayoutOrder.
		for _, child in toasts:GetChildren() do
			if child:IsA("Frame") and child.LayoutOrder >= -toastCount + 5 then
				child:Destroy()
			end
		end
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(function(text: string, color: Color3)
		-- Keep the queue short so a burst never lags far behind.
		if #announceQueue >= 3 then
			table.remove(announceQueue, 1)
		end
		table.insert(announceQueue, { Text = text, Color = color })
		uiSound(Sounds.Fanfare, 0.5)
		pumpAnnouncements()
	end)

	-- Cash "+$X" popups when cash jumps (collecting, rewards)
	local lastCash: number? = nil
	local function cashPopup(amount: number)
		local pop = Kit.Label(
			screen,
			"+" .. Format.Cash(amount),
			UDim2.fromScale(0.16, 0.04),
			UDim2.fromScale(0.42, 0.1),
			Kit.Colors.Gold
		)
		TweenService:Create(pop, TweenInfo.new(1), { Position = UDim2.fromScale(0.42, 0.06), TextTransparency = 1 })
			:Play()
		task.delay(1, function()
			pop:Destroy()
		end)
	end

	local function refreshState()
		local cash = Store.Get("Cash", 0)
		local income = Store.Get("Income", 0)
		cashLabel.Text = Format.Cash(cash)
		incomeLabel.Text = "+"
			.. Format.Cash(income)
			.. "/s  ·  x"
			.. string.format("%.2f", Store.Get("Multiplier", 1)):gsub("%.?0+$", "")
		if lastCash and cash - lastCash > math.max(income * 1.5, 1) then
			cashPopup(cash - lastCash)
			Kit.Pop(cashFrame)
		end
		lastCash = cash
		if dailyDot then
			dailyDot.Visible = Store.Get("DailyCanClaim", false)
		end
	end

	-- Timers tick every frame-ish; cheap string updates only.
	task.spawn(function()
		while true do
			local t = now()
			-- Lock button
			local endsAt = Store.Get("LockEndsAt", 0)
			local readyAt = Store.Get("LockReadyAt", 0)
			if t < endsAt then
				lockButton.Text = "🔒 LOCKED " .. Format.Time(endsAt - t)
				lockButton.BackgroundColor3 = Kit.Colors.Green
			elseif t < readyAt then
				local instant = Monetization.ProductByKey.InstantLock
				local suffix = if instant and instant.Id ~= 0 then "  ⚡ Lock now" else ""
				lockButton.Text = "⏳ " .. Format.Time(readyAt - t) .. suffix
				lockButton.BackgroundColor3 = Kit.Colors.Grey
			else
				lockButton.Text = "🔒 LOCK BASE"
				lockButton.BackgroundColor3 = Kit.Colors.Red
			end

			-- Gift button
			local claimed = Store.Get("GiftsClaimed", 0)
			local nextMinutes = Events.GiftMinutes[claimed + 1]
			local start = Store.Get("SessionStart", t)
			if not nextMinutes then
				giftButton.Visible = false
			else
				giftButton.Visible = true
				local remaining = start + nextMinutes * 60 - t
				if remaining <= 0 then
					giftButton.Text = "🎁 CLAIM!"
					giftButton.BackgroundColor3 = Kit.Colors.Green
				else
					giftButton.Text = "🎁 " .. Format.Time(remaining)
					giftButton.BackgroundColor3 = Kit.Colors.Purple
				end
			end

			-- Event banner
			local events = Store.Events
			local parts = {}
			if events.LuckEndsAt and t < events.LuckEndsAt then
				table.insert(
					parts,
					"🍀 Server Luck x" .. tostring(events.LuckMultiplier) .. " " .. Format.Time(events.LuckEndsAt - t)
				)
			end
			if events.RainEndsAt and events.NextRainAt then
				if events.RainActive and t < events.RainEndsAt then
					table.insert(parts, "🌧️ SLIME RAIN " .. Format.Time(events.RainEndsAt - t))
				else
					table.insert(parts, "🌧️ Slime Rain in " .. Format.Time(events.NextRainAt - t))
				end
			end
			if events.Seasonal then
				table.insert(parts, events.Seasonal.Name)
			end
			banner.Text = table.concat(parts, "   ·   ")
			task.wait(0.25)
		end
	end)

	Store.Changed:Connect(function(section: string)
		if section == "State" then
			refreshState()
		end
	end)
	refreshState()
end

return Hud
