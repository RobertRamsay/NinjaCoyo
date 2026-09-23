-- Server-owned protection and immobilization while a menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = Instance.new("RemoteEvent")
remote.Name = "MenuState"
remote.Parent = ReplicatedStorage:WaitForChild("NinjaCoyoRemotes")
local states = {}
local function clear(player)
	local state = states[player]
	if state then
		if state.Root.Parent then state.Root.Anchored = state.WasAnchored end
		state.Shield:Destroy()
		states[player] = nil
	end
	player:SetAttribute("MenuProtected", false)
end
local function setProtected(player, open)
	if type(open) ~= "boolean" then return end
	if not open then clear(player); return end
	if states[player] then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	local shield = Instance.new("ForceField")
	shield.Name = "MenuProtection"
	shield.Visible = false
	shield.Parent = character
	states[player] = {Root=root, WasAnchored=root.Anchored, Shield=shield}
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	player:SetAttribute("MenuProtected", true)
end
remote.OnServerEvent:Connect(setProtected)
local function watch(player)
	player.CharacterRemoving:Connect(function() clear(player) end)
end
Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do watch(player) end
Players.PlayerRemoving:Connect(clear)
