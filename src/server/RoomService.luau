-- Zalen: vanuit de hal kies je een deur. Elke zaal heeft zijn eigen ronde:
-- aftellen -> opruimen (met tijdslimiet en evt. monster) -> gewonnen/verloren -> terug naar de hal.
-- De status van elke zaal staat als attributen in ReplicatedStorage.RoomState.<Id>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BookService = require(script.Parent.BookService)
local MonsterService = require(script.Parent.MonsterService)
local DataService = require(script.Parent.DataService)
local HideService = require(script.Parent.HideService)

type Room = {
	Info: Config.RoomInfo,
	Library: any,
	Books: BookService.BookService,
	Monster: MonsterService.Monster?,
	State: Folder,
	Door: any,
	Players: { [Player]: boolean },
	Status: string, -- Idle | Starting | Playing | Won | Lost
	Finished: boolean,
	RoundRunning: boolean,
	TimeLeft: number,
}

local RoomService = {}

local rooms: { [string]: Room } = {}
local playerRoom: { [Player]: Room } = {}
local touchCooldown: { [Player]: number } = {}
local lobby

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

local function formatTime(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function roomPlayers(room: Room): { Player }
	local list = {}
	for player in room.Players do
		table.insert(list, player)
	end
	return list
end

local function isEmpty(room: Room): boolean
	return next(room.Players) == nil
end

local function updateDoor(room: Room)
	local count = #roomPlayers(room)
	local status = if room.Status == "Idle"
		then "Vrij · stap in de ring!"
		elseif room.Status == "Starting" then "Begint zo..."
		elseif room.Status == "Playing" then "Bezig · " .. formatTime(room.TimeLeft)
		else "Wordt opgeruimd..."
	room.Door.Info.Text = string.format("👥 %d   %s", count, status)
	room.State:SetAttribute("Players", count)
end

local function setState(room: Room, status: string, message: string)
	room.Status = status
	room.State:SetAttribute("RoundState", status)
	room.State:SetAttribute("Message", message)
	updateDoor(room)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	local root = getRoot(player)
	if character and root then
		root.Anchored = false
		character:PivotTo(cf + Vector3.new(math.random(-30, 30) / 10, 0, math.random(-20, 20) / 10))
	end
end

local function sendEmptyInventory(player: Player)
	Remotes.Inventory:FireClient(player, {}, player:GetAttribute("Capacity") or Config.BaseCapacity)
end

function RoomService.GetRoom(player: Player): Room?
	return playerRoom[player]
end

function RoomService.GetBooks(player: Player): BookService.BookService?
	local room = playerRoom[player]
	return if room then room.Books else nil
end

function RoomService.Leave(player: Player, toLobby: boolean)
	local room = playerRoom[player]
	if not room then
		return
	end
	HideService.Exit(player)
	room.Books:RemovePlayer(player)
	room.Players[player] = nil
	playerRoom[player] = nil
	player:SetAttribute("Room", nil)
	touchCooldown[player] = os.clock() + 3
	if toLobby then
		teleport(player, lobby.SpawnCFrame)
		sendEmptyInventory(player)
	end
	updateDoor(room)
end

local runRound

function RoomService.Join(player: Player, roomId: string)
	local room = rooms[roomId]
	if not room or playerRoom[player] or not getRoot(player) then
		return
	end
	if room.Status == "Won" or room.Status == "Lost" then
		notify(player, room.Info.Name .. " wordt net opgeruimd. Probeer het zo nog eens!", Color3.fromRGB(255, 200, 120))
		return
	end
	room.Players[player] = true
	playerRoom[player] = room
	player:SetAttribute("Room", room.Info.Id)
	DataService.SetRoundBooks(player, 0)
	room.Books:AddPlayer(player)
	teleport(player, room.Library.SpawnCFrame)
	notify(player, "Welkom in de " .. room.Info.Name .. "!", room.Info.Color)
	if not room.RoundRunning then
		task.spawn(runRound, room)
	end
	updateDoor(room)
end

local function playRound(room: Room)
	local info = room.Info
	room.Finished = false
	room.Books:Clear()

	local aborted = false
	for t = Config.StartCountdown, 1, -1 do
		if isEmpty(room) then
			aborted = true
			break
		end
		room.TimeLeft = t
		room.State:SetAttribute("TimeLeft", t)
		setState(room, "Starting", "De zaal gaat open over " .. t .. "...")
		task.wait(1)
	end

	local elapsed = 0
	if not aborted then
		room.Books:SpawnAll()
		setState(room, "Playing", "Ruim alle kasten op!")
		for _, player in roomPlayers(room) do
			notify(player, "Zet alle boeken terug in de juiste kast!", Color3.fromRGB(255, 220, 150))
		end
		local timeLeft = info.RoundTime
		local monsterSpawned = false
		while timeLeft > 0 and not room.Finished do
			if isEmpty(room) then
				aborted = true
				break
			end
			room.TimeLeft = timeLeft
			room.State:SetAttribute("TimeLeft", timeLeft)
			updateDoor(room)
			task.wait(1)
			timeLeft -= 1
			elapsed += 1
			local monster = room.Monster
			if monster then
				monster.Progress = room.Books.Placed / room.Books.Total
				if not monsterSpawned and elapsed >= Config.Monster.SpawnDelay then
					monsterSpawned = true
					monster.Spawn()
				end
			end
		end
		room.TimeLeft = math.max(timeLeft, 0)
		room.State:SetAttribute("TimeLeft", room.TimeLeft)
	end

	room.Books.Active = false
	if room.Monster then
		room.Monster.Despawn()
	end
	if aborted then
		return
	end

	if room.Finished then
		setState(room, "Won", "DE ZAAL IS SCHOON! Tijd: " .. formatTime(elapsed))
		local reward = math.floor(Config.CoinsForWin * info.CoinMultiplier)
		for _, player in roomPlayers(room) do
			DataService.AddCoins(player, reward)
			notify(player, "+" .. reward .. " munten!", Color3.fromRGB(255, 215, 0))
			local profile = DataService.Get(player)
			if profile then
				profile.Wins += 1
				if not profile.BestTime or elapsed < profile.BestTime then
					profile.BestTime = elapsed
				end
			end
		end
	else
		setState(room, "Lost", "De tijd is op... " .. room.Books.Placed .. "/" .. room.Books.Total .. " boeken")
	end
	task.wait(Config.EndScreenTime)
	for _, player in roomPlayers(room) do
		RoomService.Leave(player, true)
	end
end

function runRound(room: Room)
	room.RoundRunning = true
	local ok, err = pcall(playRound, room)
	if not ok then
		warn("[Room " .. room.Info.Id .. "] " .. tostring(err))
	end
	room.Books.Active = false
	if room.Monster then
		room.Monster.Despawn()
	end
	room.Books:Clear()
	room.RoundRunning = false
	setState(room, "Idle", "")
	-- Kwam er iemand binnen terwijl we aan het opruimen waren? Dan meteen opnieuw.
	if not isEmpty(room) then
		task.spawn(runRound, room)
	end
end

local function createRoom(info: Config.RoomInfo, library, door, stateFolder: Folder): Room
	local state = Instance.new("Folder")
	state.Name = info.Id
	state:SetAttribute("Name", info.Name)
	state:SetAttribute("Dark", info.Dark)
	state:SetAttribute("Total", Config.RoomTotalBooks(info))
	state.Parent = stateFolder

	local room: Room = {
		Info = info,
		Library = library,
		Books = BookService.new(info, library, state),
		Monster = nil,
		State = state,
		Door = door,
		Players = {},
		Status = "Idle",
		Finished = false,
		RoundRunning = false,
		TimeLeft = 0,
	}

	room.Books.OnAllPlaced = function()
		room.Finished = true
	end
	room.Books.OnBookPlaced = function(player, count)
		DataService.AddCoins(player, math.max(1, math.floor(count * Config.CoinsPerBook * info.CoinMultiplier + 0.5)))
		DataService.SetRoundBooks(player, DataService.GetRoundBooks(player) + count)
	end

	if info.Monster then
		local monster = MonsterService.new(info, library, function()
			return roomPlayers(room)
		end)
		monster.OnCatch = function(player)
			room.Books:Scatter(player)
		end
		monster.OnHiddenCatch = function(player)
			HideService.Exit(player)
		end
		room.Books.OnMistake = function(_player, position)
			monster.Noise(position, Config.Monster.HearMistakeRange)
		end
		room.Monster = monster
	end

	library.ExitPrompt.Triggered:Connect(function(player)
		if playerRoom[player] == room then
			RoomService.Leave(player, true)
		end
	end)

	door.Prompt.Triggered:Connect(function(player)
		RoomService.Join(player, info.Id)
	end)
	door.Zone.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not playerRoom[player] and os.clock() >= (touchCooldown[player] or 0) then
			touchCooldown[player] = os.clock() + 2
			RoomService.Join(player, info.Id)
		end
	end)

	setState(room, "Idle", "")
	return room
end

function RoomService.Init(lobbyData, libraries: { [string]: any })
	lobby = lobbyData
	local stateFolder = Instance.new("Folder")
	stateFolder.Name = "RoomState"
	stateFolder.Parent = ReplicatedStorage

	for _, info in Config.Rooms do
		rooms[info.Id] = createRoom(info, libraries[info.Id], lobby.Doors[info.Id], stateFolder)
	end

	Remotes.Action.OnServerEvent:Connect(function(player, action)
		local room = playerRoom[player]
		if action == "Drop" and room then
			room.Books:Drop(player)
		elseif action == "Leave" and room then
			RoomService.Leave(player, true)
		end
	end)

	local function onPlayer(player: Player)
		player:GetAttributeChangedSignal("Capacity"):Connect(function()
			local room = playerRoom[player]
			if room then
				room.Books:Changed(player)
			else
				sendEmptyInventory(player)
			end
		end)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			local root = character:WaitForChild("HumanoidRootPart") :: BasePart
			humanoid.Died:Connect(function()
				local room = playerRoom[player]
				if room then
					room.Books:Scatter(player)
				end
			end)
			-- Na doodgaan kom je terug in je zaal (zolang de ronde nog loopt)
			task.defer(function()
				local room = playerRoom[player]
				if room and (room.Status == "Playing" or room.Status == "Starting") then
					task.wait(0.2)
					teleport(player, room.Library.SpawnCFrame)
					room.Books:Changed(player)
				elseif room then
					RoomService.Leave(player, false)
				end
			end)
			-- Wie ergens doorheen valt, komt terug bij het begin
			task.spawn(function()
				while character.Parent do
					if root.Position.Y < -30 then
						local room = playerRoom[player]
						teleport(player, if room then room.Library.SpawnCFrame else lobby.SpawnCFrame)
					end
					task.wait(2)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		RoomService.Leave(player, false)
		touchCooldown[player] = nil
	end)
end

return RoomService
