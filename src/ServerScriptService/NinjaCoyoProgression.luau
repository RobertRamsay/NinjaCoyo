-- Floating treasure routes and shared, enemy-free rest dojos.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local PhysicsService = game:GetService("PhysicsService")
local Progression = {}
local shelters, slots, readyAt = {}, {}, {}
local folder = Instance.new("Folder")
folder.Name = "ProgressionLandmarks"

local function part(name, size, position, colour, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, position
	p.Color, p.Material = colour, material or Enum.Material.WoodPlanks
	p.Anchored, p.CanTouch = true, false
	p.Parent = folder
	return p
end

local function sign(anchor, text)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(240, 55), Vector3.new(0, 4, 0), 100
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.Font, label.TextSize = text, Enum.Font.FredokaOne, 18
	label.TextColor3, label.TextStrokeTransparency, label.TextWrapped = Color3.new(1, 1, 1), 0.2, true
	label.Parent = gui
end

function Progression.IsSafe(position)
	for _, shelter in ipairs(shelters) do
		local offset = position - shelter.Center
		if math.abs(offset.X) < 23 and math.abs(offset.Z) < 19
			and offset.Y > 0 and offset.Y < 19 then return true end
	end
	return false
end

function Progression.GetChestSlot(zoneId, chests)
	for _, slot in ipairs(slots) do
		if slot.Zone == zoneId and os.clock() >= (readyAt[slot.Id] or 0) then
			local occupied = false
			for _, chest in ipairs(chests:GetChildren()) do
				if chest:GetAttribute("SkySlot") == slot.Id then occupied = true; break end
			end
			if not occupied then return slot end
		end
	end
	return nil
end

function Progression.ChestOpened(id)
	if id then readyAt[id] = os.clock() + 90 end
end

function Progression.Reserved(position, margin)
	margin = margin or 0
	for index, zoneId in ipairs(Config.ZoneOrder) do
		local zone = Config.Zones[zoneId]
		local x, z = position.X - zone.Center.X, position.Z - zone.Center.Z
		if x > 6 - margin and x < 48 + margin and z > -82 - margin and z < 8 + margin then return true end
		if index % 3 == 0 and math.abs(x - 48) < 27 + margin and z > 7 - margin and z < 66 + margin then return true end
	end
	return false
end

local function restDojo(zone, y)
	local c = Vector3.new(zone.Center.X + 48, y + 3, zone.Center.Z + 32)
	table.insert(shelters, { Center = c })
	local wood, red = Color3.fromRGB(100, 62, 42), Color3.fromRGB(150, 42, 44)
	local floor = part("RestDojoFloor", Vector3.new(48, 1, 40), c + Vector3.new(0, 0.5, 0), wood)
	sign(floor, "REST DOJO\nPlayers welcome • No enemies")
	-- Solid timber foundation raises the walking surface four studs above ground.
	part("RestDojoFoundation", Vector3.new(48, 3, 40), c + Vector3.new(0, -1.5, 0), wood)
	for step = 1, 4 do
		local height = step
		part("RestDojoStep", Vector3.new(18, height, 3),
			c + Vector3.new(0, -3 + height / 2, 33.5 - step * 3), wood)
	end
	part("RestDojoBack", Vector3.new(48, 18, 1), c + Vector3.new(0, 10, -20), wood)
	for _, side in ipairs({ -1, 1 }) do
		part("RestDojoSide", Vector3.new(1, 18, 40), c + Vector3.new(side * 24, 10, 0), wood)
		part("RestDojoFront", Vector3.new(15, 18, 1), c + Vector3.new(side * 16.5, 10, 20), wood)
		part("RestDojoBench", Vector3.new(4, 2, 26), c + Vector3.new(side * 18, 2, 0), red)
		local roof = part("RestDojoRoof", Vector3.new(29, 1, 46), c + Vector3.new(side * 12, 21, 0), Color3.fromRGB(40, 48, 60), Enum.Material.Slate)
		roof.CFrame = CFrame.new(roof.Position) * CFrame.Angles(0, 0, -side * 0.16)
		for _, z in ipairs({ -13, 0, 13 }) do
			local seat = Instance.new("Seat")
			seat.Size, seat.Position = Vector3.new(3, 1, 3), c + Vector3.new(side * 12, 1.5, z)
			seat.Anchored, seat.Color, seat.Material, seat.Parent = true, red, Enum.Material.Fabric, folder
		end
	end
	part("RestDojoHeader", Vector3.new(18, 5, 1), c + Vector3.new(0, 16.5, 20), wood)
	local barrier = part("EnemyExclusion", Vector3.new(47, 18, 39), c + Vector3.new(0, 10, 0), wood)
	barrier.Transparency, barrier.CanQuery, barrier.CollisionGroup = 1, false, "NinjaCoyoRestBarrier"
	local lamp = part("RestDojoLantern", Vector3.new(2, 3, 2), c + Vector3.new(0, 16, 0), Color3.fromRGB(255, 211, 126), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Parent = lamp.Color, 2, 45, lamp
end

function Progression.Build()
	for _, name in ipairs({ "NinjaCoyoEnemies", "NinjaCoyoRestBarrier" }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
	end
	PhysicsService:CollisionGroupSetCollidable("NinjaCoyoRestBarrier", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("NinjaCoyoRestBarrier", "NinjaCoyoEnemies", true)
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { workspace.Terrain, workspace:FindFirstChild("Zones") }
	for index, zoneId in ipairs(Config.ZoneOrder) do
		local zone, route = Config.Zones[zoneId], Config.PlatformRoutes[zoneId]
		local hit = workspace:Raycast(zone.Center + Vector3.new(0, 180, 0), Vector3.new(0, -360, 0), params)
		local y = hit and hit.Position.Y or 0.1
		local start = part("TrailStart", Vector3.new(14, 1, 14), Vector3.new(zone.Center.X + 38, y + 0.5, zone.Center.Z), zone.DecorColor, Enum.Material.Slate)
		sign(start, "SKY TREASURE\nNinja Jump Lv " .. route.JumpLevel)
		for step = 1, route.Count do
			local x = zone.Center.X + (step % 2 == 1 and 16 or 38)
			local top = Vector3.new(x, y + step * route.Rise, zone.Center.Z - step * 7)
			part("FloatingPlatform", Vector3.new(16, 2, 16), top - Vector3.new(0, 1, 0), zone.FloorColor, Enum.Material.Slate)
			local trim = part("PlatformGlow", Vector3.new(16.3, 0.25, 16.3), top - Vector3.new(0, 0.4, 0), zone.DecorColor, Enum.Material.Neon)
			trim.CanCollide, trim.CanQuery = false, false
			if step == math.ceil(route.Count / 2) or step == route.Count then
				table.insert(slots, { Id = zoneId .. "_" .. step, Zone = zoneId, Position = top,
					JumpLevel = route.JumpLevel, Multiplier = step == route.Count and 6 or 3,
					Name = step == route.Count and "SUMMIT RELIC" or "SKY CACHE" })
			end
		end
		if index % 3 == 0 then restDojo(zone, y) end
	end
end

return Progression
