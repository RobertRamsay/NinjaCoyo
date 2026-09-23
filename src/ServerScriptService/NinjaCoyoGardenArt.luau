-- Rounded, branching silhouettes shared by the meadow and later gardens.
local Art = {}
local bark = Color3.fromRGB(91, 59, 48)
local function piece(parent, name, size, cf, colour, material, shape, solid)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, colour
	p.Material, p.Shape = material, shape or Enum.PartType.Block
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, solid == true, false, false
	p.Parent = parent
	return p
end
local function branch(parent, a, b, width)
	return piece(parent, "TwistedBranch", Vector3.new((b-a).Magnitude, width, width),
		CFrame.lookAt((a+b)/2, b) * CFrame.Angles(0, math.pi/2, 0), bark, Enum.Material.Wood, Enum.PartType.Cylinder, true)
end

function Art.Tree(parent, origin, height, colour, seed, blossoms)
	local rng = Random.new(seed)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local last = origin
	local tips = {}
	for segment = 1, 5 do
		local t = segment / 5
		local angle = yaw + t * 2.7
		local bend = height * 0.16 * math.sin(t * math.pi * 0.8)
		local point = origin + Vector3.new(math.cos(angle) * bend, height * t, math.sin(angle) * bend)
		branch(parent, last, point, height * (0.09 - t * 0.055))
		if segment >= 3 then
			for side = 0, 1 do
				local direction = angle + side * math.pi + 0.7
				local reach = height * (0.4 - t * 0.17)
				local elbow = point + Vector3.new(math.cos(direction) * reach * 0.55, height * 0.025, math.sin(direction) * reach * 0.55)
				local tip = point + Vector3.new(math.cos(direction) * reach, height * 0.10, math.sin(direction) * reach)
				branch(parent, point, elbow, height * 0.035)
				branch(parent, elbow, tip, height * 0.021)
				table.insert(tips, tip)
			end
		end
		last = point
	end
	for index, tip in ipairs(tips) do
		local crown
		for cluster = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-1,1), rng:NextNumber(-0.3,0.3), rng:NextNumber(-1,1)) * height * 0.06
			local tint = colour:Lerp(Color3.fromRGB(255, 232, 218), rng:NextNumber(0, blossoms and 0.35 or 0.10))
			crown = piece(parent, blossoms and "BlossomCloud" or "BonsaiCrown",
				Vector3.new(height * 0.35, height * (blossoms and 0.17 or 0.10), height * 0.30),
				CFrame.new(tip + offset), tint, Enum.Material.Grass, Enum.PartType.Ball, false)
		end
		if blossoms and index == 3 then
			local petals = Instance.new("ParticleEmitter")
			petals.Name = "DriftingBlossoms"
			petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			petals.Color = ColorSequence.new(colour, Color3.fromRGB(255, 231, 240))
			petals.Size = NumberSequence.new(0.22)
			petals.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.1), NumberSequenceKeypoint.new(0.8,0.2), NumberSequenceKeypoint.new(1,1)})
			petals.Rate, petals.Lifetime, petals.Speed = 2, NumberRange.new(4,7), NumberRange.new(0.5,2)
			petals.Acceleration, petals.SpreadAngle = Vector3.new(0.8,-1.5,0.3), Vector2.new(180,180)
			petals.Rotation, petals.RotSpeed = NumberRange.new(0,360), NumberRange.new(-50,50)
			petals.Parent = crown
		end
	end
end

function Art.Buddha(parent, origin, scale)
	local stone = Color3.fromRGB(165, 153, 129)
	local cf = CFrame.new(origin)
	local function form(name, size, offset, shape, colour)
		return piece(parent, name, size * scale, cf * CFrame.new(offset * scale), colour or stone, Enum.Material.Sandstone, shape or Enum.PartType.Ball, true)
	end
	form("LotusPlinth", Vector3.new(2,13,13), Vector3.new(0,1,0), Enum.PartType.Cylinder).CFrame = cf * CFrame.new(0,scale,0) * CFrame.Angles(0,0,math.pi/2)
	for i = 1, 10 do
		local angle = i * math.pi/5
		form("LotusPetal", Vector3.new(3,1.2,4), Vector3.new(math.cos(angle)*4.5,2,math.sin(angle)*4.5))
	end
	form("CrossedLegs", Vector3.new(9,2.7,5), Vector3.new(0,3,0))
	form("SeatedRobe", Vector3.new(5.5,6.5,3.6), Vector3.new(0,6,0))
	form("BuddhaHead", Vector3.new(3,3.8,3), Vector3.new(0,10.7,0))
	form("TopKnot", Vector3.new(1.6,1.6,1.6), Vector3.new(0,13,0))
	for _, side in ipairs({-1,1}) do
		form("LongEar", Vector3.new(.5,2,.8), Vector3.new(side*1.6,10,0))
		form("RobeArm", Vector3.new(1.6,4,1.8), Vector3.new(side*2.7,6,-.1))
		form("RestingHand", Vector3.new(1.5,.8,2), Vector3.new(side*1.3,4.4,-2))
		form("ClosedEye", Vector3.new(.75,.12,.14), Vector3.new(side*.7,11,-1.48), Enum.PartType.Block, Color3.fromRGB(75,69,60))
	end
	form("Nose", Vector3.new(.5,.9,.5), Vector3.new(0,10.6,-1.55))
	form("CalmSmile", Vector3.new(.9,.12,.18), Vector3.new(0,9.9,-1.42), Enum.PartType.Block, Color3.fromRGB(90,80,68))
end

function Art.Shrine(parent, origin, scale)
	local cf = CFrame.new(origin)
	local wood, roof = Color3.fromRGB(132,55,42), Color3.fromRGB(48,61,67)
	local function p(name,size,offset,colour)
		return piece(parent,name,size*scale,cf*CFrame.new(offset*scale),colour,Enum.Material.WoodPlanks,nil,true)
	end
	p("ShrineStep",Vector3.new(12,.8,9),Vector3.new(0,.4,1),roof)
	p("ShrineDeck",Vector3.new(10,1,7),Vector3.new(0,1.3,0),wood)
	for _, side in ipairs({-1,1}) do
		p("ShrinePillar",Vector3.new(.8,7,.8),Vector3.new(side*4,5,2.5),wood)
		local eave=p("CurvedShrineRoof",Vector3.new(7,.6,10),Vector3.new(side*3,9,0),roof)
		eave.CFrame=cf*CFrame.new(side*3*scale,9*scale,0)*CFrame.Angles(0,0,-side*.25)
		local tip=p("UpturnedEave",Vector3.new(2,.5,10.4),Vector3.new(side*6.5,8.5,0),roof)
		tip.CFrame=cf*CFrame.new(side*6.5*scale,8.5*scale,0)*CFrame.Angles(0,0,side*.25)
	end
	p("ShrineBack",Vector3.new(9,7,.5),Vector3.new(0,5,-3),wood)
	p("OfferingTable",Vector3.new(5,2,2),Vector3.new(0,2.8,0),roof)
	local bell=p("ShrineBell",Vector3.new(1,1.4,1),Vector3.new(0,7,2),Color3.fromRGB(214,168,64))
	bell.Shape, bell.Material = Enum.PartType.Ball, Enum.Material.Metal
end
return Art
