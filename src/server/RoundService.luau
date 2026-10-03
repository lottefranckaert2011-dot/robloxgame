-- Rondes: pauze -> opruimen (met monster en tijdslimiet) -> gewonnen/verloren -> opnieuw.
-- De status staat in attributen op Workspace zodat de client die kan tonen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BookService = require(script.Parent.BookService)
local MonsterService = require(script.Parent.MonsterService)
local DataService = require(script.Parent.DataService)

local RoundService = {}

local finished = false

local function setState(state: string, message: string?)
	Workspace:SetAttribute("RoundState", state)
	Workspace:SetAttribute("Message", message or "")
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function respawnEveryone()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

local function runRound()
	-- Pauze
	MonsterService.Despawn()
	BookService.Clear()
	for _, player in Players:GetPlayers() do
		DataService.SetRoundBooks(player, 0)
	end
	while #Players:GetPlayers() == 0 do
		setState("Waiting", "Wachten op spelers...")
		task.wait(1)
	end
	for t = Config.IntermissionTime, 1, -1 do
		setState("Intermission", "De nacht begint over " .. t .. "...")
		Workspace:SetAttribute("TimeLeft", t)
		task.wait(1)
	end

	-- Opruimen!
	respawnEveryone()
	finished = false
	BookService.SpawnAll()
	MonsterService.Progress = 0
	setState("Playing", "Ruim de bibliotheek op voordat de nacht voorbij is!")
	Remotes.Notify:FireAllClients("Zet alle boeken terug in de juiste kast. En wees STIL...", Color3.fromRGB(255, 220, 150))

	local timeLeft = Config.RoundTime
	local elapsed = 0
	local monsterSpawned = false
	while timeLeft > 0 and not finished do
		Workspace:SetAttribute("TimeLeft", timeLeft)
		task.wait(1)
		timeLeft -= 1
		elapsed += 1
		MonsterService.Progress = BookService.Placed / Config.TotalBooks()
		if not monsterSpawned and elapsed >= Config.Monster.SpawnDelay then
			monsterSpawned = true
			MonsterService.Spawn()
		end
	end
	Workspace:SetAttribute("TimeLeft", math.max(timeLeft, 0))

	BookService.Active = false
	MonsterService.Despawn()

	if finished then
		local text = "DE BIBLIOTHEEK IS SCHOON! Tijd: " .. formatTime(elapsed)
		setState("Won", text)
		for _, player in Players:GetPlayers() do
			DataService.AddCoins(player, Config.CoinsForWin)
			local profile = DataService.Get(player)
			if profile then
				profile.Wins += 1
				if not profile.BestTime or elapsed < profile.BestTime then
					profile.BestTime = elapsed
					Remotes.Notify:FireClient(player, "Nieuw record: " .. formatTime(elapsed) .. "!", Color3.fromRGB(255, 215, 0))
				end
			end
		end
	else
		setState("Lost", "De nachtmerrie heeft gewonnen... " .. BookService.Placed .. "/" .. Config.TotalBooks() .. " boeken")
	end
	task.wait(Config.EndScreenTime)
end

function RoundService.Init()
	BookService.OnAllPlaced = function()
		finished = true
	end
	BookService.OnBookPlaced = function(player, count)
		DataService.AddCoins(player, count * Config.CoinsPerBook)
		DataService.SetRoundBooks(player, DataService.GetRoundBooks(player) + count)
	end
	BookService.OnMistake = function(_player, position)
		MonsterService.Noise(position, Config.Monster.HearMistakeRange)
	end

	Workspace:SetAttribute("Total", Config.TotalBooks())
	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn("[Round] " .. tostring(err))
				task.wait(3)
			end
		end
	end)
end

return RoundService
