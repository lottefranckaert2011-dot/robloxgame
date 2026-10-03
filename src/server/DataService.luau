-- Slaat munten, gevonden sleutels en je snelste tijd op met DataStoreService.
-- In Studio werkt dit alleen als "Enable Studio Access to API Services" aan staat.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "CleanTheLibraryNightmare_v1"

export type Profile = {
	Coins: number,
	Keys: { [string]: boolean },
	BestTime: number?,
	Wins: number,
	Upgrades: { [string]: number }, -- winkel-upgrades en hun niveau
	Magic: { [string]: boolean }, -- gekochte vaardigheden
	Assistant: number, -- niveau van de assistent (0 = geen)
}

local DataService = {}
DataService.OnLoaded = nil :: ((player: Player, profile: Profile) -> ())?

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore niet beschikbaar, voortgang wordt niet opgeslagen: " .. tostring(result))
	end
end

local function defaultProfile(): Profile
	return { Coins = 0, Keys = {}, BestTime = nil, Wins = 0, Upgrades = {}, Magic = {}, Assistant = 0 }
end

local function load(player: Player): Profile
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			profile.Coins = tonumber(data.Coins) or 0
			profile.Wins = tonumber(data.Wins) or 0
			profile.BestTime = tonumber(data.BestTime)
			profile.Assistant = tonumber(data.Assistant) or 0
			if type(data.Keys) == "table" then
				for id, value in data.Keys do
					profile.Keys[tostring(id)] = value == true
				end
			end
			if type(data.Magic) == "table" then
				for id, value in data.Magic do
					profile.Magic[tostring(id)] = value == true
				end
			end
			if type(data.Upgrades) == "table" then
				for id, value in data.Upgrades do
					profile.Upgrades[tostring(id)] = tonumber(value) or 0
				end
			end
		elseif not ok then
			warn("[Data] Laden mislukt voor " .. player.Name .. ": " .. tostring(data))
		end
	end
	return profile
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[Data] Opslaan mislukt voor " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

local function updateStats(player: Player)
	local profile = profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	local coins = stats:FindFirstChild("Munten") :: IntValue?
	if coins then
		coins.Value = profile.Coins
	end
	player:SetAttribute("Coins", profile.Coins)
end

function DataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.Coins += amount
		updateStats(player)
	end
end

-- Geeft true terug als de speler genoeg munten had
function DataService.SpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	updateStats(player)
	return true
end

function DataService.SetRoundBooks(player: Player, value: number)
	local stats = player:FindFirstChild("leaderstats")
	local books = stats and stats:FindFirstChild("Boeken") :: IntValue?
	if books then
		books.Value = value
	end
end

function DataService.GetRoundBooks(player: Player): number
	local stats = player:FindFirstChild("leaderstats")
	local books = stats and stats:FindFirstChild("Boeken") :: IntValue?
	return if books then books.Value else 0
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local books = Instance.new("IntValue")
	books.Name = "Boeken"
	books.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Munten"
	coins.Parent = stats
	stats.Parent = player

	local profile = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = profile
	updateStats(player)
	if DataService.OnLoaded then
		DataService.OnLoaded(player, profile)
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
	-- Af en toe automatisch opslaan
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)
end

return DataService
