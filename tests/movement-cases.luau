local function signal()
	local s={handlers={}}
	function s:Connect(f) table.insert(self.handlers,f);return {Disconnect=function()end} end
	function s:Fire(...)for _,f in ipairs(self.handlers)do f(...)end end
	return s
end
local now=0
local os={clock=function()return now end}
local Enum={HumanoidStateType={Jumping="Jumping",Freefall="Freefall",Landed="Landed",Running="Running",Swimming="Swimming",Climbing="Climbing",Seated="Seated",Dead="Dead"}}
local Vector3={new=function(x,y,z)return {X=x,Y=y,Z=z}end}
local cfMeta={__mul=function(a,b)return b end}
local CFrame={Angles=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},cfMeta)end}
local rest=setmetatable({},cfMeta)
local motor={Parent=true,C0=rest,IsA=function()return true end}
local humanoid={Health=100,JumpPower=80,State="Running",StateChanged=signal()}
function humanoid:GetState()return self.State end
function humanoid:ChangeState(s)local old=self.State;self.State=s;self.StateChanged:Fire(old,s)end
local root={AssemblyLinearVelocity=Vector3.new(8,-5,4)}
motor.Part0=root
local character={Parent=true,Level=0}
function character:WaitForChild(name)return name=="Humanoid" and humanoid or root end
function character:GetDescendants()return {motor}end
function character:GetAttribute()return self.Level end
local player={Character=character,CharacterAdded=signal()}
local players={LocalPlayer=player,PlayerAdded=signal(),GetPlayers=function()return {player}end}
local render={PreSimulation=signal()}
local input={JumpRequest=signal()}
local storage={WaitForChild=function()return {}end}
local game={GetService=function(_,name)return ({Players=players,RunService=render,UserInputService=input,ReplicatedStorage=storage})[name]end}
local require=function()return {DoubleJumpDelay=.15,FlipJumpLevel=3,TripleJumpLevel=7}end
local task={spawn=function(f,...)f(...)end}
-- MOVEMENT_INSERT
local function airJump()
	humanoid:ChangeState("Freefall")
	now+=.3
	input.JumpRequest:Fire()
end
humanoid:ChangeState("Jumping")
airJump()
assert(states[character].Jumps==2,"Base double jump")
airJump()
assert(states[character].Jumps==2,"No third jump before upgrade")
assert(root.AssemblyLinearVelocity.X==8 and root.AssemblyLinearVelocity.Z==4,"Air jump preserves horizontal motion")
assert(motor.C0==rest,"No early flip")
humanoid:ChangeState("Landed")
character.Level=3
humanoid:ChangeState("Jumping")
now+=.2;render.PreSimulation:Fire()
assert(motor.C0~=rest and motor.C0.X<0,"Level 3 forward flip")
now+=.8;render.PreSimulation:Fire()
assert(motor.C0==rest,"Flip restores pose")
humanoid:ChangeState("Landed")
character.Level=7
humanoid:ChangeState("Jumping")
airJump();airJump()
assert(states[character].Jumps==3,"Level 7 third jump")
now+=.1;render.PreSimulation:Fire()
assert(motor.C0.Y>0,"Upgraded air jump spins")
airJump();assert(states[character].Jumps==3,"No fourth jump")
humanoid:ChangeState("Landed")
assert(states[character].Jumps==0 and motor.C0==rest,"Landing resets jump budget and pose")
humanoid:ChangeState("Freefall")
assert(states[character].Jumps==1,"Walking off ledge consumes ground jump")
humanoid.Health=0
local velocity=root.AssemblyLinearVelocity
now+=1;input.JumpRequest:Fire()
assert(root.AssemblyLinearVelocity==velocity,"Dead characters cannot air jump")
character.Parent=nil;render.PreSimulation:Fire()
assert(states[character]==nil,"Respawn cleans up animation state")
print("PASS: double/triple jump limits, flip threshold, spin, landing, ledges, death and cleanup")
