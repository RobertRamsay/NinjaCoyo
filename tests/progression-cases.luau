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
Color3.new=function(...)return {...}end
local CFrame={new=function(a,b,c)return {Position=type(a)=="table" and a or Vector3.new(a,b,c)}end,Angles=function()return {}end}
local cfMeta={__mul=function(a)return a end}
local rawNew=CFrame.new
CFrame.new=function(...)return setmetatable(rawNew(...),cfMeta)end
local UDim2={fromOffset=function(...)return {...}end,fromScale=function(...)return {...}end}
-- CONFIG_INSERT
local expected={50,500,1000,2500,10000,50000,150000,300000,1000000}
for i,id in ipairs(Config.ZoneOrder)do local unlock = i==1 and "Katana" or Config.Zones[id].RequiredUnlock; assert(Config.Unlocks[unlock].Cost==expected[i],"Requested cost: "..id)end
assert(#Config.ZoneOrder==9,"Eight gates need nine zones")
for i,id in ipairs(Config.ZoneOrder)do
	local route=Config.PlatformRoutes[id]
	local v=Config.GetValue("NinjaJump",route.JumpLevel)
	local jumps=route.JumpLevel>=Config.TripleJumpLevel and 3 or 2
	local maxRise=jumps*v*v/(2*196.2)
	assert(route.Rise<maxRise*.8,"Vertical gap retains jump headroom: "..id)
	assert(route.Rise*route.Count<Config.BarrierHeight,"Cannot jump above zone barriers")
	assert(route.Count==i+2,"More platforms in each zone")
	assert(route.Count*7+8<Config.Zones[id].Size/2,"Route inside gate walls")
end
local created={}
local Instance={new=function(class)local p={ClassName=class};table.insert(created,p);return p end}
local RaycastParams={new=function()return {}end}
local groups={}
local physics={IsCollisionGroupRegistered=function()return false end,RegisterCollisionGroup=function()end,
	CollisionGroupSetCollidable=function(_,a,b,v)groups[a..":"..b]=v end}
local workspace={Terrain={},FindFirstChild=function()return {}end,Raycast=function()return {Position=Vector3.zero}end}
local game={GetService=function(_,name)return name=="PhysicsService" and physics or {WaitForChild=function()return {}end}end}
local require=function()return Config end
local now=0
local os={clock=function()return now end}
-- PROGRESSION_INSERT
Progression.Build()
local platforms,seats,barriers=0,0,0
for _,p in ipairs(created)do
	if p.Name=="FloatingPlatform" then platforms+=1;assert(p.Anchored and p.Size.X==16)end
	if p.ClassName=="Seat" then seats+=1 end
	if p.Name=="EnemyExclusion" then barriers+=1;assert(p.CollisionGroup=="NinjaCoyoRestBarrier")end
end
assert(platforms==63 and seats==18 and barriers==3,"Platform and sanctuary geometry built")
assert(groups['NinjaCoyoRestBarrier:Default']==false and groups['NinjaCoyoRestBarrier:NinjaCoyoEnemies']==true,"Only enemies blocked by sanctuary volume")
for _,id in ipairs({'Sakura','Spirit','Inferno'})do
	local c=Config.Zones[id].Center
	assert(Progression.IsSafe(c+Vector3.new(48,5,32)),"Dojo interior safe")
	assert(not Progression.IsSafe(c+Vector3.new(48,5,55)),"Outside door unsafe")
	assert(not Progression.IsSafe(c+Vector3.new(48,30,32)),"Roof not a safe farming position")
end
local chests={GetChildren=function()return {}end}
local slot=Progression.GetChestSlot('Bamboo',chests)
assert(slot and slot.JumpLevel==1 and slot.Multiplier==3)
chests.GetChildren=function()return {{GetAttribute=function()return slot.Id end}}end
local summit=Progression.GetChestSlot('Bamboo',chests)
assert(summit and summit.Multiplier==6 and summit.Position.Y>slot.Position.Y,"Summit rewards exceed mid-route")
Progression.ChestOpened(slot.Id);chests.GetChildren=function()return {}end
assert(Progression.GetChestSlot('Bamboo',chests).Id==summit.Id,"Opened chest waits for cooldown")
now=91;assert(Progression.GetChestSlot('Bamboo',chests).Id==slot.Id,"Chest returns after cooldown")
print('PASS: exact prices, nine zones, jump headroom, 63 platforms, sanctuary geometry/boundaries, enemy barrier groups and treasure cooldowns')

assert(Config.Zones.Inferno.EnemiesPerPlayer==5 and Config.Zones.Inferno.EnemyMinLevel==45,"Final zone enemy pressure")
for id,spec in pairs(Config.Weapons) do assert(Config.Unlocks[id].Cost==spec.Cost and spec.Range>0 and spec.Cooldown>=.35) end
local before=#created
-- VOLCANO_INSERT
Volcano.Build({},Config.Zones.Inferno,0)
local ribs,pools=0,0
for i=before+1,#created do
	local p=created[i]
	if p.Name=="VolcanoRock" then
		ribs+=1
		assert(not p.CanQuery and p.CanCollide,"Shell blocks walking but cannot divert ground spawn rays")
		if p.Position.Y==18 then assert(math.abs(p.Position.X)>30 or p.Position.Z<Config.Zones.Inferno.Center.Z,"Front doorway clear") end
	end
	if p.Name=="LavaPool" then pools+=1;assert(not p.CanCollide)end
end
assert(ribs==157 and pools==3,"Hollow mountain and lava pools built")
print('PASS: volcano doorway, hollow shell, spawn-ray clearance, lava pools and weapon unlock catalog')
