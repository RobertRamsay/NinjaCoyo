-- Hand-placed landmarks and treasure terraces. Kept clear of gate approaches.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local Scenery = {}
local terrain = workspace.Terrain
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { terrain }
local folder = Instance.new("Folder")
folder.Name = "MeadowLandmarks"
local stone = Color3.fromRGB(143, 151, 143)
local wood = Color3.fromRGB(100, 65, 43)
local roof = Color3.fromRGB(47, 65, 68)
local cream = Color3.fromRGB(236, 220, 184)

local function ground(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or 0
end

local function part(name, size, cf, colour, material, collide, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, colour
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collide, false, false
	p.Parent = folder
	return p
end

local function guardian(x, z, yaw)
	local cf = CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, yaw, 0)
	part("GuardianPlinth", Vector3.new(5, 1, 5), cf * CFrame.new(0, 0.5, 0), stone, Enum.Material.Slate, true)
	part("WolfStatueBody", Vector3.new(2.2, 3.8, 2.6), cf * CFrame.new(0, 2.8, 0), stone, Enum.Material.Marble, true, Enum.PartType.Ball)
	part("WolfStatueHead", Vector3.new(2, 1.8, 2), cf * CFrame.new(0, 5.1, -0.6), stone, Enum.Material.Marble, true, Enum.PartType.Ball)
	part("WolfStatueMuzzle", Vector3.new(1.1, 0.8, 1.3), cf * CFrame.new(0, 4.9, -1.7), stone, Enum.Material.Marble, true)
	for _, s in ipairs({ -1, 1 }) do
		part("GuardianEar", Vector3.new(0.5, 1.2, 0.7), cf * CFrame.new(s * 0.7, 6.1, -0.4) * CFrame.Angles(0, 0, s * -0.18), stone, Enum.Material.Marble, true)
		part("GuardianPaw", Vector3.new(0.7, 2.5, 1.1), cf * CFrame.new(s * 0.8, 2.3, -1.1), stone, Enum.Material.Marble, true)
	end
	part("GuardianScarf", Vector3.new(2.2, 0.35, 2.1), cf * CFrame.new(0, 4.1, -0.5), Color3.fromRGB(169, 36, 42), Enum.Material.Fabric, false)
end

local function pavilion(x, z, yaw)
	local cf = CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, yaw, 0)
	part("TeaHouseDeck", Vector3.new(19, 1, 15), cf * CFrame.new(0, 0.5, 0), wood, Enum.Material.WoodPlanks, true)
	part("TeaHouseStep", Vector3.new(12, 0.5, 3), cf * CFrame.new(0, 0.25, -9), stone, Enum.Material.Slate, true)
	for _, xSide in ipairs({ -8, 8 }) do
		for _, zSide in ipairs({ -6, 6 }) do
			part("TimberColumn", Vector3.new(0.8, 8, 0.8), cf * CFrame.new(xSide, 5, zSide), wood, Enum.Material.Wood, true)
		end
	end
	part("PaperScreen", Vector3.new(16, 6, 0.35), cf * CFrame.new(0, 4, 6), cream, Enum.Material.Fabric, true)
	for xBar = -8, 8, 2 do
		part("ScreenLattice", Vector3.new(0.12, 6, 0.5), cf * CFrame.new(xBar, 4, 6), wood, Enum.Material.Wood, false)
	end
	for _, side in ipairs({ -1, 1 }) do
		part("SlopedTileRoof", Vector3.new(11, 0.7, 18), cf * CFrame.new(side * 5, 10, 0) * CFrame.Angles(0, 0, -side * 0.25), roof, Enum.Material.Slate, true)
	end
	part("RoofRidge", Vector3.new(1, 0.8, 19), cf * CFrame.new(0, 11.4, 0), roof, Enum.Material.Slate, true)
	part("TeaBench", Vector3.new(11, 1, 2), cf * CFrame.new(0, 2, 3.5), wood, Enum.Material.WoodPlanks, true)
	part("TeaTable", Vector3.new(4, 1.6, 3), cf * CFrame.new(0, 1.8, 0), wood, Enum.Material.Wood, true)
	for _, side in ipairs({ -1, 1 }) do
		part("SeatCushion", Vector3.new(2.5, 0.4, 2.5), cf * CFrame.new(side * 4, 1.2, 0), Color3.fromRGB(131, 44, 50), Enum.Material.Fabric, false)
	end
end

function Scenery.Build()
	folder.Parent = workspace
	for _, hill in ipairs(Config.TreasureTerraces) do
		local c = hill.Center
		-- Broad natural slopes with a level summit and stepping-stone route.
		terrain:FillBall(Vector3.new(c.X, hill.Height - hill.Radius * 1.5, c.Z), hill.Radius * 1.5, Enum.Material.Grass)
		terrain:FillCylinder(CFrame.new(c.X, hill.Height - 3, c.Z), 6, hill.Radius, Enum.Material.Grass)
		local steps = math.ceil(hill.Height / 3)
		for step = 1, steps do
			local z = c.Z + hill.Radius + (steps - step) * 4
			local top = hill.Height * step / steps
			terrain:FillBlock(CFrame.new(c.X, top / 2, z), Vector3.new(7, top, 5), Enum.Material.Rock)
		end
	end
	pavilion(-115, 175, 0.35)
	pavilion(205, 110, -0.7)
	pavilion(-44, -190, 0)
	for _, p in ipairs({ Vector3.new(-23,0,-86), Vector3.new(23,0,-86), Vector3.new(-120,0,22), Vector3.new(-120,0,-22), Vector3.new(60,0,170), Vector3.new(-215,0,165) }) do
		guardian(p.X, p.Z, math.atan2(p.X, p.Z))
	end
end

-- Reserve building footprints (including roofs) so pickups never hide in them.
function Scenery.IsPickupClear(position)
	for _, root in pairs({ folder, workspace:FindFirstChild("WorldDecor"), workspace:FindFirstChild("DressingHouses"), workspace:FindFirstChild("Zones") }) do
		if root then
			for _, p in ipairs(root:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide and p.Name ~= "Floor" then
					-- World-space footprint also handles cylinders rotated upright.
					local right, up, look = p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector
					local halfX = (math.abs(right.X) * p.Size.X + math.abs(up.X) * p.Size.Y + math.abs(look.X) * p.Size.Z) / 2
					local halfZ = (math.abs(right.Z) * p.Size.X + math.abs(up.Z) * p.Size.Y + math.abs(look.Z) * p.Size.Z) / 2
					if math.abs(position.X - p.Position.X) < halfX + 2.5 and math.abs(position.Z - p.Position.Z) < halfZ + 2.5 then
						return false
					end
				end
			end
		end
	end
	return true
end

return Scenery
