--!strict
-- Gedeelde instellingen voor Clean The Library [Nightmare].
-- Pas hier getallen aan om het spel makkelijker of moeilijker te maken.

export type Section = {
	Code: string,
	Name: string,
	Floor: number,
	Titles: { string },
}

export type KeyInfo = {
	Id: string,
	Name: string,
	Color: Color3,
	Description: string,
}

local Config = {}

Config.GameName = "Clean The Library 📖 [Nightmare]"

-- Ronde
Config.RoundTime = 20 * 60 -- seconden om de bibliotheek op te ruimen
Config.IntermissionTime = 15
Config.EndScreenTime = 10
Config.BooksPerSection = 8
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
	SightRangeFlashlight = 85, -- met je zaklamp aan zie je meer, maar zij ziet jou ook sneller!
	FieldOfView = 130, -- graden
	CloseDetectRange = 12, -- zo dichtbij voelt ze je altijd
	HearSprintRange = 45,
	HearMistakeRange = 90, -- een boek in de verkeerde kast zetten maakt lawaai
	CatchDistance = 4.5,
	LoseTargetTime = 5,
	SpawnDelay = 20, -- seconden na de start voor ze verschijnt
}

-- Magische vaardigheden (client)
Config.Abilities = {
	Insight = { Key = Enum.KeyCode.Q, Cooldown = 30, Duration = 8, Radius = 70 },
	ShelfGuide = { Key = Enum.KeyCode.T, Cooldown = 20, Duration = 12 },
}

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
	CaseHeight = 10,
	CaseDepth = 3,
}

Config.SoundIds = {
	-- Ingebouwde Roblox-geluiden. Vervang ze gerust door eigen sound IDs.
	Pickup = "rbxasset://sounds/clickfast.wav",
	Place = "rbxasset://sounds/electronicpingshort.wav",
	Wrong = "rbxasset://sounds/button.wav",
	Caught = "rbxasset://sounds/uuhhh.mp3",
}

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

-- Kleur per sectie (verdeeld over de regenboog)
function Config.SectionColor(index: number): Color3
	return Color3.fromHSV(((index - 1) * 0.618) % 1, 0.65, 0.95)
end

function Config.FindSection(code: string): (Section?, number?)
	for i, section in Config.Sections do
		if section.Code == code then
			return section, i
		end
	end
	return nil, nil
end

function Config.TotalBooks(): number
	return #Config.Sections * Config.BooksPerSection
end

return Config
