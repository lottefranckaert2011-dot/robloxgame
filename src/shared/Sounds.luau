-- Speelt een kort geluid af op een plek (server of client).
-- Lege ID's in Config.SoundIds worden overgeslagen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

-- Zoekt uit welk geluid bij een naam hoort. Geeft de SoundId terug, en eventueel
-- het stukje (begin, eind) uit het gezamenlijke effectenbestand.
function Sounds.Resolve(name: string): (string?, { number }?)
	local own = Config.AssetId((Config.SoundIds :: any)[name])
	if own then
		return own, nil
	end
	local sprite = Config.AssetId(Config.SoundEffects)
	local region = (Config.SoundEffectRegions :: any)[name]
	if sprite and region then
		return sprite, region
	end
	return Config.AssetId((Config.BuiltInSounds :: any)[name]), nil
end

-- Maakt een Sound-object voor een effect (nog niet afgespeeld)
function Sounds.Create(name: string, looped: boolean?): Sound?
	local soundId, region = Sounds.Resolve(name)
	if not soundId then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = looped == true
	if region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region[1], region[2])
		sound.LoopRegion = NumberRange.new(region[1], region[2])
	end
	return sound
end

function Sounds.Play(name: string, parent: Instance, volume: number?)
	local sound = Sounds.Create(name)
	if not sound then
		return
	end
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
