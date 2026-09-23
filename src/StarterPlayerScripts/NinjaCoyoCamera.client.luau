-- Set the initial zoom once per spawn, then leave normal pinch/wheel zoom available.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoConfig"))
local player = Players.LocalPlayer
local function startCamera(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or player.Character ~= character then return end
	local minimum, maximum = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
	local distance = math.clamp(Config.StartCameraDistance, minimum, maximum)
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	player.CameraMaxZoomDistance = maximum
	player.CameraMinZoomDistance = minimum
end
player.CharacterAdded:Connect(startCamera)
if player.Character then task.spawn(startCamera, player.Character) end
