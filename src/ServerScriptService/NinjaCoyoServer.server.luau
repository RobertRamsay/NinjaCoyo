-- NinjaCoyoServer (Script in ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local Enemies = require(script.Parent:WaitForChild("NinjaCoyoEnemies"))
local Wardrobe = require(script.Parent:WaitForChild("NinjaCoyoWardrobe"))
local Scenery = require(script.Parent:WaitForChild("NinjaCoyoScenery"))

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
local gateOpenedEvent = makeRemote("RemoteEvent", "GateOpened")
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
	data.DogCoats = {}
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
		if type(stored.DogCoats) == "table" then
			for index = 1, #Config.CoyoPackNames do
				local coatId = stored.DogCoats[tostring(index)]
				if type(coatId) == "string" and Config.Wardrobe.Coats[coatId] ~= nil then
					data.DogCoats[tostring(index)] = coatId
				end
			end
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
	character:SetAttribute("JumpLevel", data.Upgrades.NinjaJump)
	character:SetAttribute("KatanaLevel", data.Upgrades.KatanaPower)

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

local spawnCell = {}
local function getRandomGroundInZone(zone, terrace)
	local half = zone.Size / 2 - zone.SpawnMargin
	local low = zone.SpawnMin or Vector2.new(zone.Center.X - half, zone.Center.Z - half)
	local high = zone.SpawnMax or Vector2.new(zone.Center.X + half, zone.Center.Z + half)
	-- Cycle a 4 x 3 grid rather than allowing random clusters near the centre.
	local cell = spawnCell[zone] or 0
	spawnCell[zone] = (cell + 1) % 12
	local x = low.X + ((cell % 4) + rng:NextNumber(0.1, 0.9)) * (high.X - low.X) / 4
	local z = low.Y + (math.floor(cell / 4) + rng:NextNumber(0.1, 0.9)) * (high.Y - low.Y) / 3
	if terrace then
		x = terrace.Center.X + rng:NextNumber(-terrace.Radius * 0.5, terrace.Radius * 0.5)
		z = terrace.Center.Z + rng:NextNumber(-terrace.Radius * 0.5, terrace.Radius * 0.5)
	end
	local origin = Vector3.new(x, zone.Center.Y + Config.SpawnRayHeight, z)
	local result = workspace:Raycast(origin, Vector3.new(0, -Config.SpawnRayHeight * 2, 0), rayParams)
	if result == nil then
		return nil
	end
	if result.Material == Enum.Material.Water then
		return nil
	end
	if result.Normal.Y < 0.85 or not Scenery.IsPickupClear(result.Position) then
		return nil
	end
	for _, chest in ipairs(chestsFolder:GetChildren()) do
		if chest.PrimaryPart and (chest.PrimaryPart.Position - result.Position).Magnitude < 7 then return nil end
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
	local terrace = nil
	-- Fill each summit before ordinary chests so elevated treasure is always present.
	for _, hill in ipairs(Config.TreasureTerraces) do
		if hill.Zone == zoneId then
			local occupied = false
			for _, chest in ipairs(chestsFolder:GetChildren()) do
				local p = chest.PrimaryPart
				if p and Vector2.new(p.Position.X - hill.Center.X, p.Position.Z - hill.Center.Z).Magnitude < hill.Radius then
					occupied = true
					break
				end
			end
			if not occupied then terrace = hill; break end
		end
	end
	local ground = getRandomGroundInZone(zone, terrace)
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

local function findNearestCoin(data, position, radius, claimedCoins)
	local nearestCoin = nil
	local nearestDistance = radius
	for _, coinModel in ipairs(coinsFolder:GetChildren()) do
		if coinModel:GetAttribute("Collected") ~= true and claimedCoins[coinModel] ~= true then
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
	if player:GetAttribute("MenuProtected") == true then return end
	local data = playerData[player]
	if data == nil then
		return
	end
	if data.Unlocks.Katana ~= true and not Wardrobe.OwnsGoldSword(player) then
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

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if tool.Parent ~= character or humanoid == nil or humanoid.Health <= 0 then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return
	end

	-- Facing is corrected once by the attacking client. Do not snap it again
	-- when this request arrives; the player may already be moving elsewhere.
	fxEvent:FireAllClients("Slash", character)
	local katanaDamage = Config.GetValue("KatanaPower", data.Upgrades.KatanaPower)
	Enemies.HitInRange(player, rootPart.Position, Config.KatanaEnemyRange, katanaDamage, Wardrobe.OwnsGoldSword(player))

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

local function styleKatana(player, tool)
	local gold = Wardrobe.OwnsGoldSword(player)
	tool:SetAttribute("GoldSword", gold)
	tool.ToolTip = gold and "Super Gold Sword: one-hit defeat for enemies" or "Attack nearby enemies and chests"
	local blade = tool:FindFirstChild("Blade")
	if blade then
		blade.Color = gold and GOLD or Color3.fromRGB(215, 225, 235)
		blade.Material = gold and Enum.Material.Neon or Enum.Material.Metal
		blade.Size = gold and Vector3.new(0.22, 4.6, 0.5) or Vector3.new(0.1, 4, 0.3)
		local trail = blade:FindFirstChild("SlashTrail")
		if trail then trail.Color = gold and ColorSequence.new(GOLD, Color3.fromRGB(255, 245, 185))
			or ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 220, 255)) end
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

	styleKatana(player, tool)
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

local function refreshGoldSword(player)
	local data = playerData[player]
	if player.Parent == nil or data == nil or not Wardrobe.OwnsGoldSword(player) then return end
	-- The pass includes the base katana, even for a brand-new player.
	data.Unlocks.Katana = true
	sendDataToClient(player)
	task.spawn(function()
		giveKatana(player)
		for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character }) do
			local tool = container and container:FindFirstChild("Katana")
			if tool then styleKatana(player, tool) end
		end
	end)
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
	for _, zoneId in ipairs(Config.ZoneOrder) do
		if Config.Zones[zoneId].RequiredUnlock == unlockId then
			gateOpenedEvent:FireClient(player, unlockId)
			break
		end
	end
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

----------------------------------------------------------------
-- Zone decor (CanQuery is off on everything, so coins never spawn on top of it)
----------------------------------------------------------------

local function randomDecorSpot(zone)
	-- Keep a clear lane down the middle between the gate and the back opening
	local half = zone.Size / 2
	for attempt = 1, 20 do
		local x = zone.Center.X + rng:NextNumber(-half + 5, half - 5)
		local z = zone.Center.Z + rng:NextNumber(-half + 12, half - 12)
		local clear = Scenery.IsPickupClear(Vector3.new(x, 0, z))
		for _, hill in ipairs(Config.TreasureTerraces) do
			if Vector2.new(x - hill.Center.X, z - hill.Center.Z).Magnitude < hill.Radius * 1.7 then clear = false end
		end
		if clear and math.abs(x - zone.Center.X) > 10 then
			return x, z
		end
	end
	return zone.Center.X + half - 10, zone.Center.Z
end

local function makeColumn(parent, name, height, diameter, x, baseY, z, colour, material, canCollide)
	local part = makeZonePart(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, baseY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)), colour, material, 0, canCollide)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeDisc(parent, name, thickness, diameter, x, y, z, colour, material, canCollide)
	local part = makeZonePart(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), colour, material, 0, canCollide)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local DECOR_TRUNK = Color3.fromRGB(92, 62, 46)
local DECOR_SNOW = Color3.fromRGB(245, 248, 255)
local DECOR_ROCK = Color3.fromRGB(40, 34, 32)
local DECOR_CRYSTAL_ALT = Color3.fromRGB(110, 220, 255)

local function buildZoneDecor(parent, zone, baseY)
	for index = 1, zone.DecorCount do
		local x, z = randomDecorSpot(zone)

		if zone.DecorType == "Bamboo" then
			makeColumn(parent, "Stalk", rng:NextNumber(12, 26), 1.1, x, baseY, z, zone.DecorColor, Enum.Material.SmoothPlastic, true)

		elseif zone.DecorType == "Sakura" then
			local trunkHeight = rng:NextNumber(6, 9)
			makeColumn(parent, "Trunk", trunkHeight, 1.4, x, baseY, z, DECOR_TRUNK, Enum.Material.Wood, true)
			for blossom = 1, 4 do
				local radius = rng:NextNumber(3.5, 5.5)
				local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.5, 2), rng:NextNumber(-3, 3))
				local ball = makeZonePart(parent, "Blossom", Vector3.new(radius * 2, radius * 2, radius * 2), CFrame.new(Vector3.new(x, baseY + trunkHeight, z) + offset), zone.DecorColor, Enum.Material.Grass, 0, false)
				ball.Shape = Enum.PartType.Ball
			end

		elseif zone.DecorType == "SnowPine" then
			local trunkHeight = rng:NextNumber(4, 6)
			makeColumn(parent, "Trunk", trunkHeight, 1.2, x, baseY, z, DECOR_TRUNK, Enum.Material.Wood, true)
			for layer = 1, 4 do
				local layerY = baseY + trunkHeight + (layer - 1) * 2.4
				local diameter = 10 - layer * 1.9
				makeDisc(parent, "Needles", 1.6, diameter, x, layerY, z, zone.DecorColor, Enum.Material.Grass, false)
				makeDisc(parent, "SnowCap", 0.4, diameter * 0.9, x, layerY + 1, z, DECOR_SNOW, Enum.Material.Snow, false)
			end

		elseif zone.DecorType == "Volcano" then
			if rng:NextNumber() < 0.55 then
				-- Jagged rock spire
				local height = rng:NextNumber(6, 16)
				local width = rng:NextNumber(2.5, 5)
				makeZonePart(parent, "Spire", Vector3.new(width, height, width), CFrame.new(x, baseY + height / 2 - 1, z) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-12, 12))), DECOR_ROCK, Enum.Material.Basalt, 0, true)
			else
				-- Glowing lava pool
				local pool = makeDisc(parent, "Lava", 0.3, rng:NextNumber(6, 12), x, baseY + 0.1, z, zone.DecorColor, Enum.Material.Neon, false)
				local glow = Instance.new("PointLight")
				glow.Color = zone.DecorColor
				glow.Range = 14
				glow.Brightness = 1.2
				glow.Parent = pool
			end

		elseif zone.DecorType == "Spirit" then
			-- Floating glowing crystal
			local height = rng:NextNumber(4, 10)
			local colour = zone.DecorColor
			if rng:NextNumber() < 0.4 then
				colour = DECOR_CRYSTAL_ALT
			end
			local crystal = makeZonePart(parent, "Crystal", Vector3.new(1.6, height, 1.6), CFrame.new(x, baseY + height / 2 + rng:NextNumber(1, 4), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-15, 15))), colour, Enum.Material.Neon, 0.15, false)
			local glow = Instance.new("PointLight")
			glow.Color = colour
			glow.Range = 12
			glow.Brightness = 1
			glow.Parent = crystal
		end
	end
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

	-- South (back) wall: open in the middle if another zone lies beyond it
	local gateHalf = Config.GateWidth / 2
	local segmentLength = half - gateHalf
	local hasNextZone = false
	local foundThisZone = false
	for _, otherZoneId in ipairs(Config.ZoneOrder) do
		if foundThisZone and Config.Zones[otherZoneId].Build == true then
			hasNextZone = true
		end
		if otherZoneId == zoneId then
			foundThisZone = true
		end
	end
	if hasNextZone then
		buildWallSegment(zoneFolder, zone, cx - gateHalf - segmentLength / 2, cz - half, segmentLength, 2, baseY)
		buildWallSegment(zoneFolder, zone, cx + gateHalf + segmentLength / 2, cz - half, segmentLength, 2, baseY)
	else
		buildWallSegment(zoneFolder, zone, cx, cz - half, zone.Size + 2, 2, baseY)
	end

	-- West and east walls
	buildWallSegment(zoneFolder, zone, cx - half, cz, 2, zone.Size + 2, baseY)
	buildWallSegment(zoneFolder, zone, cx + half, cz, 2, zone.Size + 2, baseY)

	-- North wall with a gap for the gate
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
	-- Float the sign in front of the paper door (towards the approaching player) so it
	-- never shares depth with the door and flickers
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 0, 2.5)
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

	buildZoneDecor(zoneFolder, zone, baseY)
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

-- playerPets[player] is the player's pack: a list of dog states (Coyo, Kiba, Yuki, Hana)
local function removeCoyo(player)
	local pack = playerPets[player]
	if pack ~= nil then
		for _, petState in ipairs(pack) do
			petState.Model:Destroy()
		end
		playerPets[player] = nil
	end
end

local function createCoyoDog(player, rootPart, index)
	local followOffset = Config.CoyoPackOffsets[index]
	local dogName = Config.CoyoPackNames[index]

	local model = Instance.new("Model")
	model.Name = player.Name .. "_" .. dogName
	model:SetAttribute("PackIndex", index)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.4, 1.2, 2.6)
	body.Color = COYO_FUR
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CFrame = rootPart.CFrame * CFrame.new(followOffset)
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
	nameLabel.Text = dogName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextScaled = true
	nameLabel.Parent = nameTag

	model.Parent = petsFolder
	body:SetNetworkOwner(nil)

	local petState = {
		Model = model,
		Body = body,
		RootPart = rootPart,
		AlignPosition = alignPosition,
		AlignOrientation = alignOrientation,
		FollowOffset = followOffset,
		TargetCoin = nil,
		TargetChest = nil,
		Pounce = nil,
		HopTime = 0,
		LastBite = 0,
	}
	return petState
end

local function createCoyo(player, character)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if rootPart == nil then
		return
	end
	if character.Parent == nil or player.Character ~= character or player.Parent == nil then
		return
	end
	-- Rebuild after the only yielding call, so overlapping requests cannot leave duplicates.
	removeCoyo(player)

	local packSize = 1
	local data = playerData[player]
	if data ~= nil then
		packSize = math.clamp(Config.GetValue("PackSize", data.Upgrades.PackSize), 1, #Config.CoyoPackNames)
	end

	local pack = {}
	for index = 1, packSize do
		table.insert(pack, createCoyoDog(player, rootPart, index))
	end
	playerPets[player] = pack
end

-- Reconcile saved entitlement even if a pack entry or an entire pack was lost.
local function ensureCoyoPack(player)
	local data = playerData[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not root or not humanoid or humanoid.Health <= 0 then return end
	local count = math.clamp(Config.GetValue("PackSize", data.Upgrades.PackSize), 1, #Config.CoyoPackNames)
	local pack = playerPets[player]
	if not pack or #pack ~= count then
		createCoyo(player, character)
		Wardrobe.ApplyCoat(player)
	end
end

-- Reset both the physical dog and its old job so it cannot be pulled back away.
local function recoverCoyo(petState)
	local root = petState.RootPart
	local position = (root.CFrame * CFrame.new(petState.FollowOffset)).Position
	local ground = findGround(position, 8, 120)
	position = Vector3.new(position.X, ground and ground.Y + Config.CoyoHeight or root.Position.Y, position.Z)
	petState.Model:PivotTo(CFrame.new(position) * root.CFrame.Rotation)
	petState.Body.AssemblyLinearVelocity = Vector3.zero
	petState.Body.AssemblyAngularVelocity = Vector3.zero
	petState.AlignPosition.Position = position
	petState.AlignOrientation.CFrame = root.CFrame.Rotation
	petState.TargetCoin = nil
	petState.TargetChest = nil
	petState.Pounce = nil
	petState.HopTime = 0
	petState.StuckTime = 0
	petState.ProgressPosition = position
	petState.RecoverUntil = os.clock() + 3
end

local function updateCoyo(player, petState, deltaTime, claimedCoins)
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
		if targetCoin.Parent == nil or targetCoin:GetAttribute("Collected") == true or claimedCoins[targetCoin] == true then
			targetCoin = nil
		else
			local coinDistanceFromNinja = (targetCoin:GetAttribute("BasePosition") - rootPart.Position).Magnitude
			if coinDistanceFromNinja > sniffRadius * 1.5 then
				targetCoin = nil
			end
		end
	end
	if targetCoin == nil and os.clock() >= (petState.RecoverUntil or 0) then
		targetCoin = findNearestCoin(data, rootPart.Position, sniffRadius, claimedCoins)
	end
	if targetCoin ~= nil then
		claimedCoins[targetCoin] = true
	end
	petState.TargetCoin = targetCoin

	-- A chosen chest remains the job until it opens, even if the ninja walks away.
	local targetChest = petState.TargetChest
	if targetChest ~= nil and (targetChest.Parent == nil or targetChest.PrimaryPart == nil
		or targetChest:GetAttribute("Opened") == true) then
		targetChest = nil
	end
	local now = os.clock()
	local pounce = petState.Pounce
	if pounce ~= nil and (pounce.Enemy.Dead or pounce.Enemy.Root.Parent == nil
		or pounce.Enemy.Humanoid.Health <= 0) then
		pounce = nil
		petState.Pounce = nil
	end
	local targetEnemy = nil
	if targetChest == nil and now >= (petState.RecoverUntil or 0) then
		targetEnemy = pounce and pounce.Enemy
			or Enemies.FindNearestEnemy(player, rootPart.Position, Config.CoyoEnemyRange)
		if targetEnemy == nil then
			targetChest = findNearestChest(data, rootPart.Position, math.max(sniffRadius, Config.CoyoChestRange))
		end
	end
	petState.TargetChest = targetChest

	-- Pick where Coyo wants to be
	local goalPosition = nil
	local faceTarget = nil
	local attackLift = 0
	if targetEnemy ~= nil then
		faceTarget = targetEnemy.Root.Position
		local away = Vector3.new(body.Position.X - faceTarget.X, 0, body.Position.Z - faceTarget.Z)
		local direction = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
		if pounce == nil and away.Magnitude <= Config.CoyoAttackStandOff + 1
			and now - petState.LastBite >= Config.CoyoBiteCooldown then
			pounce = { Enemy = targetEnemy, Started = now, Direction = direction, Hit = false }
			petState.Pounce = pounce
			petState.LastBite = now
		end
		local standOff = Config.CoyoAttackStandOff
		if pounce ~= nil then
			local phase = math.clamp((now - pounce.Started) / Config.CoyoPounceDuration, 0, 1)
			local leap = math.sin(phase * math.pi)
			direction = pounce.Direction
			standOff = standOff - (standOff - 2.2) * leap
			attackLift = Config.CoyoPounceHeight * leap
			-- Damage lands only once per leap and only when Coyo actually reaches the foe.
			if not pounce.Hit and phase >= 0.3 and phase <= 0.85
				and (body.Position - faceTarget).Magnitude <= Config.CoyoBiteRange then
				pounce.Hit = true
				Enemies.DamageEnemy(player, targetEnemy, Config.GetValue("CoyoBite", data.Upgrades.CoyoBite))
			end
			if phase >= 1 then
				petState.Pounce = nil
			end
		end
		goalPosition = faceTarget + direction * standOff
		petState.AlignPosition.MaxVelocity = math.max(coyoSpeed + 8, 32)
	elseif targetChest ~= nil then
		faceTarget = targetChest.PrimaryPart.Position
		local away = Vector3.new(body.Position.X - faceTarget.X, 0, body.Position.Z - faceTarget.Z)
		local direction = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
		goalPosition = faceTarget + direction * 3.2
		petState.AlignPosition.MaxVelocity = coyoSpeed
		if (body.Position - faceTarget).Magnitude < Config.CoyoBiteRange then
			if now - petState.LastBite >= Config.CoyoBiteCooldown then
				petState.LastBite = now
				hitChest(targetChest, player)
			end
		end
	elseif targetCoin ~= nil then
		goalPosition = targetCoin:GetAttribute("BasePosition")
		petState.AlignPosition.MaxVelocity = coyoSpeed
	else
		goalPosition = (rootPart.CFrame * CFrame.new(petState.FollowOffset)).Position
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

	-- Healthy chest work can finish away from the player, but no job bypasses
	-- the hard leash or the watchdog for a dog making no travel progress.
	local separation = (body.Position - rootPart.Position).Magnitude
	petState.ProgressPosition = petState.ProgressPosition or body.Position
	local progress = petState.ProgressPosition
	local moved = Vector3.new(body.Position.X - progress.X, 0, body.Position.Z - progress.Z).Magnitude
	if distanceToGoal <= 6 or moved >= 2 then
		petState.StuckTime = 0
		petState.ProgressPosition = body.Position
	else
		petState.StuckTime = (petState.StuckTime or 0) + deltaTime
	end
	local workingChest = targetChest ~= nil and now - petState.LastBite < 3
	if separation > Config.CoyoTeleportDistance * 3
		or (separation > Config.CoyoTeleportDistance and not workingChest)
		or body.Position.Y < rootPart.Position.Y - 60
		or (petState.StuckTime or 0) >= 5 then
		recoverCoyo(petState)
		return
	end

	-- Little hops while running
	if targetEnemy == nil and distanceToGoal > 1.5 then
		petState.HopTime = petState.HopTime + deltaTime * Config.CoyoHopSpeed
		local hop = math.abs(math.sin(petState.HopTime)) * Config.CoyoHopHeight
		goalPosition = goalPosition + Vector3.new(0, hop, 0)
	else
		petState.HopTime = 0
	end
	petState.AlignPosition.Position = goalPosition + Vector3.new(0, attackLift, 0)

	-- Face the running direction, or the same way as the ninja when resting
	local faceDirection = nil
	if faceTarget ~= nil then
		faceDirection = Vector3.new(faceTarget.X - body.Position.X, 0, faceTarget.Z - body.Position.Z)
	elseif distanceToGoal > 1.5 then
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
	refreshGoldSword(player)

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

	if upgradeId == "PackSize" and player.Character ~= nil then
		task.spawn(function()
			createCoyo(player, player.Character)
			Wardrobe.ApplyCoat(player)
			Wardrobe.Refresh(player)
			local count = Config.GetValue("PackSize", data.Upgrades.PackSize)
			notifyEvent:FireClient(player, Config.CoyoPackNames[count] .. " JOINS YOUR PACK!",
				"Choose each dog's look in the Dressing House", true)
		end)
	else
		Wardrobe.Refresh(player)
	end
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
	OnOwnershipReady = refreshGoldSword,
	GetCoyoModels = function(player)
		local models = {}
		local pack = playerPets[player]
		if pack ~= nil then
			for _, petState in ipairs(pack) do
				table.insert(models, petState.Model)
			end
		end
		return models
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

local packCheckTime = 0
RunService.Heartbeat:Connect(function(deltaTime)
	packCheckTime += deltaTime
	if packCheckTime >= 1 then
		packCheckTime = 0
		for player in pairs(playerData) do ensureCoyoPack(player) end
	end
	for player, pack in pairs(playerPets) do
		local claimedCoins = {}
		for index, petState in ipairs(pack) do
			local root = petState.RootPart
			if root.Parent ~= nil and player.Character == root.Parent then
				if petState.Model.Parent ~= petsFolder or petState.Body.Parent ~= petState.Model then
					petState.Model:Destroy()
					petState = createCoyoDog(player, root, index)
					pack[index] = petState
					recoverCoyo(petState)
					Wardrobe.ApplyCoat(player)
				end
				updateCoyo(player, petState, deltaTime, claimedCoins)
			end
		end
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
