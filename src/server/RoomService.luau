-- Zalen en samen spelen.
--
-- In de hal staat voor elke soort zaal een deur met een ring. Stap met je vrienden in de ring:
-- er begint een aftelling en wie bij nul in de ring staat, gaat samen naar binnen.
-- Elke groep krijgt een eigen kopie van de zaal (tot Config.MaxCopiesPerRoom per soort),
-- zodat meerdere groepen tegelijk kunnen spelen zonder elkaar in de weg te zitten.
--
-- Elke kopie heeft zijn eigen ronde: aftellen -> opruimen -> gewonnen/verloren -> terug naar de hal.
-- De status staat als attributen in ReplicatedStorage.RoomState.<KopieId>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LibraryBuilder = require(script.Parent.LibraryBuilder)
local BookService = require(script.Parent.BookService)
local MonsterService = require(script.Parent.MonsterService)
local DataService = require(script.Parent.DataService)
local HideService = require(script.Parent.HideService)
local KeyService = require(script.Parent.KeyService)

-- Eén kopie van een zaal
type Room = {
	Id: string, -- bijv. "Classic_2"
	Info: Config.RoomInfo,
	Library: any,
	Books: BookService.BookService,
	Monster: MonsterService.Monster?,
	State: Folder,
	Players: { [Player]: boolean },
	Contributions: { [Player]: number },
	Status: string, -- Idle | Starting | Playing | Won | Lost
	Finished: boolean,
	RoundRunning: boolean,
	TimeLeft: number,
}

-- Een soort zaal met zijn deur in de hal
type RoomType = {
	Info: Config.RoomInfo,
	Door: any,
	Copies: { Room },
	QueueEnds: number?, -- wanneer de aftelling van de ring klaar is
	Waiting: { Player }, -- wie er nu in de ring staat
}

local RoomService = {}

local types: { [string]: RoomType } = {}
local typeOrder: { RoomType } = {}
local playerRoom: { [Player]: Room } = {}
local lobby
local roomsFolder: Folder
local stateFolder: Folder

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

-- Tekst boven de deur: aftelling van de ring en hoeveel groepen er bezig zijn
local function updateDoor(roomType: RoomType)
	local busy, playing = 0, 0
	for _, room in roomType.Copies do
		if not isEmpty(room) then
			busy += 1
			playing += #roomPlayers(room)
		end
	end
	local queue = if roomType.QueueEnds
		then string.format("⏳ Start over %ds · %d/%d in de ring", math.max(0, math.ceil(roomType.QueueEnds - os.clock())), #roomType.Waiting, Config.MaxGroupSize)
		else "Stap samen in de ring!"
	local groups = if busy > 0 then string.format("   🎮 %d groep%s (%d spelers) bezig", busy, if busy == 1 then "" else "en", playing) else ""
	roomType.Door.Info.Text = queue .. groups
end

local function setState(room: Room, status: string, message: string)
	room.Status = status
	room.State:SetAttribute("RoundState", status)
	room.State:SetAttribute("Message", message)
	room.State:SetAttribute("Players", #roomPlayers(room))
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
	room.State:SetAttribute("Players", #roomPlayers(room))
	if toLobby then
		teleport(player, lobby.SpawnCFrame)
		sendEmptyInventory(player)
	end
end

local function join(player: Player, room: Room)
	if playerRoom[player] or not getRoot(player) then
		return
	end
	room.Players[player] = true
	room.Contributions[player] = room.Contributions[player] or 0
	playerRoom[player] = room
	player:SetAttribute("Room", room.Id)
	DataService.SetRoundBooks(player, 0)
	room.Books:AddPlayer(player)
	teleport(player, room.Library.SpawnCFrame)
	room.State:SetAttribute("Players", #roomPlayers(room))
end

-- Uitslag: wie zette de meeste boeken terug?
local function results(room: Room): string
	local list = {}
	for player, count in room.Contributions do
		if player.Parent then
			table.insert(list, { name = player.DisplayName, count = count })
		end
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	local parts = {}
	local medals = { "🥇", "🥈", "🥉" }
	for i, entry in list do
		if i > 5 then
			break
		end
		table.insert(parts, string.format("%s %s: %d", medals[i] or "•", entry.name, entry.count))
	end
	return table.concat(parts, "    ")
end

local function playRound(room: Room)
	local info = room.Info
	room.Finished = false
	table.clear(room.Contributions)
	for player in room.Players do
		room.Contributions[player] = 0
	end
	room.State:SetAttribute("Results", "")
	room.Books:Clear()

	local aborted = false
	for t = Config.StartCountdown, 1, -1 do
		if isEmpty(room) then
			aborted = true
			break
		end
		room.TimeLeft = t
		room.State:SetAttribute("TimeLeft", t)
		setState(room, "Starting", "Klaar voor de start... " .. t)
		task.wait(1)
	end

	local elapsed = 0
	if not aborted then
		room.Books:SpawnAll()
		setState(room, "Playing", "Ruim samen alle kasten op!")
		local count = #roomPlayers(room)
		for _, player in roomPlayers(room) do
			notify(
				player,
				if count > 1 then string.format("Jullie zijn met %d. Werk samen!", count) else "Zet alle boeken terug in de juiste kast!",
				Color3.fromRGB(255, 220, 150)
			)
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

	room.State:SetAttribute("Results", results(room))
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

local function runRound(room: Room)
	room.RoundRunning = true
	local ok, err = pcall(playRound, room)
	if not ok then
		warn("[Room " .. room.Id .. "] " .. tostring(err))
	end
	room.Books.Active = false
	if room.Monster then
		room.Monster.Despawn()
	end
	-- Wie er na een fout nog in zit, gaat terug naar de hal
	for _, player in roomPlayers(room) do
		RoomService.Leave(player, true)
	end
	room.Books:Clear()
	room.RoundRunning = false
	setState(room, "Idle", "")
end

local function createCopy(roomType: RoomType): Room
	local info = roomType.Info
	local index = #roomType.Copies + 1
	local id = info.Id .. "_" .. index
	local offset = info.Offset + Config.CopySpacing * (index - 1)
	local library = LibraryBuilder.Build(info, roomsFolder, offset, id)
	KeyService.AddLibrary(library)
	HideService.AddLibrary(library)

	local state = Instance.new("Folder")
	state.Name = id
	state:SetAttribute("Name", info.Name)
	state:SetAttribute("Dark", info.Dark)
	state:SetAttribute("Total", Config.RoomTotalBooks(info))
	state.Parent = stateFolder

	local room: Room = {
		Id = id,
		Info = info,
		Library = library,
		Books = BookService.new(info, library, state),
		Monster = nil,
		State = state,
		Players = {},
		Contributions = {},
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
		room.Contributions[player] = (room.Contributions[player] or 0) + count
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

	setState(room, "Idle", "")
	table.insert(roomType.Copies, room)
	return room
end

-- Een vrije kopie van deze zaal, of een nieuwe als het maximum nog niet bereikt is
local function freeCopy(roomType: RoomType): Room?
	for _, room in roomType.Copies do
		if not room.RoundRunning and isEmpty(room) then
			return room
		end
	end
	if #roomType.Copies < Config.MaxCopiesPerRoom then
		return createCopy(roomType)
	end
	return nil
end

-- Staat er een vriend van een van deze spelers al in een kopie met plek? Dan gaan ze daarheen.
local function copyWithFriend(roomType: RoomType, group: { Player }): Room?
	for _, room in roomType.Copies do
		local space = Config.MaxGroupSize - #roomPlayers(room)
		if (room.Status == "Starting" or room.Status == "Playing") and space >= #group then
			for other in room.Players do
				for _, player in group do
					local ok, friends = pcall(player.IsFriendsWith, player, other.UserId)
					if ok and friends then
						return room
					end
				end
			end
		end
	end
	return nil
end

local function inZone(player: Player, zone: BasePart): boolean
	local root = getRoot(player)
	if not root then
		return false
	end
	local offset = root.Position - zone.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= zone.Size.X / 2 + 1 and math.abs(offset.Y) < zone.Size.Y
end

-- Stuurt een groep spelers samen naar binnen. Geeft false terug als alles bezet is.
local function sendGroup(roomType: RoomType, group: { Player }): boolean
	if #group == 0 then
		return true
	end
	local room = copyWithFriend(roomType, group) or freeCopy(roomType)
	if not room then
		for _, player in group do
			notify(player, "Alle " .. roomType.Info.Name .. "s zijn bezet. Nog even wachten...", Color3.fromRGB(255, 200, 120))
		end
		return false
	end
	for _, player in group do
		join(player, room)
	end
	local names = {}
	for _, player in group do
		table.insert(names, player.DisplayName)
	end
	for _, player in group do
		notify(player, "Welkom in de " .. roomType.Info.Name .. "! " .. (if #group > 1 then "Team: " .. table.concat(names, ", ") else ""), roomType.Info.Color)
	end
	if not room.RoundRunning then
		task.spawn(runRound, room)
	end
	return true
end

-- Iedereen die bij nul in de ring staat, gaat samen naar binnen
local function launch(roomType: RoomType): boolean
	local group = {}
	for _, player in roomType.Waiting do
		if #group < Config.MaxGroupSize then
			table.insert(group, player)
		end
	end
	return sendGroup(roomType, group)
end

-- Gekozen in het menu: meteen naar binnen (bij een vriend als die al speelt)
function RoomService.PlayNow(player: Player, typeId: string)
	local roomType = types[typeId]
	if not roomType or playerRoom[player] then
		return
	end
	sendGroup(roomType, { player })
end

local function queueLoop()
	while true do
		task.wait(0.25)
		for _, roomType in typeOrder do
			local waiting = {}
			for _, player in Players:GetPlayers() do
				if not playerRoom[player] and inZone(player, roomType.Door.Zone) then
					table.insert(waiting, player)
				end
			end
			roomType.Waiting = waiting
			if #waiting == 0 then
				roomType.QueueEnds = nil
			elseif not roomType.QueueEnds then
				roomType.QueueEnds = os.clock() + Config.QueueTime
				for _, player in waiting do
					notify(player, "Wacht even op je vrienden... iedereen in de ring gaat samen naar binnen!", roomType.Info.Color)
				end
			elseif os.clock() >= roomType.QueueEnds then
				if launch(roomType) then
					roomType.QueueEnds = nil
				else
					roomType.QueueEnds = os.clock() + 3
				end
			end
			updateDoor(roomType)
		end
	end
end

function RoomService.Init(lobbyData)
	lobby = lobbyData
	roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "Rooms"
	roomsFolder.Parent = Workspace
	stateFolder = Instance.new("Folder")
	stateFolder.Name = "RoomState"
	stateFolder.Parent = ReplicatedStorage

	for _, info in Config.Rooms do
		local door = lobby.Doors[info.Id]
		local roomType: RoomType = {
			Info = info,
			Door = door,
			Copies = {},
			QueueEnds = nil,
			Waiting = {},
		}
		types[info.Id] = roomType
		table.insert(typeOrder, roomType)
		-- Eén kopie staat al klaar; extra kopieën worden gebouwd als ze nodig zijn
		createCopy(roomType)
		-- Op E drukken bij de deur zet je in de ring
		door.Prompt.Triggered:Connect(function(player)
			if not playerRoom[player] then
				teleport(player, CFrame.new(door.Zone.Position))
			end
		end)
	end
	task.spawn(queueLoop)

	Remotes.Action.OnServerEvent:Connect(function(player, action)
		local room = playerRoom[player]
		if action == "Drop" and room then
			room.Books:Drop(player)
		elseif action == "Leave" and room then
			RoomService.Leave(player, true)
		end
	end)
	Remotes.Action.OnServerEvent:Connect(function(player, action, typeId)
		if action == "PlayRoom" and type(typeId) == "string" then
			RoomService.PlayNow(player, typeId)
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
	end)
end

return RoomService
