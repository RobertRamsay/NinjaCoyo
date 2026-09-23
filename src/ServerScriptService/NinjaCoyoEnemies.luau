-- NinjaCoyoEnemies (ModuleScript in ServerScriptService)
-- Personal AI enemies: each ninja gets their own foes that chase and attack them.
-- Defeating one pays 2x-5x the ninja's current Scroll-Coins (kept between the level's
-- floor and cap) and makes the next foe one level tougher.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))

local Progression = require(script.Parent:WaitForChild("NinjaCoyoProgression"))
local Enemies = {}

local AI_STEP = 0.1
local SWORD_COLOUR = Color3.fromRGB(200, 205, 215)
local HORN_COLOUR = Color3.fromRGB(235, 225, 200)

-- State (initialised up front)
local context = {
	PlayerData = {},
	AddCoins = nil,
	FxEvent = nil,
	NotifyEvent = nil,
}
local enemiesByPlayer = {}
local spawnInProgress = {}
local aiAccumulator = 0
local rng = Random.new()

local enemiesFolder = Instance.new("Folder")
enemiesFolder.Name = "Enemies"

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function getZoneAt(position)
	for _, zoneId in ipairs(Config.ZoneOrder) do
		local zone = Config.Zones[zoneId]
		if zone.Build == true then
			local half = zone.Size / 2
			if math.abs(position.X - zone.Center.X) < half and math.abs(position.Z - zone.Center.Z) < half then
				return zoneId
			end
		end
	end
	return ""
end

local function findSpawnGround(position)
	local result = workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), groundParams)
	if result == nil then
		return nil
	end
	if result.Material == Enum.Material.Water then
		return nil
	end
	return result.Position
end

local function attachPart(model, anchorPart, name, size, colour, material, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = anchorPart.CFrame * offset
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function decorateEnemy(model, enemyType)
	local head = model:FindFirstChild("Head")
	if head ~= nil then
		local headSize = head.Size
		attachPart(model, head, "Headband", Vector3.new(headSize.X * 1.06, headSize.Y * 0.18, headSize.Z * 1.06), enemyType.AccentColor, Enum.Material.SmoothPlastic, CFrame.new(0, headSize.Y * 0.22, 0))
		attachPart(model, head, "Mask", Vector3.new(headSize.X * 1.04, headSize.Y * 0.36, headSize.Z * 0.55), enemyType.BodyColor, Enum.Material.Fabric, CFrame.new(0, -headSize.Y * 0.2, -headSize.Z * 0.24))
		if enemyType.Horns == true then
			local hornSize = Vector3.new(headSize.X * 0.18, headSize.Y * 0.45, headSize.Z * 0.18)
			attachPart(model, head, "HornLeft", hornSize, HORN_COLOUR, Enum.Material.SmoothPlastic, CFrame.new(-headSize.X * 0.32, headSize.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(20)))
			attachPart(model, head, "HornRight", hornSize, HORN_COLOUR, Enum.Material.SmoothPlastic, CFrame.new(headSize.X * 0.32, headSize.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(-20)))
		end
	end

	local rightHand = model:FindFirstChild("RightHand")
	if rightHand ~= nil then
		attachPart(model, rightHand, "Sword", Vector3.new(0.12, 0.25, 3.4), SWORD_COLOUR, Enum.Material.Metal, CFrame.new(0, -0.35, -1.6))
	end

	-- Raycasts (coin spawns, Coyo's ground check) ignore enemies
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
		end
	end
end

local function createHealthBar(head, enemyType, tier)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyGui"
	gui.Size = UDim2.new(5, 0, 1.4, 0)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = enemyType.Name .. "  Lv " .. tier
	nameLabel.TextColor3 = enemyType.AccentColor
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextScaled = true
	nameLabel.Parent = gui

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0.1, 0, 0.65, 0)
	barBack.Size = UDim2.new(0.8, 0, 0.28, 0)
	barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	return barFill
end

local function removeFromList(enemy)
	local list = enemiesByPlayer[enemy.Owner]
	if list == nil then
		return
	end
	for index = #list, 1, -1 do
		if list[index] == enemy then
			table.remove(list, index)
		end
	end
end

local function despawnEnemy(enemy)
	if enemy.Dead == true then
		return
	end
	enemy.Dead = true
	removeFromList(enemy)
	enemy.Model:Destroy()
end

local function onEnemyDied(enemy)
	if enemy.Dead == true then
		return
	end
	enemy.Dead = true
	removeFromList(enemy)

	local player = enemy.Owner
	local data = context.PlayerData[player]
	local position = enemy.Root.Position

	if data ~= nil and player.Parent ~= nil then
		local zone = Config.Zones[enemy.ZoneId]
		local reward = math.floor(zone.EnemyReward * (Config.EnemyRewardGrowth ^ (enemy.Tier - zone.EnemyMinLevel)))

		-- Beating your toughest foe so far raises the next one's level
		if enemy.Tier >= data.EnemyTier then
			data.EnemyTier = enemy.Tier + 1
		end

		local nextText = "next foe is Lv " .. math.min(data.EnemyTier, zone.EnemyMaxLevel)
		if data.EnemyTier > zone.EnemyMaxLevel then
			nextText = "unlock the next zone for tougher foes"
		end

		context.FxEvent:FireAllClients("EnemyDefeat", position, player.UserId, reward)
		context.AddCoins(player, reward, position)
		context.NotifyEvent:FireClient(player, string.upper(enemy.Stats.Type.Name) .. " DEFEATED!", "+" .. Config.FormatNumber(reward) .. " Scroll-Coins  -  " .. nextText, true)
	end

	task.delay(1.5, function()
		if enemy.Model.Parent ~= nil then
			enemy.Model:Destroy()
		end
	end)
end

local function spawnEnemy(player)
	local data = context.PlayerData[player]
	if data == nil then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
	if rootPart == nil or playerHumanoid == nil then
		return
	end
	if playerHumanoid.Health <= 0 or Progression.IsSafe(rootPart.Position) then
		return
	end

	-- Find ground near the ninja, in the same zone, not in the lake
	local playerZone = getZoneAt(rootPart.Position)
	local spawnPosition = nil
	for attempt = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(Config.EnemySpawnDistanceMin, Config.EnemySpawnDistanceMax)
		local candidate = rootPart.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if getZoneAt(candidate) == playerZone then
			local ground = findSpawnGround(candidate)
			if ground ~= nil and not Progression.Reserved(ground, 3) then
				spawnPosition = ground
				break
			end
		end
	end
	if spawnPosition == nil then
		return
	end

	-- Enemy level comes from the ninja's progress, kept inside this zone's level band
	local zoneId = getZoneAt(spawnPosition)
	if zoneId == "" then
		zoneId = "Meadow"
	end
	local zone = Config.Zones[zoneId]
	local tier = math.clamp(data.EnemyTier, zone.EnemyMinLevel, zone.EnemyMaxLevel)
	local stats = Config.GetEnemyStats(tier)
	if zoneId == "Inferno" then
		stats.Health *= 2
		stats.Type = {Name="Ember Oni",BodyColor=Color3.fromRGB(115,20,12),SkinColor=Color3.fromRGB(255,65,18),AccentColor=Color3.fromRGB(255,120,15),Scale=1.4,Horns=true}
	end
	local enemyType = stats.Type

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = enemyType.SkinColor
	description.TorsoColor = enemyType.BodyColor
	description.LeftArmColor = enemyType.BodyColor
	description.RightArmColor = enemyType.BodyColor
	description.LeftLegColor = enemyType.BodyColor
	description.RightLegColor = enemyType.BodyColor
	description.HeightScale = enemyType.Scale
	description.WidthScale = enemyType.Scale
	description.DepthScale = enemyType.Scale
	description.HeadScale = enemyType.Scale

	local success, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if success == false or model == nil then
		warn("NinjaCoyo: could not create enemy: " .. tostring(model))
		return
	end

	-- The ninja may have left while the model was being built
	if player.Parent == nil or enemiesByPlayer[player] == nil then
		model:Destroy()
		return
	end

	model.Name = enemyType.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local enemyRoot = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if humanoid == nil or enemyRoot == nil or head == nil then
		model:Destroy()
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed

	decorateEnemy(model, enemyType)
	if zoneId == "Inferno" then
		for _,p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Material=Enum.Material.Neon end
		end
		local glow=Instance.new("PointLight")
		glow.Color,glow.Range,glow.Brightness,glow.Parent=enemyType.AccentColor,16,1.5,enemyRoot
	end
	local healthFill = createHealthBar(head, enemyType, tier)

	model:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 4 * enemyType.Scale, 0)))
	model:SetAttribute("OwnerUserId", player.UserId)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.CollisionGroup = "NinjaCoyoEnemies" end
	end
	model.Parent = enemiesFolder
	enemyRoot:SetNetworkOwner(nil)

	local enemy = {}
	enemy.Model = model
	enemy.Humanoid = humanoid
	enemy.Root = enemyRoot
	enemy.Owner = player
	enemy.Tier = tier
	enemy.ZoneId = zoneId
	enemy.Stats = stats
	enemy.Home = spawnPosition
	enemy.LastAttack = 0
	enemy.NextWander = 0
	enemy.Dead = false
	table.insert(enemiesByPlayer[player], enemy)

	humanoid.HealthChanged:Connect(function(health)
		healthFill.Size = UDim2.new(math.clamp(health / humanoid.MaxHealth, 0, 1), 0, 1, 0)
	end)
	humanoid.Died:Connect(function()
		onEnemyDied(enemy)
	end)
end

local function fillEnemies(player)
	if spawnInProgress[player] ~= false then
		return
	end
	local list = enemiesByPlayer[player]
	local data = context.PlayerData[player]
	if list == nil or data == nil then
		return
	end
	if Config.EnemiesRequireUnlock ~= "" then
		if data.Unlocks[Config.EnemiesRequireUnlock] ~= true then
			return
		end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = root and Config.Zones[getZoneAt(root.Position)]
	if #list >= (zone and zone.EnemiesPerPlayer or Config.EnemiesPerPlayer) then
		return
	end

	spawnInProgress[player] = true
	spawnEnemy(player)
	if spawnInProgress[player] ~= nil then
		spawnInProgress[player] = false
	end
end

----------------------------------------------------------------
-- AI
----------------------------------------------------------------

local function updateEnemy(enemy, now)
	if enemy.Dead == true then
		return
	end
	local humanoid = enemy.Humanoid
	if humanoid.Health <= 0 then
		return
	end
	if enemy.Root.Position.Y < -60 or Progression.IsSafe(enemy.Root.Position) then
		despawnEnemy(enemy)
		return
	end

	local character = enemy.Owner.Character
	local targetRoot = nil
	local targetHumanoid = nil
	if character ~= nil then
		targetRoot = character:FindFirstChild("HumanoidRootPart")
		targetHumanoid = character:FindFirstChildOfClass("Humanoid")
	end

	if targetRoot and Progression.IsSafe(targetRoot.Position) then
		-- Wait outside while the ninja rests; the doorway also blocks enemy physics.
		humanoid:MoveTo(enemy.Root.Position)
		return
	end
	local hasTarget = false
	if targetRoot ~= nil and targetHumanoid ~= nil and targetHumanoid.Health > 0 then
		local distance = (targetRoot.Position - enemy.Root.Position).Magnitude

		if distance > Config.EnemyDespawnDistance then
			-- Left far behind: remove it so a fresh one spawns near the ninja
			despawnEnemy(enemy)
			return
		end

		if distance <= Config.EnemyAggroRange then
			hasTarget = true
			if distance <= Config.EnemyAttackRange then
				humanoid:MoveTo(enemy.Root.Position)
				local lookTarget = Vector3.new(targetRoot.Position.X, enemy.Root.Position.Y, targetRoot.Position.Z)
				enemy.Root.CFrame = CFrame.lookAt(enemy.Root.Position, lookTarget)
				if now - enemy.LastAttack >= Config.EnemyAttackCooldown then
					enemy.LastAttack = now
					if enemy.Owner:GetAttribute("MenuProtected") ~= true then
						targetHumanoid:TakeDamage(enemy.Stats.Damage)
					end
					context.FxEvent:FireAllClients("EnemyAttack", enemy.Model, targetRoot.Position)
				end
			else
				humanoid:MoveTo(targetRoot.Position)
			end
		end
	end

	if hasTarget == false then
		if now >= enemy.NextWander then
			enemy.NextWander = now + rng:NextNumber(2, 4)
			local offset = Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
			humanoid:MoveTo(enemy.Home + offset)
		end
	end
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function Enemies.DamageEnemy(player, enemy, amount)
	if player:GetAttribute("MenuProtected") == true then return end
	local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if playerRoot and Progression.IsSafe(playerRoot.Position) then return end
	if enemy.Dead == true then
		return
	end
	if enemy.Owner ~= player then
		return
	end
	enemy.Humanoid:TakeDamage(amount)
	context.FxEvent:FireAllClients("EnemyHit", enemy.Root.Position, enemy.Model)
end

function Enemies.HitInRange(player, position, range, damage, oneHit)
	local list = enemiesByPlayer[player]
	if list == nil then
		return
	end
	for _, enemy in ipairs(table.clone(list)) do
		if enemy.Dead == false then
			if (enemy.Root.Position - position).Magnitude <= range then
				Enemies.DamageEnemy(player, enemy, oneHit and enemy.Humanoid.Health or damage)
			end
		end
	end
end

function Enemies.FindNearestEnemy(player, position, radius)
	local list = enemiesByPlayer[player]
	if list == nil then
		return nil
	end
	local nearestEnemy = nil
	local nearestDistance = radius
	for _, enemy in ipairs(list) do
		if enemy.Dead == false and enemy.Humanoid.Health > 0 then
			local distance = (enemy.Root.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestEnemy = enemy
			end
		end
	end
	return nearestEnemy
end

local function onPlayerAdded(player)
	enemiesByPlayer[player] = {}
	spawnInProgress[player] = false
end

local function onPlayerRemoving(player)
	local list = enemiesByPlayer[player]
	if list ~= nil then
		for _, enemy in ipairs(table.clone(list)) do
			despawnEnemy(enemy)
		end
	end
	enemiesByPlayer[player] = nil
	spawnInProgress[player] = nil
end

function Enemies.Init(newContext)
	context = newContext
	enemiesFolder.Parent = workspace

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		aiAccumulator = aiAccumulator + deltaTime
		if aiAccumulator < AI_STEP then
			return
		end
		aiAccumulator = 0
		local now = os.clock()
		for _, list in pairs(enemiesByPlayer) do
			for _, enemy in ipairs(table.clone(list)) do
				updateEnemy(enemy, now)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.EnemyRespawnDelay)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(fillEnemies, player)
			end
		end
	end)
end

return Enemies