-- Boeken: verspreiden, oppakken, dragen, laten vallen en in de juiste kast zetten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type BookData = {
	Id: number,
	Code: string,
	Title: string,
	Color: Color3,
}

local BOOK_COLORS = {
	Color3.fromRGB(120, 30, 30),
	Color3.fromRGB(30, 60, 120),
	Color3.fromRGB(40, 90, 50),
	Color3.fromRGB(110, 80, 30),
	Color3.fromRGB(80, 40, 100),
	Color3.fromRGB(30, 30, 30),
	Color3.fromRGB(140, 110, 80),
	Color3.fromRGB(150, 60, 20),
}

local BookService = {}
BookService.Library = nil :: any
BookService.Placed = 0
BookService.Active = false -- alleen tijdens een ronde kun je boeken pakken
-- Wordt door andere services ingevuld
BookService.OnAllPlaced = nil :: (() -> ())?
BookService.OnMistake = nil :: ((player: Player, position: Vector3) -> ())?
BookService.OnBookPlaced = nil :: ((player: Player, count: number) -> ())?

local folder: Folder
local carried: { [Player]: { BookData } } = {}
local placedPerSection: { [string]: number } = {}
local nextId = 0

local function playSound(id: string, parent: Instance)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 60
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

local function getCapacity(player: Player): number
	local capacity = player:GetAttribute("Capacity")
	return if type(capacity) == "number" then capacity else Config.BaseCapacity
end

local function sendInventory(player: Player)
	local list = {}
	local books: { BookData } = carried[player] or {}
	for _, book in books do
		table.insert(list, { Code = book.Code, Title = book.Title, Color = book.Color })
	end
	Remotes.Inventory:FireClient(player, list, getCapacity(player))
end

-- Stapel boeken die je zichtbaar voor je uit draagt
local function updateCarryVisual(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local old = character:FindFirstChild("CarriedBooks")
	if old then
		old:Destroy()
	end
	if not root then
		return
	end
	local books = carried[player] or {}
	if #books == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CarriedBooks"
	for i, book in books do
		local p = Instance.new("Part")
		p.Size = Vector3.new(1.4, 0.35, 1.9)
		p.Color = book.Color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = root.CFrame * CFrame.new(0, -0.4 + (i - 1) * 0.37, -1.3) * CFrame.Angles(0, math.rad((i * 37) % 20 - 10), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
	end
	model.Parent = character
end

local function changed(player: Player)
	updateCarryVisual(player)
	sendInventory(player)
end

local function makeLooseBook(book: BookData, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = "Book"
	p.Size = Vector3.new(1.4, 0.35, 1.9)
	p.CFrame = cf
	p.Color = book.Color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p:SetAttribute("Id", book.Id)
	p:SetAttribute("Code", book.Code)
	p:SetAttribute("Title", book.Title)

	-- Code op de kaft
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = book.Code
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(235, 220, 170)
	label.Rotation = 90
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Oppakken"
	prompt.ObjectText = string.format("[%s] %s", book.Code, book.Title)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	prompt.Triggered:Connect(function(player)
		BookService.PickUp(player, p)
	end)

	p.Parent = folder
	return p
end

function BookService.PickUp(player: Player, bookPart: BasePart)
	if not BookService.Active or bookPart.Parent ~= folder then
		return
	end
	if player:GetAttribute("Hidden") then
		return
	end
	local list = carried[player]
	if not list then
		return
	end
	if #list >= getCapacity(player) then
		notify(player, "Je handen zijn vol! Zet eerst boeken terug.", Color3.fromRGB(255, 120, 80))
		return
	end
	table.insert(list, {
		Id = bookPart:GetAttribute("Id"),
		Code = bookPart:GetAttribute("Code"),
		Title = bookPart:GetAttribute("Title"),
		Color = bookPart.Color,
	})
	if player.Character then
		playSound(Config.SoundIds.Pickup, player.Character)
	end
	bookPart:Destroy()
	changed(player)
end

local function updateSign(section)
	local count = placedPerSection[section.Code] or 0
	local text = string.format("%d / %d", count, Config.BooksPerSection)
	local done = count >= Config.BooksPerSection
	for _, label in { section.Counter, section.CounterBack } do
		label.Text = if done then "✔ COMPLEET" else text
		label.TextColor3 = if done then Color3.fromRGB(90, 255, 120) else Color3.new(1, 1, 1)
	end
end

function BookService.Place(player: Player, code: string)
	if not BookService.Active then
		return
	end
	local list = carried[player]
	local section = BookService.Library.Sections[code]
	if not list or not section then
		return
	end
	if #list == 0 then
		notify(player, "Je draagt geen boeken.", Color3.fromRGB(200, 200, 200))
		return
	end

	local placedNow = 0
	for i = #list, 1, -1 do
		local book = list[i]
		if book.Code == code then
			local count = (placedPerSection[code] or 0) + 1
			local slot = section.Slots[count]
			if slot then
				slot.Transparency = 0
				slot.Material = Enum.Material.SmoothPlastic
				slot.Color = book.Color
			end
			placedPerSection[code] = count
			placedNow += 1
			table.remove(list, i)
		end
	end

	local character = player.Character
	if placedNow == 0 then
		notify(player, string.format("Verkeerde kast! Dit is %s %s. SSShhh...", section.Code, section.Name), Color3.fromRGB(255, 70, 70))
		if character then
			playSound(Config.SoundIds.Wrong, character)
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and BookService.OnMistake then
				BookService.OnMistake(player, root.Position)
			end
		end
		return
	end

	BookService.Placed += placedNow
	Workspace:SetAttribute("Placed", BookService.Placed)
	if character then
		playSound(Config.SoundIds.Place, character)
	end
	updateSign(section)
	changed(player)
	if BookService.OnBookPlaced then
		BookService.OnBookPlaced(player, placedNow)
	end

	if (placedPerSection[code] or 0) >= Config.BooksPerSection then
		Remotes.Notify:FireAllClients(
			string.format("Sectie %s %s is compleet!", section.Code, section.Name),
			section.Color
		)
	else
		notify(player, string.format("+%d boek%s in %s", placedNow, if placedNow == 1 then "" else "en", section.Name), Color3.fromRGB(120, 255, 140))
	end

	if BookService.Placed >= Config.TotalBooks() and BookService.OnAllPlaced then
		BookService.OnAllPlaced()
	end
end

-- Zoek een plek op de grond vlak bij een positie
local function groundNear(position: Vector3): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { BookService.Library.Model }
	local offset = Vector3.new(math.random(-20, 20) / 10, 2, math.random(-20, 20) / 10)
	local result = Workspace:Raycast(position + offset, Vector3.new(0, -12, 0), params)
	if result then
		return CFrame.new(result.Position + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	end
	return BookService.Library:RandomBookSpot()
end

function BookService.Drop(player: Player)
	local list = carried[player]
	if not list or #list == 0 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, book in list do
		if root then
			makeLooseBook(book, groundNear(root.Position))
		else
			makeLooseBook(book, BookService.Library:RandomBookSpot())
		end
	end
	table.clear(list)
	changed(player)
end

-- Als het monster je pakt, vliegen je boeken terug door de hele bibliotheek
function BookService.Scatter(player: Player)
	local list = carried[player]
	if not list or #list == 0 then
		return
	end
	if BookService.Active then
		for _, book in list do
			makeLooseBook(book, BookService.Library:RandomBookSpot())
		end
	end
	table.clear(list)
	changed(player)
end

function BookService.Clear()
	BookService.Active = false
	folder:ClearAllChildren()
	for player, list in carried do
		table.clear(list)
		changed(player)
	end
	table.clear(placedPerSection)
	BookService.Placed = 0
	Workspace:SetAttribute("Placed", 0)
	Workspace:SetAttribute("Total", Config.TotalBooks())
	for _, section in BookService.Library.Sections do
		for _, slot in section.Slots do
			slot.Transparency = 0.6
			slot.Material = Enum.Material.ForceField
			slot.Color = section.Color
		end
		updateSign(section)
	end
end

function BookService.SpawnAll()
	for _, section in Config.Sections do
		for i = 1, Config.BooksPerSection do
			nextId += 1
			local title = section.Titles[(i - 1) % #section.Titles + 1]
			if i > #section.Titles then
				title ..= " (deel " .. (math.floor((i - 1) / #section.Titles) + 1) .. ")"
			end
			makeLooseBook({
				Id = nextId,
				Code = section.Code,
				Title = title,
				Color = BOOK_COLORS[math.random(1, #BOOK_COLORS)],
			}, BookService.Library:RandomBookSpot())
		end
	end
	BookService.Active = true
end

function BookService.Init(library)
	BookService.Library = library
	folder = Instance.new("Folder")
	folder.Name = "Books"
	folder.Parent = Workspace

	for code, section in library.Sections do
		for _, prompt in section.Prompts do
			prompt.Triggered:Connect(function(player)
				BookService.Place(player, code)
			end)
		end
	end

	local function onPlayer(player: Player)
		carried[player] = {}
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				BookService.Scatter(player)
			end)
			task.defer(changed, player)
		end)
		player:GetAttributeChangedSignal("Capacity"):Connect(function()
			sendInventory(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		BookService.Scatter(player)
		carried[player] = nil
	end)

	Remotes.Action.OnServerEvent:Connect(function(player, action)
		if action == "Drop" then
			BookService.Drop(player)
		end
	end)

	BookService.Clear()
end

return BookService
