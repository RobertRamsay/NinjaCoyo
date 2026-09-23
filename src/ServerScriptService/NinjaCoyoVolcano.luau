-- Hollow volcanic shell: a visible mountain outside and an open lava cavern inside.
local Volcano = {}
function Volcano.Build(parent, zone, y)
	local c=Vector3.new(zone.Center.X,y,zone.Center.Z)
	local function part(name,size,position,material,colour,solid)
		local p=Instance.new("Part")
		p.Name,p.Size,p.Position=name,size,position
		p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,solid,false,false
		p.Material,p.Color,p.Parent=material,colour,parent
		return p
	end
	local rock=Color3.fromRGB(49,34,33)
	-- Overlapping rock ribs taper around a hollow chamber. Leave a broad front doorway.
	for band=0,4 do
		local radius=154-band*17
		for segment=0,31 do
			local angle=segment*math.pi/16
			if not (band==0 and (segment==0 or segment==1 or segment==31)) then
				local p=part("VolcanoRock",Vector3.new(radius*.22,40,27),c+Vector3.new(math.sin(angle)*radius,18+band*36,math.cos(angle)*radius),Enum.Material.Basalt,rock,true)
				p.CFrame=CFrame.new(p.Position)*CFrame.Angles(0,angle,0)
			end
		end
	end
	-- Solid high vault, with a luminous crater cap visible above the exterior cone.
	local vault=part("CavernVault",Vector3.new(12,150,150),c+Vector3.new(0,182,0),Enum.Material.Basalt,rock,true)
	vault.Shape=Enum.PartType.Cylinder
	vault.CFrame=CFrame.new(vault.Position)*CFrame.Angles(0,0,math.pi/2)
	local crater=part("CraterGlow",Vector3.new(2,115,115),c+Vector3.new(0,189,0),Enum.Material.Neon,Color3.fromRGB(255,68,12),false)
	crater.Shape=Enum.PartType.Cylinder
	crater.CFrame=CFrame.new(crater.Position)*CFrame.Angles(0,0,math.pi/2)
	part("EntranceCauseway",Vector3.new(28,1,60),c+Vector3.new(0,.5,145),Enum.Material.Slate,rock,true).CanQuery=true
	-- Lava sits beside broad, level fighting areas, leaving the doorway and treasure route open.
	for _,offset in ipairs({Vector3.new(-68,0,-35),Vector3.new(-62,0,40),Vector3.new(67,0,-58)}) do
		local pool=part("LavaPool",Vector3.new(25,.3,28),c+offset+Vector3.new(0,.15,0),Enum.Material.Neon,Color3.fromRGB(255,62,8),false)
		local light=Instance.new("PointLight")
		light.Color,light.Range,light.Brightness,light.Parent=pool.Color,45,2,pool
		for i=1,4 do
			local angle=i*math.pi/2
			part("ObsidianBoulder",Vector3.new(8,9,8),pool.Position+Vector3.new(math.sin(angle)*17,3,math.cos(angle)*17),Enum.Material.Basalt,rock,true).Shape=Enum.PartType.Ball
		end
	end
	for _,x in ipairs({-19,19}) do
		local lamp=part("EntranceEmber",Vector3.new(3,12,3),c+Vector3.new(x,7,156),Enum.Material.Neon,Color3.fromRGB(255,90,20),false)
		local light=Instance.new("PointLight")
		light.Color,light.Range,light.Brightness,light.Parent=lamp.Color,30,2, lamp
	end
end
return Volcano
