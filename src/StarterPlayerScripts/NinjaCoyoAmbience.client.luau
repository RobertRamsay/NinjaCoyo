-- Quiet meadow wind and occasional chimes; fade away on entering later areas.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local player = Players.LocalPlayer
local rng = Random.new()
local settings = Config.Ambience
local function sound(name, id, looped)
	local s = Instance.new("Sound")
	s.Name, s.SoundId, s.Looped, s.Volume = name, id, looped, 0
	s.Parent = SoundService
	return s
end
local wind = sound("MeadowWind", settings.WindId, true)
local chimes = sound("MeadowChimes", settings.ChimesId, false)
local nextChime = os.clock() + rng:NextNumber(6, 12)
local mix = 0
local elapsed = 0
local windRequested = false

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then return end
	local step = elapsed
	elapsed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local target = 0
	if root and humanoid and humanoid.Health > 0 then
		local p = root.Position
		-- Soft transitions along the north gate approach and outer mountains.
		target = math.clamp((p.Z + 130) / 35, 0, 1) * math.clamp((360 - math.abs(p.X)) / 55, 0, 1)
			* math.clamp((350 - p.Z) / 55, 0, 1)
	end
	mix += (target - mix) * math.min(step * 1.2, 1)
	wind.Volume = settings.WindVolume * mix
	chimes.Volume = settings.ChimesVolume * mix
	if wind.SoundId ~= "" and mix > 0.01 and not windRequested then
		windRequested = true
		wind:Play()
	end
	if mix < 0.005 and windRequested then wind:Stop(); windRequested = false end
	if os.clock() >= nextChime then
		nextChime = os.clock() + rng:NextNumber(13, 24)
		if chimes.SoundId ~= "" and mix > 0.5 and not chimes.IsPlaying then
			chimes.PlaybackSpeed = rng:NextNumber(0.94, 1.06)
			chimes:Play()
		end
	end
end)
