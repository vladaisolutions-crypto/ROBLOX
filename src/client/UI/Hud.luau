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
}

function Hud.Create(screen: ScreenGui, menus: Menus)
	-- Cash
	local cashFrame = Kit.Frame(screen, UDim2.fromScale(0.22, 0.085), UDim2.fromScale(0.39, 0.015), Kit.Colors.Panel)
	Kit.Stroke(cashFrame, 3)
	local cashLabel = Kit.Label(cashFrame, "$0", UDim2.fromScale(0.94, 0.62), UDim2.fromScale(0.03, 0.04), Kit.Colors.Gold)
	local incomeLabel = Kit.Label(cashFrame, "+$0/s", UDim2.fromScale(0.94, 0.32), UDim2.fromScale(0.03, 0.64), Color3.fromRGB(140, 255, 140))

	-- Event banner under the cash
	local banner = Kit.Label(screen, "", UDim2.fromScale(0.4, 0.035), UDim2.fromScale(0.3, 0.105), Color3.fromRGB(150, 230, 255))

	-- Left menu buttons
	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.fromScale(0.075, 0.7)
	left.Position = UDim2.fromScale(0.01, 0.2)
	left.Parent = screen
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0.015, 0)
	list.Parent = left

	local dailyDot: Frame? = nil
	local function menuButton(text: string, color: Color3, onClick: () -> ()): TextButton
		local button = Kit.Button(left, text, UDim2.fromScale(1, 0.14), nil, color, onClick)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1.25
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
	menuButton("🎟️\nCodes", Color3.fromRGB(255, 150, 60), function()
		Kit.Toggle(menus.Codes)
	end)
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
	local lockButton = Kit.Button(screen, "🔒 LOCK BASE", UDim2.fromScale(0.2, 0.07), UDim2.fromScale(0.4, 0.75), Kit.Colors.Red, function()
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
	end)

	-- Playtime gift (right side)
	local giftButton = Kit.Button(screen, "🎁", UDim2.fromScale(0.09, 0.08), UDim2.fromScale(0.9, 0.3), Kit.Colors.Purple, function()
		Store.Action("ClaimGift")
	end)

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

	local announce = Kit.Label(screen, "", UDim2.fromScale(0.7, 0.06), UDim2.fromScale(0.15, 0.16))
	announce.TextTransparency = 1
	local announceId = 0

	local KIND_COLORS: { [string]: Color3 } = {
		Info = Kit.Colors.PanelLight,
		Good = Color3.fromRGB(40, 140, 70),
		Bad = Color3.fromRGB(160, 40, 55),
		Money = Color3.fromRGB(150, 115, 20),
	}
	Remotes.Get("Notify").OnClientEvent:Connect(function(text: string, kind: string)
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
		announceId += 1
		local id = announceId
		announce.Text = text
		announce.TextColor3 = color
		announce.TextTransparency = 0
		Kit.Pop(announce)
		task.delay(4, function()
			if announceId == id then
				TweenService:Create(announce, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
		end)
	end)

	-- Cash "+$X" popups when cash jumps (collecting, rewards)
	local lastCash: number? = nil
	local function cashPopup(amount: number)
		local pop = Kit.Label(screen, "+" .. Format.Cash(amount), UDim2.fromScale(0.16, 0.04), UDim2.fromScale(0.42, 0.1), Kit.Colors.Gold)
		TweenService:Create(pop, TweenInfo.new(1), { Position = UDim2.fromScale(0.42, 0.06), TextTransparency = 1 }):Play()
		task.delay(1, function()
			pop:Destroy()
		end)
	end

	local function refreshState()
		local cash = Store.Get("Cash", 0)
		local income = Store.Get("Income", 0)
		cashLabel.Text = Format.Cash(cash)
		incomeLabel.Text = "+" .. Format.Cash(income) .. "/s  ·  x" .. string.format("%.2f", Store.Get("Multiplier", 1)):gsub("%.?0+$", "")
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
				table.insert(parts, "🍀 Server Luck x" .. tostring(events.LuckMultiplier) .. " " .. Format.Time(events.LuckEndsAt - t))
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
