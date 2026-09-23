local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Config=require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local player=Players.LocalPlayer
local fx=ReplicatedStorage:WaitForChild("NinjaCoyoRemotes"):WaitForChild("Fx")
local lastAttack=0
local poses={}
local function pose(character,id)
	if poses[character] then return end
	local shoulder
	for _,p in ipairs(character:GetDescendants()) do
		if p:IsA("Motor6D") and (p.Name=="RightShoulder" or p.Name=="Right Shoulder") then shoulder=p;break end
	end
	if not shoulder then return end
	poses[character]=true
	local original=shoulder.C0
	local raised=original*CFrame.Angles(math.rad(id=="Bow" and 80 or 110),0,math.rad(-35))
	local draw=TweenService:Create(shoulder,TweenInfo.new(.09),{C0=raised})
	draw:Play()
	task.delay(.10,function()
		if shoulder.Parent then
			local release=TweenService:Create(shoulder,TweenInfo.new(.12),{C0=original*CFrame.Angles(math.rad(60),math.rad(70),math.rad(20))})
			release:Play()
		end
		task.delay(.13,function()
			if shoulder.Parent then TweenService:Create(shoulder,TweenInfo.new(.1),{C0=original}):Play() end
			task.delay(.11,function() poses[character]=nil end)
		end)
	end)
end
local function hook(tool)
	if not tool:IsA("Tool") or not Config.Weapons[tool:GetAttribute("WeaponId")] or tool:GetAttribute("ArsenalHooked") then return end
	tool:SetAttribute("ArsenalHooked",true)
	tool.Activated:Connect(function()
		local id=tool:GetAttribute("WeaponId")
		local spec=Config.Weapons[id]
		if player:GetAttribute("MenuOpen") or os.clock()-lastAttack<spec.Cooldown then return end
		lastAttack=os.clock()
		local char=player.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local nearest, distance=nil,spec.Range
		local enemies=workspace:FindFirstChild("Enemies")
		if enemies then
			for _,enemy in ipairs(enemies:GetChildren()) do
				local target=enemy:FindFirstChild("HumanoidRootPart")
				local hum=enemy:FindFirstChildOfClass("Humanoid")
				if target and hum and hum.Health>0 and enemy:GetAttribute("OwnerUserId")==player.UserId then
					local gap=(target.Position-root.Position).Magnitude
					if gap<distance then nearest,distance=target,gap end
				end
			end
		end
		if nearest then
			local target=Vector3.new(nearest.Position.X,root.Position.Y,nearest.Position.Z)
			if (target-root.Position).Magnitude>.1 then root.CFrame=CFrame.lookAt(root.Position,target) end
		end
		pose(char,id)
	end)
end
local function characterAdded(character)
	character.ChildAdded:Connect(hook)
	for _,child in ipairs(character:GetChildren()) do hook(child) end
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then characterAdded(player.Character) end
fx.OnClientEvent:Connect(function(kind,character,id,shot)
	if kind~="WeaponAttack" or not Config.Weapons[id] then return end
	if character~=player.Character then pose(character,id) end
	local p=Instance.new("Part")
	p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
	p.Material,p.Color=Enum.Material.Neon,Color3.fromRGB(255,214,112)
	p.Name="WeaponProjectile"
	local distance=(shot.Target-shot.Origin).Magnitude
	if distance<.01 then p:Destroy();return end
	if id=="Nunchaku" then
		p.Size=Vector3.new(.2,.2,math.min(distance,8))
		p.CFrame=CFrame.lookAt(shot.Origin,shot.Target)*CFrame.new(0,0,-p.Size.Z/2)
		p.Parent=workspace
		TweenService:Create(p,TweenInfo.new(.15),{Transparency=1}):Play()
		Debris:AddItem(p,.2)
	else
		p.Size=id=="Bow" and Vector3.new(.12,.12,3) or Vector3.new(.8,.12,.8)
		p.CFrame=CFrame.lookAt(shot.Origin,shot.Target)
		p.Parent=workspace
		TweenService:Create(p,TweenInfo.new(distance/180,Enum.EasingStyle.Linear),{Position=shot.Target,Transparency=.6}):Play()
		Debris:AddItem(p,distance/180)
	end
end)
