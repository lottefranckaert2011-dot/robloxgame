-- Boeken in één zaal: verspreiden, oppakken, dragen, laten vallen en in de juiste kast zetten.
-- Elke zaal krijgt zijn eigen BookService (BookService.new).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

	-- Voorkant: titel tussen twee gouden banden
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
local function updateCarryVisual(player: Player, books: { BookData })
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local old = character:FindFirstChild("CarriedBooks")
	if old then
		old:Destroy()
	end
	if not root or #books == 0 then
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

local BookService = {}
BookService.__index = BookService

export type BookService = typeof(setmetatable(
	{} :: {
		Room: Config.RoomInfo,
		Library: any,
		State: Instance,
		Folder: Folder,
		Total: number,
		Placed: number,
		Active: boolean,
		Carried: { [Player]: { BookData } },
		PlacedPerSection: { [string]: number },
		BookData: { [BasePart]: BookData },
		OnAllPlaced: (() -> ())?,
		OnMistake: ((player: Player, position: Vector3) -> ())?,
		OnBookPlaced: ((player: Player, count: number) -> ())?,
	},
	BookService
))

function BookService.new(room: Config.RoomInfo, library, state: Instance): BookService
	local self = setmetatable({
		Room = room,
		Library = library,
		State = state,
		Folder = library.Books,
		Total = Config.RoomTotalBooks(room),
		Placed = 0,
		Active = false, -- alleen tijdens een ronde kun je boeken pakken
		Carried = {},
		PlacedPerSection = {},
		BookData = {},
		OnAllPlaced = nil,
		OnMistake = nil,
		OnBookPlaced = nil,
	}, BookService)

	for code, section in library.Sections do
		for _, prompt in section.Prompts do
			prompt.Triggered:Connect(function(player)
				self:Place(player, code)
			end)
		end
	end
	self:Clear()
	return self
end

function BookService.AddPlayer(self: BookService, player: Player)
	self.Carried[player] = self.Carried[player] or {}
	self:Changed(player)
end

function BookService.RemovePlayer(self: BookService, player: Player)
	self:Scatter(player)
	self.Carried[player] = nil
	updateCarryVisual(player, {})
end

function BookService.Changed(self: BookService, player: Player)
	local books = self.Carried[player] or {}
	updateCarryVisual(player, books)
	local list = {}
	for _, book in books do
		table.insert(list, { Code = book.Code, Title = book.Title, Color = book.Color })
	end
	Remotes.Inventory:FireClient(player, list, getCapacity(player))
end

-- `surface` is de plek op de vloer/tafel; het boek gaat erbovenop liggen
function BookService.MakeLooseBook(self: BookService, book: BookData, surface: CFrame)
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
		self:PickUp(player, p)
	end)

	self.BookData[p] = book
	p.Destroying:Connect(function()
		self.BookData[p] = nil
	end)
	p.Parent = self.Folder
	return p
end

function BookService.PickUp(self: BookService, player: Player, bookPart: BasePart, silent: boolean?): boolean
	if not self.Active or bookPart.Parent ~= self.Folder or bookPart:GetAttribute("Flying") then
		return false
	end
	if player:GetAttribute("Hidden") then
		return false
	end
	local list = self.Carried[player]
	local book = self.BookData[bookPart]
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
		self:Changed(player)
	end
	return true
end

function BookService.UpdateSign(self: BookService, section)
	local count = self.PlacedPerSection[section.Code] or 0
	local perSection = self.Room.BooksPerSection
	local done = count >= perSection
	for _, label in section.Counters do
		label.Text = if done then "✔ " .. section.Name else string.format("%s · %d/%d", section.Name, count, perSection)
		label.TextColor3 = if done then Color3.fromRGB(150, 255, 160) else Color3.fromRGB(230, 220, 190)
	end
end

-- Zet één boek op de volgende lege plek in de kast
function BookService.FillSlot(self: BookService, section, book: BookData)
	local count = (self.PlacedPerSection[section.Code] or 0) + 1
	local slot = section.Slots[count]
	if slot then
		slot.Transparency = 0
		slot.Material = Enum.Material.SmoothPlastic
		slot.Color = book.Color
	end
	self.PlacedPerSection[section.Code] = count
	self.Placed += 1
end

-- Na het terugzetten: teller, melding, beloning, en kijken of alles klaar is
function BookService.AfterPlaced(self: BookService, player: Player, section, placedNow: number, quiet: boolean?)
	self.State:SetAttribute("Placed", self.Placed)
	self:UpdateSign(section)
	if self.OnBookPlaced then
		self.OnBookPlaced(player, placedNow)
	end
	if (self.PlacedPerSection[section.Code] or 0) >= self.Room.BooksPerSection then
		for other in self.Carried do
			notify(other, string.format("Sectie %s %s is compleet!", section.Code, section.Name), Color3.fromRGB(150, 255, 160))
		end
	elseif not quiet then
		notify(player, string.format("+%d boek%s in %s", placedNow, if placedNow == 1 then "" else "en", section.Name), Color3.fromRGB(120, 255, 140))
	end
	if self.Placed >= self.Total and self.OnAllPlaced then
		self.OnAllPlaced()
	end
end

-- Zet alle gedragen boeken met deze code in de kast. Geeft het aantal terug.
function BookService.PlaceMatching(self: BookService, player: Player, code: string, quiet: boolean?): number
	local list = self.Carried[player]
	local section = self.Library.Sections[code]
	if not list or not section then
		return 0
	end
	local placedNow = 0
	for i = #list, 1, -1 do
		if list[i].Code == code then
			self:FillSlot(section, list[i])
			table.remove(list, i)
			placedNow += 1
		end
	end
	if placedNow > 0 then
		self:AfterPlaced(player, section, placedNow, quiet)
	end
	return placedNow
end

function BookService.Place(self: BookService, player: Player, code: string)
	if not self.Active then
		return
	end
	local list = self.Carried[player]
	local section = self.Library.Sections[code]
	if not list or not section then
		return
	end
	if #list == 0 then
		notify(player, "Je draagt geen boeken.", Color3.fromRGB(220, 220, 220))
		return
	end

	local character = player.Character
	local placedNow = self:PlaceMatching(player, code)
	if placedNow == 0 then
		notify(player, string.format("Verkeerde kast! Dit is %s %s.", section.Code, section.Name), Color3.fromRGB(255, 90, 90))
		if character then
			playSound(Config.SoundIds.Wrong, character)
			local root = getRoot(player)
			if root and self.OnMistake then
				self.OnMistake(player, root.Position)
			end
		end
		return
	end
	if character then
		playSound(Config.SoundIds.Place, character)
	end
	self:Changed(player)
end

-- Magie "Verzamelen": pak de dichtstbijzijnde boeken op
function BookService.Assemble(self: BookService, player: Player, radius: number): number
	local root = getRoot(player)
	local list = self.Carried[player]
	if not self.Active or not root or not list then
		return 0
	end
	local nearby = {}
	for _, p in self.Folder:GetChildren() do
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
		if self:PickUp(player, entry.part, true) then
			got += 1
		end
	end
	if got > 0 then
		playSound(Config.SoundIds.Pickup, root)
		self:Changed(player)
	end
	return got
end

-- Magie "Auto-plaatsen": alle gedragen boeken naar de goede kast
function BookService.AutoShelf(self: BookService, player: Player): number
	local list = self.Carried[player]
	if not self.Active or not list or #list == 0 then
		return 0
	end
	local codes = {}
	for _, book in list do
		codes[book.Code] = true
	end
	local total = 0
	for code in codes do
		total += self:PlaceMatching(player, code, true)
	end
	if total > 0 then
		local root = getRoot(player)
		if root then
			playSound(Config.SoundIds.Place, root)
		end
		self:Changed(player)
	end
	return total
end

-- De assistent laat een willekeurig boek naar de goede kast vliegen
function BookService.AssistantPlace(self: BookService, player: Player): boolean
	if not self.Active then
		return false
	end
	local candidates = {}
	for _, p in self.Folder:GetChildren() do
		if p:IsA("BasePart") and not p:GetAttribute("Flying") and self.BookData[p] then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return false
	end
	local p = candidates[math.random(1, #candidates)] :: BasePart
	local book = self.BookData[p]
	local section = self.Library.Sections[book.Code]
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
	if not p.Parent or not self.Active then
		return false
	end
	p:Destroy()
	self:FillSlot(section, book)
	self:AfterPlaced(player, section, 1, true)
	return true
end

function BookService.Drop(self: BookService, player: Player)
	local list = self.Carried[player]
	if not list or #list == 0 then
		return
	end
	local root = getRoot(player)
	for _, book in list do
		local spot = root and self.Library:BookSpotNear(root.Position, 3, self.Folder)
		self:MakeLooseBook(book, spot or self.Library:RandomBookSpot())
	end
	table.clear(list)
	self:Changed(player)
end

-- Als het monster je pakt, vliegen je boeken terug door de hele zaal
function BookService.Scatter(self: BookService, player: Player)
	local list = self.Carried[player]
	if not list or #list == 0 then
		return
	end
	if self.Active then
		for _, book in list do
			self:MakeLooseBook(book, self.Library:RandomBookSpot())
		end
	end
	table.clear(list)
	self:Changed(player)
end

function BookService.Clear(self: BookService)
	self.Active = false
	self.Folder:ClearAllChildren()
	for player, list in self.Carried do
		table.clear(list)
		self:Changed(player)
	end
	table.clear(self.PlacedPerSection)
	self.Placed = 0
	self.State:SetAttribute("Placed", 0)
	self.State:SetAttribute("Total", self.Total)
	for _, section in self.Library.Sections do
		for _, slot in section.Slots do
			slot.Transparency = 0.75
			slot.Material = Enum.Material.Glass
			slot.Color = Color3.fromRGB(255, 245, 225)
		end
		self:UpdateSign(section)
	end
end

function BookService.SpawnAll(self: BookService)
	local library = self.Library
	-- Boeken liggen in rommelige stapels verspreid door de zaal
	local clusters = {}
	local clusterCount = math.max(12, math.floor(self.Total / 5.5))
	for i = 1, clusterCount do
		clusters[i] = library:RandomBookSpot().Position
	end
	for _, entry in Config.RoomSections(self.Room) do
		local section = entry.Section
		for i = 1, self.Room.BooksPerSection do
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
			local spot = library:BookSpotNear(center, 7, self.Folder) or library:RandomBookSpot()
			self:MakeLooseBook(book, spot)
		end
	end
	self.Active = true
end

return BookService
