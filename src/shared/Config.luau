--!strict
-- Gedeelde instellingen voor The Library Never Sleeps.
-- Pas hier getallen aan om het spel makkelijker of moeilijker te maken.

export type Section = {
	Code: string,
	Name: string,
	Floor: number,
	Titles: { string },
}

export type RoomInfo = {
	Id: string,
	Name: string,
	Description: string,
	Color: Color3,
	Floors: number, -- 1 of 2 verdiepingen
	MaxSections: number, -- hoeveel kastsecties (van 1A af)
	BooksPerSection: number,
	RoundTime: number,
	Monster: boolean,
	MonsterSpeed: number, -- vermenigvuldiger voor de snelheid van het monster
	Dark: boolean, -- donkere nachtmerrie-sfeer
	CoinMultiplier: number,
	Offset: Vector3, -- waar de zaal in de wereld staat
}

export type KeyInfo = {
	Id: string,
	Name: string,
	Color: Color3,
	Description: string,
}

local Config = {}

Config.GameName = "The Library Never Sleeps"

-- Ronde (per zaal staan de tijd en het aantal boeken bij Config.Rooms)
Config.StartCountdown = 5 -- seconden tussen binnenkomen en de start
Config.QueueTime = 10 -- zo lang telt de ring af voordat de groep naar binnen gaat
Config.MaxGroupSize = 8 -- zoveel spelers kunnen samen in één zaal
Config.MaxCopiesPerRoom = 4 -- zoveel groepen kunnen tegelijk dezelfde soort zaal spelen

-- Boekenseries: in elke kast hoort een serie (deel 1, 2, 3) die in de goede volgorde terug moet
Config.SeriesLength = 3

-- Pro Mode (Ascend): win een zaal en speel hem opnieuw op een hoger niveau
Config.Pro = {
	MaxLevel = 5,
	TimePerLevel = 0.12, -- elk niveau 12% minder tijd
	MinTimeFactor = 0.4,
	MonsterSpeedPerLevel = 0.08, -- elk niveau 8% sneller monster (ook in de Starterzaal komt er een)
	CoinBonusPerLevel = 0.5, -- elk niveau +50% munten
}
Config.CopySpacing = Vector3.new(0, 0, 400) -- afstand tussen kopieën van een zaal
Config.EndScreenTime = 8 -- daarna ga je terug naar de hal
Config.RespawnTime = 4

-- Speler
Config.BaseCapacity = 3 -- hoeveel boeken je tegelijk kan dragen
Config.WalkSpeed = 16
Config.SprintSpeed = 22
Config.EmeraldSprintSpeed = 28
Config.BaseJumpHeight = 7.2
Config.CrimsonJumpHeight = 14
Config.MaxStamina = 100
Config.StaminaDrain = 22 -- per seconde tijdens sprinten
Config.StaminaRegen = 14 -- per seconde

-- Beloningen
Config.CoinsPerBook = 2
Config.CoinsForWin = 150

-- Het monster: "The Librarian"
Config.Monster = {
	Name = "The Librarian",
	WanderSpeed = 11,
	ChaseSpeedStart = 17,
	ChaseSpeedEnd = 21, -- sneller naarmate er meer boeken terug staan
	SightRange = 55,
	FieldOfView = 130, -- graden
	CloseDetectRange = 12, -- zo dichtbij voelt ze je altijd
	HearSprintRange = 45,
	HearMistakeRange = 90, -- een boek in de verkeerde kast zetten maakt lawaai
	CatchDistance = 4.5,
	LoseTargetTime = 5,
	SpawnDelay = 20, -- seconden na de start voor ze verschijnt
}

export type MagicInfo = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Cost: number,
	Cooldown: number,
	Key: Enum.KeyCode,
}

-- Magie: vier vaardigheden (toetsen 1-4) die je koopt met munten
Config.Magic = {
	{
		Id = "Insight",
		Name = "Insight",
		Icon = "👁",
		Description = "Makes all nearby books light up",
		Cost = 20,
		Cooldown = 25,
		Key = Enum.KeyCode.One,
	},
	{
		Id = "ShelfGuide",
		Name = "Shelf Guide",
		Icon = "🧭",
		Description = "A beam of light points to your book's shelf",
		Cost = 40,
		Cooldown = 15,
		Key = Enum.KeyCode.Two,
	},
	{
		Id = "Assemble",
		Name = "Gather",
		Icon = "🧲",
		Description = "Pulls the nearest books towards you",
		Cost = 120,
		Cooldown = 30,
		Key = Enum.KeyCode.Three,
	},
	{
		Id = "AutoShelf",
		Name = "Auto-Shelve",
		Icon = "✨",
		Description = "All your books fly to the right shelf by themselves",
		Cost = 250,
		Cooldown = 60,
		Key = Enum.KeyCode.Four,
	},
} :: { MagicInfo }

Config.InsightDuration = 8
Config.InsightRadius = 70
Config.ShelfGuideDuration = 12
Config.AssembleRadius = 35

export type ShopItem = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
}

-- Winkel: upgrades die je blijft houden
Config.Shop = {
	{
		Id = "Capacity",
		Name = "Bigger Bag",
		Icon = "🎒",
		Description = "Carry +1 book",
		BaseCost = 40,
		CostGrowth = 1.6,
		MaxLevel = 6,
	},
	{
		Id = "Speed",
		Name = "Fast Shoes",
		Icon = "👟",
		Description = "+1.5 walk speed",
		BaseCost = 50,
		CostGrowth = 1.7,
		MaxLevel = 5,
	},
} :: { ShopItem }
Config.SpeedPerLevel = 1.5

-- Assistent: een magische uil die zelf boeken terugzet
Config.Assistant = {
	Name = "Hoot the Owl",
	Levels = {
		{ Cost = 150, Interval = 20 },
		{ Cost = 400, Interval = 13 },
		{ Cost = 900, Interval = 8 },
	},
}

-- Menu-toetsen (zoals in het origineel)
Config.MenuKeys = {
	Shop = Enum.KeyCode.F,
	Magic = Enum.KeyCode.C,
	Assistant = Enum.KeyCode.M,
	Settings = Enum.KeyCode.Z,
}

function Config.ShopCost(item: ShopItem, level: number): number
	return math.floor(item.BaseCost * item.CostGrowth ^ level)
end

function Config.FindMagic(id: string): MagicInfo?
	for _, info in Config.Magic do
		if info.Id == id then
			return info
		end
	end
	return nil
end

function Config.FindShopItem(id: string): ShopItem?
	for _, item in Config.Shop do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- De 4 verborgen sleutels die permanente upgrades geven
Config.Keys = {
	{
		Id = "Crimson",
		Name = "Crimson Octagon",
		Color = Color3.fromRGB(200, 30, 45),
		Description = "You jump much higher",
	},
	{
		Id = "Golden",
		Name = "Golden Diamond",
		Color = Color3.fromRGB(255, 196, 40),
		Description = "+3 carry capacity",
	},
	{
		Id = "Azure",
		Name = "Azure Star",
		Color = Color3.fromRGB(40, 140, 255),
		Description = "+3 carry capacity",
	},
	{
		Id = "Emerald",
		Name = "Emerald Clover",
		Color = Color3.fromRGB(30, 200, 90),
		Description = "You sprint much faster",
	},
} :: { KeyInfo }

-- Afmetingen van de bibliotheek (in studs)
Config.Map = {
	HalfX = 120,
	HalfZ = 80,
	FloorHeight = 24, -- hoogte van de tweede verdieping
	WallHeight = 48,
	GridX = { -80, -40, 0, 40, 80 },
	GridZ = { 35, 5, -25, -55 },
	CaseLength = 30,
	CaseHeight = 11,
	CaseDepth = 3,
}

----------------------------------------------------------------------------
-- MUZIEK EN GELUID
-- In de map assets/sounds staan zelfgemaakte muziek en geluiden: upload ze naar Roblox
-- (zie de README) en plak de ID's hieronder. Je mag ook geluiden uit de Creator Store gebruiken.
-- Je mag alleen het getal invullen (bijv. 1234567890) of "rbxassetid://1234567890".
-- Laat je iets leeg (""), dan is dat geluid gewoon stil.
----------------------------------------------------------------------------

-- Muziek (speelt in een lus en vloeit zacht over in de volgende)
Config.Music = {
	Lobby = "", -- in de hal: vrolijk en rustig
	Library = "", -- in de Starterzaal en de Grote Zaal: rustige bibliotheekmuziek
	Nightmare = "", -- in de Nachtmerriezaal: donker en eng
	Chase = "", -- als het monster dichtbij is: spannend en snel
	Countdown = "", -- de laatste minuut van een ronde: haastig
	Win = "", -- als de zaal schoon is (speelt één keer)
	Lose = "", -- als de tijd op is (speelt één keer)
}
Config.MusicVolume = 0.35

-- Geluidseffecten: alle effecten zitten samen in één bestand (assets/sounds/SoundEffects.ogg).
-- Upload dat bestand en plak de ID hier; het spel speelt dan steeds het juiste stukje af.
Config.SoundEffects = ""

-- Waar elk effect in SoundEffects.ogg staat (begin en eind in seconden)
Config.SoundEffectRegions = {
	Pickup = { 0, 0.35 }, -- boek oppakken
	Place = { 2, 2.9 }, -- boek in de goede kast
	Wrong = { 4, 4.45 }, -- verkeerde kast
	Key = { 6, 7.2 }, -- sleutel gevonden
	Shush = { 8, 9.3 }, -- het monster ziet je ("SSSHHH!")
	Heartbeat = { 10, 10.9 }, -- hartslag als het monster dichtbij is (speelt in een lus)
	Portal = { 12, 13 }, -- naar binnen gaan
	Coins = { 14, 14.6 }, -- munten verdiend / iets gekocht
	Caught = { 16, 17.6 }, -- gepakt door het monster
}

-- Wil je één effect vervangen door een ander geluid? Zet dan hier een eigen ID neer (dat gaat voor).
Config.SoundIds = {
	Pickup = "",
	Place = "",
	Wrong = "",
	Key = "",
	Shush = "",
	Heartbeat = "",
	Portal = "",
	Coins = "",
	Caught = "",
}

-- Oude ingebouwde Roblox-geluidjes, alleen als er nog niets is ingevuld
Config.BuiltInSounds = {
	Pickup = "rbxasset://sounds/clickfast.wav",
	Place = "rbxasset://sounds/electronicpingshort.wav",
	Wrong = "rbxasset://sounds/button.wav",
	Caught = "rbxasset://sounds/uuhhh.mp3",
}

-- Maakt van een getal of tekst een bruikbare SoundId (of nil als het leeg is)
function Config.AssetId(value: any): string?
	if type(value) == "number" then
		return "rbxassetid://" .. math.floor(value)
	elseif type(value) == "string" and value ~= "" then
		if string.match(value, "^%d+$") then
			return "rbxassetid://" .. value
		end
		return value
	end
	return nil
end

-- 31 kastsecties: 1A–1N op de begane grond, 2A–2Q op de eerste verdieping
Config.Sections = {
	{ Code = "1A", Name = "Studio", Floor = 1, Titles = { "My First Script", "Parts & Welds", "Debugging at Midnight" } },
	{ Code = "1B", Name = "Simulators", Floor = 1, Titles = { "Click a Million Times", "Rebirth Secrets", "Pet Simulator Guide" } },
	{ Code = "1C", Name = "Avatar & Catalog", Floor = 1, Titles = { "Hats Through the Ages", "The Perfect Outfit", "Dominus Dreams" } },
	{ Code = "1D", Name = "Myths", Floor = 1, Titles = { "The Tale of Guest 666", "Legends of the Old Server", "The Lost Badge" } },
	{ Code = "1E", Name = "DevEx", Floor = 1, Titles = { "Robux to Real Money", "Rich from Games", "The Big Payout Book" } },
	{ Code = "1F", Name = "Rules & Moderation", Floor = 1, Titles = { "Be Kind", "The Ban Book", "Reporting for Beginners" } },
	{ Code = "1G", Name = "Obby & Parkour", Floor = 1, Titles = { "Lava Is Hot", "1000 Stages Later", "Jump Like a Pro" } },
	{ Code = "1H", Name = "Horror", Floor = 1, Titles = { "The Creaking Stairs", "Eyes in the Dark", "Who Whispers There?" } },
	{ Code = "1I", Name = "Economy & Trading", Floor = 1, Titles = { "Trading Without Scams", "Supply and Demand", "The Limited Market" } },
	{ Code = "1J", Name = "History", Floor = 1, Titles = { "Roblox in 2006", "Castles and Knights", "The Old Library" } },
	{ Code = "1K", Name = "Cookbooks", Floor = 1, Titles = { "Pizza Factory Recipes", "Cake for Noobs", "The Witch's Soup" } },
	{ Code = "1L", Name = "Fairy Tales", Floor = 1, Titles = { "The Sleeping Librarian", "Three Little Noobs", "The Golden Book" } },
	{ Code = "1M", Name = "Space", Floor = 1, Titles = { "Building Rockets", "Life on Mars", "Black Holes" } },
	{ Code = "1N", Name = "Animals", Floor = 1, Titles = { "Cats Know Everything", "The Wise Owl", "Under the Sea" } },

	{ Code = "2A", Name = "Magic", Floor = 2, Titles = { "Spells for Tidying Up", "The Floating Books", "Choosing a Wand" } },
	{ Code = "2B", Name = "Anime", Floor = 2, Titles = { "Powerful Battle Cries", "The Final Episode", "Ninja Steps" } },
	{ Code = "2C", Name = "Meditation", Floor = 2, Titles = { "Breathe In, Breathe Out", "Silence in the Library", "A Calm Mind" } },
	{ Code = "2D", Name = "Military", Floor = 2, Titles = { "Tanks and Towers", "Strategy Handbook", "The Great Defense" } },
	{ Code = "2E", Name = "Brainrot", Floor = 2, Titles = { "Skibidi Science", "Sigma Grindset", "What Did He Just Say?" } },
	{ Code = "2F", Name = "Theme Parks", Floor = 2, Titles = { "Designing Roller Coasters", "Cotton Candy Empire", "The Haunted House" } },
	{ Code = "2G", Name = "Engineering", Floor = 2, Titles = { "Gears and Levers", "Bridges That Stay Up", "Building Robots" } },
	{ Code = "2H", Name = "Science", Floor = 2, Titles = { "Explosive Experiments", "The Atom", "Why Is the Sky Blue?" } },
	{ Code = "2I", Name = "Pirates", Floor = 2, Titles = { "Reading Treasure Maps", "Captain Crumpet", "The Cursed Ship" } },
	{ Code = "2J", Name = "Dinosaurs", Floor = 2, Titles = { "T-Rex Teeth", "Fossil Hunting", "The Last Dino" } },
	{ Code = "2K", Name = "Sports", Floor = 2, Titles = { "Football Tricks", "Run Faster", "The Grand Final" } },
	{ Code = "2L", Name = "Music", Floor = 2, Titles = { "Piano for Ghosts", "Making Beats", "The Silent Orchestra" } },
	{ Code = "2M", Name = "Art", Floor = 2, Titles = { "Painting in the Dark", "Sculpting with Blocks", "Mixing Colors" } },
	{ Code = "2N", Name = "Detectives", Floor = 2, Titles = { "Who Stole the Book?", "Fingerprints", "The Riddle of Shelf 13" } },
	{ Code = "2O", Name = "Ghosts", Floor = 2, Titles = { "Counting Ghosts", "The Cold Corner", "Boo!" } },
	{ Code = "2P", Name = "Cursed Books", Floor = 2, Titles = { "Do Not Read Me", "The Book That Looks Back", "Page 666" } },
	{ Code = "2Q", Name = "Forbidden Archive", Floor = 2, Titles = { "Shhhhh...", "The Librarian's Rules", "Never Run Again" } },
} :: { Section }

-- De zalen waaruit je in de hal kunt kiezen
Config.Rooms = {
	{
		Id = "Starter",
		Name = "Starter Hall",
		Description = "1 floor · 12 shelves · no monster",
		Color = Color3.fromRGB(90, 210, 120),
		Floors = 1,
		MaxSections = 12,
		BooksPerSection = 6,
		RoundTime = 12 * 60,
		Monster = false,
		MonsterSpeed = 1,
		Dark = false,
		CoinMultiplier = 1,
		Offset = Vector3.new(1000, 0, 0),
	},
	{
		Id = "Classic",
		Name = "Grand Hall",
		Description = "2 floors · 31 shelves · The Librarian",
		Color = Color3.fromRGB(90, 160, 255),
		Floors = 2,
		MaxSections = 31,
		BooksPerSection = 8,
		RoundTime = 20 * 60,
		Monster = true,
		MonsterSpeed = 1,
		Dark = false,
		CoinMultiplier = 1.5,
		Offset = Vector3.new(2000, 0, 0),
	},
	{
		Id = "Nightmare",
		Name = "Nightmare Hall",
		Description = "Pitch dark · faster monster · double coins",
		Color = Color3.fromRGB(220, 60, 90),
		Floors = 2,
		MaxSections = 31,
		BooksPerSection = 8,
		RoundTime = 20 * 60,
		Monster = true,
		MonsterSpeed = 1.2,
		Dark = true,
		CoinMultiplier = 2,
		Offset = Vector3.new(3000, 0, 0),
	},
} :: { RoomInfo }

function Config.FindRoom(id: string): RoomInfo?
	for _, room in Config.Rooms do
		if room.Id == id then
			return room
		end
	end
	return nil
end

-- De kastsecties die in een zaal staan (met hun index voor de kleur)
function Config.RoomSections(room: RoomInfo): { { Section: Section, Index: number } }
	local list = {}
	for index, section in Config.Sections do
		if #list < room.MaxSections and section.Floor <= room.Floors then
			table.insert(list, { Section = section, Index = index })
		end
	end
	return list
end

function Config.RoomTotalBooks(room: RoomInfo): number
	return #Config.RoomSections(room) * room.BooksPerSection
end

-- Kleur per sectie (verdeeld over de regenboog), gebruikt in het scherm
function Config.SectionColor(index: number): Color3
	return Color3.fromHSV(((index - 1) * 0.618) % 1, 0.55, 0.95)
end

function Config.FindSection(code: string): (Section?, number?)
	for i, section in Config.Sections do
		if section.Code == code then
			return section, i
		end
	end
	return nil, nil
end


return Config
