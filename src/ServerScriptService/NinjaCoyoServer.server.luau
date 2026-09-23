-- NinjaCoyoServer (Script in ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local Enemies = require(script.Parent:WaitForChild("NinjaCoyoEnemies"))
local Wardrobe = require(script.Parent:WaitForChild("NinjaCoyoWardrobe"))

local dataStore = nil
local dataStoreOk, dataStoreResult = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if dataStoreOk then
	dataStore = dataStoreResult
else
	warn("NinjaCoyo: DataStore unavailable (publish the place to enable saving). Playing without saving.")
end

local rng = Random.new()
local GATE_TAG = "NinjaCoyoGateBlocker"

-- State (initialised up front)
local playerData = {}
local playerLoadedOk = {}
local playerPets = {}
local lastSwingTime = {}
local zoneCoinCount = {}
local zoneChestCount = {}
for _, zoneId in ipairs(Config.ZoneOrder) do
	zoneCoinCount[zoneId] = 0
	zoneChestCount[zoneId] = 0
end

-- Colours
local COYO_FUR = Color3.fromRGB(181, 140, 94)
local COYO_DARK = Color3.fromRGB(110, 82, 56)
local COYO_LIGHT = Color3.fromRGB(232, 214, 184)
local COYO_BLACK = Color3.fromRGB(25, 25, 25)
local NINJA_RED = Color3.fromRGB(200, 30, 40)
local CHEST_WOOD = Color3.fromRGB(120, 78, 40)
local CHEST_LID = Color3.fromRGB(92, 58, 30)
local GOLD = Color3.fromRGB(255, 196, 40)
local GATE_RED = Color3.fromRGB(190, 35, 35)
local PAPER = Color3.fromRGB(240, 230, 200)

-- Folders and remotes
local function makeFolder(name, parent)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local remotesFolder = makeFolder("NinjaCoyoRemotes", ReplicatedStorage)

local function makeRemote(className, name)
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local buyUpgradeFunction = makeRemote("RemoteFunction", "BuyUpgrade")
local buyUnlockFunction = makeRemote("RemoteFunction", "BuyUnlock")
local getDataFunction = makeRemote("RemoteFunction", "GetData")
local dataUpdatedEvent = makeRemote("RemoteEvent", "DataUpdated")
local coinCollectedEvent = makeRemote("RemoteEvent", "CoinCollected")
local notifyEvent = makeRemote("RemoteEvent", "Notify")
local fxEvent = makeRemote("RemoteEvent", "Fx")

local coinsFolder = makeFolder("ScrollCoins", workspace)
local chestsFolder = makeFolder("ScrollChests", workspace)
local petsFolder = makeFolder("Pets", workspace)
local zonesFolder = makeFolder("Zones", workspace)

-- Raycasting ignores coins, chests, pets and characters so it only hits the ground
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { coinsFolder, chestsFolder, petsFolder }

local function refreshRayFilter()
	local excluded = { coinsFolder, chestsFolder, petsFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character ~= nil then
			table.insert(excluded, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = excluded
end

local function findGround(position, heightAbove, depth)
	local origin = position + Vector3.new(0, heightAbove, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -depth, 0), rayParams)
	if result ~= nil then
		return result.Position
	end
	return nil
end

----------------------------------------------------------------
-- Data
----------------------------------------------------------------

local function createDefaultData()
	local data = {}
	data.Coins = Config.StartingCoins
	data.Upgrades = {}
	for _, upgradeId in ipairs(Config.UpgradeOrder) do
		data.Upgrades[upgradeId] = 0
	end
	data.Unlocks = {}
	for _, unlockId in ipairs(Config.UnlockOrder) do
		data.Unlocks[unlockId] = false
	end
	data.EnemyTier = 1
	data.Outfit = "Default"
	data.CoyoCoat = "Coyote"
	return data
end

local function loadData(player)
	local data = createDefaultData()
	if dataStore == nil then
		return data, false
	end
	local success, stored = pcall(function()
		return dataStore:GetAsync("Player_" .. player.UserId)
	end)

	if success == false then
		warn("NinjaCoyo: could not load data for " .. player.Name .. " (saving disabled this session): " .. tostring(stored))
		return data, false
	end

	if type(stored) == "table" then
		if type(stored.Coins) == "number" then
			data.Coins = math.floor(stored.Coins)
		end
		if type(stored.Upgrades) == "table" then
			for _, upgradeId in ipairs(Config.UpgradeOrder) do
				local storedLevel = stored.Upgrades[upgradeId]
				if type(storedLevel) == "number" then
					local maxLevel = Config.Upgrades[upgradeId].MaxLevel
					data.Upgrades[upgradeId] = math.clamp(math.floor(storedLevel), 0, maxLevel)
				end
			end
		end
		if type(stored.Outfit) == "string" and Config.Wardrobe.Outfits[stored.Outfit] ~= nil then
			data.Outfit = stored.Outfit
		end
		if type(stored.CoyoCoat) == "string" and Config.Wardrobe.Coats[stored.CoyoCoat] ~= nil then
			data.CoyoCoat = stored.CoyoCoat
		end
		if type(stored.EnemyTier) == "number" then
			data.EnemyTier = math.max(1, math.floor(stored.EnemyTier))
		end
		if type(stored.Unlocks) == "table" then
			for _, unlockId in ipairs(Config.UnlockOrder) do
				if stored.Unlocks[unlockId] == true then
					data.Unlocks[unlockId] = true
				end
			end
		end
	end

	return data, true
end

local function saveData(player)
	local data = playerData[player]
	if data == nil then
		return
	end
	if playerLoadedOk[player] ~= true then
		return
	end

	local success, errorMessage = pcall(function()
		dataStore:SetAsync("Player_" .. player.UserId, data)
	end)
	if success == false then
		warn("NinjaCoyo: could not save data for " .. player.Name .. ": " .. tostring(errorMessage))
	end
end

local function updateLeaderstats(player)
	local data = playerData[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if data == nil or leaderstats == nil then
		return
	end
	local coinsValue = leaderstats:FindFirstChild("Scroll-Coins")
	if coinsValue ~= nil then
		coinsValue.Value = data.Coins
	end
end

local function sendDataToClient(player)
	local data = playerData[player]
	if data ~= nil then
		dataUpdatedEvent:FireClient(player, data)
	end
end

local function applyCharacterStats(player)
	local data = playerData[player]
	local character = player.Character
	if data == nil or character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	humanoid.WalkSpeed = Config.GetValue("NinjaSpeed", data.Upgrades.NinjaSpeed)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.GetValue("NinjaJump", data.Upgrades.NinjaJump)

	local newMaxHealth = Config.GetValue("NinjaHealth", data.Upgrades.NinjaHealth)
	local healthGain = newMaxHealth - humanoid.MaxHealth
	humanoid.MaxHealth = newMaxHealth
	if humanoid.Health > 0 and healthGain > 0 then
		humanoid.Health = math.min(newMaxHealth, humanoid.Health + healthGain)
	end
end

local function playerHasZone(data, zoneId)
	local zone = Config.Zones[zoneId]
	if zone == nil then
		return false
	end
	if zone.RequiredUnlock == "" then
		return true
	end
	return data.Unlocks[zone.RequiredUnlock] == true
end

local function computeReward(data, baseValue)
	local multiplier = Config.GetValue("GoldenPaws", data.Upgrades.GoldenPaws)
	local reward = math.floor(baseValue * multiplier + 0.5)
	if reward < 1 then
		reward = 1
	end
	return reward
end

local function addCoins(player, amount, worldPosition)
	local data = playerData[player]
	if data == nil then
		return
	end
	amount = amount * Wardrobe.GetCoinMultiplier(player)
	data.Coins = data.Coins + amount
	updateLeaderstats(player)
	sendDataToClient(player)
	coinCollectedEvent:FireClient(player, amount, worldPosition)
end

----------------------------------------------------------------
-- Scroll-coins and chests
----------------------------------------------------------------

local function collectCoin(coinModel, player)
	local data = playerData[player]
	if data == nil then
		return
	end
	if coinModel.Parent == nil then
		return
	end
	if coinModel:GetAttribute("Collected") == true then
		return
	end
	local zoneId = coinModel:GetAttribute("Zone")
	if playerHasZone(data, zoneId) == false then
		return
	end

	coinModel:SetAttribute("Collected", true)
	local baseValue = coinModel:GetAttribute("Value")
	local position = coinModel:GetAttribute("BasePosition")

	coinModel:Destroy()
	zoneCoinCount[zoneId] = zoneCoinCount[zoneId] - 1
	addCoins(player, computeReward(data, baseValue), position)
end

local function onCoinTouched(coinModel, hit)
	local character = hit.Parent
	if character == nil then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return
	end
	collectCoin(coinModel, player)
end

local function getRandomGroundInZone(zone)
	local half = zone.Size / 2 - zone.SpawnMargin
	local x = zone.Center.X + rng:NextNumber(-half, half)
	local z = zone.Center.Z + rng:NextNumber(-half, half)
	local origin = Vector3.new(x, zone.Center.Y + Config.SpawnRayHeight, z)
	local result = workspace:Raycast(origin, Vector3.new(0, -Config.SpawnRayHeight * 2, 0), rayParams)
	if result == nil then
		return nil
	end
	if result.Material == Enum.Material.Water then
		return nil
	end
	return result.Position
end

local function spawnCoin(zoneId)
	local zone = Config.Zones[zoneId]
	local ground = getRandomGroundInZone(zone)
	if ground == nil then
		return false
	end

	local coinModel = Instance.new("Model")
	coinModel.Name = "ScrollCoin"

	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.3, 2.2, 2.2)
	disc.Color = GOLD
	disc.Material = Enum.Material.SmoothPlastic
	disc.Reflectance = 0.25
	disc.Anchored = true
	disc.CanCollide = false
	disc.CFrame = CFrame.new(ground + Vector3.new(0, Config.CoinHoverHeight, 0))
	disc.Parent = coinModel

	local scroll = Instance.new("Part")
	scroll.Name = "Scroll"
	scroll.Shape = Enum.PartType.Cylinder
	scroll.Size = Vector3.new(1.8, 0.45, 0.45)
	scroll.Color = PAPER
	scroll.Material = Enum.Material.SmoothPlastic
	scroll.Anchored = true
	scroll.CanCollide = false
	scroll.CanTouch = false
	scroll.CFrame = disc.CFrame * CFrame.Angles(0, math.rad(90), 0)
	scroll.Parent = coinModel

	coinModel.PrimaryPart = disc
	coinModel:SetAttribute("Zone", zoneId)
	coinModel:SetAttribute("Value", zone.CoinValue)
	coinModel:SetAttribute("BasePosition", disc.Position)
	coinModel:SetAttribute("Collected", false)

	disc.Touched:Connect(function(hit)
		onCoinTouched(coinModel, hit)
	end)

	coinModel.Parent = coinsFolder
	zoneCoinCount[zoneId] = zoneCoinCount[zoneId] + 1
	return true
end

local function makeChestPart(model, name, size, colour, material, cframe)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = cframe
	part.Parent = model
	return part
end

local function spawnChest(zoneId)
	local zone = Config.Zones[zoneId]
	local ground = getRandomGroundInZone(zone)
	if ground == nil then
		return false
	end

	local chestModel = Instance.new("Model")
	chestModel.Name = "ScrollChest"

	local baseCFrame = CFrame.new(ground + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = makeChestPart(chestModel, "Base", Vector3.new(3, 2, 2.2), CHEST_WOOD, Enum.Material.WoodPlanks, baseCFrame)
	makeChestPart(chestModel, "Lid", Vector3.new(3.1, 0.7, 2.3), CHEST_LID, Enum.Material.WoodPlanks, baseCFrame * CFrame.new(0, 1.35, 0))
	makeChestPart(chestModel, "Band", Vector3.new(0.5, 2.8, 2.35), GOLD, Enum.Material.SmoothPlastic, baseCFrame * CFrame.new(0, 0.35, 0))
	makeChestPart(chestModel, "Lock", Vector3.new(0.6, 0.6, 0.2), GOLD, Enum.Material.SmoothPlastic, baseCFrame * CFrame.new(0, 0.9, -1.25))

	-- Value and health bar
	local chestGui = Instance.new("BillboardGui")
	chestGui.Name = "ChestGui"
	chestGui.Size = UDim2.new(4, 0, 1.4, 0)
	chestGui.StudsOffset = Vector3.new(0, 3, 0)
	chestGui.MaxDistance = 50
	chestGui.Parent = base

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(1, 0, 0.55, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.FredokaOne
	local chestValue = rng:NextInteger(zone.ChestValueMin, zone.ChestValueMax)
	valueLabel.Text = "📜 " .. Config.FormatNumber(chestValue)
	valueLabel.TextColor3 = GOLD
	valueLabel.TextStrokeTransparency = 0.3
	valueLabel.TextScaled = true
	valueLabel.Parent = chestGui

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0.1, 0, 0.65, 0)
	barBack.Size = UDim2.new(0.8, 0, 0.3, 0)
	barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	barBack.BorderSizePixel = 0
	barBack.Parent = chestGui

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	chestModel.PrimaryPart = base
	chestModel:SetAttribute("Zone", zoneId)
	chestModel:SetAttribute("Value", chestValue)
	chestModel:SetAttribute("Hits", zone.ChestHits)
	chestModel:SetAttribute("MaxHits", zone.ChestHits)
	chestModel:SetAttribute("Opened", false)

	chestModel.Parent = chestsFolder
	zoneChestCount[zoneId] = zoneChestCount[zoneId] + 1
	return true
end

local function hitChest(chestModel, player)
	local data = playerData[player]
	if data == nil then
		return
	end
	if chestModel.Parent == nil then
		return
	end
	if chestModel:GetAttribute("Opened") == true then
		return
	end
	local base = chestModel.PrimaryPart
	if base == nil then
		return
	end

	local hits = chestModel:GetAttribute("Hits") - 1
	local maxHits = chestModel:GetAttribute("MaxHits")
	chestModel:SetAttribute("Hits", hits)

	local chestGui = base:FindFirstChild("ChestGui")
	if chestGui ~= nil then
		local fill = chestGui:FindFirstChild("Fill", true)
		if fill ~= nil then
			fill.Size = UDim2.new(math.max(hits, 0) / maxHits, 0, 1, 0)
		end
	end

	base.Color = Color3.new(1, 1, 1)
	task.delay(0.1, function()
		if base.Parent ~= nil then
			base.Color = CHEST_WOOD
		end
	end)

	if hits <= 0 then
		chestModel:SetAttribute("Opened", true)
		local zoneId = chestModel:GetAttribute("Zone")
		local baseValue = chestModel:GetAttribute("Value")
		local position = base.Position
		local reward = computeReward(data, baseValue)
		fxEvent:FireAllClients("ChestOpen", base.CFrame, player.UserId, reward)
		chestModel:Destroy()
		zoneChestCount[zoneId] = zoneChestCount[zoneId] - 1
		addCoins(player, reward, position)
	else
		fxEvent:FireAllClients("ChestHit", base.Position, chestModel)
	end
end

local function spawnZoneItems(zoneId, maxCoinsToSpawn, maxChestsToSpawn)
	local zone = Config.Zones[zoneId]

	local spawned = 0
	local attempts = 0
	while zoneCoinCount[zoneId] < zone.MaxCoins and spawned < maxCoinsToSpawn and attempts < maxCoinsToSpawn * 4 do
		attempts = attempts + 1
		if spawnCoin(zoneId) then
			spawned = spawned + 1
		end
	end

	spawned = 0
	attempts = 0
	while zoneChestCount[zoneId] < zone.MaxChests and spawned < maxChestsToSpawn and attempts < maxChestsToSpawn * 4 do
		attempts = attempts + 1
		if spawnChest(zoneId) then
			spawned = spawned + 1
		end
	end
end

local function findNearestChest(data, position, radius)
	local nearestChest = nil
	local nearestDistance = radius
	for _, chestModel in ipairs(chestsFolder:GetChildren()) do
		local base = chestModel.PrimaryPart
		if base ~= nil and chestModel:GetAttribute("Opened") ~= true then
			if playerHasZone(data, chestModel:GetAttribute("Zone")) then
				local distance = (base.Position - position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestChest = chestModel
				end
			end
		end
	end
	return nearestChest
end

local function findNearestCoin(data, position, radius)
	local nearestCoin = nil
	local nearestDistance = radius
	for _, coinModel in ipairs(coinsFolder:GetChildren()) do
		if coinModel:GetAttribute("Collected") ~= true then
			if playerHasZone(data, coinModel:GetAttribute("Zone")) then
				local distance = (coinModel:GetAttribute("BasePosition") - position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestCoin = coinModel
				end
			end
		end
	end
	return nearestCoin
end

----------------------------------------------------------------
-- Katana
----------------------------------------------------------------

local function onKatanaSwing(player, tool)
	local data = playerData[player]
	if data == nil then
		return
	end
	if data.Unlocks.Katana ~= true then
		return
	end
	local now = os.clock()
	if now - lastSwingTime[player] < Config.KatanaCooldown then
		return
	end
	lastSwingTime[player] = now

	local character = player.Character
	if character == nil then
		return
	end

	-- Every client plays the horizontal slash (the swinger has already played it locally)
	fxEvent:FireAllClients("Slash", character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return
	end

	local katanaDamage = Config.GetValue("KatanaPower", data.Upgrades.KatanaPower)
	Enemies.HitInRange(player, rootPart.Position, Config.KatanaEnemyRange, katanaDamage)

	for _, chestModel in ipairs(chestsFolder:GetChildren()) do
		local base = chestModel.PrimaryPart
		if base ~= nil then
			if playerHasZone(data, chestModel:GetAttribute("Zone")) then
				local distance = (base.Position - rootPart.Position).Magnitude
				if distance <= Config.KatanaRange then
					hitChest(chestModel, player)
				end
			end
		end
	end
end

local function createKatanaTool(player)
	local tool = Instance.new("Tool")
	tool.Name = "Katana"
	tool.ToolTip = "Click near chests to slash them open"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 1.2, 0.3)
	handle.Color = Color3.fromRGB(30, 30, 30)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Parent = tool

	local function addKatanaPart(name, size, colour, material, offset)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = colour
		part.Material = material
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		part.Parent = tool

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	addKatanaPart("Guard", Vector3.new(0.8, 0.12, 0.8), GOLD, Enum.Material.Metal, CFrame.new(0, 0.66, 0))
	local blade = addKatanaPart("Blade", Vector3.new(0.1, 4, 0.3), Color3.fromRGB(215, 225, 235), Enum.Material.Metal, CFrame.new(0, 2.72, 0))

	-- Swoosh trail, switched on by clients during the swing
	local trailBase = Instance.new("Attachment")
	trailBase.Name = "TrailBase"
	trailBase.Position = Vector3.new(0, -1.6, 0)
	trailBase.Parent = blade

	local trailTip = Instance.new("Attachment")
	trailTip.Name = "TrailTip"
	trailTip.Position = Vector3.new(0, 2, 0)
	trailTip.Parent = blade

	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = trailBase
	trail.Attachment1 = trailTip
	trail.Lifetime = 0.18
	trail.MinLength = 0
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 220, 255))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Enabled = false
	trail.Parent = blade

	tool.Activated:Connect(function()
		onKatanaSwing(player, tool)
	end)
	return tool
end

local function giveKatana(player)
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack == nil then
		return
	end
	if backpack:FindFirstChild("Katana") ~= nil then
		return
	end
	local character = player.Character
	if character ~= nil then
		if character:FindFirstChild("Katana") ~= nil then
			return
		end
	end
	local tool = createKatanaTool(player)
	tool.Parent = backpack
end

----------------------------------------------------------------
-- Unlocks
----------------------------------------------------------------

local function applyUnlockEffects(player, unlockId)
	if unlockId == "Katana" then
		giveKatana(player)
	end
end

local function tryBuyUnlock(player, unlockId)
	local data = playerData[player]
	if data == nil then
		return false, "Loading..."
	end
	if type(unlockId) ~= "string" then
		return false, "Invalid"
	end
	local info = Config.Unlocks[unlockId]
	if info == nil then
		return false, "Invalid"
	end
	if data.Unlocks[unlockId] == true then
		return false, "Owned"
	end
	if data.Coins < info.Cost then
		return false, "Need more!"
	end

	data.Coins = data.Coins - info.Cost
	data.Unlocks[unlockId] = true
	updateLeaderstats(player)
	sendDataToClient(player)
	notifyEvent:FireClient(player, string.upper(info.DisplayName) .. " UNLOCKED!", info.UnlockMessage, true)
	task.spawn(applyUnlockEffects, player, unlockId)
	return true, "Unlocked!"
end

----------------------------------------------------------------
-- Zone building (walled zone with a gate on its +Z side)
----------------------------------------------------------------

local function makeZonePart(parent, name, size, cframe, colour, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function buildWallSegment(parent, zone, centerX, centerZ, sizeX, sizeZ, baseY)
	makeZonePart(parent, "Fence", Vector3.new(sizeX, Config.FenceHeight, sizeZ), CFrame.new(centerX, baseY + Config.FenceHeight / 2, centerZ), zone.FenceColor, Enum.Material.WoodPlanks, 0, true)
	makeZonePart(parent, "Barrier", Vector3.new(sizeX, Config.BarrierHeight, sizeZ), CFrame.new(centerX, baseY + Config.BarrierHeight / 2, centerZ), zone.FenceColor, Enum.Material.SmoothPlastic, 1, true)
end

local function buildZone(zoneId)
	local zone = Config.Zones[zoneId]
	local zoneFolder = makeFolder(zoneId, zonesFolder)

	local groundY = 0
	local ground = findGround(zone.Center, Config.SpawnRayHeight, Config.SpawnRayHeight * 2)
	if ground ~= nil then
		groundY = ground.Y
	end
	local baseY = groundY + 0.1
	local half = zone.Size / 2
	local cx = zone.Center.X
	local cz = zone.Center.Z

	-- Floor
	local floor = makeZonePart(zoneFolder, "Floor", Vector3.new(zone.Size + 4, 1, zone.Size + 4), CFrame.new(cx, baseY - 0.5, cz), zone.FloorColor, zone.FloorMaterial, 0, true)
	floor.CanQuery = true

	-- South, west and east walls
	buildWallSegment(zoneFolder, zone, cx, cz - half, zone.Size + 2, 2, baseY)
	buildWallSegment(zoneFolder, zone, cx - half, cz, 2, zone.Size + 2, baseY)
	buildWallSegment(zoneFolder, zone, cx + half, cz, 2, zone.Size + 2, baseY)

	-- North wall with a gap for the gate
	local gateHalf = Config.GateWidth / 2
	local segmentLength = half - gateHalf
	local gateZ = cz + half
	buildWallSegment(zoneFolder, zone, cx - gateHalf - segmentLength / 2, gateZ, segmentLength, 2, baseY)
	buildWallSegment(zoneFolder, zone, cx + gateHalf + segmentLength / 2, gateZ, segmentLength, 2, baseY)

	-- Red ninja gate frame
	-- Posts are thicker than the fence so their faces never share a plane with it (no z-fighting)
	local postThickness = 2.8
	local baseCollarSize = Vector3.new(postThickness + 0.6, 3, postThickness + 0.6)
	local postLeftX = cx - gateHalf - 1
	local postRightX = cx + gateHalf + 1
	makeZonePart(zoneFolder, "GatePostLeft", Vector3.new(postThickness, 18, postThickness), CFrame.new(postLeftX, baseY + 9, gateZ), GATE_RED, Enum.Material.SmoothPlastic, 0, true)
	makeZonePart(zoneFolder, "GatePostRight", Vector3.new(postThickness, 18, postThickness), CFrame.new(postRightX, baseY + 9, gateZ), GATE_RED, Enum.Material.SmoothPlastic, 0, true)

	-- Black base collars, as on traditional torii
	makeZonePart(zoneFolder, "GatePostBaseLeft", baseCollarSize, CFrame.new(postLeftX, baseY + 1.5, gateZ), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, 0, true)
	makeZonePart(zoneFolder, "GatePostBaseRight", baseCollarSize, CFrame.new(postRightX, baseY + 1.5, gateZ), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, 0, true)
	makeZonePart(zoneFolder, "GateBeamTop", Vector3.new(Config.GateWidth + 10, 1.5, 2.5), CFrame.new(cx, baseY + 18.75, gateZ), GATE_RED, Enum.Material.SmoothPlastic, 0, true)
	makeZonePart(zoneFolder, "GateBeamLower", Vector3.new(Config.GateWidth + 4, 1, 1.5), CFrame.new(cx, baseY + 15.5, gateZ), GATE_RED, Enum.Material.SmoothPlastic, 0, true)

	-- Door and invisible barrier (clients hide these locally once unlocked)
	local door = makeZonePart(zoneFolder, "GateDoor", Vector3.new(Config.GateWidth, 14, 1), CFrame.new(cx, baseY + 7, gateZ), PAPER, Enum.Material.SmoothPlastic, 0.15, true)
	local doorBarrier = makeZonePart(zoneFolder, "GateBarrier", Vector3.new(Config.GateWidth, Config.BarrierHeight, 2), CFrame.new(cx, baseY + Config.BarrierHeight / 2, gateZ), PAPER, Enum.Material.SmoothPlastic, 1, true)
	for _, blocker in ipairs({ door, doorBarrier }) do
		blocker:SetAttribute("UnlockId", zone.RequiredUnlock)
		CollectionService:AddTag(blocker, GATE_TAG)
	end

	local unlockInfo = Config.Unlocks[zone.RequiredUnlock]

	local lockGui = Instance.new("BillboardGui")
	lockGui.Size = UDim2.new(12, 0, 3, 0)
	lockGui.StudsOffset = Vector3.new(0, 1, 0)
	lockGui.MaxDistance = 150
	lockGui.Parent = door

	local lockTitle = Instance.new("TextLabel")
	lockTitle.Size = UDim2.new(1, 0, 0.55, 0)
	lockTitle.BackgroundTransparency = 1
	lockTitle.Font = Enum.Font.FredokaOne
	lockTitle.Text = "🔒 " .. zone.DisplayName
	lockTitle.TextColor3 = Color3.new(1, 1, 1)
	lockTitle.TextStrokeTransparency = 0.2
	lockTitle.TextScaled = true
	lockTitle.Parent = lockGui

	local lockCost = Instance.new("TextLabel")
	lockCost.Position = UDim2.new(0, 0, 0.55, 0)
	lockCost.Size = UDim2.new(1, 0, 0.45, 0)
	lockCost.BackgroundTransparency = 1
	lockCost.Font = Enum.Font.FredokaOne
	lockCost.Text = "📜 " .. Config.FormatNumber(unlockInfo.Cost) .. "  -  coins worth x" .. zone.CoinValue
	lockCost.TextColor3 = GOLD
	lockCost.TextStrokeTransparency = 0.2
	lockCost.TextScaled = true
	lockCost.Parent = lockGui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock for " .. Config.FormatNumber(unlockInfo.Cost)
	prompt.ObjectText = zone.DisplayName
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	prompt.Triggered:Connect(function(player)
		local success, message = tryBuyUnlock(player, zone.RequiredUnlock)
		if success == false then
			notifyEvent:FireClient(player, "Locked", "You need 📜 " .. Config.FormatNumber(unlockInfo.Cost) .. " Scroll-Coins", false)
		end
	end)

	-- Bamboo stalks (CanQuery off so coins never spawn on top of them)
	for index = 1, zone.DecorCount do
		local stalkHeight = rng:NextNumber(12, 26)
		local x = cx + rng:NextNumber(-half + 4, half - 4)
		local z = cz + rng:NextNumber(-half + 4, half - 12)
		local stalk = makeZonePart(zoneFolder, "Stalk", Vector3.new(stalkHeight, 1.1, 1.1), CFrame.new(x, baseY + stalkHeight / 2, z) * CFrame.Angles(0, 0, math.rad(90)), zone.DecorColor, Enum.Material.SmoothPlastic, 0, true)
		stalk.Shape = Enum.PartType.Cylinder
	end
end

----------------------------------------------------------------
-- Coyo
----------------------------------------------------------------

local function addCoyoPart(model, body, name, size, colour, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = body.CFrame * offset
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function removeCoyo(player)
	local petState = playerPets[player]
	if petState ~= nil then
		if petState.Model ~= nil then
			petState.Model:Destroy()
		end
		playerPets[player] = nil
	end
end

local function createCoyo(player, character)
	removeCoyo(player)

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if rootPart == nil then
		return
	end
	if character.Parent == nil then
		return
	end

	local model = Instance.new("Model")
	model.Name = player.Name .. "_Coyo"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.4, 1.2, 2.6)
	body.Color = COYO_FUR
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CFrame = rootPart.CFrame * CFrame.new(Config.CoyoFollowOffset)
	body.Parent = model
	model.PrimaryPart = body

	-- Head and face (front of Coyo is -Z)
	local head = addCoyoPart(model, body, "Head", Vector3.new(1.2, 1.1, 1.2), COYO_FUR, CFrame.new(0, 0.7, -1.6))
	addCoyoPart(model, body, "Snout", Vector3.new(0.7, 0.5, 0.7), COYO_LIGHT, CFrame.new(0, 0.5, -2.45))
	addCoyoPart(model, body, "Nose", Vector3.new(0.3, 0.25, 0.1), COYO_BLACK, CFrame.new(0, 0.65, -2.82))
	addCoyoPart(model, body, "EyeLeft", Vector3.new(0.2, 0.2, 0.05), COYO_BLACK, CFrame.new(-0.3, 0.9, -2.22))
	addCoyoPart(model, body, "EyeRight", Vector3.new(0.2, 0.2, 0.05), COYO_BLACK, CFrame.new(0.3, 0.9, -2.22))
	addCoyoPart(model, body, "EarLeft", Vector3.new(0.3, 0.6, 0.2), COYO_DARK, CFrame.new(-0.38, 1.5, -1.5))
	addCoyoPart(model, body, "EarRight", Vector3.new(0.3, 0.6, 0.2), COYO_DARK, CFrame.new(0.38, 1.5, -1.5))

	-- Ninja headband with trailing ties
	addCoyoPart(model, body, "Headband", Vector3.new(1.26, 0.25, 1.26), NINJA_RED, CFrame.new(0, 1.0, -1.6))
	addCoyoPart(model, body, "BandTieLeft", Vector3.new(0.15, 0.2, 0.8), NINJA_RED, CFrame.new(-0.2, 0.95, -0.75) * CFrame.Angles(math.rad(-15), math.rad(-10), 0))
	addCoyoPart(model, body, "BandTieRight", Vector3.new(0.15, 0.2, 0.8), NINJA_RED, CFrame.new(0.2, 0.95, -0.75) * CFrame.Angles(math.rad(-15), math.rad(10), 0))

	-- Tail and legs
	addCoyoPart(model, body, "Tail", Vector3.new(0.35, 0.35, 1.4), COYO_DARK, CFrame.new(0, 0.55, 1.9) * CFrame.Angles(math.rad(-25), 0, 0))
	addCoyoPart(model, body, "LegFrontLeft", Vector3.new(0.35, 0.9, 0.35), COYO_FUR, CFrame.new(-0.45, -1.05, -0.9))
	addCoyoPart(model, body, "LegFrontRight", Vector3.new(0.35, 0.9, 0.35), COYO_FUR, CFrame.new(0.45, -1.05, -0.9))
	addCoyoPart(model, body, "LegBackLeft", Vector3.new(0.35, 0.9, 0.35), COYO_FUR, CFrame.new(-0.45, -1.05, 0.9))
	addCoyoPart(model, body, "LegBackRight", Vector3.new(0.35, 0.9, 0.35), COYO_FUR, CFrame.new(0.45, -1.05, 0.9))

	-- Movement constraints
	local attachment = Instance.new("Attachment")
	attachment.Parent = body

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 50000
	alignPosition.Responsiveness = 30
	alignPosition.MaxVelocity = Config.Upgrades.CoyoSpeed.BaseValue
	alignPosition.Position = body.Position
	alignPosition.Parent = body

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 50000
	alignOrientation.Responsiveness = 20
	alignOrientation.CFrame = body.CFrame.Rotation
	alignOrientation.Parent = body

	-- Name tag
	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.new(4, 0, 1, 0)
	nameTag.StudsOffset = Vector3.new(0, 1.6, 0)
	nameTag.MaxDistance = 60
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = "Coyo"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextScaled = true
	nameLabel.Parent = nameTag

	model.Parent = petsFolder
	body:SetNetworkOwner(nil)

	playerPets[player] = {
		Model = model,
		Body = body,
		RootPart = rootPart,
		AlignPosition = alignPosition,
		AlignOrientation = alignOrientation,
		TargetCoin = nil,
		HopTime = 0,
		LastBite = 0,
	}
end

local function updateCoyo(player, petState, deltaTime)
	local data = playerData[player]
	if data == nil then
		return
	end
	local rootPart = petState.RootPart
	local body = petState.Body
	if rootPart.Parent == nil or body.Parent == nil then
		return
	end

	local sniffRadius = Config.GetValue("CoyoSniff", data.Upgrades.CoyoSniff)
	local coyoSpeed = Config.GetValue("CoyoSpeed", data.Upgrades.CoyoSpeed)
	local ninjaSpeed = Config.GetValue("NinjaSpeed", data.Upgrades.NinjaSpeed)

	-- Drop the current target if it's gone or the ninja wandered away from it
	local targetCoin = petState.TargetCoin
	if targetCoin ~= nil then
		if targetCoin.Parent == nil or targetCoin:GetAttribute("Collected") == true then
			targetCoin = nil
		else
			local coinDistanceFromNinja = (targetCoin:GetAttribute("BasePosition") - rootPart.Position).Magnitude
			if coinDistanceFromNinja > sniffRadius * 1.5 then
				targetCoin = nil
			end
		end
	end
	if targetCoin == nil then
		targetCoin = findNearestCoin(data, rootPart.Position, sniffRadius)
	end
	petState.TargetCoin = targetCoin

	-- Enemies near the ninja come first, then chests, then coins
	local targetEnemy = Enemies.FindNearestEnemy(player, rootPart.Position, Config.CoyoEnemyRange)
	local targetChest = findNearestChest(data, rootPart.Position, math.max(sniffRadius, Config.CoyoChestRange))

	-- Pick where Coyo wants to be
	local goalPosition = nil
	if targetEnemy ~= nil then
		goalPosition = targetEnemy.Root.Position
		petState.AlignPosition.MaxVelocity = coyoSpeed + 8
		if (body.Position - goalPosition).Magnitude < Config.CoyoBiteRange then
			local now = os.clock()
			if now - petState.LastBite >= Config.CoyoBiteCooldown then
				petState.LastBite = now
				Enemies.DamageEnemy(player, targetEnemy, Config.GetValue("CoyoBite", data.Upgrades.CoyoBite))
			end
		end
	elseif targetChest ~= nil then
		goalPosition = targetChest.PrimaryPart.Position
		petState.AlignPosition.MaxVelocity = coyoSpeed
		if (body.Position - goalPosition).Magnitude < Config.CoyoBiteRange then
			local now = os.clock()
			if now - petState.LastBite >= Config.CoyoBiteCooldown then
				petState.LastBite = now
				hitChest(targetChest, player)
			end
		end
	elseif targetCoin ~= nil then
		goalPosition = targetCoin:GetAttribute("BasePosition")
		petState.AlignPosition.MaxVelocity = coyoSpeed
	else
		goalPosition = (rootPart.CFrame * CFrame.new(Config.CoyoFollowOffset)).Position
		petState.AlignPosition.MaxVelocity = math.max(coyoSpeed, ninjaSpeed + 6)
	end

	-- Keep Coyo standing on the ground
	local groundPosition = findGround(goalPosition, 8, 120)
	if groundPosition ~= nil then
		goalPosition = Vector3.new(goalPosition.X, groundPosition.Y + Config.CoyoHeight, goalPosition.Z)
	else
		goalPosition = Vector3.new(goalPosition.X, rootPart.Position.Y - Config.CoyoHeight, goalPosition.Z)
	end

	local flatOffset = Vector3.new(goalPosition.X - body.Position.X, 0, goalPosition.Z - body.Position.Z)
	local distanceToGoal = flatOffset.Magnitude

	-- Teleport to the ninja if left far behind
	if (body.Position - rootPart.Position).Magnitude > Config.CoyoTeleportDistance then
		petState.Model:PivotTo(CFrame.new(goalPosition))
		distanceToGoal = 0
	end

	-- Little hops while running
	if distanceToGoal > 1.5 then
		petState.HopTime = petState.HopTime + deltaTime * Config.CoyoHopSpeed
		local hop = math.abs(math.sin(petState.HopTime)) * Config.CoyoHopHeight
		goalPosition = goalPosition + Vector3.new(0, hop, 0)
	else
		petState.HopTime = 0
	end
	petState.AlignPosition.Position = goalPosition

	-- Face the running direction, or the same way as the ninja when resting
	local faceDirection = nil
	if distanceToGoal > 1.5 then
		faceDirection = flatOffset.Unit
	else
		local look = rootPart.CFrame.LookVector
		faceDirection = Vector3.new(look.X, 0, look.Z)
	end
	if faceDirection.Magnitude > 0.01 then
		petState.AlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, faceDirection.Unit)
	end

	-- Grab the coin once close enough
	if targetCoin ~= nil then
		local coinPosition = targetCoin:GetAttribute("BasePosition")
		if (body.Position - coinPosition).Magnitude < Config.CoyoCollectDistance then
			petState.TargetCoin = nil
			collectCoin(targetCoin, player)
		end
	end
end

----------------------------------------------------------------
-- Players
----------------------------------------------------------------

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil then
		return
	end
	applyCharacterStats(player)
	refreshRayFilter()

	local data = playerData[player]
	if data ~= nil then
		if data.Unlocks.Katana == true then
			task.spawn(giveKatana, player)
		end
	end

	createCoyo(player, character)
	Wardrobe.ApplyCoat(player)
	Wardrobe.ApplyOutfit(player, character, true)
end

local function onPlayerAdded(player)
	lastSwingTime[player] = 0

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Scroll-Coins"
	coinsValue.Value = 0
	coinsValue.Parent = leaderstats

	local data, loadedOk = loadData(player)
	if player.Parent == nil then
		return
	end
	playerData[player] = data
	playerLoadedOk[player] = loadedOk

	updateLeaderstats(player)
	sendDataToClient(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		removeCoyo(player)
		task.defer(refreshRayFilter)
	end)
	if player.Character ~= nil then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	saveData(player)
	removeCoyo(player)
	playerData[player] = nil
	playerLoadedOk[player] = nil
	lastSwingTime[player] = nil
	refreshRayFilter()
end

buyUpgradeFunction.OnServerInvoke = function(player, upgradeId)
	local data = playerData[player]
	if data == nil then
		return false, "Loading..."
	end
	if type(upgradeId) ~= "string" then
		return false, "Invalid"
	end
	local info = Config.Upgrades[upgradeId]
	if info == nil then
		return false, "Invalid"
	end

	local currentLevel = data.Upgrades[upgradeId]
	if currentLevel >= info.MaxLevel then
		return false, "MAX"
	end
	local cost = Config.GetCost(upgradeId, currentLevel)
	if data.Coins < cost then
		return false, "Need more!"
	end

	data.Coins = data.Coins - cost
	data.Upgrades[upgradeId] = currentLevel + 1
	updateLeaderstats(player)
	applyCharacterStats(player)
	sendDataToClient(player)
	return true, "Upgraded!"
end

buyUnlockFunction.OnServerInvoke = function(player, unlockId)
	return tryBuyUnlock(player, unlockId)
end

getDataFunction.OnServerInvoke = function(player)
	return playerData[player]
end

----------------------------------------------------------------
-- Start up
----------------------------------------------------------------

local World = require(script.Parent:WaitForChild("NinjaCoyoWorld"))
World.Build()

Wardrobe.Init({
	PlayerData = playerData,
	GetCoyoModel = function(player)
		local petState = playerPets[player]
		if petState == nil then
			return nil
		end
		return petState.Model
	end,
	NotifyEvent = notifyEvent,
})

Enemies.Init({
	PlayerData = playerData,
	AddCoins = addCoins,
	FxEvent = fxEvent,
	NotifyEvent = notifyEvent,
})

for _, zoneId in ipairs(Config.ZoneOrder) do
	if Config.Zones[zoneId].Build == true then
		buildZone(zoneId)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

RunService.Heartbeat:Connect(function(deltaTime)
	for player, petState in pairs(playerPets) do
		updateCoyo(player, petState, deltaTime)
	end
end)

-- Coin and chest spawner
task.spawn(function()
	for _, zoneId in ipairs(Config.ZoneOrder) do
		local zone = Config.Zones[zoneId]
		spawnZoneItems(zoneId, zone.MaxCoins, zone.MaxChests)
	end
	while true do
		task.wait(Config.CoinSpawnInterval)
		for _, zoneId in ipairs(Config.ZoneOrder) do
			spawnZoneItems(zoneId, Config.CoinSpawnBatch, Config.ChestSpawnBatch)
		end
	end
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(Config.AutoSaveSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending = pending + 1
		task.spawn(function()
			saveData(player)
			pending = pending - 1
		end)
	end
	local startTime = os.clock()
	while pending > 0 and os.clock() - startTime < 25 do
		task.wait()
	end
end)