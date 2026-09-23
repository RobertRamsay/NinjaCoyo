-- NinjaCoyoConfig (ModuleScript in ReplicatedStorage)
local Config = {}

-- General
Config.StartingCoins = 5000
Config.CoinSpawnBatch = 5
Config.ChestSpawnBatch = 1
Config.CoinSpawnInterval = 1
Config.CoinHoverHeight = 2.2
Config.CoinSpinSpeed = 3
Config.SpawnRayHeight = 200

-- Katana
Config.KatanaRange = 9
Config.KatanaEnemyRange = 10
Config.KatanaCooldown = 0.35

-- Zone walls and gates (the gate is always on the zone's +Z side)
Config.FenceHeight = 12
Config.BarrierHeight = 200
Config.GateWidth = 16

-- Coyo
Config.CoyoFollowOffset = Vector3.new(3, 0, 4)
Config.CoyoHeight = 1.5
Config.CoyoCollectDistance = 3.5
Config.CoyoTeleportDistance = 60
Config.CoyoHopSpeed = 14
Config.CoyoHopHeight = 0.6
Config.CoyoEnemyRange = 30
Config.CoyoBiteRange = 4.5
Config.CoyoBiteCooldown = 0.8
Config.CoyoChestRange = 20

-- Ninja
Config.DoubleJumpDelay = 0.15

-- Enemies
Config.EnemiesRequireUnlock = "Katana"
Config.EnemiesPerPlayer = 2
Config.EnemySpawnDistanceMin = 30
Config.EnemySpawnDistanceMax = 55
Config.EnemyRespawnDelay = 4
Config.EnemyAggroRange = 45
Config.EnemyAttackRange = 5
Config.EnemyAttackCooldown = 1.2
Config.EnemyDespawnDistance = 150
Config.EnemyBaseHealth = 30
Config.EnemyHealthGrowth = 1.22
Config.EnemyBaseDamage = 6
Config.EnemyDamageGrowth = 1.12
Config.EnemyBaseSpeed = 12
Config.EnemySpeedPerTier = 0.5
Config.EnemyMaxSpeed = 22
Config.EnemyRewardMinMultiplier = 2
Config.EnemyRewardMaxMultiplier = 5
Config.EnemyRewardFloorBase = 25
Config.EnemyRewardFloorGrowth = 1.8
Config.EnemyRewardCapBase = 1000
Config.EnemyRewardCapGrowth = 3
Config.TiersPerEnemyType = 5

Config.EnemyTypes = {
	{
		Name = "Bandit",
		BodyColor = Color3.fromRGB(120, 90, 60),
		SkinColor = Color3.fromRGB(234, 184, 146),
		AccentColor = Color3.fromRGB(230, 200, 80),
		Scale = 1,
		Horns = false,
	},
	{
		Name = "Ronin",
		BodyColor = Color3.fromRGB(60, 70, 110),
		SkinColor = Color3.fromRGB(234, 184, 146),
		AccentColor = Color3.fromRGB(150, 180, 255),
		Scale = 1.05,
		Horns = false,
	},
	{
		Name = "Shadow Ninja",
		BodyColor = Color3.fromRGB(25, 25, 30),
		SkinColor = Color3.fromRGB(40, 40, 48),
		AccentColor = Color3.fromRGB(160, 60, 220),
		Scale = 1.1,
		Horns = false,
	},
	{
		Name = "Oni",
		BodyColor = Color3.fromRGB(170, 40, 40),
		SkinColor = Color3.fromRGB(200, 60, 50),
		AccentColor = Color3.fromRGB(255, 200, 60),
		Scale = 1.25,
		Horns = true,
	},
	{
		Name = "Demon Samurai",
		BodyColor = Color3.fromRGB(60, 20, 70),
		SkinColor = Color3.fromRGB(90, 30, 100),
		AccentColor = Color3.fromRGB(255, 80, 80),
		Scale = 1.4,
		Horns = true,
	},
}

-- Sound effects
-- These start on sounds built into Roblox so you hear something straight away.
-- Upload the NinjaCoyo .ogg files (Creator Hub > Development Items > Audio),
-- then replace each Id with "rbxassetid://" followed by the uploaded asset's number.
Config.Sounds = {
	CoinPickup = { Id = "rbxassetid://136880211129207", Volume = 0.35 },
	CoinBurst = { Id = "rbxassetid://77465759271184", Volume = 0.4 },
	Swoosh = { Id = "rbxassetid://133160922744753", Volume = 0.6 },
	ChestHit = { Id = "rbxassetid://90211216045918", Volume = 0.5 },
	ChestSmash = { Id = "rbxassetid://104232022038321", Volume = 0.55 },
	EnemyHit = { Id = "rbxassetid://82158142863352", Volume = 0.55 },
	EnemyDefeat = { Id = "rbxassetid://72685976774549", Volume = 0.55 },
	PlayerHurt = { Id = "rbxassetid://74924866907165", Volume = 0.45 },
	Unlock = { Id = "rbxassetid://118284264599830", Volume = 0.6 },
	Click = { Id = "rbxassetid://107541070659477", Volume = 0.4 },
}

-- Saving
Config.DataStoreName = "NinjaCoyoData_v1"
Config.AutoSaveSeconds = 60

-- Number formatting
Config.NumberSuffixes = {
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

----------------------------------------------------------------
-- Zones
----------------------------------------------------------------

Config.ZoneOrder = { "Meadow", "Bamboo" }

Config.Zones = {
	Meadow = {
		DisplayName = "Dojo Meadow",
		Center = Vector3.new(0, 0, 0),
		Size = 200,
		SpawnMargin = 4,
		CoinValue = 1,
		ChestValueMin = 5,
		ChestValueMax = 20,
		ChestHits = 3,
		MaxCoins = 60,
		MaxChests = 6,
		RequiredUnlock = "",
		Build = false,
		FloorColor = Color3.fromRGB(100, 150, 70),
		FloorMaterial = Enum.Material.Grass,
		FenceColor = Color3.fromRGB(170, 140, 80),
		DecorColor = Color3.fromRGB(120, 168, 70),
		DecorCount = 0,
	},
	Bamboo = {
		DisplayName = "Bamboo Forest",
		Center = Vector3.new(0, 0, -215),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 10,
		ChestValueMin = 50,
		ChestValueMax = 200,
		ChestHits = 5,
		MaxCoins = 50,
		MaxChests = 6,
		RequiredUnlock = "BambooGate",
		Build = true,
		FloorColor = Color3.fromRGB(86, 130, 58),
		FloorMaterial = Enum.Material.Grass,
		FenceColor = Color3.fromRGB(170, 140, 80),
		DecorColor = Color3.fromRGB(120, 168, 70),
		DecorCount = 45,
	},
}

----------------------------------------------------------------
-- Unlocks (each roughly 10x the last)
----------------------------------------------------------------

Config.UnlockOrder = { "Katana", "BambooGate" }

Config.Unlocks = {
	Katana = {
		DisplayName = "Katana",
		Description = "Slash chests and enemies",
		Cost = 100,
		UnlockMessage = "Equip it and click to slash. Enemies will now hunt you!",
	},
	BambooGate = {
		DisplayName = "Bamboo Forest",
		Description = "New zone: coins worth x10",
		Cost = 1000,
		UnlockMessage = "The red gate is open. Coins there are worth x10!",
	},
}

----------------------------------------------------------------
-- Dojo upgrades
-- ValueMode: "Add" = base + perLevel * level, "Multiply" = base * perLevel ^ level
-- DisplayMode: "Number" shows the value, "Multiplier" shows it as x1.5
----------------------------------------------------------------

Config.UpgradeOrder = { "NinjaSpeed", "NinjaJump", "NinjaHealth", "KatanaPower", "CoyoSniff", "CoyoSpeed", "CoyoBite", "GoldenPaws" }

Config.Upgrades = {
	NinjaSpeed = {
		DisplayName = "Ninja Speed",
		Description = "Run faster",
		Category = "Ninja",
		MaxLevel = 10,
		BaseCost = 15,
		CostGrowth = 1.5,
		BaseValue = 16,
		PerLevel = 2,
		ValueMode = "Add",
		DisplayMode = "Number",
	},
	NinjaJump = {
		DisplayName = "Ninja Jump",
		Description = "Jump higher",
		Category = "Ninja",
		MaxLevel = 10,
		BaseCost = 15,
		CostGrowth = 1.5,
		BaseValue = 50,
		PerLevel = 6,
		ValueMode = "Add",
		DisplayMode = "Number",
	},
	NinjaHealth = {
		DisplayName = "Ninja Vitality",
		Description = "More max health",
		Category = "Ninja",
		MaxLevel = 30,
		BaseCost = 80,
		CostGrowth = 1.6,
		BaseValue = 100,
		PerLevel = 1.25,
		ValueMode = "Multiply",
		DisplayMode = "Number",
	},
	KatanaPower = {
		DisplayName = "Katana Power",
		Description = "Katana damage",
		Category = "Ninja",
		MaxLevel = 30,
		BaseCost = 100,
		CostGrowth = 1.7,
		BaseValue = 12,
		PerLevel = 1.4,
		ValueMode = "Multiply",
		DisplayMode = "Number",
	},
	CoyoSniff = {
		DisplayName = "Coyo Sniff",
		Description = "Coyo finds coins further away",
		Category = "Coyo",
		MaxLevel = 10,
		BaseCost = 20,
		CostGrowth = 1.55,
		BaseValue = 10,
		PerLevel = 4,
		ValueMode = "Add",
		DisplayMode = "Number",
	},
	CoyoSpeed = {
		DisplayName = "Coyo Speed",
		Description = "Coyo fetches coins faster",
		Category = "Coyo",
		MaxLevel = 10,
		BaseCost = 20,
		CostGrowth = 1.55,
		BaseValue = 20,
		PerLevel = 4,
		ValueMode = "Add",
		DisplayMode = "Number",
	},
	CoyoBite = {
		DisplayName = "Coyo Bite",
		Description = "Coyo's bite damage",
		Category = "Coyo",
		MaxLevel = 30,
		BaseCost = 80,
		CostGrowth = 1.7,
		BaseValue = 6,
		PerLevel = 1.4,
		ValueMode = "Multiply",
		DisplayMode = "Number",
	},
	GoldenPaws = {
		DisplayName = "Golden Paws",
		Description = "Multiplies every coin and chest",
		Category = "Coyo",
		MaxLevel = 10,
		BaseCost = 50,
		CostGrowth = 1.8,
		BaseValue = 1,
		PerLevel = 1.5,
		ValueMode = "Multiply",
		DisplayMode = "Multiplier",
	},
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

function Config.GetCost(upgradeId, currentLevel)
	local info = Config.Upgrades[upgradeId]
	return math.floor(info.BaseCost * (info.CostGrowth ^ currentLevel))
end

function Config.GetValue(upgradeId, level)
	local info = Config.Upgrades[upgradeId]
	if info.ValueMode == "Multiply" then
		return info.BaseValue * (info.PerLevel ^ level)
	end
	return info.BaseValue + info.PerLevel * level
end

function Config.FormatNumber(value)
	for _, entry in ipairs(Config.NumberSuffixes) do
		if value >= entry[1] then
			local text = string.format("%.1f", value / entry[1])
			text = string.gsub(text, "%.0$", "")
			return text .. entry[2]
		end
	end
	return tostring(math.floor(value))
end

function Config.FormatValue(upgradeId, value)
	local info = Config.Upgrades[upgradeId]
	if info.DisplayMode == "Multiplier" then
		return string.format("x%.1f", value)
	end
	return Config.FormatNumber(math.floor(value))
end

function Config.GetEnemyStats(tier)
	local stats = {}
	stats.Health = math.floor(Config.EnemyBaseHealth * (Config.EnemyHealthGrowth ^ (tier - 1)))
	stats.Damage = math.floor(Config.EnemyBaseDamage * (Config.EnemyDamageGrowth ^ (tier - 1)))
	stats.Speed = math.min(Config.EnemyMaxSpeed, Config.EnemyBaseSpeed + Config.EnemySpeedPerTier * (tier - 1))
	stats.RewardFloor = math.floor(Config.EnemyRewardFloorBase * (Config.EnemyRewardFloorGrowth ^ (tier - 1)))
	stats.RewardCap = math.floor(Config.EnemyRewardCapBase * (Config.EnemyRewardCapGrowth ^ (tier - 1)))
	local typeIndex = (math.floor((tier - 1) / Config.TiersPerEnemyType) % #Config.EnemyTypes) + 1
	stats.Type = Config.EnemyTypes[typeIndex]
	return stats
end

return Config