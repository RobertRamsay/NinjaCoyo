local Vector3={new=function(x,y,z)return {X=x,Y=y,Z=z}end}
local CFrame={new=function()return {}end,Angles=function()return setmetatable({},{__mul=function(a,b)return b end})end}
local Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end}
local ColorSequence={new=function(...)return {...}end}
local NumberSequence={new=function(...)return {...}end}
local NumberSequenceKeypoint={new=function(...)return {...}end}
local Enum={Material={Neon=true},PartType={Block=true}}
local instances={}
local Instance={new=function(class)local obj={ClassName=class};table.insert(instances,obj);return obj end}
local function makeFxPart()return {}end
local function findMotor()return nil end
local function placeArc()end
local originalGrip={}
local activeSwings={}
local calls={}
local Sounds={Play=function(...)table.insert(calls,{...})end}
local rng={NextNumber=function(_,a,b)return (a+b)/2 end}
local task={delay=function(_,fn)fn()end}
local player={}
-- SWING_TUNING_INSERT
-- SWING_FUNCTIONS_INSERT
for _,level in ipairs({0,5,10,20,30})do
	local tool={Grip={}}
	local root={}
	local character={FindFirstChild=function(_,name)return name=="Katana" and tool or root end,GetAttribute=function()return level end}
	tool.FindFirstChild=function()return nil end
	player.Character=character
	instances={};calls={}
	playSwing(character)
	local swing=activeSwings[character]
	assert(math.abs(swing.EndYaw-ARC_START_YAW-math.rad(180+math.min(level,10)*18))<.001,"Sweep scales to full circle")
	assert(-instances[2].Position.Z<=9.5,"Visual sweep stays within hit radius")
	assert(swing.ArcTrail.Lifetime>=.22,"Trail remains visible")
	assert(#calls==(level>=20 and 2 or 1),"Higher tier layered whoosh")
	playSwing(character)
	assert(#calls==(level>=20 and 2 or 1),"Overlapping swing request ignored")
end
print("PASS: katana sweep tiers, visual radius, trail lifetime, layered whoosh and duplicate guard")
