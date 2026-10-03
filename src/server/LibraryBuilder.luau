-- Bouwt de hele (donkere) bibliotheek met code: vloeren, trap, kasten,
-- bordjes, lampen, tafels, kluisjes om je te verstoppen en plekken voor sleutels.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Map = Config.Map
local F2 = Map.FloorHeight

local LibraryBuilder = {}

export type SectionData = {
	Code: string,
	Name: string,
	Index: number,
	Floor: number,
	Color: Color3,
	Model: Model,
	Center: Vector3,
	Target: BasePart, -- onzichtbaar onderdeel voor de kastgids
	Slots: { BasePart },
	Prompts: { ProximityPrompt },
	Counter: TextLabel,
	CounterBack: TextLabel,
	Sign: BasePart,
}

export type LockerData = {
	Model: Model,
	Inside: CFrame,
	Outside: CFrame,
	Prompt: ProximityPrompt,
}

export type Library = {
	Model: Model,
	SpawnCFrame: CFrame,
	Sections: { [string]: SectionData },
	Lockers: { LockerData },
	Waypoints: { Vector3 },
	KeySpots: { [string]: Vector3 },
	MonsterSpawn: Vector3,
	RandomBookSpot: (self: Library) -> CFrame,
}

local WOOD = Color3.fromRGB(74, 50, 34)
local DARK_WOOD = Color3.fromRGB(45, 30, 22)
local WALL = Color3.fromRGB(58, 52, 66)
local CARPET = Color3.fromRGB(70, 22, 30)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Onderdelen waarop boeken mogen verschijnen krijgen dit attribuut
local function bookSurface(p: BasePart)
	p:SetAttribute("BookSurface", true)
end

local function makeSurfaceText(p: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.Fantasy
	label.Parent = gui
	return label
end

local function buildStructure(parent: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Structure"
	folder.Parent = parent

	local hx, hz = Map.HalfX, Map.HalfZ

	-- Begane grond (tapijt)
	local floor1 = part({
		Name = "Floor1",
		Size = Vector3.new(hx * 2, 2, hz * 2),
		Position = Vector3.new(0, -1, 0),
		Color = CARPET,
		Material = Enum.Material.Fabric,
		Parent = folder,
	})
	bookSurface(floor1)

	-- Eerste verdieping met een gat voor de oprit (x 100..112, z 24..72)
	local holeX0, holeX1, holeZ0, holeZ1 = 100, 112, 24, 72
	local pieces = {
		{ x0 = -hx, x1 = holeX0, z0 = -hz, z1 = hz },
		{ x0 = holeX1, x1 = hx, z0 = -hz, z1 = hz },
		{ x0 = holeX0, x1 = holeX1, z0 = -hz, z1 = holeZ0 },
		{ x0 = holeX0, x1 = holeX1, z0 = holeZ1, z1 = hz },
	}
	for i, r in pieces do
		local slab = part({
			Name = "Floor2_" .. i,
			Size = Vector3.new(r.x1 - r.x0, 2, r.z1 - r.z0),
			Position = Vector3.new((r.x0 + r.x1) / 2, F2 - 1, (r.z0 + r.z1) / 2),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})
		bookSurface(slab)
	end

	-- Plafond
	part({
		Name = "Roof",
		Size = Vector3.new(hx * 2 + 4, 2, hz * 2 + 4),
		Position = Vector3.new(0, Map.WallHeight + 1, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		Parent = folder,
	})

	-- Muren
	local h = Map.WallHeight + 2
	local walls = {
		{ Vector3.new(hx * 2 + 4, h, 2), Vector3.new(0, h / 2 - 2, hz + 1) },
		{ Vector3.new(hx * 2 + 4, h, 2), Vector3.new(0, h / 2 - 2, -hz - 1) },
		{ Vector3.new(2, h, hz * 2 + 4), Vector3.new(hx + 1, h / 2 - 2, 0) },
		{ Vector3.new(2, h, hz * 2 + 4), Vector3.new(-hx - 1, h / 2 - 2, 0) },
	}
	for i, w in walls do
		part({
			Name = "Wall" .. i,
			Size = w[1],
			Position = w[2],
			Color = WALL,
			Material = Enum.Material.Brick,
			Parent = folder,
		})
	end

	-- Oprit naar boven: van (106, 0, 72) naar (106, F2, 24)
	local bottom = Vector3.new(106, 0, holeZ1)
	local top = Vector3.new(106, F2, holeZ0)
	local mid = (bottom + top) / 2
	local length = (top - bottom).Magnitude
	local ramp = part({
		Name = "Ramp",
		Size = Vector3.new(holeX1 - holeX0, 1, length + 1),
		CFrame = CFrame.lookAt(mid, top) * CFrame.new(0, -0.5, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	ramp:SetAttribute("NoBooks", true)

	-- Leuningen rond het gat op de eerste verdieping
	local railColor = Color3.fromRGB(110, 80, 45)
	local rails = {
		{ Vector3.new(0.6, 3.5, holeZ1 - holeZ0), Vector3.new(holeX0 - 0.3, F2 + 1.75, (holeZ0 + holeZ1) / 2) },
		{ Vector3.new(0.6, 3.5, holeZ1 - holeZ0), Vector3.new(holeX1 + 0.3, F2 + 1.75, (holeZ0 + holeZ1) / 2) },
		{ Vector3.new(holeX1 - holeX0, 3.5, 0.6), Vector3.new((holeX0 + holeX1) / 2, F2 + 1.75, holeZ1 + 0.3) },
	}
	for i, r in rails do
		part({ Name = "Rail" .. i, Size = r[1], Position = r[2], Color = railColor, Material = Enum.Material.Wood, Parent = folder })
	end

	-- Balie bij de ingang
	part({
		Name = "Desk",
		Size = Vector3.new(16, 3.5, 3),
		Position = Vector3.new(0, 1.75, 58),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
		Parent = folder,
	})

	-- Grote voordeur (decoratie)
	local door = part({
		Name = "FrontDoor",
		Size = Vector3.new(14, 18, 0.5),
		Position = Vector3.new(0, 9, hz - 0.2),
		Color = Color3.fromRGB(35, 20, 14),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	makeSurfaceText(door, Enum.NormalId.Front, "GESLOTEN\nTOT ALLES\nOPGERUIMD IS", Color3.fromRGB(200, 40, 40))
end

local function buildBookcase(parent: Model, center: CFrame, color: Color3)
	local L, H, D = Map.CaseLength, Map.CaseHeight, Map.CaseDepth
	local function piece(name: string, size: Vector3, offset: Vector3)
		local p = part({
			Name = name,
			Size = size,
			CFrame = center * CFrame.new(offset),
			Color = WOOD,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		p:SetAttribute("NoBooks", true)
		return p
	end
	piece("Back", Vector3.new(L, H, 0.4), Vector3.new(0, H / 2, -D / 2 + 0.2))
	piece("SideL", Vector3.new(0.5, H, D), Vector3.new(-L / 2 + 0.25, H / 2, 0))
	piece("SideR", Vector3.new(0.5, H, D), Vector3.new(L / 2 - 0.25, H / 2, 0))
	for i, y in { 0.15, 2.65, 5.15, 7.65, H - 0.15 } do
		piece("Shelf" .. i, Vector3.new(L, 0.3, D), Vector3.new(0, y, 0))
	end
	-- Gekleurde rand zodat je de sectie herkent
	local trim = part({
		Name = "Trim",
		Size = Vector3.new(L, 0.4, 0.2),
		CFrame = center * CFrame.new(0, H - 0.5, D / 2 + 0.1),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = parent,
	})
	trim:SetAttribute("NoBooks", true)
end

local function buildSection(parent: Folder, section: Config.Section, index: number, slot: number): SectionData
	local col = (slot - 1) % #Map.GridX + 1
	local row = math.floor((slot - 1) / #Map.GridX) + 1
	local floorY = if section.Floor == 1 then 0 else F2
	local center = CFrame.new(Map.GridX[col], floorY, Map.GridZ[row])
	local color = Config.SectionColor(index)

	local model = Instance.new("Model")
	model.Name = "Section_" .. section.Code
	model:SetAttribute("Code", section.Code)
	model.Parent = parent

	buildBookcase(model, center, color)

	-- Bordje boven de kast (voor- en achterkant)
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(10, 3.6, 0.4),
		CFrame = center * CFrame.new(0, Map.CaseHeight + 2.2, 0),
		Color = Color3.fromRGB(25, 20, 18),
		Parent = model,
	})
	sign:SetAttribute("NoBooks", true)
	local title = string.format("%s  %s", section.Code, section.Name)
	makeSurfaceText(sign, Enum.NormalId.Front, title, color).Size = UDim2.fromScale(1, 0.65)
	makeSurfaceText(sign, Enum.NormalId.Back, title, color).Size = UDim2.fromScale(1, 0.65)
	local counter = makeSurfaceText(sign, Enum.NormalId.Front, "", Color3.new(1, 1, 1), Enum.Font.GothamBold)
	counter.Size = UDim2.fromScale(1, 0.32)
	counter.Position = UDim2.fromScale(0, 0.66)
	counter.Name = "Counter"
	local counterBack = makeSurfaceText(sign, Enum.NormalId.Back, "", Color3.new(1, 1, 1), Enum.Font.GothamBold)
	counterBack.Size = UDim2.fromScale(1, 0.32)
	counterBack.Position = UDim2.fromScale(0, 0.66)
	counterBack.Name = "Counter"
	for _, gui in sign:GetChildren() do
		if gui:IsA("SurfaceGui") then
			gui.PixelsPerStud = 30
		end
	end

	-- Lege plekken (spookboeken) die opvullen als je boeken terugzet
	local slots = {}
	local n = Config.BooksPerSection
	local levels = { 0.3, 2.8, 5.3 }
	local perLevel = math.ceil(n / #levels)
	local spacing = (Map.CaseLength - 4) / perLevel
	for i = 1, n do
		local level = math.floor((i - 1) / perLevel) + 1
		local pos = (i - 1) % perLevel
		local x = -Map.CaseLength / 2 + 2 + spacing * (pos + 0.5)
		local ghost = part({
			Name = "Slot" .. i,
			Size = Vector3.new(0.6, 2, 1.8),
			CFrame = center * CFrame.new(x, levels[level] + 1.15, 0.2),
			Color = color,
			Material = Enum.Material.ForceField,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
		table.insert(slots, ghost)
	end

	-- Onzichtbaar onderdeel voor de "terugzetten"-knoppen
	local front = part({
		Name = "PromptZone",
		Size = Vector3.new(Map.CaseLength, Map.CaseHeight, 1),
		CFrame = center * CFrame.new(0, Map.CaseHeight / 2, Map.CaseDepth / 2 + 0.6),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local prompts = {}
	for _, x in { -10, 0, 10 } do
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(x, -1.5, 0)
		att.Parent = front
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Boeken terugzetten"
		prompt.ObjectText = title
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = att
		table.insert(prompts, prompt)
	end

	return {
		Code = section.Code,
		Name = section.Name,
		Index = index,
		Floor = section.Floor,
		Color = color,
		Model = model,
		Center = center.Position,
		Target = front,
		Slots = slots,
		Prompts = prompts,
		Counter = counter,
		CounterBack = counterBack,
		Sign = sign,
	}
end

local function buildTable(parent: Folder, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "ReadingTable"
	model.Parent = parent
	local top = part({
		Name = "Top",
		Size = Vector3.new(14, 0.5, 6),
		Position = pos + Vector3.new(0, 3, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	bookSurface(top)
	for _, o in { Vector3.new(-6.5, 0, -2.5), Vector3.new(6.5, 0, -2.5), Vector3.new(-6.5, 0, 2.5), Vector3.new(6.5, 0, 2.5) } do
		part({
			Name = "Leg",
			Size = Vector3.new(0.5, 2.75, 0.5),
			Position = pos + o + Vector3.new(0, 1.375, 0),
			Color = DARK_WOOD,
			Parent = model,
		}):SetAttribute("NoBooks", true)
	end
	-- Een kaarsje op tafel
	local candle = part({
		Name = "Candle",
		Size = Vector3.new(0.4, 1, 0.4),
		Position = pos + Vector3.new(0, 3.75, 0),
		Color = Color3.fromRGB(240, 230, 200),
		Parent = model,
	})
	candle:SetAttribute("NoBooks", true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 70)
	light.Range = 12
	light.Brightness = 1
	light.Parent = candle
	candle:SetAttribute("Flicker", true)
end

local function buildLocker(parent: Folder, pos: Vector3, facing: Vector3): LockerData
	local model = Instance.new("Model")
	model.Name = "Locker"
	model.Parent = parent
	local base = CFrame.lookAt(pos, pos + facing)
	local metal = Color3.fromRGB(60, 66, 70)
	local function piece(name: string, size: Vector3, offset: Vector3)
		local p = part({
			Name = name,
			Size = size,
			CFrame = base * CFrame.new(offset),
			Color = metal,
			Material = Enum.Material.DiamondPlate,
			Parent = model,
		})
		p:SetAttribute("NoBooks", true)
		return p
	end
	-- Voorkant = -Z (CFrame.lookAt kijkt langs -Z)
	piece("Back", Vector3.new(4.4, 8, 0.4), Vector3.new(0, 4, 2))
	piece("Left", Vector3.new(0.4, 8, 4.4), Vector3.new(-2, 4, 0))
	piece("Right", Vector3.new(0.4, 8, 4.4), Vector3.new(2, 4, 0))
	piece("Roof", Vector3.new(4.4, 0.4, 4.4), Vector3.new(0, 8.2, 0))
	local door = piece("Door", Vector3.new(3.6, 7.8, 0.3), Vector3.new(0, 4, -2))
	door.Color = Color3.fromRGB(80, 88, 92)
	-- Kijkgleufjes
	for i = 1, 3 do
		part({
			Name = "Slit",
			Size = Vector3.new(2.4, 0.15, 0.05),
			CFrame = base * CFrame.new(0, 6.6 - i * 0.35, -2.17),
			Color = Color3.new(0, 0, 0),
			CanCollide = false,
			Parent = model,
		})
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Verstoppen"
	prompt.ObjectText = "Kluisje"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	return {
		Model = model,
		Inside = base * CFrame.new(0, 3, 0),
		Outside = base * CFrame.new(0, 3, -5),
		Prompt = prompt,
	}
end

local function buildLamps(parent: Folder)
	local index = 0
	for _, y in { F2 - 3, Map.WallHeight - 3 } do
		for x = -100, 100, 50 do
			for z = -60, 60, 40 do
				index += 1
				local lamp = part({
					Name = "Lamp",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.6, 1.6, 1.6),
					Position = Vector3.new(x, y, z),
					Color = Color3.fromRGB(255, 200, 130),
					Material = Enum.Material.Neon,
					CanCollide = false,
					CanQuery = false,
					Parent = parent,
				})
				part({
					Name = "Chain",
					Size = Vector3.new(0.15, 2, 0.15),
					Position = Vector3.new(x, y + 1.8, z),
					Color = Color3.fromRGB(40, 40, 40),
					CanCollide = false,
					CanQuery = false,
					Parent = parent,
				})
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 190, 120)
				light.Range = 26
				light.Brightness = 0.9
				light.Shadows = true
				light.Parent = lamp
				-- Ongeveer een op de drie lampen flikkert (dat doet de client)
				if index % 3 == 0 then
					lamp:SetAttribute("Flicker", true)
				end
			end
		end
	end
end

local function isInsideRect(pos: Vector3, x0: number, x1: number, z0: number, z1: number): boolean
	return pos.X >= x0 and pos.X <= x1 and pos.Z >= z0 and pos.Z <= z1
end

function LibraryBuilder.Build(): Library
	local old = Workspace:FindFirstChild("Library")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Library"

	buildStructure(model)

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "Sections"
	sectionsFolder.Parent = model

	local sections: { [string]: SectionData } = {}
	local usedSlots = { [1] = 0, [2] = 0 }
	for index, section in Config.Sections do
		usedSlots[section.Floor] += 1
		sections[section.Code] = buildSection(sectionsFolder, section, index, usedSlots[section.Floor])
	end

	-- Leestafels op de overgebleven plekken in het rooster
	local tables = Instance.new("Folder")
	tables.Name = "Tables"
	tables.Parent = model
	local slotCount = #Map.GridX * #Map.GridZ
	for floor = 1, 2 do
		for slot = usedSlots[floor] + 1, slotCount do
			local col = (slot - 1) % #Map.GridX + 1
			local row = math.floor((slot - 1) / #Map.GridX) + 1
			local y = if floor == 1 then 0 else F2
			buildTable(tables, Vector3.new(Map.GridX[col], y, Map.GridZ[row]))
		end
	end
	-- Extra tafels in de hal bij de ingang
	buildTable(tables, Vector3.new(-60, 0, 62))
	buildTable(tables, Vector3.new(60, 0, 62))
	buildTable(tables, Vector3.new(-60, F2, 62))
	buildTable(tables, Vector3.new(40, F2, 62))

	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = model
	buildLamps(lamps)

	local lockersFolder = Instance.new("Folder")
	lockersFolder.Name = "Lockers"
	lockersFolder.Parent = model
	local lockers = {}
	local lockerSpots = {
		{ Vector3.new(-117, 0, 60), Vector3.new(1, 0, 0) },
		{ Vector3.new(-117, 0, -40), Vector3.new(1, 0, 0) },
		{ Vector3.new(20, 0, -77), Vector3.new(0, 0, 1) },
		{ Vector3.new(117, 0, -20), Vector3.new(-1, 0, 0) },
		{ Vector3.new(-117, F2, 40), Vector3.new(1, 0, 0) },
		{ Vector3.new(-20, F2, -77), Vector3.new(0, 0, 1) },
		{ Vector3.new(117, F2, -50), Vector3.new(-1, 0, 0) },
		{ Vector3.new(80, F2, 77), Vector3.new(0, 0, -1) },
	}
	for _, spot in lockerSpots do
		table.insert(lockers, buildLocker(lockersFolder, spot[1], spot[2]))
	end

	-- Spawnplek achter de balie
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, 68)
	spawn.Color = Color3.fromRGB(60, 40, 30)
	spawn.Material = Enum.Material.Wood
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn:SetAttribute("NoBooks", true)
	spawn.Parent = model

	-- Patrouillepunten voor het monster (in de gangpaden, beide verdiepingen)
	local waypoints = {}
	for floor = 1, 2 do
		local y = (if floor == 1 then 0 else F2) + 3
		for _, x in { -108, -60, -20, 20, 60 } do
			for _, z in { 50, 20, -10, -40, -70 } do
				table.insert(waypoints, Vector3.new(x, y, z))
			end
		end
	end
	table.insert(waypoints, Vector3.new(106, 3, 76))
	table.insert(waypoints, Vector3.new(106, F2 + 3, 18))
	table.insert(waypoints, Vector3.new(116, 3, 0))

	-- Pas aan het eind in Workspace zetten, dan komt alles in één keer bij de spelers aan
	model.Parent = Workspace

	local library = {
		Model = model,
		SpawnCFrame = spawn.CFrame + Vector3.new(0, 3, 0),
		Sections = sections,
		Lockers = lockers,
		Waypoints = waypoints,
		KeySpots = {
			Crimson = Vector3.new(106, 1.5, 40), -- onder de oprit
			Golden = Vector3.new(-116, F2 + 1.5, -77), -- achterste hoek boven
			Azure = Vector3.new(-80, 1.5, -77), -- achter de laatste kastenrij beneden
			Emerald = Vector3.new(-40, F2 + 1.5, -58.5), -- achter het Verboden Archief
		},
		MonsterSpawn = Vector3.new(0, F2 + 6, -70),
	}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { model }

	-- Zoekt een willekeurige plek op een vloer of tafel voor een boek
	function library.RandomBookSpot(_self: Library): CFrame
		for _ = 1, 60 do
			local floor = math.random(1, 2)
			local x = math.random(-Map.HalfX + 3, Map.HalfX - 3) + math.random()
			local z = math.random(-Map.HalfZ + 3, Map.HalfZ - 3) + math.random()
			local origin = Vector3.new(x, (if floor == 1 then F2 - 3 else Map.WallHeight - 4), z)
			local probe = Vector3.new(x, 0, z)
			local blocked = isInsideRect(probe, 97, 115, 20, 76) -- oprit
				or isInsideRect(probe, -9, 9, 55, 80) -- balie en spawn
			if not blocked then
				local result = Workspace:Raycast(origin, Vector3.new(0, -30, 0), rayParams)
				if result and result.Instance:GetAttribute("BookSurface") then
					local yaw = math.rad(math.random(0, 359))
					return CFrame.new(result.Position + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, yaw, 0)
				end
			end
		end
		return CFrame.new(0, 0.2, 50)
	end

	return library
end

return LibraryBuilder
