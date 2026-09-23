local V = {}
V.__index = function(v,k)
	if k == "Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	return V[k]
end
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end}
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local CFrame={lookAt=function(position,target)return {Position=position,Target=target}end}
local now=10
local os={clock=function()return now end}
local player={UserId=1,Parent=true}
local WardrobeConfig={GoldSwordPassId=0,DoubleCoinsPassId=0,OutfitOrder={},CoatOrder={},StudioOwnsEverything=true}
local Wardrobe={}
local ownedPasses={[player]={}}
local MarketplaceService={UserOwnsGamePassAsync=function()return false end}
-- OWNERSHIP_INSERT
assert(not Wardrobe.OwnsGoldSword(player),"Unset pass must not grant gold, even in Studio")
WardrobeConfig.GoldSwordPassId=42
loadOwnedPasses(player)
assert(not Wardrobe.OwnsGoldSword(player),"Non-owner denied")
MarketplaceService.UserOwnsGamePassAsync=function()error("offline")end
loadOwnedPasses(player)
assert(not Wardrobe.OwnsGoldSword(player),"Failed lookup denies benefit")
MarketplaceService.UserOwnsGamePassAsync=function()return true end
loadOwnedPasses(player)
assert(Wardrobe.OwnsGoldSword(player),"Owner restored on join")
ownedPasses[player]={}
local notices,grants=0,0
local context={NotifyEvent={FireClient=function()notices+=1 end},OnOwnershipReady=function()grants+=1 end,
	FxEvent={FireAllClients=function()end}}
local function sendState()end
-- PURCHASE_INSERT
onPassPurchased(player,42,false)
assert(not Wardrobe.OwnsGoldSword(player) and grants==0,"Cancellation does not grant")
onPassPurchased(player,42,true)
assert(Wardrobe.OwnsGoldSword(player) and grants==1 and notices==1,"Successful server purchase grants immediately")
local Enemies={}
local enemiesByPlayer={[player]={}}
-- ENEMIES_INSERT
local humanoid={Health=100,Sit=false}
local root={Position=Vector3.new(0,2,0)}
local character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return humanoid end}
player.Character=character
local tool={Parent=character}
local playerData={[player]={Unlocks={Katana=true},Upgrades={KatanaPower=0}}}
local lastSwingTime={[player]=0}
local Config={KatanaCooldown=.35,KatanaEnemyRange=10,KatanaRange=9,GetValue=function()return 15 end}
local fxEvent={FireAllClients=function()end}
local chestsFolder={GetChildren=function()return {}end}
local function playerHasZone()return true end
local function hitChest()error("Unexpected chest")end
-- SWING_INSERT
local function enemy(x,health,owner)
	local h={Health=health,TakeDamage=function(self,damage)self.Health=math.max(0,self.Health-damage)end}
	return {Dead=false,Owner=owner or player,Humanoid=h,Root={Position=Vector3.new(x,2,0)}}
end
local far,near,outside=enemy(8,120),enemy(-4,200),enemy(11,500)
enemiesByPlayer[player]={far,near,outside}
ownedPasses[player]={}
onKatanaSwing(player,tool)
assert(root.CFrame.Target.X==-4,"Faces nearest enemy instead of first in list")
assert(near.Humanoid.Health==185 and far.Humanoid.Health==105,"Normal damage retained")
assert(outside.Humanoid.Health==500,"Out-of-range enemy untouched")
ownedPasses[player][42]=true
onKatanaSwing(player,tool)
assert(near.Humanoid.Health==185,"Cooldown prevents duplicate hit")
now+=1; onKatanaSwing(player,tool)
assert(near.Humanoid.Health==0 and far.Humanoid.Health==0,"Gold one-hits enemies of different health")
assert(outside.Humanoid.Health==500,"Gold does not expand range")
local other=enemy(1,80,{})
Enemies.DamageEnemy(player,other,80)
assert(other.Humanoid.Health==80,"Cannot hurt another player's enemies")
near.Humanoid.Health=200; tool.Parent={}; now+=1
onKatanaSwing(player,tool)
assert(near.Humanoid.Health==200,"Unequipped tool cannot damage")
tool.Parent=character; humanoid.Health=0; now+=1
onKatanaSwing(player,tool)
assert(near.Humanoid.Health==200,"Dead player cannot damage")
humanoid.Health=100; ownedPasses[player]={}; near.Humanoid.Health=0; far.Humanoid.Health=0
local prior=root.CFrame; now+=1; onKatanaSwing(player,tool)
assert(root.CFrame==prior,"No nearby living enemy leaves facing alone")
print("PASS: pass ownership/failure/cancellation/purchase, nearest facing, normal and gold damage, range, cooldown, owner, equipped/alive checks")
