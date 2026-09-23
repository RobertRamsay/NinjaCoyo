-- NinjaCoyoWorld (ModuleScript in ServerScriptService)
-- Builds the Japanese landscape at startup: green rolling terrain, a mountain ring,
-- a lake with a floating torii, a pagoda temple on a hill, stone paths,
-- glowing lanterns, sakura and pine trees.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))

local World = {}

local terrain = workspace.Terrain
local rng = Random.new(7) -- fixed seed so the world looks the same every time

-- Layout
local GROUND_CENTER = Vector3.new(0, 0, -60)
local GROUND_SIZE = Vector3.new(900, 16, 1000)
local SPAWN_CLEAR_RADIUS = 30
local PATH_WIDTH = 12
local LAKE_CENTER = Vector3.new(165, 0, 0)
local LAKE_RADIUS = 50
local TEMPLE_CENTER = Vector3.new(-160, 0, 0)
local TEMPLE_HILL_RADIUS = 36
local TEMPLE_PLATEAU_RADIUS = 18
local STAIR_COUNT = 14
local STAIR_RUN = 2
local MOUNTAIN_RING_RADIUS = 420
local MOUNTAIN_COUNT = 22
local MOUND_COUNT = 30
local SAKURA_COUNT = 24
local PINE_COUNT = 14
local BOULDER_COUNT = 14
local LILY_PAD_COUNT = 14

-- Colours
local GRASS_GREEN = Color3.fromRGB(96, 156, 64)
local LEAFY_GREEN = Color3.fromRGB(80, 140, 56)
local SAKURA_PINK = Color3.fromRGB(255, 183, 206)
local SAKURA_DEEP = Color3.fromRGB(245, 150, 185)
local PINE_GREEN = Color3.fromRGB(46, 96, 56)
local LILY_GREEN = Color3.fromRGB(70, 140, 60)
local TRUNK_BROWN = Color3.fromRGB(92, 62, 46)
local DOCK_BROWN = Color3.fromRGB(130, 96, 64)
local TORII_RED = Color3.fromRGB(196, 38, 38)
local STONE_GREY = Color3.fromRGB(150, 150, 145)
local ROOF_DARK = Color3.fromRGB(50, 52, 60)
local WALL_WHITE = Color3.fromRGB(240, 234, 220)
local GOLD = Color3.fromRGB(255, 196, 40)
local LANTERN_GLOW = Color3.fromRGB(255, 214, 150)

-- State (initialised up front)
local decorFolder = Instance.new("Folder")
decorFolder.Name = "WorldDecor"

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { terrain }
groundParams.IgnoreWater = true

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function groundHeightAt(x, z)
	local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), groundParams)
	if result ~= nil then
		return result.Position.Y
	end
	return 0
end

local function makePart(name, size, cframe, colour, material, canCollide, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Anchored = true
	part.CanCollide = canCollide
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = decorFolder
	return part
end

-- Vertical cylinder standing on (x, baseY, z)
local function makeColumn(name, height, diameter, x, baseY, z, colour, material, canCollide)
	local cframe = CFrame.new(x, baseY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	return makePart(name, Vector3.new(height, diameter, diameter), cframe, colour, material, canCollide, Enum.PartType.Cylinder)
end

-- Flat disc centred at (x, y, z)
local function makeDisc(name, thickness, diameter, x, y, z, colour, material, canCollide)
	local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	return makePart(name, Vector3.new(thickness, diameter, diameter), cframe, colour, material, canCollide, Enum.PartType.Cylinder)
end

local function flatDistance(x, z, point)
	return Vector2.new(x - point.X, z - point.Z).Magnitude
end

local function isInsideWalledZone(x, z, margin)
	for _, zoneId in ipairs(Config.ZoneOrder) do
		local zone = Config.Zones[zoneId]
		if zone.Build == true then
			local half = zone.Size / 2 + margin
			if math.abs(x - zone.Center.X) < half and math.abs(z - zone.Center.Z) < half then
				return true
			end
		end
	end
	return false
end

local function isOnPath(x, z, margin)
	local halfWidth = PATH_WIDTH / 2 + margin
	-- North path: spawn to the Bamboo Forest gate
	if math.abs(x) < halfWidth and z < 0 and z > -140 then
		return true
	end
	-- West path to the temple and east path to the lake
	if math.abs(z) < halfWidth and math.abs(x) < 200 then
		return true
	end
	return false
end

local function isFreeSpot(x, z, clearance)
	if flatDistance(x, z, Vector3.zero) < SPAWN_CLEAR_RADIUS + clearance then
		return false
	end
	if flatDistance(x, z, LAKE_CENTER) < LAKE_RADIUS + 10 + clearance then
		return false
	end
	if flatDistance(x, z, TEMPLE_CENTER) < TEMPLE_HILL_RADIUS + 8 + clearance then
		return false
	end
	if isInsideWalledZone(x, z, 8 + clearance) then
		return false
	end
	if isOnPath(x, z, clearance) then
		return false
	end
	return true
end

local function randomFreeSpot(minRadius, maxRadius, clearance)
	for attempt = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(minRadius, maxRadius)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		if isFreeSpot(x, z, clearance) then
			return true, x, z
		end
	end
	return false, 0, 0
end

----------------------------------------------------------------
-- Terrain
----------------------------------------------------------------

local function buildTerrain()
	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, GRASS_GREEN)
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, LEAFY_GREEN)
	terrain.WaterColor = Color3.fromRGB(40, 120, 130)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.1
	terrain.WaterReflectance = 0.6

	-- Base ground, top surface at y = 0
	terrain:FillBlock(CFrame.new(GROUND_CENTER.X, -GROUND_SIZE.Y / 2, GROUND_CENTER.Z), GROUND_SIZE, Enum.Material.Grass)

	-- Rolling mounds
	for index = 1, MOUND_COUNT do
		local radius = rng:NextNumber(10, 22)
		local found, x, z = randomFreeSpot(50, 330, radius)
		if found then
			local material = Enum.Material.Grass
			if rng:NextNumber() < 0.4 then
				material = Enum.Material.LeafyGrass
			end
			terrain:FillBall(Vector3.new(x, -radius * 0.7, z), radius, material)
		end
	end

	-- Mountain ring with rocky peaks, snow on the biggest
	for index = 1, MOUNTAIN_COUNT do
		local angle = (index / MOUNTAIN_COUNT) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local distance = MOUNTAIN_RING_RADIUS + rng:NextNumber(-30, 40)
		local radius = rng:NextNumber(60, 95)
		local x = GROUND_CENTER.X + math.cos(angle) * distance
		local z = GROUND_CENTER.Z + math.sin(angle) * distance
		local centerY = -radius * 0.45
		terrain:FillBall(Vector3.new(x, centerY, z), radius, Enum.Material.Grass)
		terrain:FillBall(Vector3.new(x, centerY + radius * 0.62, z), radius * 0.4, Enum.Material.Rock)
		if radius > 85 then
			terrain:FillBall(Vector3.new(x, centerY + radius * 0.85, z), radius * 0.2, Enum.Material.Snow)
		end
	end

	-- Temple hill with a flat plateau on top
	terrain:FillBall(Vector3.new(TEMPLE_CENTER.X, -22, TEMPLE_CENTER.Z), TEMPLE_HILL_RADIUS, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(TEMPLE_CENTER.X, 10, TEMPLE_CENTER.Z), 8, TEMPLE_PLATEAU_RADIUS, Enum.Material.Grass)

	-- Lake: sandy shore, carved bowl, sandy bottom, water
	terrain:FillCylinder(CFrame.new(LAKE_CENTER.X, -2, LAKE_CENTER.Z), 4, LAKE_RADIUS + 8, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(LAKE_CENTER.X, -4, LAKE_CENTER.Z), 12, LAKE_RADIUS, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(LAKE_CENTER.X, -11, LAKE_CENTER.Z), 2, LAKE_RADIUS + 2, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(LAKE_CENTER.X, -6, LAKE_CENTER.Z), 8, LAKE_RADIUS, Enum.Material.Water)

	-- Cobblestone paths
	local stairsBottomX = TEMPLE_CENTER.X + TEMPLE_PLATEAU_RADIUS + STAIR_COUNT * STAIR_RUN
	local shoreX = LAKE_CENTER.X - LAKE_RADIUS - 8
	terrain:FillBlock(CFrame.new(0, -2, -70), Vector3.new(PATH_WIDTH, 4, 140), Enum.Material.Cobblestone)
	terrain:FillBlock(CFrame.new(stairsBottomX / 2, -2, 0), Vector3.new(math.abs(stairsBottomX) + 4, 4, PATH_WIDTH), Enum.Material.Cobblestone)
	terrain:FillBlock(CFrame.new(shoreX / 2, -2, 0), Vector3.new(shoreX, 4, PATH_WIDTH), Enum.Material.Cobblestone)

	-- Boulders
	for index = 1, BOULDER_COUNT do
		local radius = rng:NextNumber(2, 4.5)
		local found, x, z = randomFreeSpot(40, 300, radius + 2)
		if found then
			terrain:FillBall(Vector3.new(x, groundHeightAt(x, z), z), radius, Enum.Material.Rock)
		end
	end
end

----------------------------------------------------------------
-- Structures
----------------------------------------------------------------

local function buildTorii(position, width, height, facingAngle)
	local base = CFrame.new(position) * CFrame.Angles(0, facingAngle, 0)
	local leftPost = base * CFrame.new(-width / 2, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	local rightPost = base * CFrame.new(width / 2, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	makePart("ToriiPost", Vector3.new(height, 1.6, 1.6), leftPost, TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Cylinder)
	makePart("ToriiPost", Vector3.new(height, 1.6, 1.6), rightPost, TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Cylinder)
	makePart("ToriiTie", Vector3.new(width + 2, 1, 1.2), base * CFrame.new(0, height - 2, 0), TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
	makePart("ToriiTop", Vector3.new(width + 6, 1.4, 2.2), base * CFrame.new(0, height + 0.7, 0), TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
	makePart("ToriiCap", Vector3.new(width + 7, 0.6, 2.6), base * CFrame.new(0, height + 1.7, 0), ROOF_DARK, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
end

local function buildPagoda(center)
	local x = center.X
	local z = center.Z

	makePart("TemplePlatform", Vector3.new(30, 2, 30), CFrame.new(x, center.Y + 1, z), STONE_GREY, Enum.Material.Slate, true, Enum.PartType.Block)
	local floorY = center.Y + 2

	local tiers = {
		{ Width = 20, Height = 9 },
		{ Width = 16, Height = 7 },
		{ Width = 12, Height = 6 },
	}

	for tierIndex, tier in ipairs(tiers) do
		local half = tier.Width / 2 - 1

		-- Red corner pillars
		local corners = {
			Vector3.new(-half, 0, -half),
			Vector3.new(half, 0, -half),
			Vector3.new(-half, 0, half),
			Vector3.new(half, 0, half),
		}
		for _, corner in ipairs(corners) do
			makePart("Pillar", Vector3.new(1.4, tier.Height, 1.4), CFrame.new(x + corner.X, floorY + tier.Height / 2, z + corner.Z), TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
		end

		if tierIndex == 1 then
			-- Open ground floor with a small shrine facing the stairs (+X)
			makePart("Shrine", Vector3.new(6, 5, 6), CFrame.new(x, floorY + 2.5, z), WALL_WHITE, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
			makePart("ShrineEmblem", Vector3.new(0.3, 2.4, 2.4), CFrame.new(x + 3.1, floorY + 3, z), GOLD, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		else
			-- Paper walls on the upper tiers
			makePart("Walls", Vector3.new(tier.Width - 2, tier.Height - 1, tier.Width - 2), CFrame.new(x, floorY + (tier.Height - 1) / 2, z), WALL_WHITE, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
		end

		-- Stepped roof with a wide overhang and red trim
		local roofY = floorY + tier.Height
		makePart("RoofTrim", Vector3.new(tier.Width + 8.4, 0.4, tier.Width + 8.4), CFrame.new(x, roofY - 0.2, z), TORII_RED, Enum.Material.SmoothPlastic, true, Enum.PartType.Block)
		makePart("Roof", Vector3.new(tier.Width + 8, 1, tier.Width + 8), CFrame.new(x, roofY + 0.5, z), ROOF_DARK, Enum.Material.Slate, true, Enum.PartType.Block)
		makePart("RoofUpper", Vector3.new(tier.Width + 3, 1, tier.Width + 3), CFrame.new(x, roofY + 1.5, z), ROOF_DARK, Enum.Material.Slate, true, Enum.PartType.Block)
		floorY = roofY + 2
	end

	-- Golden spire
	makeColumn("Spire", 6, 0.8, x, floorY, z, GOLD, Enum.Material.Metal, true)
	makePart("SpireBall", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x, floorY + 6.6, z), GOLD, Enum.Material.Metal, true, Enum.PartType.Ball)
end

local function buildTempleStairs(plateauY)
	local startX = TEMPLE_CENTER.X + TEMPLE_PLATEAU_RADIUS
	local rise = plateauY / (STAIR_COUNT + 1)
	for step = 1, STAIR_COUNT do
		local top = plateauY - rise * step
		local height = top + 4
		local x = startX + (step - 0.5) * STAIR_RUN
		makePart("Step", Vector3.new(STAIR_RUN, height, 8), CFrame.new(x, top - height / 2, TEMPLE_CENTER.Z), STONE_GREY, Enum.Material.Slate, true, Enum.PartType.Block)
	end
end

local function buildLantern(x, z)
	local y = groundHeightAt(x, z)
	makePart("LanternBase", Vector3.new(1.8, 0.6, 1.8), CFrame.new(x, y + 0.3, z), STONE_GREY, Enum.Material.Slate, true, Enum.PartType.Block)
	makePart("LanternPost", Vector3.new(0.7, 2.6, 0.7), CFrame.new(x, y + 1.9, z), STONE_GREY, Enum.Material.Slate, true, Enum.PartType.Block)
	local lightBox = makePart("LanternLight", Vector3.new(1.4, 1.2, 1.4), CFrame.new(x, y + 3.8, z), LANTERN_GLOW, Enum.Material.Neon, true, Enum.PartType.Block)
	makePart("LanternCap", Vector3.new(2.4, 0.6, 2.4), CFrame.new(x, y + 4.7, z), ROOF_DARK, Enum.Material.Slate, true, Enum.PartType.Block)
	makePart("LanternTop", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, y + 5.3, z), ROOF_DARK, Enum.Material.Slate, true, Enum.PartType.Block)

	local glow = Instance.new("PointLight")
	glow.Color = LANTERN_GLOW
	glow.Range = 12
	glow.Brightness = 1.2
	glow.Parent = lightBox
end

local function buildSakura(x, z)
	local y = groundHeightAt(x, z)
	local trunkHeight = rng:NextNumber(6, 9)
	makeColumn("Trunk", trunkHeight, 1.4, x, y, z, TRUNK_BROWN, Enum.Material.Wood, true)
	local top = Vector3.new(x, y + trunkHeight, z)
	for blossom = 1, 4 do
		local radius = rng:NextNumber(3.5, 5.5)
		local offset = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.5, 2), rng:NextNumber(-3, 3))
		local colour = SAKURA_PINK
		if rng:NextNumber() < 0.4 then
			colour = SAKURA_DEEP
		end
		makePart("Blossom", Vector3.new(radius * 2, radius * 2, radius * 2), CFrame.new(top + offset), colour, Enum.Material.Grass, false, Enum.PartType.Ball)
	end
end

local function buildPine(x, z)
	local y = groundHeightAt(x, z)
	local trunkHeight = rng:NextNumber(9, 13)
	makeColumn("Trunk", trunkHeight, 1.3, x, y, z, TRUNK_BROWN, Enum.Material.Wood, true)
	-- Cloud-like foliage pads
	for pad = 1, 3 do
		local padY = y + trunkHeight - (pad - 1) * 2.6
		local diameter = 5 + pad * 1.6
		local offsetX = rng:NextNumber(-1.5, 1.5)
		local offsetZ = rng:NextNumber(-1.5, 1.5)
		makeDisc("Foliage", 2, diameter, x + offsetX, padY, z + offsetZ, PINE_GREEN, Enum.Material.Grass, false)
	end
end

local function buildLakeDecor()
	-- Floating torii standing in the water
	buildTorii(Vector3.new(LAKE_CENTER.X + 15, -10, LAKE_CENTER.Z), 12, 22, math.rad(90))

	-- Wooden dock from the end of the east path
	local shoreX = LAKE_CENTER.X - LAKE_RADIUS - 8
	local dockLength = 18
	makePart("Dock", Vector3.new(dockLength, 0.6, 5), CFrame.new(shoreX + dockLength / 2, 0.3, 0), DOCK_BROWN, Enum.Material.WoodPlanks, true, Enum.PartType.Block)
	for postIndex = 0, 3 do
		local postX = shoreX + 3 + postIndex * 5
		makeColumn("DockPost", 12, 0.6, postX, -11.5, -2.2, DOCK_BROWN, Enum.Material.Wood, true)
		makeColumn("DockPost", 12, 0.6, postX, -11.5, 2.2, DOCK_BROWN, Enum.Material.Wood, true)
	end

	-- Lily pads, some with a pink flower
	for index = 1, LILY_PAD_COUNT do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(8, LAKE_RADIUS - 6)
		local x = LAKE_CENTER.X + math.cos(angle) * distance
		local z = LAKE_CENTER.Z + math.sin(angle) * distance
		makeDisc("LilyPad", 0.2, rng:NextNumber(2.5, 4), x, -1.9, z, LILY_GREEN, Enum.Material.SmoothPlastic, false)
		if rng:NextNumber() < 0.35 then
			makePart("LilyFlower", Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, -1.5, z), SAKURA_PINK, Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
		end
	end
end

local function buildLanterns()
	local sideOffset = PATH_WIDTH / 2 + 2
	-- North path
	for z = -20, -108, -22 do
		buildLantern(-sideOffset, z)
		buildLantern(sideOffset, z)
	end
	-- West path
	for x = -24, -104, -20 do
		buildLantern(x, -sideOffset)
		buildLantern(x, sideOffset)
	end
	-- East path
	for x = 24, 84, 20 do
		buildLantern(x, -sideOffset)
		buildLantern(x, sideOffset)
	end
end

local function buildTrees()
	for index = 1, SAKURA_COUNT do
		local found, x, z = randomFreeSpot(45, 330, 6)
		if found then
			buildSakura(x, z)
		end
	end
	for index = 1, PINE_COUNT do
		local found, x, z = randomFreeSpot(60, 340, 6)
		if found then
			buildPine(x, z)
		end
	end
end

----------------------------------------------------------------
-- Lighting
----------------------------------------------------------------

local function setupLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere == nil then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(215, 225, 240)
	atmosphere.Decay = Color3.fromRGB(120, 130, 150)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2

	local colourCorrection = Instance.new("ColorCorrectionEffect")
	colourCorrection.Name = "NinjaCoyoColour"
	colourCorrection.Saturation = 0.15
	colourCorrection.Contrast = 0.05
	colourCorrection.Parent = Lighting
end

----------------------------------------------------------------
-- Build everything
----------------------------------------------------------------

function World.Build()
	decorFolder.Parent = workspace

	buildTerrain()

	-- The terrain replaces the grey baseplate while the game runs
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil then
		baseplate:Destroy()
	end

	local plateauY = groundHeightAt(TEMPLE_CENTER.X, TEMPLE_CENTER.Z)
	buildPagoda(Vector3.new(TEMPLE_CENTER.X, plateauY, TEMPLE_CENTER.Z))
	buildTempleStairs(plateauY)

	local stairsBottomX = TEMPLE_CENTER.X + TEMPLE_PLATEAU_RADIUS + STAIR_COUNT * STAIR_RUN
	buildTorii(Vector3.new(stairsBottomX + 5, 0, TEMPLE_CENTER.Z), 12, 13, math.rad(90))
	buildLantern(stairsBottomX + 2, -9)
	buildLantern(stairsBottomX + 2, 9)

	buildLakeDecor()
	buildLanterns()
	buildTrees()
	setupLighting()
end

return World