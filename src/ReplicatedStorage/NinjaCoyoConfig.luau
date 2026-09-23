-- NinjaCoyoConfig (ModuleScript in ReplicatedStorage)
local Config = {}

-- General
Config.StartingCoins = 0
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
Config.StartCameraDistance = 18

-- Zone walls and gates (the gate is always on the zone's +Z side)
Config.FenceHeight = 12
Config.BarrierHeight = 200
Config.GateWidth = 16

-- Coyo
Config.CoyoPackNames = { "Coyo", "Kiba", "Yuki", "Hana" }
Config.CoyoPackOffsets = {
	Vector3.new(3, 0, 4),
	Vector3.new(-3, 0, 4),
	Vector3.new(5.5, 0, 0.5),
	Vector3.new(-5.5, 0, 0.5),
}
Config.CoyoHeight = 1.5
Config.CoyoCollectDistance = 3.5
Config.CoyoTeleportDistance = 60
Config.CoyoHopSpeed = 14
Config.CoyoHopHeight = 0.6
Config.CoyoEnemyRange = 30
Config.CoyoBiteRange = 4.5
Config.CoyoBiteCooldown = 0.8
Config.CoyoPounceDuration = 0.55
Config.CoyoPounceHeight = 2.2
Config.CoyoAttackStandOff = 5
Config.CoyoChestRange = 20

-- Ninja
Config.DoubleJumpDelay = 0.15
Config.FlipJumpLevel = 3
Config.TripleJumpLevel = 7

-- Upload assets/sounds/NinjaCoyo_wind.wav and NinjaCoyo_chimes.wav, then set IDs.
Config.Ambience = {
	WindId = "",
	ChimesId = "",
	WindVolume = 0.18,
	ChimesVolume = 0.25,
}

-- Flat-topped grassy treasure hills, clear of spawn, paths, lake and gates.
Config.TreasureTerraces = {
	{ Zone = "Meadow", Center = Vector3.new(-105, 0, 95), Height = 9, Radius = 16 },
	{ Zone = "Meadow", Center = Vector3.new(90, 0, 115), Height = 16, Radius = 15 },
	{ Zone = "Meadow", Center = Vector3.new(-205, 0, 115), Height = 23, Radius = 14 },
	{ Zone = "Bamboo", Center = Vector3.new(-48, 0, -245), Height = 12, Radius = 12 },
	{ Zone = "Sakura", Center = Vector3.new(46, 0, -435), Height = 18, Radius = 12 },
}

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
Config.EnemyRewardGrowth = 1.2
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
	{
		Name = "Spirit Warrior",
		BodyColor = Color3.fromRGB(90, 160, 230),
		SkinColor = Color3.fromRGB(200, 235, 255),
		AccentColor = Color3.fromRGB(200, 120, 255),
		Scale = 1.5,
		Horns = true,
	},
}

-- Sound effects
-- These start on sounds built into Roblox so you hear something straight away.
-- Upload the NinjaCoyo .ogg files (Creator Hub > Development Items > Audio),
-- then replace each Id with "rbxassetid://" followed by the uploaded asset's number.
-- Music: plays once each time a zone gate is opened, unless it is still playing
Config.Music = {
	Id = "rbxassetid://70968087799750",
	Volume = 0.5,
}

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

----------------------------------------------------------------
-- Wardrobe Shrine (Robux cosmetics and boosts)
-- Each item with a PassId of 0 is not for sale yet. Create a Game Pass for it in the
-- Creator Hub (your game > Monetization > Passes), then paste the pass ID here.
-- While testing in Studio, StudioOwnsEverything lets you try every item for free.
----------------------------------------------------------------

Config.Wardrobe = {
	StudioOwnsEverything = true,
	ShrinePosition = Vector3.new(-45, 0, 45),
	DoubleCoinsPassId = 0,
	PackPassIds = { [2] = 1990304738, [3] = 1994504253, [4] = 1994474258 }, -- Total dogs; permanent alternate unlocks.
	GoldSwordPassId = 1993376284, -- Permanent Gold Katana game pass.

	OutfitOrder = { "Default", "Crimson", "Shadow", "Jade", "Samurai" },
	Outfits = {
		Default = {
			DisplayName = "Your Avatar",
			PassId = 0,
			Free = true,
			BodyColor = Color3.fromRGB(160, 160, 170),
			AccentColor = Color3.fromRGB(110, 110, 120),
			SashColor = Color3.fromRGB(200, 200, 210),
			Armour = false,
		},
		Crimson = {
			DisplayName = "Crimson Ninja",
			PassId = 0,
			Free = true,
			BodyColor = Color3.fromRGB(150, 22, 32),
			AccentColor = Color3.fromRGB(20, 20, 22),
			SashColor = Color3.fromRGB(240, 190, 50),
			Armour = false,
		},
		Shadow = {
			RequiredUpgrade = "NinjaJump", RequiredLevel = 3,
			DisplayName = "Shadow Ninja",
			PassId = 0,
			Free = false,
			BodyColor = Color3.fromRGB(28, 28, 34),
			AccentColor = Color3.fromRGB(150, 60, 220),
			SashColor = Color3.fromRGB(150, 60, 220),
			Armour = false,
		},
		Jade = {
			RequiredUpgrade = "NinjaHealth", RequiredLevel = 3,
			DisplayName = "Jade Ninja",
			PassId = 0,
			Free = false,
			BodyColor = Color3.fromRGB(38, 120, 90),
			AccentColor = Color3.fromRGB(240, 240, 235),
			SashColor = Color3.fromRGB(240, 190, 50),
			Armour = false,
		},
		Samurai = {
			RequiredUpgrade = "KatanaPower", RequiredLevel = 10,
			DisplayName = "Golden Samurai",
			PassId = 0,
			Free = false,
			BodyColor = Color3.fromRGB(40, 40, 46),
			AccentColor = Color3.fromRGB(250, 195, 45),
			SashColor = Color3.fromRGB(190, 30, 40),
			Armour = true,
		},
	},

	CoatOrder = { "Coyote", "Shiba", "Snow", "ShadowFox", "FireFox", "Spirit" },
	Coats = {
		Shiba = {
			DisplayName = "Amber Shiba", PassId = 0, Free = true, Shape = "Shiba",
			FurColor = Color3.fromRGB(205, 139, 65), DarkColor = Color3.fromRGB(139, 80, 40),
			LightColor = Color3.fromRGB(255, 233, 198), Material = Enum.Material.Fabric, Effect = "",
		},
		Coyote = {
			DisplayName = "Coyote",
			PassId = 0,
			Free = true,
			FurColor = Color3.fromRGB(181, 140, 94),
			DarkColor = Color3.fromRGB(110, 82, 56),
			LightColor = Color3.fromRGB(232, 214, 184),
			Material = Enum.Material.SmoothPlastic,
			Effect = "",
		},
		Snow = {
			Shape = "Wolf", RequiredUpgrade = "PackSize", RequiredLevel = 1,
			DisplayName = "Snow Wolf",
			PassId = 0,
			Free = false,
			FurColor = Color3.fromRGB(235, 238, 245),
			DarkColor = Color3.fromRGB(175, 185, 200),
			LightColor = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			Effect = "Snow",
		},
		ShadowFox = {
			Shape = "Fox", RequiredUpgrade = "NinjaJump", RequiredLevel = 3,
			DisplayName = "Shadow Fox",
			PassId = 0,
			Free = false,
			FurColor = Color3.fromRGB(40, 40, 48),
			DarkColor = Color3.fromRGB(20, 20, 25),
			LightColor = Color3.fromRGB(130, 60, 170),
			Material = Enum.Material.SmoothPlastic,
			Effect = "Shadow",
		},
		FireFox = {
			Shape = "Fox", RequiredUpgrade = "CoyoBite", RequiredLevel = 5,
			DisplayName = "Fire Fox",
			PassId = 0,
			Free = false,
			FurColor = Color3.fromRGB(235, 110, 40),
			DarkColor = Color3.fromRGB(150, 50, 20),
			LightColor = Color3.fromRGB(255, 225, 170),
			Material = Enum.Material.SmoothPlastic,
			Effect = "Embers",
		},
		Spirit = {
			Shape = "Wolf", RequiredUpgrade = "PackSize", RequiredLevel = 3,
			DisplayName = "Spirit Wolf",
			PassId = 0,
			Free = false,
			FurColor = Color3.fromRGB(120, 200, 255),
			DarkColor = Color3.fromRGB(60, 120, 230),
			LightColor = Color3.fromRGB(225, 245, 255),
			Material = Enum.Material.Neon,
			Effect = "Spirit",
		},
	},
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

Config.ZoneOrder = { "Meadow", "Bamboo", "Sakura", "Snow", "Volcano", "Spirit" }

-- Walled zones form a chain northwards (-Z) from the Meadow. Each has its gate on
-- its +Z side and an opening in its back wall leading to the next zone's gate.
-- EnemyMinLevel/EnemyMaxLevel: the level band of enemies in that zone.
-- EnemyReward: coins for a kill at EnemyMinLevel (grows by EnemyRewardGrowth per level).
Config.Zones = {
	Meadow = {
		DisplayName = "Dojo Meadow",
		Center = Vector3.new(0, 0, 0),
		Size = 200,
		SpawnMin = Vector2.new(-245, -110),
		SpawnMax = Vector2.new(245, 235),
		SpawnMargin = 4,
		CoinValue = 1,
		ChestValueMin = 5,
		ChestValueMax = 20,
		ChestHits = 3,
		MaxCoins = 100,
		MaxChests = 10,
		EnemyMinLevel = 1,
		EnemyMaxLevel = 5,
		EnemyReward = 12,
		RequiredUnlock = "",
		Build = false,
		FloorColor = Color3.fromRGB(100, 150, 70),
		FloorMaterial = Enum.Material.Grass,
		FenceColor = Color3.fromRGB(170, 140, 80),
		DecorType = "",
		DecorColor = Color3.fromRGB(120, 168, 70),
		DecorCount = 0,
	},
	Bamboo = {
		DisplayName = "Bamboo Forest",
		Center = Vector3.new(0, 0, -215),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 4,
		ChestValueMin = 25,
		ChestValueMax = 80,
		ChestHits = 4,
		MaxCoins = 45,
		MaxChests = 6,
		EnemyMinLevel = 5,
		EnemyMaxLevel = 10,
		EnemyReward = 50,
		RequiredUnlock = "BambooGate",
		Build = true,
		FloorColor = Color3.fromRGB(86, 130, 58),
		FloorMaterial = Enum.Material.Grass,
		FenceColor = Color3.fromRGB(170, 140, 80),
		DecorType = "Bamboo",
		DecorColor = Color3.fromRGB(120, 168, 70),
		DecorCount = 45,
	},
	Sakura = {
		DisplayName = "Sakura Grove",
		Center = Vector3.new(0, 0, -405),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 15,
		ChestValueMin = 90,
		ChestValueMax = 300,
		ChestHits = 5,
		MaxCoins = 40,
		MaxChests = 6,
		EnemyMinLevel = 10,
		EnemyMaxLevel = 15,
		EnemyReward = 200,
		RequiredUnlock = "SakuraGate",
		Build = true,
		FloorColor = Color3.fromRGB(120, 165, 80),
		FloorMaterial = Enum.Material.Grass,
		FenceColor = Color3.fromRGB(150, 100, 80),
		DecorType = "Sakura",
		DecorColor = Color3.fromRGB(255, 183, 206),
		DecorCount = 22,
	},
	Snow = {
		DisplayName = "Snowy Peak",
		Center = Vector3.new(0, 0, -595),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 60,
		ChestValueMin = 350,
		ChestValueMax = 1200,
		ChestHits = 6,
		MaxCoins = 40,
		MaxChests = 6,
		EnemyMinLevel = 15,
		EnemyMaxLevel = 20,
		EnemyReward = 800,
		RequiredUnlock = "SnowGate",
		Build = true,
		FloorColor = Color3.fromRGB(235, 240, 248),
		FloorMaterial = Enum.Material.Snow,
		FenceColor = Color3.fromRGB(110, 90, 75),
		DecorType = "SnowPine",
		DecorColor = Color3.fromRGB(46, 96, 64),
		DecorCount = 28,
	},
	Volcano = {
		DisplayName = "Oni Volcano",
		Center = Vector3.new(0, 0, -785),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 250,
		ChestValueMin = 1500,
		ChestValueMax = 5000,
		ChestHits = 7,
		MaxCoins = 40,
		MaxChests = 6,
		EnemyMinLevel = 20,
		EnemyMaxLevel = 25,
		EnemyReward = 3200,
		RequiredUnlock = "VolcanoGate",
		Build = true,
		FloorColor = Color3.fromRGB(45, 38, 36),
		FloorMaterial = Enum.Material.Basalt,
		FenceColor = Color3.fromRGB(60, 45, 40),
		DecorType = "Volcano",
		DecorColor = Color3.fromRGB(255, 110, 30),
		DecorCount = 26,
	},
	Spirit = {
		DisplayName = "Spirit Realm",
		Center = Vector3.new(0, 0, -975),
		Size = 180,
		SpawnMargin = 8,
		CoinValue = 1000,
		ChestValueMin = 6000,
		ChestValueMax = 20000,
		ChestHits = 8,
		MaxCoins = 40,
		MaxChests = 6,
		EnemyMinLevel = 25,
		EnemyMaxLevel = 30,
		EnemyReward = 13000,
		RequiredUnlock = "SpiritGate",
		Build = true,
		FloorColor = Color3.fromRGB(40, 28, 60),
		FloorMaterial = Enum.Material.Slate,
		FenceColor = Color3.fromRGB(70, 50, 100),
		DecorType = "Spirit",
		DecorColor = Color3.fromRGB(170, 110, 255),
		DecorCount = 30,
	},
}

----------------------------------------------------------------
-- Unlocks (each roughly 8x the last)
----------------------------------------------------------------

Config.UnlockOrder = { "Katana", "BambooGate", "SakuraGate", "SnowGate", "VolcanoGate", "SpiritGate" }

Config.Unlocks = {
	Katana = {
		DisplayName = "Katana",
		Description = "Slash chests and enemies",
		Cost = 100,
		UnlockMessage = "Equip it and click to slash. Enemies will now hunt you!",
	},
	BambooGate = {
		DisplayName = "Bamboo Forest",
		Description = "New zone: coins worth x4",
		Cost = 750,
		UnlockMessage = "The Bamboo Forest gate is open!",
	},
	SakuraGate = {
		DisplayName = "Sakura Grove",
		Description = "New zone: coins worth x15",
		Cost = 6000,
		UnlockMessage = "The Sakura Grove gate is open!",
	},
	SnowGate = {
		DisplayName = "Snowy Peak",
		Description = "New zone: coins worth x60",
		Cost = 50000,
		UnlockMessage = "The Snowy Peak gate is open!",
	},
	VolcanoGate = {
		DisplayName = "Oni Volcano",
		Description = "New zone: coins worth x250",
		Cost = 400000,
		UnlockMessage = "The Oni Volcano gate is open!",
	},
	SpiritGate = {
		DisplayName = "Spirit Realm",
		Description = "New zone: coins worth x1000",
		Cost = 3000000,
		UnlockMessage = "The Spirit Realm gate is open!",
	},
}

----------------------------------------------------------------
-- Dojo upgrades
-- ValueMode: "Add" = base + perLevel * level, "Multiply" = base * perLevel ^ level
-- DisplayMode: "Number" shows the value, "Multiplier" shows it as x1.5
----------------------------------------------------------------

Config.UpgradeOrder = { "NinjaSpeed", "NinjaJump", "NinjaHealth", "KatanaPower", "PackSize", "CoyoSniff", "CoyoSpeed", "CoyoBite", "GoldenPaws" }

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
		Description = "Higher jumps; flip Lv 3, triple jump Lv 7",
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
		Description = "More damage and wider sweeps; 360 at Lv 10",
		Category = "Ninja",
		MaxLevel = 30,
		BaseCost = 100,
		CostGrowth = 1.7,
		BaseValue = 12,
		PerLevel = 1.4,
		ValueMode = "Multiply",
		DisplayMode = "Number",
	},
	PackSize = {
		DisplayName = "Wolf Pack",
		Description = "Another dog joins your pack",
		Category = "Coyo",
		MaxLevel = 3,
		BaseCost = 2000,
		CostGrowth = 15,
		BaseValue = 1,
		PerLevel = 1,
		ValueMode = "Add",
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
		BaseCost = 150,
		CostGrowth = 2.2,
		BaseValue = 1,
		PerLevel = 1.2,
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
	local typeIndex = (math.floor((tier - 1) / Config.TiersPerEnemyType) % #Config.EnemyTypes) + 1
	stats.Type = Config.EnemyTypes[typeIndex]
	return stats
end

return Config
