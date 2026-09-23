-- NinjaCoyoClient (LocalScript in StarterPlayer > StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local Sounds = require(ReplicatedStorage:WaitForChild("NinjaCoyoSounds"))
local remotes = ReplicatedStorage:WaitForChild("NinjaCoyoRemotes")
local buyUpgradeFunction = remotes:WaitForChild("BuyUpgrade")
local buyUnlockFunction = remotes:WaitForChild("BuyUnlock")
local getDataFunction = remotes:WaitForChild("GetData")
local dataUpdatedEvent = remotes:WaitForChild("DataUpdated")
local gateOpenedEvent = remotes:WaitForChild("GateOpened")
gateOpenedEvent.OnClientEvent:Connect(function()
	Sounds.PlayMusicIfIdle()
end)
local coinCollectedEvent = remotes:WaitForChild("CoinCollected")
local notifyEvent = remotes:WaitForChild("Notify")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local coinsFolder = workspace:WaitForChild("ScrollCoins")
local rng = Random.new()
local formatNumber = Config.FormatNumber

local GATE_TAG = "NinjaCoyoGateBlocker"

-- State (initialised up front)
local currentData = {}
currentData.Coins = 0
currentData.Upgrades = {}
for _, upgradeId in ipairs(Config.UpgradeOrder) do
	currentData.Upgrades[upgradeId] = 0
end
currentData.Unlocks = {}
for _, unlockId in ipairs(Config.UnlockOrder) do
	currentData.Unlocks[unlockId] = false
end
local upgradeRows = {}
local unlockRows = {}
local isBuying = false
local spinAngle = 0
local bannerToken = 0
local coinStreak = 0
local lastCoinTime = 0



-- Colours
local COLOUR_PANEL = Color3.fromRGB(34, 28, 44)
local COLOUR_ROW = Color3.fromRGB(52, 44, 66)
local COLOUR_GOLD = Color3.fromRGB(255, 205, 60)
local COLOUR_WHITE = Color3.new(1, 1, 1)
local COLOUR_NINJA = Color3.fromRGB(200, 40, 55)
local COLOUR_COYO = Color3.fromRGB(196, 150, 96)
local COLOUR_CAN_BUY = Color3.fromRGB(60, 180, 90)
local COLOUR_CANT_BUY = Color3.fromRGB(90, 84, 100)
local COLOUR_MAX = Color3.fromRGB(120, 100, 200)
local COLOUR_ERROR = Color3.fromRGB(200, 60, 60)
local COLOUR_DOJO = Color3.fromRGB(235, 120, 40)

----------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, thickness, colour)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = colour
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, textColour)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = textColour
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

local function bounce(uiScale, amount)
	local grow = TweenService:Create(uiScale, TweenInfo.new(0.07), { Scale = amount })
	grow.Completed:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	grow:Play()
end

----------------------------------------------------------------
-- Build the UI
----------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NinjaCoyoGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Coin counter
local coinFrame = Instance.new("Frame")
coinFrame.Name = "CoinCounter"
coinFrame.AnchorPoint = Vector2.new(0.5, 0)
coinFrame.Position = UDim2.new(0.5, 0, 0, 12)
coinFrame.Size = UDim2.new(0, 220, 0, 50)
coinFrame.BackgroundColor3 = COLOUR_PANEL
coinFrame.Parent = screenGui
addCorner(coinFrame, 14)
addStroke(coinFrame, 3, COLOUR_GOLD)

local coinScale = Instance.new("UIScale")
coinScale.Parent = coinFrame

local coinLabel = makeLabel(coinFrame, "📜 0", COLOUR_GOLD)
coinLabel.Position = UDim2.new(0, 10, 0, 4)
coinLabel.Size = UDim2.new(1, -20, 1, -8)

-- Next-goal bar
local goalFrame = Instance.new("Frame")
goalFrame.Name = "NextGoal"
goalFrame.AnchorPoint = Vector2.new(0.5, 0)
goalFrame.Position = UDim2.new(0.5, 0, 0, 68)
goalFrame.Size = UDim2.new(0, 300, 0, 28)
goalFrame.BackgroundColor3 = COLOUR_PANEL
goalFrame.ClipsDescendants = true
goalFrame.Parent = screenGui
addCorner(goalFrame, 10)
addStroke(goalFrame, 2, COLOUR_GOLD)

local goalFill = Instance.new("Frame")
goalFill.Size = UDim2.new(0, 0, 1, 0)
goalFill.BackgroundColor3 = COLOUR_CAN_BUY
goalFill.BorderSizePixel = 0
goalFill.Parent = goalFrame
addCorner(goalFill, 10)

local goalLabel = makeLabel(goalFrame, "", COLOUR_WHITE)
goalLabel.Position = UDim2.new(0, 8, 0, 3)
goalLabel.Size = UDim2.new(1, -16, 1, -6)
goalLabel.ZIndex = 2
goalLabel.TextStrokeTransparency = 0.3

-- Dojo button
local dojoButton = makeButton(screenGui, "DOJO", COLOUR_DOJO)
dojoButton.AnchorPoint = Vector2.new(0, 0.5)
dojoButton.Position = UDim2.new(0, 12, 0.5, 0)
dojoButton.Size = UDim2.new(0, 110, 0, 56)
addStroke(dojoButton, 3, COLOUR_WHITE)

-- Shop panel
local shopFrame = Instance.new("Frame")
shopFrame.Name = "DojoShop"
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
shopFrame.Size = UDim2.new(0.6, 0, 0.7, 0)
shopFrame.BackgroundColor3 = COLOUR_PANEL
shopFrame.Visible = false
shopFrame.Parent = screenGui
addCorner(shopFrame, 16)
addStroke(shopFrame, 3, COLOUR_GOLD)

local shopSizeLimit = Instance.new("UISizeConstraint")
shopSizeLimit.MaxSize = Vector2.new(460, 480)
shopSizeLimit.MinSize = Vector2.new(300, 280)
shopSizeLimit.Parent = shopFrame

local shopTitle = makeLabel(shopFrame, "NinjaCoyo Dojo", COLOUR_GOLD)
shopTitle.Position = UDim2.new(0, 16, 0, 10)
shopTitle.Size = UDim2.new(1, -80, 0, 40)
shopTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = makeButton(shopFrame, "X", COLOUR_ERROR)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -10, 0, 10)
closeButton.Size = UDim2.new(0, 40, 0, 40)

local shopList = Instance.new("ScrollingFrame")
shopList.Position = UDim2.new(0, 12, 0, 60)
shopList.Size = UDim2.new(1, -24, 1, -72)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.Parent = shopFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = shopList

-- Unlock banner
local bannerFrame = Instance.new("Frame")
bannerFrame.Name = "Banner"
bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
bannerFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
bannerFrame.Size = UDim2.new(0, 440, 0, 92)
bannerFrame.BackgroundColor3 = COLOUR_PANEL
bannerFrame.Visible = false
bannerFrame.Parent = screenGui
addCorner(bannerFrame, 16)
local bannerStroke = addStroke(bannerFrame, 4, COLOUR_GOLD)

local bannerScale = Instance.new("UIScale")
bannerScale.Parent = bannerFrame

local bannerTitle = makeLabel(bannerFrame, "", COLOUR_GOLD)
bannerTitle.Position = UDim2.new(0, 12, 0, 8)
bannerTitle.Size = UDim2.new(1, -24, 0, 44)
bannerTitle.TextStrokeTransparency = 0.2

local bannerSubtitle = makeLabel(bannerFrame, "", COLOUR_WHITE)
bannerSubtitle.Position = UDim2.new(0, 12, 0, 56)
bannerSubtitle.Size = UDim2.new(1, -24, 0, 28)

-- Compact HUD responds to phone rotation and window resizing. Animation scales
-- remain separate from layout, so a notification cannot grow back to desktop size.
local compactHud = false
local function layoutHud()
	local size = screenGui.AbsoluteSize
	compactHud = size.X < 900 or size.Y < 600
	coinFrame.Size = UDim2.fromOffset(compactHud and 132 or 180, compactHud and 30 or 40)
	coinFrame.Position = UDim2.new(0.5, 0, 0, 6)
	goalFrame.Size = UDim2.fromOffset(compactHud and 210 or 260, compactHud and 20 or 24)
	goalFrame.Position = UDim2.new(0.5, 0, 0, compactHud and 42 or 52)
	dojoButton.AnchorPoint = Vector2.zero
	dojoButton.Size = UDim2.fromOffset(80, 44)
	dojoButton.Position = UDim2.fromOffset(8, 76)
	dojoButton.TextScaled = false
	dojoButton.TextSize = 16
	bannerFrame.AnchorPoint = Vector2.new(1, 0)
	bannerFrame.Position = UDim2.new(1, -8, 0, 72)
	bannerFrame.Size = UDim2.fromOffset(math.min(compactHud and 220 or 300, size.X - 108), compactHud and 52 or 64)
	bannerStroke.Thickness = 2
	bannerTitle.Position = UDim2.fromOffset(8, 5)
	bannerTitle.Size = UDim2.new(1, -16, 0, compactHud and 20 or 26)
	bannerSubtitle.Position = UDim2.fromOffset(8, compactHud and 29 or 35)
	bannerSubtitle.Size = UDim2.new(1, -16, 0, compactHud and 17 or 22)
	shopFrame.Size = UDim2.new(0, math.min(420, size.X - 24), 0, math.min(440, size.Y - 24))
	shopSizeLimit.MinSize = Vector2.new(0, 0)
end
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutHud)
layoutHud()

----------------------------------------------------------------
-- Display updates
----------------------------------------------------------------

local function updateGoal()
	local nextUnlockId = ""
	for _, unlockId in ipairs(Config.UnlockOrder) do
		if currentData.Unlocks[unlockId] ~= true then
			nextUnlockId = unlockId
			break
		end
	end
	if nextUnlockId == "" then
		goalFrame.Visible = false
		return
	end

	goalFrame.Visible = true
	local info = Config.Unlocks[nextUnlockId]
	local progress = math.clamp(currentData.Coins / info.Cost, 0, 1)
	goalFill.Size = UDim2.new(progress, 0, 1, 0)
	if progress >= 1 then
		goalLabel.Text = info.DisplayName .. " ready! Open the DOJO"
	else
		goalLabel.Text = "Next: " .. info.DisplayName .. "  " .. formatNumber(currentData.Coins) .. " / " .. formatNumber(info.Cost)
	end
end

local function refreshShop()
	for _, unlockId in ipairs(Config.UnlockOrder) do
		local rowInfo = unlockRows[unlockId]
		local info = Config.Unlocks[unlockId]
		rowInfo.NameLabel.Text = info.DisplayName
		rowInfo.InfoLabel.Text = info.Description
		if currentData.Unlocks[unlockId] == true then
			rowInfo.BuyButton.Text = "OWNED"
			rowInfo.BuyButton.BackgroundColor3 = COLOUR_MAX
		else
			rowInfo.BuyButton.Text = "📜 " .. formatNumber(info.Cost)
			if currentData.Coins >= info.Cost then
				rowInfo.BuyButton.BackgroundColor3 = COLOUR_CAN_BUY
			else
				rowInfo.BuyButton.BackgroundColor3 = COLOUR_CANT_BUY
			end
		end
	end

	for _, upgradeId in ipairs(Config.UpgradeOrder) do
		local rowInfo = upgradeRows[upgradeId]
		local info = Config.Upgrades[upgradeId]
		local level = currentData.Upgrades[upgradeId]
		local currentText = Config.FormatValue(upgradeId, Config.GetValue(upgradeId, level))

		rowInfo.NameLabel.Text = info.DisplayName .. "  Lv " .. level .. "/" .. info.MaxLevel

		if level >= info.MaxLevel then
			rowInfo.InfoLabel.Text = info.Description .. "  (" .. currentText .. ")"
			rowInfo.BuyButton.Text = "MAX"
			rowInfo.BuyButton.BackgroundColor3 = COLOUR_MAX
		else
			local nextText = Config.FormatValue(upgradeId, Config.GetValue(upgradeId, level + 1))
			local cost = Config.GetCost(upgradeId, level)
			rowInfo.InfoLabel.Text = info.Description .. "  (" .. currentText .. " > " .. nextText .. ")"
			rowInfo.BuyButton.Text = "📜 " .. formatNumber(cost)
			if currentData.Coins >= cost then
				rowInfo.BuyButton.BackgroundColor3 = COLOUR_CAN_BUY
			else
				rowInfo.BuyButton.BackgroundColor3 = COLOUR_CANT_BUY
			end
		end
	end
end

local function applyGateBlocker(part)
	local unlockId = part:GetAttribute("UnlockId")
	if unlockId == nil then
		return
	end
	local isUnlocked = currentData.Unlocks[unlockId] == true
	if isUnlocked then
		part.CanCollide = false
		part.LocalTransparencyModifier = 1
	else
		part.CanCollide = true
		part.LocalTransparencyModifier = 0
	end
	for _, descendant in ipairs(part:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") then
			descendant.Enabled = not isUnlocked
		end
	end
end

local function applyAllGates()
	for _, part in ipairs(CollectionService:GetTagged(GATE_TAG)) do
		applyGateBlocker(part)
	end
end

local function applyData(newData)
	if type(newData) ~= "table" then
		return
	end
	currentData.Coins = newData.Coins
	for _, upgradeId in ipairs(Config.UpgradeOrder) do
		local level = newData.Upgrades[upgradeId]
		if level ~= nil then
			currentData.Upgrades[upgradeId] = level
		end
	end
	for _, unlockId in ipairs(Config.UnlockOrder) do
		if newData.Unlocks[unlockId] == true then
			currentData.Unlocks[unlockId] = true
		end
	end

	coinLabel.Text = "📜 " .. formatNumber(currentData.Coins)
	refreshShop()
	updateGoal()
	applyAllGates()
end

local function showBanner(title, subtitle, isGood)
	bannerToken = bannerToken + 1
	local myToken = bannerToken

	bannerTitle.Text = title
	bannerSubtitle.Text = subtitle
	local duration = 2
	if isGood == true then
		bannerTitle.TextColor3 = COLOUR_GOLD
		bannerStroke.Color = COLOUR_GOLD
		duration = 3.5
		Sounds.Play("Unlock", 1, 1)
	else
		bannerTitle.TextColor3 = COLOUR_ERROR
		bannerStroke.Color = COLOUR_ERROR
		Sounds.Play("Click", 0.6, 1)
	end

	bannerFrame.Visible = true
	bannerScale.Scale = 0.6
	TweenService:Create(bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(duration, function()
		if bannerToken == myToken then
			bannerFrame.Visible = false
		end
	end)
end

----------------------------------------------------------------
-- Shop rows
----------------------------------------------------------------

local function onBuyClicked(kind, itemId)
	Sounds.Play("Click", 1, 1)
	if isBuying then
		return
	end
	isBuying = true

	local remote = buyUpgradeFunction
	local rowInfo = upgradeRows[itemId]
	if kind == "Unlock" then
		remote = buyUnlockFunction
		rowInfo = unlockRows[itemId]
	end

	local callOk, success, message = pcall(function()
		return remote:InvokeServer(itemId)
	end)
	isBuying = false

	if callOk == false then
		success = false
		message = "Try again"
	end

	if success == true then
		bounce(rowInfo.Scale, 1.05)
	else
		rowInfo.BuyButton.Text = tostring(message)
		rowInfo.BuyButton.BackgroundColor3 = COLOUR_ERROR
		task.delay(1, refreshShop)
	end
end

local function createSectionHeader(text, order)
	local header = makeLabel(shopList, text, COLOUR_GOLD)
	header.LayoutOrder = order
	header.Size = UDim2.new(1, -10, 0, 26)
	header.TextXAlignment = Enum.TextXAlignment.Left
end

local function createRow(kind, itemId, displayName, accentColour, order)
	local row = Instance.new("Frame")
	row.Name = itemId
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, 72)
	row.BackgroundColor3 = COLOUR_ROW
	row.Parent = shopList
	addCorner(row, 12)

	local rowScale = Instance.new("UIScale")
	rowScale.Parent = row

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 8, 1, 0)
	accent.BackgroundColor3 = accentColour
	accent.BorderSizePixel = 0
	accent.Parent = row
	addCorner(accent, 12)

	local nameLabel = makeLabel(row, displayName, COLOUR_WHITE)
	nameLabel.Position = UDim2.new(0, 18, 0, 6)
	nameLabel.Size = UDim2.new(1, -124, 0, 30)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	local infoLabel = makeLabel(row, "", Color3.fromRGB(200, 190, 215))
	infoLabel.Position = UDim2.new(0, 18, 0, 38)
	infoLabel.Size = UDim2.new(1, -124, 0, 24)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left

	local buyButton = makeButton(row, "...", COLOUR_CANT_BUY)
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -10, 0.5, 0)
	buyButton.Size = UDim2.new(0, 96, 0, 44)
	buyButton.Activated:Connect(function()
		onBuyClicked(kind, itemId)
	end)

	local rowInfo = {}
	rowInfo.NameLabel = nameLabel
	rowInfo.InfoLabel = infoLabel
	rowInfo.BuyButton = buyButton
	rowInfo.Scale = rowScale
	return rowInfo
end

createSectionHeader("UNLOCKS", 0)
for index, unlockId in ipairs(Config.UnlockOrder) do
	local info = Config.Unlocks[unlockId]
	unlockRows[unlockId] = createRow("Unlock", unlockId, info.DisplayName, COLOUR_GOLD, index)
end

createSectionHeader("UPGRADES", 100)
for index, upgradeId in ipairs(Config.UpgradeOrder) do
	local info = Config.Upgrades[upgradeId]
	local accentColour = COLOUR_NINJA
	if info.Category == "Coyo" then
		accentColour = COLOUR_COYO
	end
	upgradeRows[upgradeId] = createRow("Upgrade", upgradeId, info.DisplayName, accentColour, 100 + index)
end

refreshShop()
updateGoal()

dojoButton.Activated:Connect(function()
	Sounds.Play("Click", 1, 1)
	shopFrame.Visible = not shopFrame.Visible
end)

closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

----------------------------------------------------------------
-- Server events
----------------------------------------------------------------

dataUpdatedEvent.OnClientEvent:Connect(applyData)
notifyEvent.OnClientEvent:Connect(showBanner)
CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(applyGateBlocker)

coinCollectedEvent.OnClientEvent:Connect(function(amount)
	-- Quick pickups in a row climb in pitch
	local now = os.clock()
	if now - lastCoinTime < 0.6 then
		coinStreak = math.min(coinStreak + 1, 12)
	else
		coinStreak = 0
	end
	lastCoinTime = now
	Sounds.Play("CoinPickup", 1 + coinStreak * 0.04, 1)

	local popup = makeLabel(screenGui, "+" .. formatNumber(amount), COLOUR_GOLD)
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Position = UDim2.new(0.5, rng:NextInteger(-45, 45), 0, compactHud and 64 or 82)
	popup.Size = UDim2.fromOffset(64, compactHud and 18 or 24)
	popup.TextStrokeTransparency = 0.2

	local tween = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.new(0, 0, 0, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	Debris:AddItem(popup, 0.9)

	bounce(coinScale, 1.1)
end)

task.spawn(function()
	local attempts = 0
	while attempts < 20 do
		attempts = attempts + 1
		local success, data = pcall(function()
			return getDataFunction:InvokeServer()
		end)
		if success and data ~= nil then
			applyData(data)
			break
		end
		task.wait(0.5)
	end
end)

----------------------------------------------------------------
-- Spinning, bobbing scroll-coins (visual only, runs locally)
----------------------------------------------------------------

RunService.RenderStepped:Connect(function(deltaTime)
	spinAngle = spinAngle + deltaTime * Config.CoinSpinSpeed
	local now = os.clock()
	for _, coinModel in ipairs(coinsFolder:GetChildren()) do
		local basePosition = coinModel:GetAttribute("BasePosition")
		if basePosition ~= nil and coinModel.PrimaryPart ~= nil then
			local bob = math.sin(now * 2 + basePosition.X) * 0.3
			coinModel:PivotTo(CFrame.new(basePosition + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spinAngle, 0))
		end
	end
end)
