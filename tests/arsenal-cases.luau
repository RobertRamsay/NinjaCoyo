local V={}
V.__index=V
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},V)end}
V.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V.__mul=function(a,b)return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
local Config={Weapons={Bow={Range=80,Cooldown=1,Damage=3.5},Kunai={Range=28,Cooldown=.45,Damage=1.15}},GetValue=function()return 12 end}
local hits,fxCount,now=0,0,10
local enemy={Model={},Root={Position=Vector3.new(0,0,-20)}}
local Enemies={FindNearestEnemy=function(_,_,range)assert(range==80 or range==28);return enemy end,DamageEnemy=function(_,_,damage)hits+=1;assert(math.abs(damage-42)<.001 or math.abs(damage-13.8)<.001)end}
local game={GetService=function()return {WaitForChild=function()return "config" end}end}
local script={Parent={WaitForChild=function()return "enemies"end}}
local require=function(name)return name=="config" and Config or Enemies end
local os={clock=function()return now end}
local RaycastParams={new=function()return {}end}
local Enum={RaycastFilterType={Exclude="Exclude"}}
local blocked=false
local workspace={FindFirstChild=function()return {}end,Raycast=function(_,_,_,params)assert(params.RespectCanCollide);return blocked and {} or nil end}
-- WEAPONS_INSERT
local root={Position=Vector3.new(0,0,0),CFrame={LookVector=Vector3.new(0,0,-1)}}
local hum={Health=100}
local character={FindFirstChild=function()return root end,FindFirstChildOfClass=function()return hum end}
local protected=false
local player={Character=character,GetAttribute=function()return protected end}
local id="Bow"
local tool={Parent=character,GetAttribute=function()return id end}
local data={Unlocks={},Upgrades={KatanaPower=1}}
local context={Data={[player]=data},LastAttack={},Fx={FireAllClients=function()fxCount+=1 end}}
Weapons.Attack(player,tool,context);assert(hits==0 and fxCount==0,"Unowned weapon rejected")
data.Unlocks.Bow=true
Weapons.Attack(player,tool,context);assert(hits==1 and fxCount==1,"Owned equipped bow deals tuned damage")
Weapons.Attack(player,tool,context);assert(hits==1,"Repeat activation throttled")
id="Kunai";data.Unlocks.Kunai=true
Weapons.Attack(player,tool,context);assert(hits==1,"Swapping weapons cannot bypass shared attack clock")
now+=2;protected=true
Weapons.Attack(player,tool,context);assert(hits==1,"Menu protection prevents outgoing attacks")
protected=false;tool.Parent={}
Weapons.Attack(player,tool,context);assert(hits==1,"Backpack tools cannot attack")
tool.Parent=character;hum.Health=0
Weapons.Attack(player,tool,context);assert(hits==1,"Dead player cannot attack")
hum.Health=100;blocked=true
Weapons.Attack(player,tool,context);assert(hits==1,"Walls block thrown weapon damage")
now+=2;blocked=false
Weapons.Attack(player,tool,context);assert(hits==2,"Clear kunai throw damages enemy")
print("PASS: arsenal ownership, equipped/alive/menu checks, shared cooldown, damage scaling and wall occlusion")
