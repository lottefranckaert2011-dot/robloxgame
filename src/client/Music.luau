-- Muziek die vanzelf past bij waar je bent en wat er gebeurt:
-- hal, bibliotheek, nachtmerrie, achtervolging, laatste minuut, gewonnen of verloren.
-- Nummers vloeien zacht in elkaar over. De ID's staan in Config.Music.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer

local Music = {}

local tracks: { [string]: Sound } = {}
local current: string? = nil
local heartbeat: Sound? = nil

local function makeSound(name: string, soundId: string, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

local function roomState(): Instance?
	local id = player:GetAttribute("Room")
	local folder = ReplicatedStorage:FindFirstChild("RoomState")
	if type(id) ~= "string" or not folder then
		return nil
	end
	return folder:FindFirstChild(id)
end

-- Welke nummers passen nu, van best naar minder goed (het eerste dat bestaat wint)
local function wishes(danger: number): { string }
	local state = roomState()
	if not state then
		return { "Lobby", "Library" }
	end
	local status = state:GetAttribute("RoundState")
	if status == "Won" then
		return { "Win" }
	elseif status == "Lost" then
		return { "Lose" }
	end
	local base = if state:GetAttribute("Dark") then { "Nightmare", "Library" } else { "Library", "Lobby" }
	local list = {}
	if danger > 0.35 then
		table.insert(list, "Chase")
	end
	if status == "Playing" and (state:GetAttribute("TimeLeft") or math.huge) <= 60 then
		table.insert(list, "Countdown")
	end
	for _, name in base do
		table.insert(list, name)
	end
	return list
end

function Music.Init(hud, effects)
	for name, value in Config.Music do
		local soundId = Config.AssetId(value)
		if soundId then
			tracks[name] = makeSound("Music_" .. name, soundId, name ~= "Win" and name ~= "Lose")
		end
	end
	local heartbeatId = Config.AssetId(Config.SoundIds.Heartbeat)
	if heartbeatId then
		heartbeat = makeSound("Heartbeat", heartbeatId, true)
	end

	-- Kleine geluidjes voor jezelf: munten erbij en door een deur stappen
	local lastCoins = player:GetAttribute("Coins") or 0
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local coins = player:GetAttribute("Coins") or 0
		if coins ~= lastCoins then
			Sounds.Play("Coins", SoundService, 0.5)
		end
		lastCoins = coins
	end)
	player:GetAttributeChangedSignal("Room"):Connect(function()
		if player:GetAttribute("Room") then
			Sounds.Play("Portal", SoundService, 0.7)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local enabled = hud.Settings.Music
		local danger = effects.Danger or 0

		local target: string? = nil
		for _, name in wishes(danger) do
			if tracks[name] then
				target = name
				break
			end
		end
		if target ~= current then
			current = target
			local sound = if target then tracks[target] else nil
			if sound and not sound.IsPlaying then
				sound.TimePosition = 0
				sound:Play()
			end
		end

		-- Zacht in- en uitfaden
		local fade = math.min(1, dt * 1.5)
		for name, sound in tracks do
			local goal = if enabled and name == current then Config.MusicVolume else 0
			sound.Volume += (goal - sound.Volume) * fade
			if goal == 0 and sound.IsPlaying and sound.Volume < 0.01 then
				sound:Stop()
			end
		end

		if heartbeat then
			local goal = if enabled then math.clamp(danger, 0, 1) * 0.9 else 0
			heartbeat.Volume += (goal - heartbeat.Volume) * fade
			heartbeat.PlaybackSpeed = 1 + danger * 0.6
			if goal > 0.02 and not heartbeat.IsPlaying then
				heartbeat:Play()
			elseif goal <= 0.02 and heartbeat.IsPlaying and heartbeat.Volume < 0.01 then
				heartbeat:Stop()
			end
		end
	end)
end

return Music
