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
local function findMotor(character,_,name)return character.Motors and character.Motors[name] end
local function placeArc()end
local originalGrip={}
local activeSwings={}
local calls={}
local Sounds={Play=function(...)table.insert(calls,{...})end}
local rng={NextNumber=function(_,a,b)return (a+b)/2 end}
local task={delay=function(_,fn)fn()end}
local player={}
local clock=0
local os={clock=function()return clock end}
local Debris={AddItem=function()end}
local function lerp(a,b,t)return a+(b-a)*t end
local function easeOutQuad(t)return 1-(1-t)^2 end
local function easeInOutCubic(t)return t<.5 and 4*t*t*t or 1-(-2*t+2)^3/2 end
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

local shoulderBase,waistBase=CFrame.Angles(0,0,0),CFrame.Angles(0,0,0)
local shoulder={C0=shoulderBase,Parent=true}
local waist={C0=waistBase,Parent=true}
local root={Parent=true,CFrame={}}
local originalRoot=root.CFrame
local tool={Grip={},FindFirstChild=function()return nil end}
local character={Parent=true,Motors={RightShoulder=shoulder,Waist=waist},
	FindFirstChild=function(_,name)return name=="Katana" and tool or root end,
	GetAttribute=function()return 20 end}
tool.Parent=character
activeSwings={};clock=1
playSwing(character)
assert(activeSwings[character].WaistFinish<math.pi,"Torso never performs a full-body spin")
clock=1+SWING_WINDUP_TIME*.9;updateSwings()
assert(shoulder.C0~=shoulderBase and waist.C0~=waistBase,"Upper-body pose visibly changes during windup")
assert(root.CFrame==originalRoot,"Animation does not move or hold the root")
clock=1+SWING_WINDUP_TIME+SWING_SLASH_TIME*.5;updateSwings()
assert(activeSwings[character].ArcTrail.Enabled,"Trail follows the strike")
clock=2;updateSwings()
assert(activeSwings[character]==nil and shoulder.C0==shoulderBase and waist.C0==waistBase,"Joint offsets restored after slash")
playSwing(character);tool.Parent=nil;updateSwings()
assert(activeSwings[character]==nil and shoulder.C0==shoulderBase,"Unequip also restores pose")
assert(SWING_WINDUP_TIME+SWING_SLASH_TIME+SWING_RECOVER_TIME<=.35,"Slash finishes before next allowed attack")
print("PASS: upper-body movement, free root, trail timing, pose cleanup, no torso spin and repeat attack timing")
