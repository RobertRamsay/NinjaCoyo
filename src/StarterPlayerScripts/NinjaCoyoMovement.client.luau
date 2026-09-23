-- Upgrade-driven air jumps and visual flips. Root physics stays upright.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local player = Players.LocalPlayer
local states = {}
local lastRequest = 0

local function resetPose(state)
	if state.Motor and state.Motor.Parent then state.Motor.C0 = state.RestC0 end
	state.FlipStart = nil
end

local function watch(character)
	if states[character] then return end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or not character.Parent then return end
	local state = { Humanoid = humanoid, Root = root, Jumps = 0, NextJump = 0 }
	states[character] = state
	for _, motor in ipairs(character:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Part0 == root then
			state.Motor, state.RestC0 = motor, motor.C0
			break
		end
	end
	state.Connection = humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping then
			state.Jumps += 1
			state.NextJump = os.clock() + Config.DoubleJumpDelay + 0.1
			local level = character:GetAttribute("JumpLevel") or 0
			if level >= Config.FlipJumpLevel then
				resetPose(state)
				state.FlipStart = os.clock()
				state.Duration = level >= Config.TripleJumpLevel and 0.5 or 0.65
				state.Spin = level >= Config.TripleJumpLevel and state.Jumps >= 2
			end
		elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.Swimming or newState == Enum.HumanoidStateType.Climbing
			or newState == Enum.HumanoidStateType.Seated or newState == Enum.HumanoidStateType.Dead then
			state.Jumps = 0
			resetPose(state)
		elseif newState == Enum.HumanoidStateType.Freefall and state.Jumps == 0 then
			-- Walking off a ledge uses the ground jump, not a free extra jump.
			state.Jumps = 1
			state.NextJump = os.clock() + Config.DoubleJumpDelay
		end
	end)
end

Input.JumpRequest:Connect(function()
	local state = states[player.Character]
	if not state or state.Humanoid.Health <= 0 then return end
	local now = os.clock()
	if now - lastRequest < 0.2 then return end
	lastRequest = now
	local level = player.Character:GetAttribute("JumpLevel") or 0
	local maxJumps = level >= Config.TripleJumpLevel and 3 or 2
	if state.Jumps > 0 and state.Jumps < maxJumps and now >= state.NextJump
		and state.Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		local velocity = state.Root.AssemblyLinearVelocity
		state.Root.AssemblyLinearVelocity = Vector3.new(velocity.X, state.Humanoid.JumpPower, velocity.Z)
		state.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

RunService.PreSimulation:Connect(function()
	for character, state in pairs(states) do
		if character.Parent == nil then
			resetPose(state)
			state.Connection:Disconnect()
			states[character] = nil
		elseif state.FlipStart and state.Motor then
			local t = math.clamp((os.clock() - state.FlipStart) / state.Duration, 0, 1)
			local ease = t * t * (3 - 2 * t)
			state.Motor.C0 = state.RestC0 * CFrame.Angles(-math.pi * 2 * ease, state.Spin and math.pi * 2 * ease or 0, 0)
			if t >= 1 then resetPose(state) end
		end
	end
end)

local function watchPlayer(other)
	other.CharacterAdded:Connect(function(character) task.spawn(watch, character) end)
	if other.Character then task.spawn(watch, other.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
