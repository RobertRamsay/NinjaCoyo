local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local House = {}

function House.Build(onOpen)
	local folder = Instance.new("Folder")
	folder.Name = "DressingHouses"
	folder.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local positions = { Config.Wardrobe.ShrinePosition, Vector3.new(46, 0, -180), Vector3.new(-46, 0, -380) }
	for _, position in ipairs(positions) do
		local result = workspace:Raycast(position + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
		local cf = CFrame.new(position.X, result and result.Position.Y or 0, position.Z)
		local wood = Color3.fromRGB(99, 65, 46)
		local cream = Color3.fromRGB(231, 213, 174)
		local indigo = Color3.fromRGB(57, 65, 106)
		local function part(name, size, offset, colour, material, collide)
			local p = Instance.new("Part")
			p.Name, p.Size, p.CFrame = name, size, cf * offset
			p.Color, p.Material = colour, material
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, collide, false, false
			p.Parent = folder
			return p
		end
		part("WoodenDeck", Vector3.new(16, 1, 14), CFrame.new(0, 0.5, 0), wood, Enum.Material.WoodPlanks, true)
		part("Doorstep", Vector3.new(7, 0.5, 3), CFrame.new(0, 0.25, 8), wood, Enum.Material.WoodPlanks, true)
		part("BackWall", Vector3.new(15, 8, 0.6), CFrame.new(0, 5, -6), cream, Enum.Material.WoodPlanks, true)
		for _, side in ipairs({ -1, 1 }) do
			part("SideWall", Vector3.new(0.6, 8, 12), CFrame.new(side * 7.3, 5, 0), cream, Enum.Material.WoodPlanks, true)
			part("DoorFrame", Vector3.new(0.7, 8, 0.8), CFrame.new(side * 3, 5, 6), wood, Enum.Material.Wood, true)
			part("FrontPanel", Vector3.new(4, 8, 0.6), CFrame.new(side * 5.1, 5, 6), cream, Enum.Material.WoodPlanks, true)
			part("ChangingCurtain", Vector3.new(2.5, 4.5, 0.13), CFrame.new(side * 1.55, 6.7, 6.45), indigo, Enum.Material.Fabric, false)
			part("CurtainEmblem", Vector3.new(0.5, 0.7, 0.04), CFrame.new(side * 1.55, 6.7, 6.54) * CFrame.Angles(0, 0, 0.7), cream, Enum.Material.Fabric, false)
			part("RoofSlope", Vector3.new(9.5, 0.7, 17), CFrame.new(side * 4.5, 10.4, 0) * CFrame.Angles(0, 0, -side * 0.25), indigo, Enum.Material.Slate, true)
			for z = -7, 7, 1.5 do
				part("TileSeam", Vector3.new(9.5, 0.12, 0.08), CFrame.new(side * 4.5, 10.8, z) * CFrame.Angles(0, 0, -side * 0.25), wood, Enum.Material.Slate, false)
			end
			local lantern = part("PaperLantern", Vector3.new(1.2, 1.8, 1.2), CFrame.new(side * 5, 7, 7), Color3.fromRGB(255, 216, 141), Enum.Material.Neon, false)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Parent = lantern.Color, 13, 0.7, lantern
		end
		part("RidgeCap", Vector3.new(1, 0.8, 18), CFrame.new(0, 11.7, 0), indigo, Enum.Material.Slate, true)
		part("MirrorFrame", Vector3.new(3.5, 5.5, 0.4), CFrame.new(-4, 4.3, -5.5), wood, Enum.Material.Wood, true)
		local mirror = part("MirrorGlass", Vector3.new(3, 5, 0.08), CFrame.new(-4, 4.3, -5.23), Color3.fromRGB(159, 192, 203), Enum.Material.Glass, false)
		mirror.Reflectance = 0.3
		part("ClothesRail", Vector3.new(5.5, 0.2, 0.2), CFrame.new(3, 6.5, -4), wood, Enum.Material.Wood, false)
		for i = 1, 3 do
			part("HangingJacket", Vector3.new(1.4, 3.5, 0.25), CFrame.new(0.5 + i * 1.4, 4.6, -4), ({ indigo, Color3.fromRGB(149, 40, 50), Color3.fromRGB(64, 130, 96) })[i], Enum.Material.Fabric, false)
		end
		part("ChangingBench", Vector3.new(9, 1.2, 2), CFrame.new(0, 1.6, -2), wood, Enum.Material.WoodPlanks, true)
		local signPart = part("HouseSign", Vector3.new(7, 1.5, 0.4), CFrame.new(0, 9, 6.8), wood, Enum.Material.Wood, false)
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.MaxDistance, gui.Parent = UDim2.fromOffset(230, 44), Vector3.new(0, 1, 0), 80, signPart
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.Font, label.TextScaled = "DRESSING HOUSE", Enum.Font.FredokaOne, true
		label.TextColor3, label.TextStrokeTransparency, label.Parent = cream, 0.3, gui
		local entry = part("WardrobeEntrance", Vector3.new(1, 1, 1), CFrame.new(0, 3, 7.5), cream, Enum.Material.SmoothPlastic, false)
		entry.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Choose outfit & dogs", "Dressing House"
		prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = 10, false, entry
		prompt.Triggered:Connect(onOpen)
	end
end

return House
