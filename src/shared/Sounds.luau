-- Speelt een kort geluid af op een plek (server of client).
-- Lege ID's in Config.SoundIds worden overgeslagen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

function Sounds.Play(name: string, parent: Instance, volume: number?)
	local soundId = Config.AssetId((Config.SoundIds :: any)[name])
	if not soundId then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

return Sounds
