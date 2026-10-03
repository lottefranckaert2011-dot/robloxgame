-- Boeken: verspreiden, oppakken, dragen, laten vallen en in de juiste kast zetten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type BookData = {
	Id: number,
	Code: string,
	Title: string,
	Color: Color3,
	Scale: number,
	Font: Enum.Font,
}

local BOOK_COLORS = {
	Color3.fromRGB(196, 52, 48),
	Color3.fromRGB(38, 88, 170),
	Color3.fromRGB(58, 128, 72),
	Color3.fromRGB(226, 170, 60),
	Color3.fromRGB(120, 66, 160),
	Color3.fromRGB(40, 40, 46),
	Color3.fromRGB(232, 120, 160),
	Color3.fromRGB(230, 112, 40),
	Color3.fromRGB(70, 170, 190),
	Color3.fromRGB(150, 90, 50),
	Color3.fromRGB(235, 225, 200),
}

local BOOK_FONTS = {
	Enum.Font.Garamond,
	Enum.Font.Fantasy,
	Enum.Font.Antique,
	Enum.Font.Bodoni,
	Enum.Font.Cartoon,
	Enum.Font.GothamBlack,
	Enum.Font.FredokaOne,
	Enum.Font.Merriweather,
}

local BASE_SIZE = Vector3.new(1.4, 0.35, 1.9)
local PAGES_COLOR = Color3.fromRGB(246, 236, 210)
local CLUSTERS = 45

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
local bookData: { [BasePart]: BookData } = {}
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

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sendInventory(player: Player)
	local list = {}
	local books: { BookData } = carried[player] or {}
	for _, book in books do
		table.insert(list, { Code = book.Code, Title = book.Title, Color = book.Color })
	end
	Remotes.Inventory:FireClient(player, list, getCapacity(player))
end

-- Maakt de onderdelen van een boek: kaft + bladzijden die aan drie kanten uitsteken.
local function buildBookParts(book: BookData, scale: number): BasePart
	local size = BASE_SIZE * scale
	local cover = Instance.new("Part")
	cover.Name = "Book"
	cover.Size = size
	cover.Color = book.Color
	cover.Material = Enum.Material.SmoothPlastic
	cover.TopSurface = Enum.SurfaceType.Smooth
	cover.BottomSurface = Enum.SurfaceType.Smooth
	cover.CanCollide = false
	cover.CanTouch = false

	local pages = Instance.new("Part")
	pages.Name = "Pages"
	pages.Size = Vector3.new(size.X - 0.1 * scale, size.Y * 0.7, size.Z + 0.04)
	pages.Color = PAGES_COLOR
	pages.Material = Enum.Material.SmoothPlastic
	pages.CanCollide = false
	pages.CanTouch = false
	pages.Massless = true
	pages.Anchored = false
	pages:SetAttribute("IsBook", true)
	local weld = Instance.new("Weld")
	weld.Part0 = cover
	weld.Part1 = pages
	weld.C0 = CFrame.new(0.05 * scale + 0.02, 0, 0)
	weld.Parent = pages
	pages.Parent = cover

	-- Voorkant: titel + code
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 70
	gui.Parent = cover
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0.08, 0)
	band.Position = UDim2.fromScale(0, 0.12)
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Color3.fromRGB(240, 210, 120)
	band.Parent = gui
	local band2 = band:Clone()
	band2.Position = UDim2.fromScale(0, 0.8)
	band2.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.9, 0.5)
	title.Position = UDim2.fromScale(0.05, 0.25)
	title.TextScaled = true
	title.TextWrapped = true
	title.Font = book.Font
	title.TextColor3 = if book.Color.R + book.Color.G + book.Color.B > 2 then Color3.fromRGB(60, 40, 30) else Color3.fromRGB(250, 238, 205)
	title.Text = book.Title
	title.Parent = gui

	-- Rug: de code, zoals op de echte boeken
	local spine = Instance.new("SurfaceGui")
	spine.Face = Enum.NormalId.Left
	spine.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	spine.PixelsPerStud = 80
	spine.Parent = cover
	local code = Instance.new("TextLabel")
	code.BackgroundTransparency = 1
	code.Size = UDim2.fromScale(1, 1)
	code.TextScaled = true
	code.Font = Enum.Font.GothamBlack
	code.TextColor3 = title.TextColor3
	code.Text = book.Code
	code.Parent = spine

	cover:SetAttribute("IsBook", true)
	return cover
end

-- Zet kaft én bladzijden op hun plek (ook buiten Workspace)
local function moveBook(cover: BasePart, cf: CFrame)
	cover.CFrame = cf
	local pages = cover:FindFirstChild("Pages") :: BasePart?
	local weld = pages and pages:FindFirstChildOfClass("Weld")
	if pages and weld then
		pages.CFrame = cf * weld.C0
	end
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
	local height = -0.5
	for i, book in books do
		local scale = math.min(book.Scale, 1.1)
		local p = buildBookParts(book, scale)
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		local pages = p:FindFirstChild("Pages") :: BasePart?
		if pages then
			pages.CanQuery = false
		end
		height += BASE_SIZE.Y * scale / 2
		moveBook(p, root.CFrame * CFrame.new(0, height, -1.4) * CFrame.Angles(0, math.rad((i * 37) % 24 - 12), 0))
		height += BASE_SIZE.Y * scale / 2 + 0.02
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

-- `surface` is de plek op de vloer/tafel; het boek gaat erbovenop liggen
local function makeLooseBook(book: BookData, surface: CFrame)
	local p = buildBookParts(book, book.Scale)
	local cf = surface * CFrame.new(0, p.Size.Y / 2, 0)
	-- Af en toe ligt een boek scheef tegen iets aan
	if math.random() < 0.18 then
		local tilt = math.rad(math.random(8, 22))
		cf = surface * CFrame.new(0, p.Size.Y / 2 + math.sin(tilt) * p.Size.X / 2, 0) * CFrame.Angles(0, 0, tilt)
	end
	moveBook(p, cf)
	p.Anchored = true
	p:SetAttribute("Id", book.Id)
	p:SetAttribute("Code", book.Code)
	p:SetAttribute("Title", book.Title)

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

	bookData[p] = book
	p.Destroying:Connect(function()
		bookData[p] = nil
	end)
	p.Parent = folder
	return p
end

function BookService.PickUp(player: Player, bookPart: BasePart, silent: boolean?): boolean
	if not BookService.Active or bookPart.Parent ~= folder or bookPart:GetAttribute("Flying") then
		return false
	end
	if player:GetAttribute("Hidden") then
		return false
	end
	local list = carried[player]
	local book = bookData[bookPart]
	if not list or not book then
		return false
	end
	if #list >= getCapacity(player) then
		if not silent then
			notify(player, "Je handen zijn vol! Zet eerst boeken terug.", Color3.fromRGB(255, 120, 80))
		end
		return false
	end
	table.insert(list, book)
	if player.Character and not silent then
		playSound(Config.SoundIds.Pickup, player.Character)
	end
	bookPart:Destroy()
	if not silent then
		changed(player)
	end
	return true
end

local function updateSign(section)
	local count = placedPerSection[section.Code] or 0
	local done = count >= Config.BooksPerSection
	for _, label in section.Counters do
		label.Text = if done
			then "✔ " .. section.Name
			else string.format("%s · %d/%d", section.Name, count, Config.BooksPerSection)
		label.TextColor3 = if done then Color3.fromRGB(150, 255, 160) else Color3.fromRGB(230, 220, 190)
	end
end

-- Zet één boek op de volgende lege plek in de kast
local function fillSlot(section, book: BookData)
	local count = (placedPerSection[section.Code] or 0) + 1
	local slot = section.Slots[count]
	if slot then
		slot.Transparency = 0
		slot.Material = Enum.Material.SmoothPlastic
		slot.Color = book.Color
	end
	placedPerSection[section.Code] = count
	BookService.Placed += 1
end

-- Na het terugzetten: teller, melding, beloning, en kijken of alles klaar is
local function afterPlaced(player: Player, section, placedNow: number, quiet: boolean?)
	Workspace:SetAttribute("Placed", BookService.Placed)
	updateSign(section)
	if BookService.OnBookPlaced then
		BookService.OnBookPlaced(player, placedNow)
	end
	if (placedPerSection[section.Code] or 0) >= Config.BooksPerSection then
		Remotes.Notify:FireAllClients(
			string.format("Sectie %s %s is compleet!", section.Code, section.Name),
			Color3.fromRGB(150, 255, 160)
		)
	elseif not quiet then
		notify(player, string.format("+%d boek%s in %s", placedNow, if placedNow == 1 then "" else "en", section.Name), Color3.fromRGB(120, 255, 140))
	end
	if BookService.Placed >= Config.TotalBooks() and BookService.OnAllPlaced then
		BookService.OnAllPlaced()
	end
end

-- Zet alle gedragen boeken met deze code in de kast. Geeft het aantal terug.
local function placeMatching(player: Player, code: string, quiet: boolean?): number
	local list = carried[player]
	local section = BookService.Library.Sections[code]
	if not list or not section then
		return 0
	end
	local placedNow = 0
	for i = #list, 1, -1 do
		if list[i].Code == code then
			fillSlot(section, list[i])
			table.remove(list, i)
			placedNow += 1
		end
	end
	if placedNow > 0 then
		afterPlaced(player, section, placedNow, quiet)
	end
	return placedNow
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
		notify(player, "Je draagt geen boeken.", Color3.fromRGB(220, 220, 220))
		return
	end

	local character = player.Character
	local placedNow = placeMatching(player, code)
	if placedNow == 0 then
		notify(player, string.format("Verkeerde kast! Dit is %s %s.", section.Code, section.Name), Color3.fromRGB(255, 90, 90))
		if character then
			playSound(Config.SoundIds.Wrong, character)
			local root = getRoot(player)
			if root and BookService.OnMistake then
				BookService.OnMistake(player, root.Position)
			end
		end
		return
	end
	if character then
		playSound(Config.SoundIds.Place, character)
	end
	changed(player)
end

-- Magie "Verzamelen": pak de dichtstbijzijnde boeken op
function BookService.Assemble(player: Player, radius: number): number
	local root = getRoot(player)
	local list = carried[player]
	if not BookService.Active or not root or not list then
		return 0
	end
	local nearby = {}
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and not p:GetAttribute("Flying") then
			local d = (p.Position - root.Position).Magnitude
			if d <= radius then
				table.insert(nearby, { part = p, distance = d })
			end
		end
	end
	table.sort(nearby, function(a, b)
		return a.distance < b.distance
	end)
	local got = 0
	for _, entry in nearby do
		if #list >= getCapacity(player) then
			break
		end
		if BookService.PickUp(player, entry.part, true) then
			got += 1
		end
	end
	if got > 0 then
		playSound(Config.SoundIds.Pickup, root)
		changed(player)
	end
	return got
end

-- Magie "Auto-plaatsen": alle gedragen boeken naar de goede kast
function BookService.AutoShelf(player: Player): number
	local list = carried[player]
	if not BookService.Active or not list or #list == 0 then
		return 0
	end
	local codes = {}
	for _, book in list do
		codes[book.Code] = true
	end
	local total = 0
	for code in codes do
		total += placeMatching(player, code, true)
	end
	if total > 0 then
		local root = getRoot(player)
		if root then
			playSound(Config.SoundIds.Place, root)
		end
		changed(player)
	end
	return total
end

-- De assistent laat een willekeurig boek naar de goede kast vliegen
function BookService.AssistantPlace(player: Player): boolean
	if not BookService.Active then
		return false
	end
	local candidates = {}
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and not p:GetAttribute("Flying") and bookData[p] then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return false
	end
	local p = candidates[math.random(1, #candidates)] :: BasePart
	local book = bookData[p]
	local section = BookService.Library.Sections[book.Code]
	if not section then
		return false
	end
	p:SetAttribute("Flying", true)
	local prompt = p:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 230, 140)
	sparkles.Parent = p

	local target = section.Target.Position
	local up = p.CFrame + Vector3.new(0, 6, 0)
	local tween1 = TweenService:Create(p, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up })
	tween1:Play()
	tween1.Completed:Wait()
	if not p.Parent then
		return false
	end
	local distance = (target - p.Position).Magnitude
	local tween2 = TweenService:Create(
		p,
		TweenInfo.new(math.clamp(distance / 40, 0.8, 3), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = CFrame.new(target) * CFrame.Angles(0, math.rad(180), 0) }
	)
	tween2:Play()
	tween2.Completed:Wait()
	if not p.Parent or not BookService.Active then
		return false
	end
	p:Destroy()
	fillSlot(section, book)
	afterPlaced(player, section, 1, true)
	return true
end

-- Zoek een plek op de grond vlak bij een positie
local function groundNear(position: Vector3): CFrame
	return BookService.Library:BookSpotNear(position, 3, folder) or BookService.Library:RandomBookSpot()
end

function BookService.Drop(player: Player)
	local list = carried[player]
	if not list or #list == 0 then
		return
	end
	local root = getRoot(player)
	for _, book in list do
		makeLooseBook(book, if root then groundNear(root.Position) else BookService.Library:RandomBookSpot())
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
			slot.Transparency = 0.75
			slot.Material = Enum.Material.Glass
			slot.Color = Color3.fromRGB(255, 245, 225)
		end
		updateSign(section)
	end
end

function BookService.SpawnAll()
	local library = BookService.Library
	-- Boeken liggen in rommelige stapels verspreid door de bibliotheek
	local clusters = {}
	for i = 1, CLUSTERS do
		clusters[i] = library:RandomBookSpot().Position
	end
	for _, section in Config.Sections do
		for i = 1, Config.BooksPerSection do
			nextId += 1
			local title = section.Titles[(i - 1) % #section.Titles + 1]
			if i > #section.Titles then
				title ..= " " .. (math.floor((i - 1) / #section.Titles) + 1)
			end
			local scale = if math.random() < 0.15 then math.random(130, 165) / 100 else math.random(85, 120) / 100
			local book: BookData = {
				Id = nextId,
				Code = section.Code,
				Title = title,
				Color = BOOK_COLORS[math.random(1, #BOOK_COLORS)],
				Scale = scale,
				Font = BOOK_FONTS[math.random(1, #BOOK_FONTS)],
			}
			local center = clusters[math.random(1, #clusters)]
			local spot = library:BookSpotNear(center, 7, folder) or library:RandomBookSpot()
			makeLooseBook(book, spot)
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
