-- NinjaCoyoWardrobe (ModuleScript in ServerScriptService)
-- The Wardrobe Shrine: a glowing torii near spawn where players equip ninja outfits
-- and Coyo coats. Items are sold as Game Passes; ownership is checked with Roblox,
-- and the equipped choice is saved with the rest of the player's data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))

local Wardrobe = {}

local WardrobeConfig = Config.Wardrobe
local OUTFIT_FOLDER_NAME = "NinjaCoyoOutfit"
local COAT_EFFECT_NAME = "CoatEffect"
local TORII_RED = Color3.fromRGB(196, 38, 38)
local TORII_BLACK = Color3.fromRGB(20, 20, 22)
local STONE_GREY = Color3.fromRGB(150, 150, 145)
local GLOW_PURPLE = Color3.fromRGB(190, 120, 255)
local GLOW_GOLD = Color3.fromRGB(255, 205, 90)

-- State (initialised up front)
local context = {
	PlayerData = {},
	GetCoyoModels = nil,
	NotifyEvent = nil,
}
local ownedPasses = {}
local isStudio = RunService:IsStudio()

-- Remotes are created here and placed in NinjaCoyoRemotes when Init runs
local openEvent = Instance.new("RemoteEvent")
openEvent.Name = "WardrobeOpen"

local stateEvent = Instance.new("RemoteEvent")
stateEvent.Name = "WardrobeState"

local equipFunction = Instance.new("RemoteFunction")
equipFunction.Name = "WardrobeEquip"

local getStateFunction = Instance.new("RemoteFunction")
getStateFunction.Name = "WardrobeGetState"

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

----------------------------------------------------------------
-- Ownership
----------------------------------------------------------------

local function ownsPass(player, passId)
	if passId == 0 then
		return false
	end
	local passes = ownedPasses[player]
	if passes == nil then
		return false
	end
	return passes[passId] == true
end

local function ownsItem(player, item)
	if item.Free == true then
		return true
	end
	local data = context.PlayerData[player]
	if item.RequiredUpgrade ~= nil and data ~= nil
		and (data.Upgrades[item.RequiredUpgrade] or 0) >= item.RequiredLevel then
		return true
	end
	if isStudio and WardrobeConfig.StudioOwnsEverything == true then
		return true
	end
	return ownsPass(player, item.PassId)
end

function Wardrobe.OwnsGoldSword(player)
	-- Paid combat benefits never use the Studio cosmetics unlock override.
	return ownsPass(player, WardrobeConfig.GoldSwordPassId)
end

local function collectPassIds()
	local passIds = {}
	for _, outfitId in ipairs(WardrobeConfig.OutfitOrder) do
		local passId = WardrobeConfig.Outfits[outfitId].PassId
		if passId ~= 0 then
			table.insert(passIds, passId)
		end
	end
	for _, coatId in ipairs(WardrobeConfig.CoatOrder) do
		local passId = WardrobeConfig.Coats[coatId].PassId
		if passId ~= 0 then
			table.insert(passIds, passId)
		end
	end
	if WardrobeConfig.DoubleCoinsPassId ~= 0 then
		table.insert(passIds, WardrobeConfig.DoubleCoinsPassId)
	end
	if WardrobeConfig.GoldSwordPassId ~= 0 then
		table.insert(passIds, WardrobeConfig.GoldSwordPassId)
	end
	return passIds
end

local function loadOwnedPasses(player)
	for _, passId in ipairs(collectPassIds()) do
		local success, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if success and owns == true then
			if ownedPasses[player] == nil then return end
			ownedPasses[player][passId] = true
		end
	end
end

local function buildState(player)
	local data = context.PlayerData[player]
	local state = {}
	state.Outfit = "Default"
	state.Coat = "Coyote"
	state.DogCoats = {}
	state.PackSize = 1
	if data ~= nil then
		state.Outfit = data.Outfit
		state.Coat = data.CoyoCoat
		state.DogCoats = table.clone(data.DogCoats)
		state.PackSize = Config.GetValue("PackSize", data.Upgrades.PackSize)
	end

	state.OwnedOutfits = {}
	for _, outfitId in ipairs(WardrobeConfig.OutfitOrder) do
		state.OwnedOutfits[outfitId] = ownsItem(player, WardrobeConfig.Outfits[outfitId])
	end
	state.OwnedCoats = {}
	for _, coatId in ipairs(WardrobeConfig.CoatOrder) do
		state.OwnedCoats[coatId] = ownsItem(player, WardrobeConfig.Coats[coatId])
	end

	state.GoldSword = ownsPass(player, WardrobeConfig.GoldSwordPassId)
	state.DoubleCoins = false
	if ownsPass(player, WardrobeConfig.DoubleCoinsPassId) then
		state.DoubleCoins = true
	end
	return state
end

local function sendState(player)
	stateEvent:FireClient(player, buildState(player))
end

----------------------------------------------------------------
-- Outfits
----------------------------------------------------------------

local function attachPart(folder, anchorPart, name, size, colour, material, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = anchorPart.CFrame * offset
	part.Parent = folder

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function removeOutfitParts(character)
	local folder = character:FindFirstChild(OUTFIT_FOLDER_NAME)
	if folder ~= nil then
		folder:Destroy()
	end
end

local function addOutfitParts(character, outfit)
	local folder = Instance.new("Folder")
	folder.Name = OUTFIT_FOLDER_NAME
	folder.Parent = character

	local head = character:FindFirstChild("Head")
	if head ~= nil then
		local headSize = head.Size
		if outfit.Armour == true then
			-- Samurai kabuto helmet with a golden crest
			attachPart(folder, head, "Helmet", Vector3.new(headSize.X * 1.2, headSize.Y * 0.45, headSize.Z * 1.2), outfit.BodyColor, Enum.Material.Metal, CFrame.new(0, headSize.Y * 0.38, 0))
			attachPart(folder, head, "HelmetBrim", Vector3.new(headSize.X * 1.6, headSize.Y * 0.08, headSize.Z * 1.5), outfit.BodyColor, Enum.Material.Metal, CFrame.new(0, headSize.Y * 0.18, 0))
			attachPart(folder, head, "CrestLeft", Vector3.new(headSize.X * 0.12, headSize.Y * 0.6, headSize.Z * 0.12), outfit.AccentColor, Enum.Material.Metal, CFrame.new(-headSize.X * 0.22, headSize.Y * 0.85, -headSize.Z * 0.45) * CFrame.Angles(0, 0, math.rad(25)))
			attachPart(folder, head, "CrestRight", Vector3.new(headSize.X * 0.12, headSize.Y * 0.6, headSize.Z * 0.12), outfit.AccentColor, Enum.Material.Metal, CFrame.new(headSize.X * 0.22, headSize.Y * 0.85, -headSize.Z * 0.45) * CFrame.Angles(0, 0, math.rad(-25)))
		else
			-- Ninja headband with trailing ties
			attachPart(folder, head, "Headband", Vector3.new(headSize.X * 1.06, headSize.Y * 0.18, headSize.Z * 1.06), outfit.AccentColor, Enum.Material.Fabric, CFrame.new(0, headSize.Y * 0.22, 0))
			attachPart(folder, head, "BandTieLeft", Vector3.new(headSize.X * 0.12, headSize.Y * 0.14, headSize.Z * 0.7), outfit.AccentColor, Enum.Material.Fabric, CFrame.new(-headSize.X * 0.15, headSize.Y * 0.15, headSize.Z * 0.75) * CFrame.Angles(math.rad(-20), math.rad(-10), 0))
			attachPart(folder, head, "BandTieRight", Vector3.new(headSize.X * 0.12, headSize.Y * 0.14, headSize.Z * 0.7), outfit.AccentColor, Enum.Material.Fabric, CFrame.new(headSize.X * 0.15, headSize.Y * 0.15, headSize.Z * 0.75) * CFrame.Angles(math.rad(-20), math.rad(10), 0))
		end
		attachPart(folder, head, "Mask", Vector3.new(headSize.X * 1.04, headSize.Y * 0.36, headSize.Z * 0.55), outfit.BodyColor, Enum.Material.Fabric, CFrame.new(0, -headSize.Y * 0.2, -headSize.Z * 0.24))
	end

	local lowerTorso = character:FindFirstChild("LowerTorso")
	-- Cloth weave plus fitted layers, stitched lapels, utility pockets and limb pads.
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		local s = torso.Size
		attachPart(folder, torso, "WovenJacket", Vector3.new(s.X * 1.025, s.Y * 0.94, s.Z * 1.04),
			outfit.BodyColor, Enum.Material.Fabric, CFrame.new())
		for _, side in ipairs({ -1, 1 }) do
			attachPart(folder, torso, "FoldedLapel", Vector3.new(s.X * 0.13, s.Y * 0.92, 0.12),
				outfit.AccentColor, Enum.Material.Fabric, CFrame.new(side * s.X * 0.15, 0.08, -s.Z * 0.56) * CFrame.Angles(0, 0, side * -0.28))
			local x = side * s.X * 0.32
			attachPart(folder, torso, "ChestPocket", Vector3.new(s.X * 0.24, s.Y * 0.28, 0.22),
				outfit.BodyColor:Lerp(outfit.AccentColor, 0.25), Enum.Material.Fabric, CFrame.new(x, -s.Y * 0.15, -s.Z * 0.59))
			attachPart(folder, torso, "PocketFlap", Vector3.new(s.X * 0.26, 0.12, 0.27),
				outfit.AccentColor, Enum.Material.Fabric, CFrame.new(x, -s.Y * 0.02, -s.Z * 0.61))
			attachPart(folder, torso, "PocketClasp", Vector3.new(0.08, 0.1, 0.05),
				outfit.SashColor, Enum.Material.Metal, CFrame.new(x, -s.Y * 0.1, -s.Z * 0.61 - 0.16))
			for stitch = 1, 5 do
				attachPart(folder, torso, "Stitch", Vector3.new(0.035, 0.055, 0.025), outfit.SashColor,
					Enum.Material.Fabric, CFrame.new(x - s.X * 0.1 + stitch * s.X * 0.033, -s.Y * 0.29, -s.Z * 0.59 - 0.12))
			end
		end
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local thigh = character:FindFirstChild(side .. "UpperLeg")
		if thigh then
			local sign = side == "Left" and -1 or 1
			local s = thigh.Size
			attachPart(folder, thigh, "CargoPocket", Vector3.new(0.3, s.Y * 0.45, s.Z * 0.75),
				outfit.AccentColor, Enum.Material.Fabric, CFrame.new(sign * (s.X * 0.5 + 0.1), 0, 0))
			attachPart(folder, thigh, "CargoFlap", Vector3.new(0.36, 0.14, s.Z * 0.83),
				outfit.SashColor, Enum.Material.Fabric, CFrame.new(sign * (s.X * 0.5 + 0.1), s.Y * 0.22, 0))
		end
		for _, limbName in ipairs({ side .. "LowerArm", side .. "LowerLeg" }) do
			local limb = character:FindFirstChild(limbName)
			if limb then
				local s = limb.Size
				attachPart(folder, limb, "PaddedGuard", Vector3.new(s.X * 1.05, s.Y * 0.58, 0.16),
					outfit.AccentColor, Enum.Material.Fabric, CFrame.new(0, 0, -s.Z * 0.53))
				for _, y in ipairs({ -0.24, 0.24 }) do
					attachPart(folder, limb, "Wrap", Vector3.new(s.X * 1.08, 0.1, s.Z * 1.08),
						outfit.SashColor, Enum.Material.Fabric, CFrame.new(0, s.Y * y, 0))
				end
			end
		end
	end
	if lowerTorso ~= nil then
		local torsoSize = lowerTorso.Size
		attachPart(folder, lowerTorso, "Sash", Vector3.new(torsoSize.X * 1.08, torsoSize.Y * 0.35, torsoSize.Z * 1.12), outfit.SashColor, Enum.Material.Fabric, CFrame.new(0, torsoSize.Y * 0.2, 0))
		attachPart(folder, lowerTorso, "SashKnot", Vector3.new(torsoSize.X * 0.2, torsoSize.Y * 0.5, torsoSize.Z * 0.15), outfit.SashColor, Enum.Material.Fabric, CFrame.new(torsoSize.X * 0.3, -torsoSize.Y * 0.05, -torsoSize.Z * 0.58))
	end

	if outfit.Armour == true then
		for _, armName in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
			local arm = character:FindFirstChild(armName)
			if arm ~= nil then
				local armSize = arm.Size
				attachPart(folder, arm, "ShoulderPlate", Vector3.new(armSize.X * 1.5, armSize.Y * 0.5, armSize.Z * 1.4), outfit.AccentColor, Enum.Material.Metal, CFrame.new(0, armSize.Y * 0.25, 0))
			end
		end
		local upperTorso = character:FindFirstChild("UpperTorso")
		if upperTorso ~= nil then
			local torsoSize = upperTorso.Size
			attachPart(folder, upperTorso, "ChestPlate", Vector3.new(torsoSize.X * 1.05, torsoSize.Y * 0.8, torsoSize.Z * 0.2), outfit.AccentColor, Enum.Material.Metal, CFrame.new(0, 0, -torsoSize.Z * 0.5))
		end
	end
end

local function applyOutfit(player, character, isSpawn)
	local data = context.PlayerData[player]
	if data == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	local outfitId = data.Outfit
	local outfit = WardrobeConfig.Outfits[outfitId]
	if outfit == nil then
		return
	end

	-- A fresh character already wears the player's own avatar
	if isSpawn == true and outfitId == "Default" then
		return
	end

	-- Let Roblox finish dressing the avatar first, or it would overwrite the outfit
	if player:HasAppearanceLoaded() == false then
		player.CharacterAppearanceLoaded:Wait()
	end
	if character.Parent == nil then
		return
	end

	removeOutfitParts(character)

	if outfitId == "Default" then
		-- Put the player's own avatar back
		local success, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if success and description ~= nil and character.Parent ~= nil then
			pcall(function()
				humanoid:ApplyDescription(description)
			end)
		end
		return
	end

	local description = humanoid:GetAppliedDescription()
	description.Shirt = 0
	description.Pants = 0
	description.GraphicTShirt = 0
	description.TorsoColor = outfit.BodyColor
	description.LeftArmColor = outfit.BodyColor
	description.RightArmColor = outfit.BodyColor
	description.LeftLegColor = outfit.BodyColor
	description.RightLegColor = outfit.BodyColor

	local success = pcall(function()
		humanoid:ApplyDescription(description)
	end)
	if success == false then
		return
	end
	if character.Parent == nil then
		return
	end
	addOutfitParts(character, outfit)
end

----------------------------------------------------------------
-- Coyo coats
----------------------------------------------------------------

local COAT_ROLES = {
	Body = "Fur",
	Head = "Fur",
	LegFrontLeft = "Fur",
	LegFrontRight = "Fur",
	LegBackLeft = "Fur",
	LegBackRight = "Fur",
	EarLeft = "Dark",
	EarRight = "Dark",
	Tail = "Dark",
	Snout = "Light",
}

local function makeCoatEffect(body, effect)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = COAT_EFFECT_NAME
	emitter.LightEmission = 1
	emitter.Rate = 0

	if effect == "Embers" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20))
		emitter.Size = NumberSequence.new(0.35, 0)
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.Rate = 14
	elseif effect == "Spirit" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(80, 150, 255))
		emitter.Size = NumberSequence.new(0.45, 0)
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 18
	elseif effect == "Snow" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Speed = NumberRange.new(0.3, 0.8)
		emitter.Acceleration = Vector3.new(0, -1.5, 0)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 0.3
		emitter.Rate = 8
	elseif effect == "Shadow" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 50, 170), Color3.fromRGB(20, 10, 30))
		emitter.Size = NumberSequence.new(0.6, 0.1)
		emitter.Transparency = NumberSequence.new(0.4, 1)
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(0.2, 0.6)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 0
		emitter.Rate = 12
	end

	emitter.Parent = body
end

local function applyCoatToModel(model, coat)
	local oldDetails = model:FindFirstChild("BreedDetails")
	if oldDetails then oldDetails:Destroy() end
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local role = COAT_ROLES[part.Name]
			if role == "Fur" then
				part.Color = coat.FurColor
				part.Material = coat.Material
			elseif role == "Dark" then
				part.Color = coat.DarkColor
				part.Material = coat.Material
			elseif role == "Light" then
				part.Color = coat.LightColor
				part.Material = coat.Material
			end
		end
	end

	local body = model:FindFirstChild("Body")
	if body == nil then
		return
	end
	local details = Instance.new("Folder")
	details.Name = "BreedDetails"
	details.Parent = model
	if coat.Shape == "Wolf" then
		for _, side in ipairs({ -1, 1 }) do
			local ruff = attachPart(details, body, "CheekRuff", Vector3.new(0.7, 0.85, 0.9), coat.LightColor,
				Enum.Material.Fabric, CFrame.new(side * 0.65, 0.45, -1.25) * CFrame.Angles(0, 0, side * 0.3))
			ruff.Shape = Enum.PartType.Ball
		end
	elseif coat.Shape == "Shiba" then
		local curl = attachPart(details, body, "CurledTail", Vector3.new(0.85, 0.85, 1), coat.FurColor,
			Enum.Material.Fabric, CFrame.new(0, 1, 1.45))
		curl.Shape = Enum.PartType.Ball
	elseif coat.Shape == "Fox" then
		local tail = attachPart(details, body, "BrushTail", Vector3.new(0.8, 0.8, 2), coat.FurColor,
			Enum.Material.Fabric, CFrame.new(0, 0.65, 2) * CFrame.Angles(-0.4, 0, 0))
		tail.Shape = Enum.PartType.Ball
		local tip = attachPart(details, body, "TailTip", Vector3.new(0.65, 0.65, 0.65), coat.LightColor,
			Enum.Material.Fabric, CFrame.new(0, 1, 2.8))
		tip.Shape = Enum.PartType.Ball
	end
	local tail = model:FindFirstChild("Tail")
	if tail then tail.Transparency = (coat.Shape == "Shiba" or coat.Shape == "Fox") and 1 or 0 end
	local oldEffect = body:FindFirstChild(COAT_EFFECT_NAME)
	if oldEffect ~= nil then
		oldEffect:Destroy()
	end
	if coat.Effect ~= "" then
		makeCoatEffect(body, coat.Effect)
	end
end

-- Saved choices belong to individual pack slots; legacy saves keep their old coat.
local function applyCoat(player)
	local data = context.PlayerData[player]
	if data == nil then
		return
	end
	for _, model in ipairs(context.GetCoyoModels(player)) do
		local index = tostring(model:GetAttribute("PackIndex") or 1)
		local coat = WardrobeConfig.Coats[data.DogCoats[index] or data.CoyoCoat]
		if coat then applyCoatToModel(model, coat) end
	end
end

----------------------------------------------------------------
-- The shrine
----------------------------------------------------------------

local function buildShrine()
	require(script.Parent:WaitForChild("NinjaCoyoDressingHouse")).Build(function(player)
		sendState(player)
		openEvent:FireClient(player)
	end)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function Wardrobe.GetCoinMultiplier(player)
	if ownsPass(player, WardrobeConfig.DoubleCoinsPassId) then
		return 2
	end
	return 1
end

function Wardrobe.ApplyOutfit(player, character, isSpawn)
	task.spawn(applyOutfit, player, character, isSpawn)
end

function Wardrobe.ApplyCoat(player)
	applyCoat(player)
end

function Wardrobe.Refresh(player)
	sendState(player)
end

local function onEquip(player, kind, itemId, packIndex)
	local data = context.PlayerData[player]
	if data == nil then
		return false, "Loading..."
	end
	if type(kind) ~= "string" or type(itemId) ~= "string" then
		return false, "Invalid"
	end

	if kind == "Outfit" then
		local outfit = WardrobeConfig.Outfits[itemId]
		if outfit == nil then
			return false, "Invalid"
		end
		if ownsItem(player, outfit) == false then
			return false, "Not owned"
		end
		data.Outfit = itemId
		if player.Character ~= nil then
			Wardrobe.ApplyOutfit(player, player.Character, false)
		end
	elseif kind == "Coat" then
		packIndex = packIndex or 1
		if type(packIndex) ~= "number" or packIndex ~= math.floor(packIndex)
			or packIndex < 1 or packIndex > Config.GetValue("PackSize", data.Upgrades.PackSize) then
			return false, "Dog not unlocked"
		end
		local coat = WardrobeConfig.Coats[itemId]
		if coat == nil then
			return false, "Invalid"
		end
		if ownsItem(player, coat) == false then
			return false, "Not owned"
		end
		data.DogCoats[tostring(packIndex)] = itemId
		applyCoat(player)
	else
		return false, "Invalid"
	end

	sendState(player)
	return true, "Equipped"
end

local function onPassPurchased(player, passId, wasPurchased)
	if wasPurchased ~= true then
		return
	end
	if ownedPasses[player] == nil then
		return
	end
	ownedPasses[player][passId] = true

	local itemName = passId == WardrobeConfig.GoldSwordPassId and "Super Gold Sword" or "Double Scroll-Coins"
	if context.OnOwnershipReady then context.OnOwnershipReady(player) end
	for _, outfitId in ipairs(WardrobeConfig.OutfitOrder) do
		local outfit = WardrobeConfig.Outfits[outfitId]
		if outfit.PassId == passId then
			itemName = outfit.DisplayName
		end
	end
	for _, coatId in ipairs(WardrobeConfig.CoatOrder) do
		local coat = WardrobeConfig.Coats[coatId]
		if coat.PassId == passId then
			itemName = coat.DisplayName
		end
	end

	context.NotifyEvent:FireClient(player, "THANK YOU!", itemName .. " is now yours", true)
	sendState(player)
end

function Wardrobe.Init(newContext)
	context = newContext

	local remotesFolder = ReplicatedStorage:WaitForChild("NinjaCoyoRemotes")
	openEvent.Parent = remotesFolder
	stateEvent.Parent = remotesFolder
	equipFunction.Parent = remotesFolder
	getStateFunction.Parent = remotesFolder

	Players.PlayerAdded:Connect(function(player)
		ownedPasses[player] = {}
		task.spawn(function()
			loadOwnedPasses(player)
			if player.Parent == nil then return end
			if context.OnOwnershipReady then context.OnOwnershipReady(player) end
			sendState(player)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		ownedPasses[player] = {}
		task.spawn(function()
			loadOwnedPasses(player)
			if player.Parent == nil then return end
			if context.OnOwnershipReady then context.OnOwnershipReady(player) end
			sendState(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	equipFunction.OnServerInvoke = onEquip
	getStateFunction.OnServerInvoke = function(player)
		return buildState(player)
	end

	buildShrine()
end

return Wardrobe
