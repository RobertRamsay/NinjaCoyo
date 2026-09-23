-- NinjaCoyoSounds (ModuleScript in ReplicatedStorage)
-- Plays the sound effects listed in Config.Sounds. Used by the client scripts.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("NinjaCoyoConfig"))

local Sounds = {}

-- State (initialised up front)
local templates = {}
local soundFolder = Instance.new("Folder")
soundFolder.Name = "NinjaCoyoSounds"
soundFolder.Parent = SoundService

for name, info in pairs(Config.Sounds) do
	local template = Instance.new("Sound")
	template.Name = name
	template.SoundId = info.Id
	template.Volume = info.Volume
	template.Parent = soundFolder
	templates[name] = template
end

-- Load every sound in the background so the first play isn't delayed
task.spawn(function()
	local list = {}
	for _, template in pairs(templates) do
		if template.SoundId ~= "" then
			table.insert(list, template)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end)

function Sounds.Play(name, pitch, volumeScale)
	local template = templates[name]
	if template == nil then
		return
	end
	if template.SoundId == "" then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch
	sound.Volume = template.Volume * volumeScale
	sound.Parent = soundFolder
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sounds
