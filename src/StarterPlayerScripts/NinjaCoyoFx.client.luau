-- NinjaCoyoFx (LocalScript in StarterPlayer > StarterPlayerScripts)
-- Katana swing animation and trail, chest hit sparks, chest smash and coin bursts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))
local Sounds = require(ReplicatedStorage:WaitForChild("NinjaCoyoSounds"))
local remotes = ReplicatedStorage:WaitForChild("NinjaCoyoRemotes")
local fxEvent = remotes:WaitForChild("Fx")

local player = Players.LocalPlayer
local rng = Random.new()

-- Swing tuning (angles are relative to the torso; negative yaw = ninja's right)
local SWING_WINDUP_TIME = 0.07
local SWING_SLASH_TIME = 0.14
local SWING_RECOVER_TIME = 0.12
local ARM_RAISE_START = math.rad(50)
local ARM_RAISE = math.rad(92)
local ARM_YAW_WINDUP = math.rad(-100)
local ARM_YAW_FINISH = math.rad(115)
local WAIST_TWIST_WINDUP = math.rad(-40)
local WAIST_TWIST_FINISH = math.rad(55)
local BLADE_FORWARD = CFrame.Angles(math.rad(90), 0, 0)

-- Slash arc effect (a wide glowing crescent that sweeps around the ninja)
local ARC_INNER = 2
local ARC_OUTER = 7.5
local ARC_HEIGHT = 0.4
local ARC_START_YAW = math.rad(-80)
local ARC_END_YAW = math.rad(100)
local ARC_TILT = math.rad(-8)

-- Effects tuning
local COIN_GRAVITY = 70
local COIN_MAGNET_DELAY = 0.55
local COIN_LIFETIME = 2
local BURST_COIN_COUNT = 10

-- Colours
local CHEST_WOOD = Color3.fromRGB(120, 78, 40)
local CHEST_LID = Color3.fromRGB(92, 58, 30)
local GOLD = Color3.fromRGB(255, 196, 40)
local SPARK = Color3.fromRGB(255, 240, 180)

-- State (initialised up front)
local originalGrip = setmetatable({}, { __mode = "k" })
local activeSwings = {}
local fxBits = {}
local lastLocalSwing = 0

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function easeOutQuad(a)
	return 1 - (1 - a) * (1 - a)
end

local function easeInOutCubic(a)
	if a < 0.5 then
		return 4 * a * a * a
	end
	local f = -2 * a + 2
	return 1 - f * f * f / 2
end

local function makeFxPart(size, cframe, colour, material, shape)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = colour
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = fxFolder
	return part
end

local function launchBit(part, position, velocity, groundY, magnet)
	local bit = {}
	bit.Part = part
	bit.Position = position
	bit.Velocity = velocity
	bit.GroundY = groundY
	bit.Age = 0
	bit.Magnet = magnet
	table.insert(fxBits, bit)
end

local function burstSparks(position, count, colour)
	local holder = makeFxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), colour, Enum.Material.Neon, Enum.PartType.Block)
	holder.Transparency = 1

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)

	Debris:AddItem(holder, 1)
end

local function shakeCamera(duration, strength)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local fade = 1 - elapsed / duration
			local jitter = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			humanoid.CameraOffset = jitter * strength * fade
			elapsed = elapsed + RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function findMotor(character, partName, motorName)
	local part = character:FindFirstChild(partName)
	if part == nil then
		return nil
	end
	local motor = part:FindFirstChild(motorName)
	if motor == nil then
		return nil
	end
	if motor:IsA("Motor6D") == false then
		return nil
	end
	return motor
end

----------------------------------------------------------------
-- Katana swing (horizontal slash, right to left)
----------------------------------------------------------------

local function createSlashArc(level)
	local pivot = makeFxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Block)
	pivot.Transparency = 1

	local inner = Instance.new("Attachment")
	inner.Position = Vector3.new(0, 0, -ARC_INNER)
	inner.Parent = pivot

	local outer = Instance.new("Attachment")
	outer.Position = Vector3.new(0, 0, -math.min(9.5, ARC_OUTER + level * 0.1))
	outer.Parent = pivot

	local trail = Instance.new("Trail")
	trail.Attachment0 = inner
	trail.Attachment1 = outer
	trail.Lifetime = 0.22 + math.min(level, 30) * 0.004
	trail.MinLength = 0
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 210, 255))
	if level >= 20 then
		trail.Color = ColorSequence.new(Color3.fromRGB(245, 210, 255), Color3.fromRGB(182, 106, 255))
	elseif level >= 10 then
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 246, 194), Color3.fromRGB(255, 183, 70))
	end
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Enabled = false
	trail.Parent = pivot

	return pivot, trail
end

local function placeArc(swing, arcYaw)
	local rootCFrame = swing.Root.CFrame
	swing.ArcPivot.CFrame = CFrame.new(rootCFrame.Position + Vector3.new(0, ARC_HEIGHT, 0)) * rootCFrame.Rotation * CFrame.Angles(0, arcYaw, 0) * CFrame.Angles(ARC_TILT, 0, 0)
end

local function playSwing(character)
	local tool = character:FindFirstChild("Katana")
	if tool == nil then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil then
		return
	end
	if activeSwings[character] ~= nil then
		return
	end

	local bladeTrail = nil
	local blade = tool:FindFirstChild("Blade")
	if blade ~= nil then
		bladeTrail = blade:FindFirstChild("SlashTrail")
	end

	if originalGrip[tool] == nil then
		originalGrip[tool] = tool.Grip
	end
	tool.Grip = BLADE_FORWARD * originalGrip[tool]

	local level = character:GetAttribute("KatanaLevel") or 0
	local arcPivot, arcTrail = createSlashArc(level)

	local swing = {}
	swing.Tool = tool
	swing.Root = rootPart
	swing.BladeTrail = bladeTrail
	swing.ArcPivot = arcPivot
	swing.ArcTrail = arcTrail
	swing.Shoulder = findMotor(character, "RightUpperArm", "RightShoulder")
		or findMotor(character, "Torso", "Right Shoulder")
	swing.Waist = findMotor(character, "UpperTorso", "Waist")
	swing.ShoulderC0 = swing.Shoulder and swing.Shoulder.C0
	swing.WaistC0 = swing.Waist and swing.Waist.C0
	swing.StartTime = os.clock()
	swing.EndYaw = ARC_START_YAW + math.rad(180 + math.min(level, 10) * 18)
	swing.WaistFinish = WAIST_TWIST_FINISH -- Full-circle upgrades affect the trail, not the torso.
	activeSwings[character] = swing
	placeArc(swing, ARC_START_YAW)

	local volume = 0.4
	if character == player.Character then
		volume = 1
	end
	Sounds.Play("Swoosh", rng:NextNumber(0.95, 1.08) - math.min(level, 30) * 0.008, volume)
	if level >= 20 then
		task.delay(0.08, function() Sounds.Play("Swoosh", 1.25, volume * 0.4) end)
	end
end

local function finishSwing(character, swing)
	if swing.Shoulder and swing.Shoulder.Parent then swing.Shoulder.C0 = swing.ShoulderC0 end
	if swing.Waist and swing.Waist.Parent then swing.Waist.C0 = swing.WaistC0 end
	if swing.BladeTrail ~= nil then
		swing.BladeTrail.Enabled = false
	end
	swing.ArcTrail.Enabled = false
	Debris:AddItem(swing.ArcPivot, 0.35)
	if swing.Tool.Parent ~= nil then
		swing.Tool.Grip = originalGrip[swing.Tool]
	end
	activeSwings[character] = nil
end

-- Offset upper-body joints over the walking/running animation. Restore their
-- original offsets on completion or interruption; never hold the character root.
local function updateSwings()
	local now = os.clock()
	local totalTime = SWING_WINDUP_TIME + SWING_SLASH_TIME + SWING_RECOVER_TIME

	for character, swing in pairs(activeSwings) do
		local elapsed = now - swing.StartTime
		local armYaw = 0
		local armRaise = 0
		local waistTwist = 0
		local arcYaw = ARC_START_YAW
		local slashing = false
		local finished = false

		if character.Parent == nil or swing.Tool.Parent ~= character or swing.Root.Parent == nil then
			finished = true
		elseif elapsed < SWING_WINDUP_TIME then
			local t = easeOutQuad(elapsed / SWING_WINDUP_TIME)
			armYaw = lerp(0, ARM_YAW_WINDUP, t)
			armRaise = lerp(ARM_RAISE_START, ARM_RAISE, t)
			waistTwist = lerp(0, WAIST_TWIST_WINDUP, t)
		elseif elapsed < SWING_WINDUP_TIME + SWING_SLASH_TIME then
			local t = easeInOutCubic((elapsed - SWING_WINDUP_TIME) / SWING_SLASH_TIME)
			armYaw = lerp(ARM_YAW_WINDUP, ARM_YAW_FINISH, t)
			armRaise = ARM_RAISE
			waistTwist = lerp(WAIST_TWIST_WINDUP, swing.WaistFinish, t)
			arcYaw = lerp(ARC_START_YAW, swing.EndYaw, t)
			slashing = true
		elseif elapsed < totalTime then
			local t = easeOutQuad((elapsed - SWING_WINDUP_TIME - SWING_SLASH_TIME) / SWING_RECOVER_TIME)
			armYaw = lerp(ARM_YAW_FINISH, 0, t)
			armRaise = lerp(ARM_RAISE, ARM_RAISE_START, t)
			waistTwist = lerp(WAIST_TWIST_FINISH, 0, t)
			arcYaw = swing.EndYaw
		else
			finished = true
		end

		if finished then
			finishSwing(character, swing)
		else
			if swing.Shoulder ~= nil then
				swing.Shoulder.C0 = swing.ShoulderC0 * CFrame.Angles(0, armYaw, 0) * CFrame.Angles(armRaise, 0, -armYaw * 0.12)
			end
			if swing.Waist ~= nil then
				swing.Waist.C0 = swing.WaistC0 * CFrame.Angles(math.abs(waistTwist) * 0.16, waistTwist, -waistTwist * 0.12)
			end
			placeArc(swing, arcYaw)
			swing.ArcTrail.Enabled = slashing
			if swing.BladeTrail ~= nil then
				swing.BladeTrail.Enabled = slashing
			end
		end
	end
end

RunService.Stepped:Connect(updateSwings)
RunService:BindToRenderStep("NinjaCoyoSwing", Enum.RenderPriority.Last.Value, updateSwings)

local function faceNearestEnemy(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local folder = workspace:FindFirstChild("Enemies")
	if root == nil or humanoid == nil or humanoid.Health <= 0 or humanoid.Sit or folder == nil then return end
	local nearest, distance = nil, Config.KatanaEnemyRange
	for _, enemy in ipairs(folder:GetChildren()) do
		local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
		local enemyHumanoid = enemy:FindFirstChildOfClass("Humanoid")
		if enemy:GetAttribute("OwnerUserId") == player.UserId and enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
			local gap = (enemyRoot.Position - root.Position).Magnitude
			if gap < distance then nearest, distance = enemyRoot, gap end
		end
	end
	if nearest then
		local target = Vector3.new(nearest.Position.X, root.Position.Y, nearest.Position.Z)
		if (target - root.Position).Magnitude > 0.01 then
			-- A one-time aim correction; movement and automatic turning stay free.
			root.CFrame = CFrame.lookAt(root.Position, target)
		end
	end
end

local function hookKatana(child)
	if child:IsA("Tool") == false then
		return
	end
	if child.Name ~= "Katana" then
		return
	end
	if child:GetAttribute("FxHooked") == true then
		return
	end
	child:SetAttribute("FxHooked", true)

	child.Activated:Connect(function()
		local now = os.clock()
		if now - lastLocalSwing < Config.KatanaCooldown then
			return
		end
		lastLocalSwing = now
		local character = player.Character
		if character ~= nil then
			faceNearestEnemy(character)
			playSwing(character)
		end
	end)
end

-- Red screen flash when the ninja takes damage
local damageGui = Instance.new("ScreenGui")
damageGui.Name = "DamageFlash"
damageGui.IgnoreGuiInset = true
damageGui.ResetOnSpawn = false
damageGui.Parent = player:WaitForChild("PlayerGui")

local damageFrame = Instance.new("Frame")
damageFrame.Size = UDim2.new(1, 0, 1, 0)
damageFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
damageFrame.BackgroundTransparency = 1
damageFrame.BorderSizePixel = 0
damageFrame.Parent = damageGui

local function flashDamage()
	Sounds.Play("PlayerHurt", rng:NextNumber(0.95, 1.05), 1)
	damageFrame.BackgroundTransparency = 0.65
	TweenService:Create(damageFrame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function watchHealth(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil then
		return
	end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			flashDamage()
		end
		lastHealth = health
	end)
end

local function onCharacterAdded(character)
	task.spawn(watchHealth, character)
	character.ChildAdded:Connect(hookKatana)
	for _, child in ipairs(character:GetChildren()) do
		hookKatana(child)
	end
end

----------------------------------------------------------------
-- Chest effects
----------------------------------------------------------------

local function onSlash(character)
	if character == nil then
		return
	end
	if character == player.Character then
		return
	end
	playSwing(character)
end

local function onChestHit(position, chestModel)
	Sounds.Play("ChestHit", rng:NextNumber(0.9, 1.1), 1)
	burstSparks(position + Vector3.new(0, 1, 0), 12, SPARK)

	for chipIndex = 1, 3 do
		local chip = makeFxPart(Vector3.new(0.4, 0.2, 0.3), CFrame.new(position), CHEST_WOOD, Enum.Material.WoodPlanks, Enum.PartType.Block)
		local velocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(12, 20), rng:NextNumber(-10, 10))
		launchBit(chip, position + Vector3.new(0, 1, 0), velocity, position.Y - 0.9, false)
	end

	if chestModel ~= nil and chestModel.Parent ~= nil then
		local originalPivot = chestModel:GetPivot()
		local jolt = originalPivot * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10)))
		chestModel:PivotTo(jolt)
		task.delay(0.07, function()
			if chestModel.Parent ~= nil then
				chestModel:PivotTo(originalPivot)
			end
		end)
	end
end

local function onChestOpen(baseCFrame, openerUserId, reward)
	local isMine = openerUserId == player.UserId
	local position = baseCFrame.Position

	local volume = 0.4
	if isMine then
		volume = 1
	end
	Sounds.Play("ChestSmash", 1, volume)
	Sounds.Play("CoinBurst", 1, volume)
	local groundY = position.Y - 1

	-- Stand-in chest pieces for the smash animation
	local box = makeFxPart(Vector3.new(3, 2, 2.2), baseCFrame, CHEST_WOOD, Enum.Material.WoodPlanks, Enum.PartType.Block)
	local band = makeFxPart(Vector3.new(0.5, 2.05, 2.35), baseCFrame, GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Block)
	local lid = makeFxPart(Vector3.new(3.1, 0.7, 2.3), baseCFrame * CFrame.new(0, 1.35, 0), CHEST_LID, Enum.Material.WoodPlanks, Enum.PartType.Block)

	-- Lid flies off spinning
	local lidTarget = baseCFrame * CFrame.new(0, 7, 2.5) * CFrame.Angles(math.rad(-160), math.rad(40), 0)
	TweenService:Create(lid, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = lidTarget }):Play()

	-- Box squashes flat
	local squashInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	TweenService:Create(box, squashInfo, { Size = Vector3.new(3.4, 0.6, 2.6), CFrame = baseCFrame * CFrame.new(0, -0.7, 0) }):Play()
	TweenService:Create(band, squashInfo, { Size = Vector3.new(0.6, 0.65, 2.7), CFrame = baseCFrame * CFrame.new(0, -0.7, 0) }):Play()

	task.delay(0.35, function()
		local fadeInfo = TweenInfo.new(0.35)
		for _, piece in ipairs({ box, band, lid }) do
			TweenService:Create(piece, fadeInfo, { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(box, 0.8)
	Debris:AddItem(band, 0.8)
	Debris:AddItem(lid, 0.8)

	-- Gold flash with light
	local flash = makeFxPart(Vector3.new(1, 1, 1), baseCFrame, GOLD, Enum.Material.Neon, Enum.PartType.Ball)
	local flashLight = Instance.new("PointLight")
	flashLight.Color = GOLD
	flashLight.Brightness = 3
	flashLight.Range = 14
	flashLight.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
	TweenService:Create(flashLight, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.4)

	-- Shockwave ring along the ground
	local ringCFrame = CFrame.new(position.X, groundY + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	local ring = makeFxPart(Vector3.new(0.2, 2, 2), ringCFrame, GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 18, 18), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)

	burstSparks(position + Vector3.new(0, 1, 0), 30, GOLD)

	-- Coins burst out, bounce, then fly to whoever opened it
	for coinIndex = 1, BURST_COIN_COUNT do
		local coin = makeFxPart(Vector3.new(0.25, 1.1, 1.1), CFrame.new(position), GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		coin.Reflectance = 0.3
		local angle = (coinIndex / BURST_COIN_COUNT) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local speed = rng:NextNumber(8, 16)
		local velocity = Vector3.new(math.cos(angle) * speed, rng:NextNumber(18, 28), math.sin(angle) * speed)
		launchBit(coin, position + Vector3.new(0, 1.2, 0), velocity, groundY + 0.55, isMine)
	end

	if isMine then
		shakeCamera(0.25, 0.35)
	end
end

----------------------------------------------------------------
-- Enemy effects
----------------------------------------------------------------

local ENEMY_HIT_COLOUR = Color3.fromRGB(255, 120, 60)
local ENEMY_DEFEAT_PURPLE = Color3.fromRGB(200, 70, 255)
local enemyAttackStart = setmetatable({}, { __mode = "k" })
local enemyWalkTime = 0

local function flashModel(model, colour)
	if model == nil then
		return
	end
	if model.Parent == nil then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = colour
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.12)
end

local function onEnemyHit(position, model)
	Sounds.Play("EnemyHit", rng:NextNumber(0.9, 1.12), 1)
	burstSparks(position, 14, ENEMY_HIT_COLOUR)
	flashModel(model, Color3.fromRGB(255, 60, 60))
end

local function onEnemyAttack(model, targetPosition)
	if model ~= nil then
		enemyAttackStart[model] = os.clock()
	end
	burstSparks(targetPosition, 10, Color3.fromRGB(255, 40, 40))
end

local function onEnemyDefeat(position, ownerUserId, reward)
	local isMine = ownerUserId == player.UserId
	local groundY = position.Y - 2.5

	local volume = 0.4
	if isMine then
		volume = 1
	end
	Sounds.Play("EnemyDefeat", 1, volume)
	Sounds.Play("CoinBurst", 1.1, volume)

	burstSparks(position, 40, GOLD)
	burstSparks(position, 25, ENEMY_DEFEAT_PURPLE)

	local flash = makeFxPart(Vector3.new(1, 1, 1), CFrame.new(position), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(10, 10, 10), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.4)

	local ringCFrame = CFrame.new(position.X, groundY + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	local ring = makeFxPart(Vector3.new(0.2, 2, 2), ringCFrame, ENEMY_DEFEAT_PURPLE, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 24, 24), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.55)

	for coinIndex = 1, 16 do
		local coin = makeFxPart(Vector3.new(0.25, 1.1, 1.1), CFrame.new(position), GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		coin.Reflectance = 0.3
		local angle = (coinIndex / 16) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local speed = rng:NextNumber(10, 20)
		local velocity = Vector3.new(math.cos(angle) * speed, rng:NextNumber(20, 32), math.sin(angle) * speed)
		launchBit(coin, position, velocity, groundY + 0.55, isMine)
	end

	if isMine then
		shakeCamera(0.3, 0.45)
	end
end

local function setMotorTransform(model, partName, motorName, transform)
	local part = model:FindFirstChild(partName)
	if part == nil then
		return
	end
	local motor = part:FindFirstChild(motorName)
	if motor == nil then
		return
	end
	motor.Transform = transform
end

-- Simple procedural walk and sword chop for enemies (they have no animation assets)
RunService.Stepped:Connect(function(_, deltaTime)
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder == nil then
		return
	end
	enemyWalkTime = enemyWalkTime + deltaTime
	local now = os.clock()

	for _, model in ipairs(enemiesFolder:GetChildren()) do
		local root = model:FindFirstChild("HumanoidRootPart")
		if root ~= nil then
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local amount = math.clamp(speed / 14, 0, 1)
			local swing = math.sin(enemyWalkTime * 10) * 0.7 * amount

			setMotorTransform(model, "LeftUpperLeg", "LeftHip", CFrame.Angles(swing, 0, 0))
			setMotorTransform(model, "RightUpperLeg", "RightHip", CFrame.Angles(-swing, 0, 0))
			setMotorTransform(model, "LeftUpperArm", "LeftShoulder", CFrame.Angles(-swing * 0.8, 0, 0))

			local swordArm = math.rad(40) + swing * 0.2
			local attackStart = enemyAttackStart[model]
			if attackStart ~= nil then
				local progress = now - attackStart
				if progress < 0.1 then
					swordArm = lerp(math.rad(40), math.rad(150), progress / 0.1)
				elseif progress < 0.3 then
					swordArm = lerp(math.rad(150), math.rad(-10), (progress - 0.1) / 0.2)
				end
			end
			setMotorTransform(model, "RightUpperArm", "RightShoulder", CFrame.Angles(swordArm, 0, 0))
		end
	end
end)

----------------------------------------------------------------
-- Flying bits (coins and wood chips)
----------------------------------------------------------------

RunService.RenderStepped:Connect(function(deltaTime)
	local rootPart = nil
	local character = player.Character
	if character ~= nil then
		rootPart = character:FindFirstChild("HumanoidRootPart")
	end

	for index = #fxBits, 1, -1 do
		local bit = fxBits[index]
		bit.Age = bit.Age + deltaTime
		local finished = false

		if bit.Magnet == true and bit.Age > COIN_MAGNET_DELAY and rootPart ~= nil then
			local toRoot = rootPart.Position - bit.Position
			local distance = toRoot.Magnitude
			if distance < 1.5 then
				finished = true
			else
				local move = math.min(distance, (40 + bit.Age * 60) * deltaTime)
				bit.Position = bit.Position + toRoot.Unit * move
			end
		else
			bit.Velocity = bit.Velocity - Vector3.new(0, COIN_GRAVITY * deltaTime, 0)
			bit.Position = bit.Position + bit.Velocity * deltaTime
			if bit.Position.Y < bit.GroundY then
				bit.Position = Vector3.new(bit.Position.X, bit.GroundY, bit.Position.Z)
				bit.Velocity = Vector3.new(bit.Velocity.X * 0.5, math.abs(bit.Velocity.Y) * 0.35, bit.Velocity.Z * 0.5)
			end
			local fadeStart = COIN_LIFETIME - 0.5
			if bit.Age > fadeStart then
				bit.Part.Transparency = math.clamp((bit.Age - fadeStart) / 0.5, 0, 1)
			end
		end

		if bit.Age > COIN_LIFETIME then
			finished = true
		end

		if finished then
			bit.Part:Destroy()
			table.remove(fxBits, index)
		else
			bit.Part.CFrame = CFrame.new(bit.Position) * CFrame.Angles(bit.Age * 7, bit.Age * 11, 0)
		end
	end
end)

----------------------------------------------------------------
-- Hook up
----------------------------------------------------------------

fxEvent.OnClientEvent:Connect(function(kind, argumentA, argumentB, argumentC)
	if kind == "Slash" then
		onSlash(argumentA)
	elseif kind == "ChestHit" then
		onChestHit(argumentA, argumentB)
	elseif kind == "ChestOpen" then
		onChestOpen(argumentA, argumentB, argumentC)
	elseif kind == "EnemyHit" then
		onEnemyHit(argumentA, argumentB)
	elseif kind == "EnemyAttack" then
		onEnemyAttack(argumentA, argumentB)
	elseif kind == "EnemyDefeat" then
		onEnemyDefeat(argumentA, argumentB, argumentC)
	end
end)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character ~= nil then
	onCharacterAdded(player.Character)
end
