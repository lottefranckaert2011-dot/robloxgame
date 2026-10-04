--!strict
-- Gedeelde instellingen voor Clean The Library [Nightmare].
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

Config.GameName = "Clean The Library 📖 [Nightmare]"

-- Ronde (per zaal staan de tijd en het aantal boeken bij Config.Rooms)
Config.StartCountdown = 5 -- seconden tussen binnenkomen en de start
Config.QueueTime = 10 -- zo lang telt de ring af voordat de groep naar binnen gaat
Config.MaxGroupSize = 8 -- zoveel spelers kunnen samen in één zaal
Config.MaxCopiesPerRoom = 4 -- zoveel groepen kunnen tegelijk dezelfde soort zaal spelen
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

-- Het monster: "De Bibliothecaresse"
Config.Monster = {
	Name = "De Bibliothecaresse",
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
		Name = "Inzicht",
		Icon = "👁",
		Description = "Laat alle boeken in de buurt oplichten",
		Cost = 20,
		Cooldown = 25,
		Key = Enum.KeyCode.One,
	},
	{
		Id = "ShelfGuide",
		Name = "Kastgids",
		Icon = "🧭",
		Description = "Een lichtstraal wijst naar de kast van je boek",
		Cost = 40,
		Cooldown = 15,
		Key = Enum.KeyCode.Two,
	},
	{
		Id = "Assemble",
		Name = "Verzamelen",
		Icon = "🧲",
		Description = "Trekt de dichtstbijzijnde boeken naar je toe",
		Cost = 120,
		Cooldown = 30,
		Key = Enum.KeyCode.Three,
	},
	{
		Id = "AutoShelf",
		Name = "Auto-plaatsen",
		Icon = "✨",
		Description = "Al je boeken vliegen vanzelf naar de goede kast",
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
		Name = "Grotere Tas",
		Icon = "🎒",
		Description = "+1 boek dragen",
		BaseCost = 40,
		CostGrowth = 1.6,
		MaxLevel = 6,
	},
	{
		Id = "Speed",
		Name = "Snelle Schoenen",
		Icon = "👟",
		Description = "+1,5 loopsnelheid",
		BaseCost = 50,
		CostGrowth = 1.7,
		MaxLevel = 5,
	},
} :: { ShopItem }
Config.SpeedPerLevel = 1.5

-- Assistent: een magische uil die zelf boeken terugzet
Config.Assistant = {
	Name = "Uil Oehoe",
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
		Name = "Karmijnrode Achthoek",
		Color = Color3.fromRGB(200, 30, 45),
		Description = "Je springt veel hoger",
	},
	{
		Id = "Golden",
		Name = "Gouden Diamant",
		Color = Color3.fromRGB(255, 196, 40),
		Description = "+3 draagcapaciteit",
	},
	{
		Id = "Azure",
		Name = "Azuurblauwe Ster",
		Color = Color3.fromRGB(40, 140, 255),
		Description = "+3 draagcapaciteit",
	},
	{
		Id = "Emerald",
		Name = "Smaragdgroene Klaver",
		Color = Color3.fromRGB(30, 200, 90),
		Description = "Je sprint veel sneller",
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
-- Plak hier de ID's van geluiden uit de Creator Store (Toolbox -> Audio).
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

-- Geluidseffecten
Config.SoundIds = {
	Pickup = "rbxasset://sounds/clickfast.wav", -- boek oppakken
	Place = "rbxasset://sounds/electronicpingshort.wav", -- boek in de goede kast
	Wrong = "rbxasset://sounds/button.wav", -- verkeerde kast
	Caught = "rbxasset://sounds/uuhhh.mp3", -- gepakt door het monster
	Key = "", -- sleutel gevonden
	Shush = "", -- het monster ziet je ("SSSHHH!")
	Heartbeat = "", -- hartslag als het monster dichtbij is (speelt in een lus)
	Portal = "", -- door een deur naar een zaal
	Coins = "", -- munten verdiend / iets gekocht
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
	{ Code = "1A", Name = "Studio", Floor = 1, Titles = { "Mijn Eerste Script", "Parts & Welds", "Debuggen om Middernacht" } },
	{ Code = "1B", Name = "Simulators", Floor = 1, Titles = { "Klik 1 Miljoen Keer", "Rebirth Geheimen", "Huisdieren Simulator Gids" } },
	{ Code = "1C", Name = "Avatar & Catalogus", Floor = 1, Titles = { "Hoeden door de Eeuwen", "De Perfecte Outfit", "Dominus Dromen" } },
	{ Code = "1D", Name = "Mythes", Floor = 1, Titles = { "Het Verhaal van Guest 666", "Legendes van de Oude Server", "De Verloren Badge" } },
	{ Code = "1E", Name = "DevEx", Floor = 1, Titles = { "Robux naar Euro", "Rijk met Games", "Het Grote Uitbetaalboek" } },
	{ Code = "1F", Name = "Regels & Moderatie", Floor = 1, Titles = { "Wees Vriendelijk", "Het Verbanboek", "Rapporteren voor Beginners" } },
	{ Code = "1G", Name = "Obby & Parkour", Floor = 1, Titles = { "Lava is Heet", "1000 Stages Later", "Springen als een Pro" } },
	{ Code = "1H", Name = "Horror", Floor = 1, Titles = { "Het Krakende Trapgat", "Ogen in het Donker", "Wie Fluistert Daar?" } },
	{ Code = "1I", Name = "Economie & Handel", Floor = 1, Titles = { "Ruilen Zonder Scams", "Vraag en Aanbod", "De Limited Markt" } },
	{ Code = "1J", Name = "Geschiedenis", Floor = 1, Titles = { "Roblox in 2006", "Kastelen en Ridders", "De Oude Bibliotheek" } },
	{ Code = "1K", Name = "Kookboeken", Floor = 1, Titles = { "Pizza Fabriek Recepten", "Taart voor Noobs", "Soep van de Heks" } },
	{ Code = "1L", Name = "Sprookjes", Floor = 1, Titles = { "De Slapende Bibliothecaris", "Drie Kleine Noobs", "Het Gouden Boek" } },
	{ Code = "1M", Name = "Ruimtevaart", Floor = 1, Titles = { "Raketten Bouwen", "Leven op Mars", "Zwarte Gaten" } },
	{ Code = "1N", Name = "Dieren", Floor = 1, Titles = { "Katten Weten Alles", "De Slimme Uil", "Onder de Zee" } },

	{ Code = "2A", Name = "Magie", Floor = 2, Titles = { "Spreuken voor Opruimen", "De Zwevende Boeken", "Toverstokken Kiezen" } },
	{ Code = "2B", Name = "Anime", Floor = 2, Titles = { "Krachtige Kreten", "De Laatste Aflevering", "Ninja Stappen" } },
	{ Code = "2C", Name = "Meditatie", Floor = 2, Titles = { "Adem In, Adem Uit", "Stilte in de Bibliotheek", "Rust in je Hoofd" } },
	{ Code = "2D", Name = "Leger", Floor = 2, Titles = { "Tanks en Torens", "Strategie Handboek", "De Grote Verdediging" } },
	{ Code = "2E", Name = "Brainrot", Floor = 2, Titles = { "Skibidi Wetenschap", "Sigma Grindset", "Wat Zei Hij Nou?" } },
	{ Code = "2F", Name = "Pretparken", Floor = 2, Titles = { "Achtbanen Ontwerpen", "Suikerspin Rijk", "Het Spookhuis" } },
	{ Code = "2G", Name = "Techniek", Floor = 2, Titles = { "Tandwielen en Hendels", "Bruggen die Blijven Staan", "Robots Bouwen" } },
	{ Code = "2H", Name = "Wetenschap", Floor = 2, Titles = { "Explosieve Proefjes", "Het Atoom", "Waarom is de Lucht Blauw?" } },
	{ Code = "2I", Name = "Piraten", Floor = 2, Titles = { "Schatkaarten Lezen", "Kapitein Krakeling", "Het Vervloekte Schip" } },
	{ Code = "2J", Name = "Dino's", Floor = 2, Titles = { "T-Rex Tanden", "Fossielen Zoeken", "De Laatste Dino" } },
	{ Code = "2K", Name = "Sport", Floor = 2, Titles = { "Voetbal Trucs", "Sneller Rennen", "De Grote Finale" } },
	{ Code = "2L", Name = "Muziek", Floor = 2, Titles = { "Piano voor Spoken", "Beats Maken", "Het Stille Orkest" } },
	{ Code = "2M", Name = "Kunst", Floor = 2, Titles = { "Schilderen in het Donker", "Beeldhouwen met Blokken", "Kleuren Mengen" } },
	{ Code = "2N", Name = "Detectives", Floor = 2, Titles = { "Wie Stal het Boek?", "Vingerafdrukken", "Het Raadsel van Kast 13" } },
	{ Code = "2O", Name = "Spoken", Floor = 2, Titles = { "Spoken Tellen", "Het Koude Hoekje", "Boe!" } },
	{ Code = "2P", Name = "Vervloekte Boeken", Floor = 2, Titles = { "Lees Mij Niet", "Het Boek dat Terugkijkt", "Bladzijde 666" } },
	{ Code = "2Q", Name = "Verboden Archief", Floor = 2, Titles = { "Shhhhh...", "De Regels van de Bibliothecaresse", "Nooit Meer Rennen" } },
} :: { Section }

-- De zalen waaruit je in de hal kunt kiezen
Config.Rooms = {
	{
		Id = "Starter",
		Name = "Starterzaal",
		Description = "1 verdieping · 12 kasten · geen monster",
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
		Name = "Grote Zaal",
		Description = "2 verdiepingen · 31 kasten · De Bibliothecaresse",
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
		Name = "Nachtmerriezaal",
		Description = "Pikdonker · sneller monster · dubbele munten",
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
