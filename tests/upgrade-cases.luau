local V={}
V.__index=function(v,k)
	if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+(v.Z or 0)^2) end
	return V[k]
end
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end}
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
Vector3.zero=Vector3.new(0,0,0)
local Vector2={new=function(x,y)return setmetatable({X=x,Y=y},V)end}
local Color3={fromRGB=function(...)return {...}end}
local Enum=setmetatable({},{__index=function()return setmetatable({},{__index=function(_,k)return k end})end})
-- CONFIG_INSERT
local player={UserId=1,Name="Tester",Parent=true}
local playerData={}
local playerPets={}
local dataStore={GetAsync=function()return {CoyoCoat="Snow",DogCoats={['2']="Shiba",['3']="Invalid"},Upgrades={PackSize=1}}end}
-- SAVE_INSERT
local data,loaded=loadData(player)
assert(loaded and data.CoyoCoat=="Snow" and data.DogCoats['2']=="Shiba" and data.DogCoats['3']==nil,"Legacy and per-dog migration")
playerData[player]=data
local root={}
local character={Parent=true,WaitForChild=function()return root end}
player.Character=character
local function createCoyoDog(_,_,index)
	return {Model={Index=index,Destroy=function(m)m.Destroyed=true end}}
end
-- PACK_INSERT
for level=0,3 do
	data.Upgrades.PackSize=level
	local old=playerPets[player]
	createCoyo(player,character)
	assert(#playerPets[player]==level+1,"Actual pack construction must match upgrade")
	if old then for _,pet in ipairs(old)do assert(pet.Model.Destroyed,"Old pack removed") end end
end
local old=playerPets[player]
createCoyo(player,character)
assert(#playerPets[player]==4 and old[1].Model.Destroyed,"Rebuild cannot duplicate dogs")
data=createDefaultData(); playerData[player]=data
local WardrobeConfig=Config.Wardrobe
local ownedPasses={}
local isStudio=false
local Wardrobe={ApplyOutfit=function()end}
local models={{GetAttribute=function()return 1 end},{GetAttribute=function()return 2 end}}
local context={PlayerData=playerData,GetCoyoModels=function()return models end}
local stateEvent={FireClient=function()end}
local function applyCoatToModel(model,coat)model.Coat=coat end
-- WARDROBE_INSERT
assert(not ownsItem(player,WardrobeConfig.Coats.Snow),"Snow Wolf locked before pack upgrade")
assert(ownsItem(player,WardrobeConfig.Coats.Shiba),"Starter Shiba available")
assert(not onEquip(player,"Coat","Shiba",2),"Cannot equip locked dog")
assert(not onEquip(player,"Coat","Spirit",1),"Cannot equip unearned coat")
data.Upgrades.PackSize=1
assert(ownsItem(player,WardrobeConfig.Coats.Snow),"Snow Wolf earned with second dog")
assert(onEquip(player,"Coat","Snow",2),"Equip second dog")
assert(onEquip(player,"Coat","Shiba",1),"Equip first dog separately")
assert(models[1].Coat==WardrobeConfig.Coats.Shiba and models[2].Coat==WardrobeConfig.Coats.Snow,"Independent visible coats")
assert(not onEquip(player,"Coat","Shiba",1.5),"Reject fractional slot")
assert(not onEquip(player,"Coat","Shiba",0/0),"Reject NaN slot")
assert(not onEquip(player,"Coat","Missing",1),"Reject unknown coat")
assert(not onEquip(player,"Coat","Shiba",math.huge),"Reject infinite slot")
local state=buildState(player)
assert(state.PackSize==2 and state.DogCoats['1']=="Shiba" and state.DogCoats['2']=="Snow","UI state contains choices and count")
assert(state.OwnedOutfits.Crimson,"Starter outfit free in live game")
print("PASS: old saves, 1-4 dogs, rebuild cleanup, individual coats, unlock rules, invalid requests")

local spawnCell={}
local rng={NextNumber=function(_,lo,hi)return (lo+hi)/2 end}
local Scenery={IsPickupClear=function()return true end}
local chestsFolder={GetChildren=function()return {}end}
local rayParams={}
local workspace={Raycast=function(_,origin)return {Position=Vector3.new(origin.X,0,origin.Z),Material=Enum.Material.Grass,Normal={Y=1}}end}
-- SPAWN_INSERT
local positions={}
local meadow=Config.Zones.Meadow
for i=1,12 do
	local p=getRandomGroundInZone(meadow)
	positions[p.X..":"..p.Z]=true
	assert(p.X>meadow.SpawnMin.X and p.X<meadow.SpawnMax.X and p.Z>meadow.SpawnMin.Y and p.Z<meadow.SpawnMax.Y,"Inside meadow")
	assert(p.Z>-125,"Meadow coins cannot spawn behind first gate")
end
local count=0; for _ in pairs(positions)do count+=1 end
assert(count==12,"All twelve spawn cells visited")
for _,hill in ipairs(Config.TreasureTerraces)do
	local p=getRandomGroundInZone(Config.Zones[hill.Zone],hill)
	assert(p.X==hill.Center.X and p.Z==hill.Center.Z,"Chest sampler targets summit")
end
Scenery.IsPickupClear=function()return false end
assert(getRandomGroundInZone(meadow)==nil,"Building footprint rejects pickup")
print("PASS: twelve-cell pickup coverage, gate boundary, terrace targeting, building exclusion")

local column={Name="Trunk",CanCollide=true,Size=Vector3.new(12,1.4,1.4),Position=Vector3.new(20,6,10),
	CFrame={RightVector=Vector3.new(0,1,0),UpVector=Vector3.new(-1,0,0),LookVector=Vector3.new(0,0,-1)},IsA=function()return true end}
local folder={GetDescendants=function()return {column}end}
workspace.FindFirstChild=function()return nil end
-- CLEARANCE_INSERT
assert(not Scenery.IsPickupClear(Vector3.new(20,0,10)),"No pickup inside tree trunk")
assert(Scenery.IsPickupClear(Vector3.new(40,0,10)),"Upright cylinders do not block entire row")
column.Name="Floor";column.Size=Vector3.new(500,1,500)
assert(Scenery.IsPickupClear(Vector3.new(20,0,10)),"Zone floor remains spawnable")
print("PASS: rotated scenery footprints and floor exclusion")
