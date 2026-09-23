-- NinjaCoyoWardrobeUI (LocalScript in StarterPlayer > StarterPlayerScripts)
-- The Wardrobe Shrine window: ninja outfits, Coyo coats and boosts, with Equip and
-- Robux buy buttons. Opened from the WARDROBE button or at the shrine itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local Menus = require(ReplicatedStorage:WaitForChild("NinjaCoyoMenus"))
local Sounds = require(ReplicatedStorage:WaitForChild("NinjaCoyoSounds"))
local remotes = ReplicatedStorage:WaitForChild("NinjaCoyoRemotes")
local openEvent = remotes:WaitForChild("WardrobeOpen")
local stateEvent = remotes:WaitForChild("WardrobeState")
local equipFunction = remotes:WaitForChild("WardrobeEquip")
local getStateFunction = remotes:WaitForChild("WardrobeGetState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local WardrobeConfig = Config.Wardrobe

-- Colours
local COLOUR_PANEL = Color3.fromRGB(34, 28, 44)
local COLOUR_CARD = Color3.fromRGB(52, 44, 66)
local COLOUR_GOLD = Color3.fromRGB(255, 205, 60)
local COLOUR_WHITE = Color3.new(1, 1, 1)
local COLOUR_PURPLE = Color3.fromRGB(150, 80, 220)
local COLOUR_EQUIP = Color3.fromRGB(60, 180, 90)
local COLOUR_EQUIPPED = Color3.fromRGB(200, 150, 30)
local COLOUR_BUY = Color3.fromRGB(0, 170, 90)
local COLOUR_SOON = Color3.fromRGB(90, 84, 100)
local COLOUR_TAB = Color3.fromRGB(70, 60, 88)
local COLOUR_ERROR = Color3.fromRGB(200, 60, 60)

-- State (initialised up front)
local currentState = {}
currentState.Outfit = "Default"
currentState.Coat = "Coyote"
currentState.DogCoats = {}
currentState.PackSize = 1
local selectedDog = 1
local dogButtons = {}
currentState.OwnedOutfits = {}
currentState.OwnedCoats = {}
currentState.DoubleCoins = false
for _, outfitId in ipairs(WardrobeConfig.OutfitOrder) do
	currentState.OwnedOutfits[outfitId] = false
end
for _, coatId in ipairs(WardrobeConfig.CoatOrder) do
	currentState.OwnedCoats[coatId] = false
end
local cards = {}
local tabPages = {}
local tabButtons = {}
local priceByPass = {}
local isBusy = false

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent, thickness, colour)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = colour
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function makeLabel(parent, text, colour)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = colour
	label.TextScaled = true
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

local function makeButton(parent, text, colour)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = colour
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextColor3 = COLOUR_WHITE
	button.TextScaled = true
	button.TextStrokeTransparency = 0.6
	button.AutoButtonColor = true
	button.Parent = parent
	addCorner(button, 10)
	return button
end

----------------------------------------------------------------
-- Window
----------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NinjaCoyoWardrobe"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 21
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local wardrobeButton = makeButton(screenGui, "WARDROBE", COLOUR_PURPLE)
wardrobeButton.AnchorPoint = Vector2.new(0, 0.5)
wardrobeButton.Position = UDim2.new(0, 12, 0.5, 70)
wardrobeButton.Size = UDim2.new(0, 110, 0, 56)
addStroke(wardrobeButton, 3, COLOUR_WHITE)

local blocker = Instance.new("TextButton")
blocker.Size = UDim2.fromScale(1, 1)
blocker.Text = ""
blocker.BackgroundColor3 = Color3.new(0, 0, 0)
blocker.BackgroundTransparency = 0.65
blocker.AutoButtonColor = false
blocker.Active = true
blocker.Modal = true
blocker.Visible = false
blocker.ZIndex = 2
blocker.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "WardrobePanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.7, 0, 0.75, 0)
panel.BackgroundColor3 = COLOUR_PANEL
panel.Visible = false
panel.Parent = screenGui
panel.ZIndex = 3
panel.Active = true
addCorner(panel, 16)
addStroke(panel, 3, COLOUR_PURPLE)

local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MaxSize = Vector2.new(660, 540)
panelLimit.MinSize = Vector2.new(320, 320)
panelLimit.Parent = panel

local function layoutWardrobe()
	local size = screenGui.AbsoluteSize
	wardrobeButton.AnchorPoint = Vector2.zero
	wardrobeButton.Position = UDim2.fromOffset(8, 128)
	wardrobeButton.Size = UDim2.fromOffset(80, 44)
	wardrobeButton.TextScaled = false
	wardrobeButton.TextSize = 12
	panelLimit.MinSize = Vector2.zero
	panel.Size = UDim2.fromOffset(math.min(620, size.X - 24), math.min(500, size.Y - 24))
end
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutWardrobe)
layoutWardrobe()

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local title = makeLabel(panel, "Dressing House", COLOUR_GOLD)
title.Position = UDim2.new(0, 16, 0, 10)
title.Size = UDim2.new(1, -80, 0, 40)
title.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = makeButton(panel, "X", COLOUR_ERROR)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.new(0, 40, 0, 40)

local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Position = UDim2.new(0, 12, 0, 58)
tabRow.Size = UDim2.new(1, -24, 0, 38)
tabRow.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabRow

local function createPage(pageName)
	local page = Instance.new("ScrollingFrame")
	page.Name = pageName
	page.Position = UDim2.new(0, 12, 0, 106)
	page.Size = UDim2.new(1, -24, 1, -118)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 6
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 180, 0, 224)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = page

	tabPages[pageName] = page
	return page
end

local function showTab(pageName)
	for _, button in ipairs(dogButtons) do button.Visible = pageName == "Coyo" end
	for name, page in pairs(tabPages) do
		page.Visible = name == pageName
		local tabButton = tabButtons[name]
		if name == pageName then
			tabButton.BackgroundColor3 = COLOUR_PURPLE
		else
			tabButton.BackgroundColor3 = COLOUR_TAB
		end
	end
end

local function createTabButton(pageName, label, order)
	local tabButton = makeButton(tabRow, label, COLOUR_TAB)
	tabButton.LayoutOrder = order
		tabButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	tabButton.Activated:Connect(function()
		Sounds.Play("Click", 1, 1)
		showTab(pageName)
	end)
	tabButtons[pageName] = tabButton
end

----------------------------------------------------------------
-- Cards
----------------------------------------------------------------

local function refreshCards()
	selectedDog = math.min(selectedDog, currentState.PackSize or 1)
	for index, button in ipairs(dogButtons) do
		local unlocked = index <= (currentState.PackSize or 1)
		button.Text = Config.CoyoPackNames[index] .. (unlocked and "" or " (locked)")
		button.BackgroundColor3 = index == selectedDog and COLOUR_PURPLE or COLOUR_TAB
		button.AutoButtonColor = unlocked
	end
	for _, card in pairs(cards) do
		local owned = false
		local equipped = false
		if card.Kind == "Outfit" then
			owned = currentState.OwnedOutfits[card.ItemId] == true
			equipped = currentState.Outfit == card.ItemId
		elseif card.Kind == "Coat" then
			owned = currentState.OwnedCoats[card.ItemId] == true
			equipped = ((currentState.DogCoats or {})[tostring(selectedDog)] or currentState.Coat) == card.ItemId
		elseif card.Kind == "Boost" then
			owned = (card.PackSize ~= nil and (currentState.PackSize or 1) >= card.PackSize)
			or (card.ItemId == "GoldSword" and currentState.GoldSword == true)
			or (card.ItemId == "DoubleCoins" and currentState.DoubleCoins == true)
			equipped = owned
		end

		if equipped then
			card.Button.BackgroundColor3 = COLOUR_EQUIPPED
			if card.Kind == "Boost" then
				card.Button.Text = "OWNED"
			else
				card.Button.Text = "EQUIPPED"
			end
		elseif owned then
			card.Button.BackgroundColor3 = COLOUR_EQUIP
			card.Button.Text = "EQUIP"
		elseif card.PassId ~= 0 then
			card.Button.BackgroundColor3 = COLOUR_BUY
			local price = priceByPass[card.PassId]
			if price ~= nil then
				card.Button.Text = "R$ " .. price
			else
				card.Button.Text = "BUY"
			end
		else
			card.Button.BackgroundColor3 = COLOUR_SOON
			card.Button.Text = card.UnlockText or "SOON"
		end
	end
end

local function applyState(newState)
	if type(newState) ~= "table" then
		return
	end
	currentState = newState
	refreshCards()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who)
	if who == player then Menus.Set("Purchase", false) end
end)

local function onCardClicked(card)
	if isBusy then
		return
	end
	Sounds.Play("Click", 1, 1)

	local owned = false
	if card.Kind == "Outfit" then
		owned = currentState.OwnedOutfits[card.ItemId] == true
	elseif card.Kind == "Coat" then
		owned = currentState.OwnedCoats[card.ItemId] == true
	elseif card.Kind == "Boost" then
		owned = (card.PackSize ~= nil and (currentState.PackSize or 1) >= card.PackSize)
			or (card.ItemId == "GoldSword" and currentState.GoldSword == true)
			or (card.ItemId == "DoubleCoins" and currentState.DoubleCoins == true)
	end

	if owned then
		if card.Kind == "Boost" then
			return
		end
		isBusy = true
		local callOk, success, message = pcall(function()
			return equipFunction:InvokeServer(card.Kind, card.ItemId, selectedDog)
		end)
		isBusy = false
		if callOk == false or success ~= true then
			card.Button.Text = tostring(message)
			card.Button.BackgroundColor3 = COLOUR_ERROR
			task.delay(1, refreshCards)
		end
		return
	end

	if card.PassId ~= 0 then
		Menus.Set("Purchase", true)
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, card.PassId) end)
		if not ok then Menus.Set("Purchase", false) end
	end
end

local function createCard(page, kind, itemId, displayName, passId, swatchColours, order)
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = itemId
	cardFrame.LayoutOrder = order
	cardFrame.BackgroundColor3 = COLOUR_CARD
	cardFrame.Parent = page
	addCorner(cardFrame, 12)

	-- Small 3D mannequins make the clothes and dog colours easier to recognise.
	local swatch = Instance.new("Frame")
	swatch.Position = UDim2.new(0, 10, 0, 10)
	swatch.Size = UDim2.new(1, -20, 0, 90)
	swatch.BackgroundTransparency = 1
	swatch.ClipsDescendants = true
	swatch.Parent = cardFrame
	addCorner(swatch, 10)

	local preview = Instance.new("ViewportFrame")
	preview.Size, preview.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	preview.Ambient, preview.LightColor = Color3.fromRGB(180, 180, 190), Color3.new(1, 1, 1)
	preview.Parent = swatch
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(5, 3, -7), Vector3.new(0, 0.3, 0))
	camera.FieldOfView, camera.Parent, preview.CurrentCamera = 40, preview, camera
	local function previewPart(size, position, colour, material)
		local p = Instance.new("Part")
		p.Size, p.Position, p.Color, p.Material = size, position, colour, material or Enum.Material.Fabric
		p.Anchored, p.Parent = true, preview
		return p
	end
	if kind == "Coat" then
		previewPart(Vector3.new(1.3, 1.1, 2.4), Vector3.zero, swatchColours[1])
		previewPart(Vector3.new(1.1, 1, 1), Vector3.new(0, 0.6, -1.4), swatchColours[1])
		previewPart(Vector3.new(0.7, 0.5, 0.7), Vector3.new(0, 0.3, -2), swatchColours[3])
		previewPart(Vector3.new(0.25, 0.2, 0.15), Vector3.new(0, 0.45, -2.4), Color3.new(0.05, 0.05, 0.05))
		for _, side in ipairs({ -1, 1 }) do
			previewPart(Vector3.new(0.3, 0.7, 0.3), Vector3.new(side * 0.4, 1.3, -1.3), swatchColours[2])
			for _, z in ipairs({ -0.8, 0.8 }) do
				previewPart(Vector3.new(0.3, 0.8, 0.3), Vector3.new(side * 0.4, -0.8, z), swatchColours[1])
			end
		end
		local shape = WardrobeConfig.Coats[itemId].Shape
		local tail = previewPart(shape == "Shiba" and Vector3.new(0.8, 0.8, 0.8) or Vector3.new(0.6, 0.6, 1.5), Vector3.new(0, 0.5, 1.5), swatchColours[2])
		tail.Shape = Enum.PartType.Ball
		if shape == "Wolf" then
			previewPart(Vector3.new(1.6, 0.6, 0.7), Vector3.new(0, 0.3, -1.1), swatchColours[3])
		end
	elseif kind == "Outfit" then
		previewPart(Vector3.new(1.7, 1.8, 0.9), Vector3.zero, swatchColours[1])
		previewPart(Vector3.new(1, 1, 1), Vector3.new(0, 1.4, 0), Color3.fromRGB(221, 187, 150))
		previewPart(Vector3.new(1.05, 0.3, 1.05), Vector3.new(0, 1.65, 0), swatchColours[2])
		previewPart(Vector3.new(1.75, 0.25, 1), Vector3.new(0, -0.65, 0), swatchColours[3])
		for _, side in ipairs({ -1, 1 }) do
			previewPart(Vector3.new(0.55, 1.6, 0.7), Vector3.new(side * 1.15, 0, 0), swatchColours[1])
			previewPart(Vector3.new(0.65, 1.5, 0.7), Vector3.new(side * 0.5, -1.5, 0), swatchColours[1])
			previewPart(Vector3.new(0.45, 0.5, 0.25), Vector3.new(side * 0.5, -0.1, -0.58), swatchColours[2])
			previewPart(Vector3.new(0.55, 0.1, 0.3), Vector3.new(side * 0.5, 0.15, -0.58), swatchColours[3])
		end
	elseif string.sub(itemId, 1, 4) == "Pack" then
		local count = tonumber(string.sub(itemId, 5)) or 2
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 1.3
			previewPart(Vector3.new(1, 0.8, 1.6), Vector3.new(x, 0, 0), Color3.fromRGB(196, 150, 96))
			previewPart(Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, 0.5, -0.9), Color3.fromRGB(196, 150, 96))
			previewPart(Vector3.new(0.85, 0.2, 0.85), Vector3.new(x, 0.7, -0.9), Color3.fromRGB(200, 40, 55))
		end
		camera.CFrame = CFrame.lookAt(Vector3.new(6, 4, -10), Vector3.zero)
	elseif itemId == "GoldSword" then
		previewPart(Vector3.new(0.3, 3.4, 0.45), Vector3.new(0, 0.7, 0), COLOUR_GOLD, Enum.Material.Neon)
		previewPart(Vector3.new(1.3, 0.2, 0.7), Vector3.new(0, -1, 0), COLOUR_GOLD, Enum.Material.Metal)
		previewPart(Vector3.new(0.35, 1, 0.35), Vector3.new(0, -1.6, 0), Color3.fromRGB(100, 25, 25))
	else
		local coin = previewPart(Vector3.new(0.3, 3, 3), Vector3.zero, COLOUR_GOLD, Enum.Material.Metal)
		coin.Shape = Enum.PartType.Cylinder
	end

	local nameLabel = makeLabel(cardFrame, displayName, COLOUR_WHITE)
	nameLabel.Position = UDim2.new(0, 10, 0, 108)
	nameLabel.Size = UDim2.new(1, -20, 0, 30)

	local button = makeButton(cardFrame, "...", COLOUR_SOON)
	button.Position = UDim2.new(0, 10, 1, -54)
	button.Size = UDim2.new(1, -20, 0, 44)

	local card = {}
	card.Kind = kind
	card.ItemId = itemId
	card.PassId = passId
	card.PackSize = string.sub(itemId, 1, 4) == "Pack" and tonumber(string.sub(itemId, 5)) or nil
	card.Button = button
	local info = kind == "Coat" and WardrobeConfig.Coats[itemId] or kind == "Outfit" and WardrobeConfig.Outfits[itemId]
	if info and info.RequiredUpgrade then
		card.UnlockText = Config.Upgrades[info.RequiredUpgrade].DisplayName .. " Lv " .. info.RequiredLevel
	end
	local detail = makeLabel(cardFrame, card.UnlockText or (card.PackSize and (card.PackSize .. " dogs total • Also earn in Dojo") or kind == "Coat" and "Choose for the selected dog" or kind == "Outfit" and "Fabric layers & utility gear" or itemId == "GoldSword" and "Permanent • One-hit enemies" or "Double every coin reward"), COLOUR_GOLD)
	detail.Position = UDim2.new(0, 10, 0, 139)
	detail.Size = UDim2.new(1, -20, 0, 25)
	cards[kind .. ":" .. itemId] = card

	button.Activated:Connect(function()
		onCardClicked(card)
	end)
end

local ninjaPage = createPage("Ninja")
local coyoPage = createPage("Coyo")
local boostPage = createPage("Boosts")
coyoPage.Position = UDim2.new(0, 12, 0, 146)
coyoPage.Size = UDim2.new(1, -24, 1, -158)
for index, name in ipairs(Config.CoyoPackNames) do
	local button = makeButton(panel, name, COLOUR_TAB)
	button.Position = UDim2.new((index - 1) / 4, 12, 0, 105)
	button.Size = UDim2.new(0.25, -16, 0, 32)
	button.Visible = false
	button.Activated:Connect(function()
		if index <= (currentState.PackSize or 1) then
			selectedDog = index
			refreshCards()
		end
	end)
	dogButtons[index] = button
end
createTabButton("Ninja", "NINJA", 1)
createTabButton("Coyo", "DOG PACK", 2)
createTabButton("Boosts", "BOOSTS", 3)

for index, outfitId in ipairs(WardrobeConfig.OutfitOrder) do
	local outfit = WardrobeConfig.Outfits[outfitId]
	createCard(ninjaPage, "Outfit", outfitId, outfit.DisplayName, outfit.PassId, { outfit.BodyColor, outfit.AccentColor, outfit.SashColor }, index)
end
for index, coatId in ipairs(WardrobeConfig.CoatOrder) do
	local coat = WardrobeConfig.Coats[coatId]
	createCard(coyoPage, "Coat", coatId, coat.DisplayName, coat.PassId, { coat.FurColor, coat.DarkColor, coat.LightColor }, index)
end
createCard(boostPage, "Boost", "DoubleCoins", "2x Scroll-Coins", WardrobeConfig.DoubleCoinsPassId, { COLOUR_GOLD, Color3.fromRGB(255, 235, 150), COLOUR_GOLD }, 1)

createCard(boostPage, "Boost", "GoldSword", "Super Gold Sword", WardrobeConfig.GoldSwordPassId, { COLOUR_GOLD }, 2)

for count = 2, 4 do
	createCard(boostPage, "Boost", "Pack" .. count, count .. "-Dog Pack", WardrobeConfig.PackPassIds[count], { COLOUR_GOLD }, count + 1)
end

showTab("Ninja")
refreshCards()

----------------------------------------------------------------
-- Opening and closing
----------------------------------------------------------------

local function setPanelOpen(open)
	panel.Visible = open
	blocker.Visible = open
	Menus.Set("Wardrobe", open)
end
player.CharacterRemoving:Connect(function() setPanelOpen(false) end)

local function openPanel()
	setPanelOpen(true)
	panelScale.Scale = 0.85
	TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		local success, newState = pcall(function()
			return getStateFunction:InvokeServer()
		end)
		if success then
			applyState(newState)
		end
	end)
end

wardrobeButton.Activated:Connect(function()
	Sounds.Play("Click", 1, 1)
	if panel.Visible then
		setPanelOpen(false)
	else
		openPanel()
	end
end)

closeButton.Activated:Connect(function()
	Sounds.Play("Click", 1, 1)
	setPanelOpen(false)
end)

openEvent.OnClientEvent:Connect(openPanel)
stateEvent.OnClientEvent:Connect(applyState)

-- Look up the real Robux prices of any passes that have been set up
task.spawn(function()
	for _, card in pairs(cards) do
		if card.PassId ~= 0 then
			local success, info = pcall(function()
				return MarketplaceService:GetProductInfo(card.PassId, Enum.InfoType.GamePass)
			end)
			if success and info ~= nil and info.PriceInRobux ~= nil then
				priceByPass[card.PassId] = info.PriceInRobux
			end
		end
	end
	refreshCards()
end)
