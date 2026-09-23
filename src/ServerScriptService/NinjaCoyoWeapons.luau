-- Server-owned unlocks, target selection, cooldowns and damage for the dojo arsenal.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local Enemies = require(script.Parent:WaitForChild("NinjaCoyoEnemies"))
local Weapons = {}

function Weapons.ClearShot(character, enemy, origin, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, enemy.Model, workspace:FindFirstChild("Pets") }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(origin, target-origin, params)
	return hit == nil, hit
end

function Weapons.Attack(player, tool, context)
	local id = tool:GetAttribute("WeaponId")
	local spec = Config.Weapons[id]
	local data, character = context.Data[player], player.Character
	if not spec or not data or not data.Unlocks[id] or not character or tool.Parent ~= character
		or player:GetAttribute("MenuProtected") then return end
	local root, humanoid = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	local now = os.clock()
	if now - (context.LastAttack[player] or 0) < spec.Cooldown then return end
	context.LastAttack[player] = now
	local origin = root.Position + Vector3.new(0,1,0)
	local target = origin + root.CFrame.LookVector * spec.Range
	local damage = Config.GetValue("KatanaPower", data.Upgrades.KatanaPower) * spec.Damage
	local enemy = Enemies.FindNearestEnemy(player, origin, spec.Range)
	if enemy then target = enemy.Root.Position end
	local clear, obstruction = Weapons.ClearShot(character, enemy or {Model=tool}, origin, target)
	if obstruction and obstruction.Position then target = obstruction.Position end
	if enemy and clear then
		-- Gold sword entitlement applies only to the katana, not other weapons.
		Enemies.DamageEnemy(player, enemy, damage)
	end
	context.Fx:FireAllClients("WeaponAttack", character, id, { Origin = origin, Target = target })
end

function Weapons.Give(player, id, context)
	local spec, data = Config.Weapons[id], context.Data[player]
	if not spec or not data or not data.Unlocks[id] then return end
	local backpack = player:WaitForChild("Backpack",5)
	if not backpack then return end
	for _, container in ipairs({backpack, player.Character}) do
		if container:FindFirstChild(id) then return end
	end
	local tool = Instance.new("Tool")
	tool.Name, tool.ToolTip, tool.CanBeDropped = id, spec.Description, false
	tool:SetAttribute("WeaponId",id)
	local handle = Instance.new("Part")
	handle.Name, handle.Size = "Handle", Vector3.new(.25,1,.25)
	handle.Color, handle.Material = Color3.fromRGB(80,42,29), Enum.Material.Wood
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false,false,false,true
	handle.Parent = tool
	local function p(name,size,offset,colour)
		local part = handle:Clone()
		part.Name, part.Size, part.CFrame = name,size,handle.CFrame*offset
		part.Color, part.Material, part.Parent = colour or Color3.fromRGB(210,222,232),Enum.Material.Metal,tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent=handle,part,part
		return part
	end
	if id == "Bow" then
		for side=-1,1,2 do
			p("BowLimb",Vector3.new(.22,1.5,.22),CFrame.new(0,side*1.15,.25)*CFrame.Angles(side*.35,0,0),Color3.fromRGB(139,76,40))
		end
		p("BowString",Vector3.new(.04,3.4,.04),CFrame.new(0,0,.6))
		p("Arrow",Vector3.new(.08,.08,2.5),CFrame.new(0,0,-.6))
	elseif id == "Nunchaku" then
		p("Chain",Vector3.new(.1,.8,.1),CFrame.new(0,.85,0))
		p("SecondBaton",Vector3.new(.3,1.3,.3),CFrame.new(.4,1.75,0)*CFrame.Angles(0,0,-.6),Color3.fromRGB(120,60,35))
	elseif id == "Shuriken" then
		handle.Transparency=1
		for i=0,3 do
			p("StarBlade",Vector3.new(.28,1.4,.08),CFrame.Angles(0,0,i*math.pi/2)*CFrame.new(0,.45,0))
		end
	else
		local blade=p("KunaiBlade",Vector3.new(.65,1.5,.16),CFrame.new(0,1.1,0))
		blade.Shape=Enum.PartType.Block
		p("KunaiPoint",Vector3.new(.35,.6,.12),CFrame.new(0,2.0,0)*CFrame.Angles(0,0,math.pi/4))
	end
	tool.Activated:Connect(function() Weapons.Attack(player,tool,context) end)
	tool.Parent = backpack
end
return Weapons
