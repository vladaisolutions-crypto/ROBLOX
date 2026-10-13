--!strict
-- Menu panels: Shop, Index, Rebirth and Daily rewards.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Config.Economy)
local Events = require(Shared.Config.Events)
local Monetization = require(Shared.Config.Monetization)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Slimes = require(Shared.Config.Slimes)
local Format = require(Shared.Util.Format)

local Store = require(script.Parent.Parent.Store)
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer

local Panels = {}

local function scrollGrid(parent: Instance, cellSize: UDim2, columns: number?): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.Parent = parent
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	if columns then
		grid.FillDirectionMaxCells = columns
	end
	grid.Parent = scroll
	return scroll
end

-- Real Robux price from Roblox, falling back to the suggested price.
local priceCache: { [string]: number } = {}
local function robuxPrice(id: number, isPass: boolean, fallback: number): number
	local cacheKey = (if isPass then "p" else "d") .. id
	local cached = priceCache[cacheKey]
	if cached then
		return cached
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(
			id,
			if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
	end)
	local price = if ok
			and type(info) == "table"
			and type(info.PriceInRobux) == "number"
		then info.PriceInRobux
		else fallback
	priceCache[cacheKey] = price
	return price
end

function Panels.Shop(screen: ScreenGui): Kit.Panel
	local panel = Kit.Panel(screen, "🛒 Shop", Kit.Colors.Gold)
	local scroll = scrollGrid(panel.Body, UDim2.new(0.32, -6, 0, 150))
	local passButtons: { [string]: TextButton } = {}

	local function card(order: number, icon: string, name: string, description: string, color: Color3): Frame
		local frame = Kit.Frame(scroll, UDim2.new(), nil, Kit.Colors.PanelLight)
		frame.LayoutOrder = order
		Kit.Stroke(frame, 2, color)
		Kit.Label(frame, icon .. " " .. name, UDim2.new(0.92, 0, 0, 30), UDim2.new(0.04, 0, 0, 6), color)
		local desc =
			Kit.Label(frame, description, UDim2.new(0.92, 0, 0, 48), UDim2.new(0.04, 0, 0, 40), Kit.Colors.Muted)
		desc.TextWrapped = true
		return frame
	end

	local order = 0
	for _, pass in Monetization.Passes do
		order += 1
		local frame = card(order, pass.Icon, pass.Name, pass.Description, Kit.Colors.Gold)
		local button = Kit.Button(
			frame,
			if pass.Id == 0 then "Coming soon" else "R$ " .. pass.SuggestedPrice,
			UDim2.new(0.8, 0, 0, 40),
			UDim2.new(0.1, 0, 1, -48),
			if pass.Id == 0 then Kit.Colors.Grey else Kit.Colors.Green,
			function()
				if pass.Id ~= 0 and not Store.HasPass(pass.Key) then
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				end
			end
		)
		passButtons[pass.Key] = button
		if pass.Id ~= 0 then
			task.spawn(function()
				local price = robuxPrice(pass.Id, true, pass.SuggestedPrice)
				if not Store.HasPass(pass.Key) then
					button.Text = "R$ " .. price
				end
			end)
		end
	end
	-- Bundles go first; the Starter Pack hides once bought, the Halloween
	-- Bundle once the event is over.
	local bundles: { { Frame: Frame, Product: Monetization.Product } } = {}
	local function refreshBundles()
		local seasonal = Store.Events.Seasonal
		for _, entry in bundles do
			local p = entry.Product
			local visible = true
			if p.OneTime and Store.Get("StarterBought", false) then
				visible = false
			end
			if p.Event and not (type(seasonal) == "table" and seasonal.Id == p.Event) then
				visible = false
			end
			entry.Frame.Visible = visible
		end
	end
	for _, product in Monetization.Products do
		if product.Shop then
			order += 1
			local bundle = product.Kind == "Bundle"
			local frame = card(
				if bundle then order - 1000 else order,
				product.Icon,
				product.Name,
				product.Description,
				if bundle then Kit.Colors.Gold else Kit.Colors.Blue
			)
			if bundle then
				table.insert(bundles, { Frame = frame, Product = product })
			end
			local button = Kit.Button(
				frame,
				if product.Id == 0 then "Coming soon" else "R$ " .. product.SuggestedPrice,
				UDim2.new(0.8, 0, 0, 40),
				UDim2.new(0.1, 0, 1, -48),
				if product.Id == 0 then Kit.Colors.Grey else Kit.Colors.Blue,
				function()
					if product.Id ~= 0 then
						MarketplaceService:PromptProductPurchase(player, product.Id)
					end
				end
			)
			if product.Id ~= 0 then
				task.spawn(function()
					button.Text = "R$ " .. robuxPrice(product.Id, false, product.SuggestedPrice)
				end)
			end
		end
	end

	refreshBundles()
	Store.Changed:Connect(function(section: string)
		if section == "Events" or section == "State" then
			refreshBundles()
		end
		if section ~= "State" then
			return
		end
		for key, button in passButtons do
			if Store.HasPass(key) then
				button.Text = "Owned ✓"
				button.BackgroundColor3 = Kit.Colors.Grey
			end
		end
	end)
	return panel
end

function Panels.Index(screen: ScreenGui): Kit.Panel
	local panel = Kit.Panel(screen, "📖 Slime Index", Kit.Colors.Blue)
	local header = Kit.Label(panel.Body, "", UDim2.new(1, 0, 0, 30), nil, Kit.Colors.Gold)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, -38)
	holder.Position = UDim2.fromOffset(0, 38)
	holder.Parent = panel.Body
	local scroll = scrollGrid(holder, UDim2.new(0.19, -6, 0, 110))

	type Cell = { Name: TextLabel, Dot: Frame, Mutations: TextLabel, Def: Slimes.SlimeDef }
	local cells: { Cell } = {}
	local sorted = table.clone(Slimes.List)
	table.sort(sorted, function(a, b)
		local ra, rb = Rarities.ByName[a.Rarity].Order, Rarities.ByName[b.Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return a.Price < b.Price
	end)
	for i, def in sorted do
		local rarity = Rarities.ByName[def.Rarity]
		local frame = Kit.Frame(scroll, UDim2.new(), nil, Kit.Colors.PanelLight)
		frame.LayoutOrder = i
		Kit.Stroke(frame, 2, rarity.Color)
		local dot = Kit.Frame(frame, UDim2.fromOffset(38, 32), UDim2.new(0.5, -19, 0, 8), def.Color)
		Kit.Corner(dot, 100)
		local name = Kit.Label(frame, "???", UDim2.new(0.9, 0, 0, 22), UDim2.new(0.05, 0, 0, 44))
		Kit.Label(
			frame,
			def.Rarity .. (if def.Event then " · " .. def.Event else ""),
			UDim2.new(0.9, 0, 0, 16),
			UDim2.new(0.05, 0, 0, 66),
			rarity.Color
		)
		local mutations = Kit.Label(frame, "", UDim2.new(0.9, 0, 0, 16), UDim2.new(0.05, 0, 0, 86), Kit.Colors.Gold)
		table.insert(cells, { Name = name, Dot = dot, Mutations = mutations, Def = def })
	end

	local function refresh()
		local found = 0
		for _, cell in cells do
			local entry = Store.Index[cell.Def.Id]
			if entry then
				found += 1
				cell.Name.Text = cell.Def.Name
				cell.Dot.BackgroundColor3 = cell.Def.Color
				local owned = {}
				for _, mutation in Mutations.List do
					if entry[mutation.Id] then
						table.insert(owned, string.sub(mutation.Id, 1, 1))
					end
				end
				cell.Mutations.Text = table.concat(owned, " ")
			else
				cell.Name.Text = "???"
				cell.Dot.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
				cell.Mutations.Text = ""
			end
		end
		header.Text = string.format(
			"Discovered %d / %d  ·  +%d%% cash forever",
			found,
			#cells,
			math.floor(found * Economy.IndexBonusPerSlime * 100 + 0.5)
		)
	end
	Store.Changed:Connect(function(section: string)
		if section == "Index" then
			refresh()
		end
	end)
	refresh()
	return panel
end

function Panels.Rebirth(screen: ScreenGui): Kit.Panel
	local panel = Kit.Panel(screen, "✨ Rebirth", Kit.Colors.Purple)
	local body = panel.Body
	local title = Kit.Label(body, "", UDim2.new(1, 0, 0.12, 0), UDim2.fromScale(0, 0.02), Kit.Colors.Gold)
	Kit.Label(
		body,
		"Rebirthing resets your cash but KEEPS your slimes.",
		UDim2.new(1, 0, 0.08, 0),
		UDim2.fromScale(0, 0.17),
		Kit.Colors.Muted
	)
	local rewards = Kit.Label(body, "", UDim2.new(1, 0, 0.1, 0), UDim2.fromScale(0, 0.3), Color3.fromRGB(150, 255, 150))
	local barBack = Kit.Frame(body, UDim2.fromScale(0.8, 0.09), UDim2.fromScale(0.1, 0.48), Kit.Colors.Stroke)
	local barFill = Kit.Frame(barBack, UDim2.fromScale(0, 1), nil, Kit.Colors.Purple)
	local barText = Kit.Label(barBack, "", UDim2.fromScale(1, 0.8), UDim2.fromScale(0, 0.1))
	barText.ZIndex = 2
	local button = Kit.Button(
		body,
		"REBIRTH",
		UDim2.fromScale(0.4, 0.14),
		UDim2.fromScale(0.3, 0.7),
		Kit.Colors.Grey,
		function()
			Store.Action("Rebirth")
		end
	)

	local function refresh()
		local rebirths = Store.Get("Rebirths", 0)
		local cost = Store.Get("RebirthCost", Economy.RebirthCost(0))
		local cash = Store.Get("Cash", 0)
		title.Text = "Rebirth " .. rebirths .. " → " .. rebirths + 1
		local slotText = if rebirths * Economy.SlotsPerRebirth < Economy.MaxRebirthSlots
			then " · +" .. Economy.SlotsPerRebirth .. " slots"
			else ""
		rewards.Text = "+" .. math.floor(Economy.RebirthMultiplier * 100) .. "% cash forever" .. slotText
		local progress = math.clamp(cash / cost, 0, 1)
		barFill.Size = UDim2.fromScale(progress, 1)
		barText.Text = Format.Cash(cash) .. " / " .. Format.Cash(cost)
		button.BackgroundColor3 = if progress >= 1 then Kit.Colors.Green else Kit.Colors.Grey
	end
	Store.Changed:Connect(function(section: string)
		if section == "State" and panel.IsOpen() then
			refresh()
		end
	end)
	panel.Frame:GetPropertyChangedSignal("Visible"):Connect(refresh)
	refresh()
	return panel
end

function Panels.Daily(screen: ScreenGui): Kit.Panel
	local panel = Kit.Panel(screen, "📅 Daily Rewards", Kit.Colors.Green)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 0.55)
	row.Position = UDim2.fromScale(0, 0.05)
	row.Parent = panel.Body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = row

	local tiles: { Frame } = {}
	for day = 1, 7 do
		local tile = Kit.Frame(row, UDim2.fromScale(0.133, 1), nil, Kit.Colors.PanelLight)
		Kit.Stroke(tile, 2)
		Kit.Label(tile, "Day " .. day, UDim2.fromScale(0.9, 0.2), UDim2.fromScale(0.05, 0.05))
		local reward = if day == 7
			then "💎\nEpic Slime\n+ cash"
			else "💰\n" .. Events.DailyIncomeMinutes[day] .. " min\nof cash"
		local label = Kit.Label(tile, reward, UDim2.fromScale(0.9, 0.65), UDim2.fromScale(0.05, 0.3), Kit.Colors.Gold)
		label.TextWrapped = true
		table.insert(tiles, tile)
	end
	local status = Kit.Label(panel.Body, "", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.64), Kit.Colors.Muted)
	local button = Kit.Button(
		panel.Body,
		"CLAIM",
		UDim2.fromScale(0.36, 0.16),
		UDim2.fromScale(0.32, 0.78),
		Kit.Colors.Green,
		function()
			Store.Action("ClaimDaily")
		end
	)

	local function refresh()
		local streak = Store.Get("DailyStreak", 1)
		local canClaim = Store.Get("DailyCanClaim", false)
		for day, tile in tiles do
			local claimedToday = not canClaim and day <= streak
			tile.BackgroundColor3 = if canClaim and day == streak
				then Kit.Colors.Green
				elseif claimedToday or day < streak then Kit.Colors.Grey
				else Kit.Colors.PanelLight
		end
		button.Visible = canClaim
		if canClaim then
			status.Text = "Come back every day — missing a day resets your streak!"
		else
			status.Text = "Next reward in " .. Format.Time(Store.Get("DailyNextAt", 0) - workspace:GetServerTimeNow())
		end
	end
	Store.Changed:Connect(function(section: string)
		if section == "State" and panel.IsOpen() then
			refresh()
		end
	end)
	panel.Frame:GetPropertyChangedSignal("Visible"):Connect(refresh)
	refresh()
	return panel
end

function Panels.Codes(screen: ScreenGui): Kit.Panel
	local panel = Kit.Panel(screen, "🎟️ Codes", Color3.fromRGB(255, 120, 170))
	Kit.Label(
		panel.Body,
		"Follow the group for new codes!",
		UDim2.fromScale(1, 0.12),
		UDim2.fromScale(0, 0.08),
		Kit.Colors.Muted
	)
	local box = Instance.new("TextBox")
	box.Size = UDim2.fromScale(0.7, 0.18)
	box.Position = UDim2.fromScale(0.15, 0.32)
	box.BackgroundColor3 = Kit.Colors.PanelLight
	box.PlaceholderText = "Enter code"
	box.PlaceholderColor3 = Kit.Colors.Muted
	box.Text = ""
	box.Font = Kit.Font
	box.TextScaled = true
	box.TextColor3 = Kit.Colors.Text
	box.ClearTextOnFocus = false
	box.Parent = panel.Body
	Kit.Corner(box)
	Kit.Stroke(box, 2)
	local function submit()
		if box.Text ~= "" then
			Store.Action("Redeem", box.Text)
			box.Text = ""
		end
	end
	box.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			submit()
		end
	end)
	Kit.Button(panel.Body, "REDEEM", UDim2.fromScale(0.36, 0.16), UDim2.fromScale(0.32, 0.6), Kit.Colors.Green, submit)
	return panel
end

return Panels
