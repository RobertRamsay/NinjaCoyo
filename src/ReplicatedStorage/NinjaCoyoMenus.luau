-- Shared client menu state: overlapping panels and purchase dialogs release independently.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local remote = game:GetService("ReplicatedStorage"):WaitForChild("NinjaCoyoRemotes"):WaitForChild("MenuState")
local Menus = {}
local reasons = {}
local controls
local blocked = false
local function stopMovement()
	player:Move(Vector3.zero, false)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(Vector3.zero, false); humanoid.Jump = false end
end
function Menus.Set(reason, open)
	reasons[reason] = open and true or nil
	local nextBlocked = next(reasons) ~= nil
	if nextBlocked == blocked then return end
	blocked = nextBlocked
	player:SetAttribute("MenuOpen", blocked)
	remote:FireServer(blocked)
	if blocked then
		if controls then controls:Disable() end
		stopMovement()
		RunService:BindToRenderStep("NinjaCoyoMenuMovement", Enum.RenderPriority.Input.Value + 1, stopMovement)
	else
		RunService:UnbindFromRenderStep("NinjaCoyoMenuMovement")
		if controls then controls:Enable() end
	end
end
task.spawn(function()
	controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	if blocked then controls:Disable() end
end)
GuiService.MenuOpened:Connect(function() Menus.Set("Roblox", true) end)
GuiService.MenuClosed:Connect(function() Menus.Set("Roblox", false) end)
player.CharacterAdded:Connect(function()
	if blocked then remote:FireServer(true) end
end)
return Menus
