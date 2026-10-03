-- Bouwt de hele bibliotheek met code, in de stijl van het origineel:
-- roze/crème muren met bogen en houten pilaren, een glazen dakraam,
-- houten kasten met groene naambordjes, wandlampen, planten en tafels.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Map = Config.Map
local F2 = Map.FloorHeight

local LibraryBuilder = {}

-- Instellingen van de zaal die nu gebouwd wordt
local currentFloors = 2
local currentDark = false

local function levels(): { number }
	return if currentFloors >= 2 then { 0, F2 } else { 0 }
end

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
	Counters: { TextLabel },
}

export type LockerData = {
	Model: Model,
	Inside: CFrame,
	Outside: CFrame,
	Prompt: ProximityPrompt,
}

export type Library = {
	Model: Model,
	Books: Folder,
	Offset: Vector3,
	SpawnCFrame: CFrame,
	ExitPrompt: ProximityPrompt,
	Sections: { [string]: SectionData },
	Lockers: { LockerData },
	Waypoints: { Vector3 },
	KeySpots: { [string]: Vector3 },
	MonsterSpawn: Vector3,
	RandomBookSpot: (self: Library) -> CFrame,
	BookSpotNear: (self: Library, center: Vector3, radius: number, extra: Instance?) -> CFrame?,
}

-- Kleuren uit het origineel
local WALL = Color3.fromRGB(242, 222, 210)
local WALL_PANEL = Color3.fromRGB(232, 200, 192)
local PILLAR = Color3.fromRGB(214, 128, 66)
local MOULDING = Color3.fromRGB(170, 64, 42)
local FLOOR = Color3.fromRGB(178, 76, 40)
local CASE_WOOD = Color3.fromRGB(226, 156, 92)
local CASE_BACK = Color3.fromRGB(206, 132, 72)
local DARK_WOOD = Color3.fromRGB(120, 62, 34)
local GOLD = Color3.fromRGB(230, 186, 96)
local PLAQUE = Color3.fromRGB(52, 112, 94)
local LAMP_LIGHT = Color3.fromRGB(255, 214, 160)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	-- Shape eerst, anders kan Size verkeerd uitvallen
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Decoratie: botst niet en wordt niet geraakt door raycasts
local function deco(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props)
end

-- Onderdelen waarop boeken mogen verschijnen krijgen dit attribuut
local function bookSurface(p: BasePart)
	p:SetAttribute("BookSurface", true)
end

local function noBooks(p: BasePart)
	p:SetAttribute("NoBooks", true)
end

local function surfaceGui(p: BasePart, face: Enum.NormalId, pixelsPerStud: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 50
	gui.Parent = p
	return gui
end

-- Groen naambordje zoals in het origineel. Geeft het label voor de teller terug.
local function plaque(p: BasePart, face: Enum.NormalId, code: string, withCounter: boolean): TextLabel?
	local gui = surfaceGui(p, face, 60)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.94, 0.88)
	frame.BackgroundColor3 = PLAQUE
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 5
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, if withCounter then 0.62 else 0.9)
	label.Position = UDim2.fromScale(0, if withCounter then 0.06 else 0.05)
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 235, 210)
	label.Text = code
	label.Parent = frame

	if not withCounter then
		return nil
	end
	local counter = Instance.new("TextLabel")
	counter.BackgroundTransparency = 1
	counter.Size = UDim2.fromScale(0.8, 0.26)
	counter.Position = UDim2.fromScale(0.1, 0.66)
	counter.Font = Enum.Font.Garamond
	counter.TextScaled = true
	counter.TextColor3 = Color3.fromRGB(230, 220, 190)
	counter.Text = ""
	counter.Parent = frame
	return counter
end

----------------------------------------------------------------------------
-- Gebouw
----------------------------------------------------------------------------

local function buildFloors(folder: Folder)
	local hx, hz = Map.HalfX, Map.HalfZ

	local floor1 = part({
		Name = "Floor1",
		Size = Vector3.new(hx * 2, 2, hz * 2),
		Position = Vector3.new(0, -1, 0),
		Color = FLOOR,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	bookSurface(floor1)
	if currentFloors < 2 then
		return
	end

	-- Eerste verdieping met een gat voor de oprit (x 100..112, z 24..72):
	-- bovenkant hout, onderkant gestuukt plafond
	local holeX0, holeX1, holeZ0, holeZ1 = 100, 112, 24, 72
	local pieces = {
		{ x0 = -hx, x1 = holeX0, z0 = -hz, z1 = hz },
		{ x0 = holeX1, x1 = hx, z0 = -hz, z1 = hz },
		{ x0 = holeX0, x1 = holeX1, z0 = -hz, z1 = holeZ0 },
		{ x0 = holeX0, x1 = holeX1, z0 = holeZ1, z1 = hz },
	}
	for i, r in pieces do
		local size = Vector3.new(r.x1 - r.x0, 1, r.z1 - r.z0)
		local center = Vector3.new((r.x0 + r.x1) / 2, 0, (r.z0 + r.z1) / 2)
		local top = part({
			Name = "Floor2_" .. i,
			Size = size,
			Position = center + Vector3.new(0, F2 - 0.5, 0),
			Color = FLOOR,
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})
		bookSurface(top)
		part({
			Name = "Ceiling1_" .. i,
			Size = size,
			Position = center + Vector3.new(0, F2 - 1.5, 0),
			Color = WALL,
			Material = Enum.Material.Plaster,
			Parent = folder,
		})
	end

	-- Oprit naar boven: van (106, 0, 72) naar (106, F2, 24)
	local bottom = Vector3.new(106, 0, holeZ1)
	local top = Vector3.new(106, F2, holeZ0)
	local mid = (bottom + top) / 2
	local length = (top - bottom).Magnitude
	local rampCFrame = CFrame.lookAt(mid, top)
	noBooks(part({
		Name = "Ramp",
		Size = Vector3.new(holeX1 - holeX0, 1, length + 1),
		CFrame = rampCFrame * CFrame.new(0, -0.5, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	}))
	-- Loper op de oprit
	deco({
		Name = "RampRunner",
		Size = Vector3.new(6, 0.1, length),
		CFrame = rampCFrame * CFrame.new(0, 0.03, 0),
		Color = MOULDING,
		Material = Enum.Material.Fabric,
		Parent = folder,
	})

	-- Leuningen rond het gat op de eerste verdieping
	local rails = {
		{ Vector3.new(0.6, 3.5, holeZ1 - holeZ0), Vector3.new(holeX0 - 0.3, F2 + 1.75, (holeZ0 + holeZ1) / 2) },
		{ Vector3.new(0.6, 3.5, holeZ1 - holeZ0), Vector3.new(holeX1 + 0.3, F2 + 1.75, (holeZ0 + holeZ1) / 2) },
		{ Vector3.new(holeX1 - holeX0, 3.5, 0.6), Vector3.new((holeX0 + holeX1) / 2, F2 + 1.75, holeZ1 + 0.3) },
	}
	for i, r in rails do
		noBooks(part({ Name = "Rail" .. i, Size = r[1], Position = r[2], Color = PILLAR, Material = Enum.Material.Wood, Parent = folder }))
	end
	-- Leuningen langs de oprit zelf
	for _, x in { holeX0 + 0.3, holeX1 - 0.3 } do
		noBooks(part({
			Name = "RampRail",
			Size = Vector3.new(0.4, 3, length),
			CFrame = CFrame.lookAt(Vector3.new(x, mid.Y, mid.Z), Vector3.new(x, top.Y, top.Z)) * CFrame.new(0, 1.5, 0),
			Color = PILLAR,
			Material = Enum.Material.Wood,
			Parent = folder,
		}))
	end
end

-- Een muur met pilaren, boogpanelen, lijsten en wandlampen
local function buildWall(folder: Folder, origin: Vector3, along: Vector3, inward: Vector3, length: number, pillarStep: number, skipBay: ((Vector3, number) -> boolean)?)
	local thickness = 2
	local h = Map.WallHeight + 2
	local wallCenter = origin - inward * (thickness / 2) + Vector3.new(0, h / 2 - 2, 0)
	local rot = CFrame.lookAt(Vector3.zero, inward) -- -Z wijst de kamer in
	part({
		Name = "Wall",
		Size = Vector3.new(length + 4, h, thickness),
		CFrame = CFrame.new(wallCenter) * rot,
		Color = WALL,
		Material = Enum.Material.Plaster,
		Parent = folder,
	})

	local function at(t: number, y: number, depth: number): CFrame
		return CFrame.new(origin + along * t + inward * depth + Vector3.new(0, y, 0)) * rot
	end

	-- Lijsten: plint onderaan en een rode lijst onder elk plafond
	for _, y0 in levels() do
		deco({ Name = "Baseboard", Size = Vector3.new(length, 1, 0.4), CFrame = at(0, y0 + 0.5, 0.2), Color = DARK_WOOD, Parent = folder })
		local top = if y0 == 0 and currentFloors >= 2 then F2 - 2 else Map.WallHeight
		deco({ Name = "Moulding", Size = Vector3.new(length, 1.4, 1), CFrame = at(0, top - 0.7, 0.5), Color = MOULDING, Material = Enum.Material.Wood, Parent = folder })
		deco({ Name = "MouldingTrim", Size = Vector3.new(length, 0.3, 1.3), CFrame = at(0, top - 1.55, 0.65), Color = PILLAR, Material = Enum.Material.Wood, Parent = folder })
	end

	local count = math.floor(length / pillarStep)
	local first = -(count - 1) * pillarStep / 2
	for i = 0, count - 1 do
		local t = first + i * pillarStep
		deco({
			Name = "Pillar",
			Size = Vector3.new(2.6, Map.WallHeight, 1.2),
			CFrame = at(t, Map.WallHeight / 2, 0.6),
			Color = PILLAR,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		-- Wandlamp op de pilaar (beide verdiepingen)
		for _, y0 in levels() do
			deco({ Name = "SconceBase", Size = Vector3.new(0.7, 1.4, 0.5), CFrame = at(t, y0 + 9, 1.45), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
			local bulb = deco({
				Name = "SconceBulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1),
				CFrame = at(t, y0 + 10.1, 1.9),
				Color = Color3.fromRGB(255, 236, 190),
				Material = Enum.Material.Neon,
				Parent = folder,
			})
			-- In een donkere zaal branden er minder lampen en die flikkeren
			if (currentDark and i % 4 == 0) or (not currentDark and i % 2 == 0) then
				local light = Instance.new("PointLight")
				light.Color = LAMP_LIGHT
				light.Range = 18
				light.Brightness = if currentDark then 0.9 else 1.4
				light.Parent = bulb
				if currentDark then
					bulb:SetAttribute("Flicker", true)
				end
			elseif currentDark then
				bulb.Material = Enum.Material.SmoothPlastic
				bulb.Color = Color3.fromRGB(90, 80, 70)
			end
		end
		-- Boogpaneel tussen deze en de volgende pilaar
		if i < count - 1 then
			local bt = t + pillarStep / 2
			for _, y0 in levels() do
				local bayCenter = origin + along * bt + Vector3.new(0, y0, 0)
				if not (skipBay and skipBay(bayCenter, y0)) then
					local width = math.min(12, pillarStep - 6)
					deco({
						Name = "ArchPanel",
						Size = Vector3.new(width, 9, 0.2),
						CFrame = at(bt, y0 + 7.5, 0.1),
						Color = WALL_PANEL,
						Material = Enum.Material.Plaster,
						Parent = folder,
					})
					deco({
						Name = "ArchTop",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.1, width, width),
						CFrame = at(bt, y0 + 12, 0.1) * CFrame.Angles(0, math.rad(90), 0),
						Color = WALL_PANEL,
						Material = Enum.Material.Plaster,
						Parent = folder,
					})
					-- Rand rond de boog
					deco({
						Name = "ArchRim",
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new(0.08, width + 1, width + 1),
						CFrame = at(bt, y0 + 12, 0.04) * CFrame.Angles(0, math.rad(90), 0),
						Color = PILLAR,
						Material = Enum.Material.Wood,
						Parent = folder,
					})
				end
			end
		end
	end
end

local function buildRoof(folder: Folder)
	local hx, hz = Map.HalfX + 2, Map.HalfZ + 2
	local y = Map.WallHeight + 1
	-- Dakraam in het midden: x -70..70, z -30..30
	local sx0, sx1, sz0, sz1 = -70, 70, -30, 30
	local pieces = {
		{ -hx, hx, -hz, sz0 },
		{ -hx, hx, sz1, hz },
		{ -hx, sx0, sz0, sz1 },
		{ sx1, hx, sz0, sz1 },
	}
	for i, r in pieces do
		part({
			Name = "Roof" .. i,
			Size = Vector3.new(r[2] - r[1], 2, r[4] - r[3]),
			Position = Vector3.new((r[1] + r[2]) / 2, y, (r[3] + r[4]) / 2),
			Color = WALL,
			Material = Enum.Material.Plaster,
			Parent = folder,
		})
	end
	part({
		Name = "Skylight",
		Size = Vector3.new(sx1 - sx0, 0.4, sz1 - sz0),
		Position = Vector3.new(0, y - 0.2, 0),
		Color = Color3.fromRGB(200, 225, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		CastShadow = false,
		Parent = folder,
	})
	-- Houten balken over het dakraam
	for x = sx0, sx1, 20 do
		deco({ Name = "Beam", Size = Vector3.new(1.4, 1.6, sz1 - sz0 + 2), Position = Vector3.new(x, y - 0.6, 0), Color = MOULDING, Material = Enum.Material.Wood, Parent = folder })
	end
	for _, z in { sz0, sz1 } do
		deco({ Name = "Beam", Size = Vector3.new(sx1 - sx0 + 2, 1.6, 1.4), Position = Vector3.new(0, y - 0.6, z), Color = MOULDING, Material = Enum.Material.Wood, Parent = folder })
	end

	-- Paarse boom boven het dakraam (zoals op de screenshot)
	local trunk = Color3.fromRGB(70, 45, 40)
	local function branch(a: Vector3, b: Vector3, thickness: number)
		deco({
			Name = "Branch",
			Size = Vector3.new(thickness, thickness, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = trunk,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	branch(Vector3.new(-180, -2, -20), Vector3.new(-112, 64, -10), 6)
	branch(Vector3.new(-112, 64, -10), Vector3.new(-40, 66, -6), 3.5)
	branch(Vector3.new(-112, 64, -10), Vector3.new(-70, 72, 18), 3)
	branch(Vector3.new(-60, 64, -8), Vector3.new(-20, 70, -24), 2)
	local purple = { Color3.fromRGB(150, 92, 205), Color3.fromRGB(122, 74, 182), Color3.fromRGB(176, 116, 222) }
	local blobs = {
		{ Vector3.new(-40, 70, -6), 26 },
		{ Vector3.new(-70, 76, 18), 24 },
		{ Vector3.new(-16, 74, -24), 20 },
		{ Vector3.new(-95, 66, -12), 22 },
		{ Vector3.new(-50, 80, 10), 22 },
		{ Vector3.new(-5, 66, 4), 16 },
	}
	for i, blob in blobs do
		deco({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(blob[2], blob[2], blob[2]),
			Position = blob[1],
			Color = purple[(i - 1) % #purple + 1],
			Material = Enum.Material.LeafyGrass,
			Parent = folder,
		})
	end
end

local function buildStructure(parent: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Structure"
	folder.Parent = parent

	local hx, hz = Map.HalfX, Map.HalfZ
	buildFloors(folder)
	buildRoof(folder)

	-- Bij de voordeur (midden van de voormuur, begane grond) geen boogpaneel
	local function skipDoor(center: Vector3, y0: number): boolean
		return y0 == 0 and math.abs(center.X) < 10 and center.Z > 0
	end
	buildWall(folder, Vector3.new(0, 0, hz), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), hx * 2, 20, skipDoor)
	buildWall(folder, Vector3.new(0, 0, -hz), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), hx * 2, 20)
	buildWall(folder, Vector3.new(hx, 0, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), hz * 2, 20)
	buildWall(folder, Vector3.new(-hx, 0, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), hz * 2, 20)

	-- Balie bij de ingang met een stapeltje boeken
	noBooks(part({
		Name = "Desk",
		Size = Vector3.new(16, 3.5, 3),
		Position = Vector3.new(0, 1.75, 58),
		Color = PILLAR,
		Material = Enum.Material.Wood,
		Parent = folder,
	}))
	deco({ Name = "DeskTop", Size = Vector3.new(16.6, 0.3, 3.6), Position = Vector3.new(0, 3.6, 58), Color = MOULDING, Material = Enum.Material.Wood, Parent = folder })
	for i, color in { Color3.fromRGB(40, 80, 150), Color3.fromRGB(150, 40, 50), Color3.fromRGB(60, 130, 70) } do
		deco({
			Name = "DeskBook",
			Size = Vector3.new(1.6, 0.4, 2.1),
			CFrame = CFrame.new(-5, 3.95 + (i - 1) * 0.4, 58) * CFrame.Angles(0, math.rad(i * 17), 0),
			Color = color,
			Parent = folder,
		})
	end

	-- Voordeur met het naambord erboven
	deco({
		Name = "FrontDoor",
		Size = Vector3.new(14, 18, 0.5),
		Position = Vector3.new(0, 9, hz - 0.2),
		Color = MOULDING,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({
		Name = "DoorFrame",
		Size = Vector3.new(16, 19, 0.3),
		Position = Vector3.new(0, 9.5, hz - 0.05),
		Color = PILLAR,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	local title = deco({
		Name = "TitleSign",
		Size = Vector3.new(30, 3, 0.3),
		Position = Vector3.new(0, 20.2, hz - 0.3),
		Color = PLAQUE,
		Parent = folder,
	})
	local gui = surfaceGui(title, Enum.NormalId.Front, 30)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "📖 Clean The Library"
	label.Parent = gui

	-- Kleed bij de ingang
	deco({ Name = "Rug", Size = Vector3.new(26, 0.1, 12), Position = Vector3.new(0, 0.05, 68), Color = MOULDING, Material = Enum.Material.Fabric, Parent = folder })
	deco({ Name = "RugBorder", Size = Vector3.new(28, 0.08, 14), Position = Vector3.new(0, 0.04, 68), Color = GOLD, Material = Enum.Material.Fabric, Parent = folder })
end

----------------------------------------------------------------------------
-- Kasten
----------------------------------------------------------------------------

-- Eén boogkast (10 breed). Voorkant is +Z.
local function buildCabinet(parent: Model, cf: CFrame)
	local H, D = Map.CaseHeight, Map.CaseDepth
	local W = Map.CaseLength / 3
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3?)
		local p = part({
			Name = name,
			Size = size,
			CFrame = cf * CFrame.new(offset),
			Color = color or CASE_WOOD,
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		noBooks(p)
		return p
	end
	piece("Back", Vector3.new(W - 0.4, H, 0.4), Vector3.new(0, H / 2, -D / 2 + 0.2), CASE_BACK)
	piece("SideL", Vector3.new(0.5, H, D), Vector3.new(-W / 2 + 0.25, H / 2, 0))
	piece("SideR", Vector3.new(0.5, H, D), Vector3.new(W / 2 - 0.25, H / 2, 0))
	for i, y in { 0.15, 2.9, 5.65, 8.4 } do
		piece("Shelf" .. i, Vector3.new(W - 0.6, 0.3, D - 0.2), Vector3.new(0, y, 0))
	end
	piece("Top", Vector3.new(W + 0.2, 0.6, D + 0.3), Vector3.new(0, H + 0.1, 0), PILLAR)
	-- Plint
	piece("Plinth", Vector3.new(W, 0.6, D + 0.2), Vector3.new(0, 0.3, 0.05), PILLAR)
	-- Boog bovenop, met een lichtere rand eromheen
	noBooks(part({
		Name = "Arch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, W - 0.6, W - 0.6),
		CFrame = cf * CFrame.new(0, H + 0.4, -D / 2 + 0.3) * CFrame.Angles(0, math.rad(90), 0),
		Color = CASE_BACK,
		Material = Enum.Material.Wood,
		Parent = parent,
	}))
	noBooks(part({
		Name = "ArchRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, W + 0.2, W + 0.2),
		CFrame = cf * CFrame.new(0, H + 0.4, -D / 2 + 0.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = PILLAR,
		Material = Enum.Material.Wood,
		Parent = parent,
	}))
end

local function buildSection(parent: Folder, section: Config.Section, index: number, slot: number, booksPerSection: number): SectionData
	local col = (slot - 1) % #Map.GridX + 1
	local row = math.floor((slot - 1) / #Map.GridX) + 1
	local floorY = if section.Floor == 1 then 0 else F2
	local center = CFrame.new(Map.GridX[col], floorY, Map.GridZ[row])
	local color = Config.SectionColor(index)
	local W = Map.CaseLength / 3
	local H, D = Map.CaseHeight, Map.CaseDepth

	local model = Instance.new("Model")
	model.Name = "Section_" .. section.Code
	model:SetAttribute("Code", section.Code)
	model.Parent = parent

	local counters = {}
	for i = -1, 1 do
		local cf = center * CFrame.new(i * W, 0, 0)
		buildCabinet(model, cf)
		-- Naambordjes voor op de boog (voor- en achterkant)
		for _, side in { 1, -1 } do
			local holder = part({
				Name = "Plaque",
				Size = Vector3.new(4.4, 2.2, 0.1),
				CFrame = cf * CFrame.new(0, H + 2.7, -D / 2 + 0.3 + side * 0.32),
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = model,
			})
			-- Back = +Z (voorkant van de kast), Front = -Z (achterkant)
			local face = if side == 1 then Enum.NormalId.Back else Enum.NormalId.Front
			local counter = plaque(holder, face, section.Code, i == 0)
			if counter then
				table.insert(counters, counter)
			end
		end
	end

	-- Lege plekken die opvullen als je boeken terugzet
	local slots = {}
	local n = booksPerSection
	local levels = { 0.3, 3.05, 5.8 }
	local perLevel = math.ceil(n / #levels)
	local spacing = (Map.CaseLength - 4) / perLevel
	for i = 1, n do
		local level = math.floor((i - 1) / perLevel) + 1
		local pos = (i - 1) % perLevel
		local x = -Map.CaseLength / 2 + 2 + spacing * (pos + 0.5)
		local ghost = part({
			Name = "Slot" .. i,
			Size = Vector3.new(0.6, 2.1, 1.8),
			CFrame = center * CFrame.new(x, levels[level] + 1.1, 0.2),
			Color = Color3.fromRGB(255, 245, 225),
			Material = Enum.Material.Glass,
			Transparency = 0.75,
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
		Size = Vector3.new(Map.CaseLength, H, 1),
		CFrame = center * CFrame.new(0, H / 2, D / 2 + 0.6),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local title = string.format("%s  %s", section.Code, section.Name)
	local prompts = {}
	for _, x in { -10, 0, 10 } do
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(x, -2, 0)
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
		Counters = counters,
	}
end

----------------------------------------------------------------------------
-- Meubels
----------------------------------------------------------------------------

local function buildTable(parent: Folder, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "ReadingTable"
	model.Parent = parent
	local top = part({
		Name = "Top",
		Size = Vector3.new(14, 0.5, 6),
		Position = pos + Vector3.new(0, 3, 0),
		Color = PILLAR,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	bookSurface(top)
	for _, o in { Vector3.new(-6.3, 0, -2.4), Vector3.new(6.3, 0, -2.4), Vector3.new(-6.3, 0, 2.4), Vector3.new(6.3, 0, 2.4) } do
		noBooks(part({
			Name = "Leg",
			Size = Vector3.new(0.6, 2.75, 0.6),
			Position = pos + o + Vector3.new(0, 1.375, 0),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
			Parent = model,
		}))
	end
	-- Groene bureaulamp
	deco({ Name = "LampBase", Size = Vector3.new(0.9, 0.2, 0.9), Position = pos + Vector3.new(0, 3.35, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = model })
	deco({ Name = "LampStem", Size = Vector3.new(0.15, 1.2, 0.15), Position = pos + Vector3.new(0, 3.95, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = model })
	local shade = deco({
		Name = "LampShade",
		Size = Vector3.new(1.8, 0.5, 0.8),
		Position = pos + Vector3.new(0, 4.6, 0),
		Color = Color3.fromRGB(40, 120, 80),
		Material = Enum.Material.Glass,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = LAMP_LIGHT
	light.Range = 12
	light.Brightness = 1
	light.Parent = shade
	-- Stoelen
	for _, z in { -4.5, 4.5 } do
		for _, x in { -4, 4 } do
			noBooks(part({ Name = "ChairSeat", Size = Vector3.new(2.2, 0.4, 2.2), Position = pos + Vector3.new(x, 1.8, z), Color = MOULDING, Material = Enum.Material.Fabric, Parent = model }))
			deco({ Name = "ChairBack", Size = Vector3.new(2.2, 2.4, 0.3), Position = pos + Vector3.new(x, 3.2, z + math.sign(z) * 1), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = model })
		end
	end
end

local function buildPlant(parent: Folder, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Plant"
	model.Parent = parent
	noBooks(part({
		Name = "Vase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(160, 178, 112),
		Material = Enum.Material.Marble,
		Parent = model,
	}))
	deco({
		Name = "VaseRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2.4, 2.4),
		CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 160, 96),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	for i = 1, 9 do
		local yaw = math.rad(i * 40 + math.random(-10, 10))
		local tilt = math.rad(math.random(15, 40))
		local len = math.random(30, 50) / 10
		deco({
			Name = "Leaf",
			Size = Vector3.new(0.7, len, 0.12),
			CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, len / 2, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(70, 150, 70) else Color3.fromRGB(110, 175, 80),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
end

-- Houten kast om je in te verstoppen
local function buildLocker(parent: Folder, pos: Vector3, facing: Vector3): LockerData
	local model = Instance.new("Model")
	model.Name = "Wardrobe"
	model.Parent = parent
	local base = CFrame.lookAt(pos, pos + facing)
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3?)
		local p = part({
			Name = name,
			Size = size,
			CFrame = base * CFrame.new(offset),
			Color = color or CASE_WOOD,
			Material = Enum.Material.Wood,
			Parent = model,
		})
		noBooks(p)
		return p
	end
	-- Voorkant = -Z (CFrame.lookAt kijkt langs -Z)
	piece("Back", Vector3.new(4.6, 8.5, 0.4), Vector3.new(0, 4.25, 2))
	piece("Left", Vector3.new(0.4, 8.5, 4.4), Vector3.new(-2.1, 4.25, 0))
	piece("Right", Vector3.new(0.4, 8.5, 4.4), Vector3.new(2.1, 4.25, 0))
	piece("Roof", Vector3.new(5, 0.6, 4.8), Vector3.new(0, 8.6, 0), PILLAR)
	local door = piece("Door", Vector3.new(3.8, 8, 0.3), Vector3.new(0, 4.2, -2), CASE_BACK)
	-- Deurpaneeltjes en knop
	for _, y in { 2.3, 6 } do
		deco({ Name = "DoorPanel", Size = Vector3.new(2.8, 2.8, 0.08), CFrame = base * CFrame.new(0, y, -2.18), Color = CASE_WOOD, Material = Enum.Material.Wood, Parent = model })
	end
	deco({
		Name = "Knob",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.35, 0.35, 0.35),
		CFrame = base * CFrame.new(1.4, 4.2, -2.25),
		Color = GOLD,
		Material = Enum.Material.Metal,
		Parent = model,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Verstoppen"
	prompt.ObjectText = "Kast"
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
	-- Hangende kroonluchters op de begane grond
	local ceiling = if currentFloors >= 2 then F2 - 2 else Map.WallHeight
	local index = 0
	for x = -100, 100, 50 do
		for z = -60, 60, 40 do
			index += 1
			local y = if currentFloors >= 2 then F2 - 4.5 else 30
			local chain = ceiling - (y + 0.6)
			deco({ Name = "Chain", Size = Vector3.new(0.15, chain, 0.15), Position = Vector3.new(x, y + 0.6 + chain / 2, z), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
			deco({ Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3, 3), CFrame = CFrame.new(x, y + 0.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
			local lamp = deco({
				Name = "Lamp",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.8, 1.8, 1.8),
				Position = Vector3.new(x, y, z),
				Color = Color3.fromRGB(255, 236, 190),
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			local light = Instance.new("PointLight")
			light.Color = LAMP_LIGHT
			light.Range = 30
			light.Brightness = if currentDark then 0.7 else 1.2
			light.Parent = lamp
			if currentDark and index % 3 == 0 then
				lamp:SetAttribute("Flicker", true)
			end
		end
	end
end

local function isInsideRect(pos: Vector3, x0: number, x1: number, z0: number, z1: number): boolean
	return pos.X >= x0 and pos.X <= x1 and pos.Z >= z0 and pos.Z <= z1
end

function LibraryBuilder.Build(room: Config.RoomInfo, parent: Instance): Library
	currentFloors = room.Floors
	currentDark = room.Dark
	local offset = room.Offset

	local model = Instance.new("Model")
	model.Name = room.Id
	model:SetAttribute("RoomId", room.Id)
	model:SetAttribute("Dark", room.Dark)

	buildStructure(model)

	-- Deur terug naar de hal
	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ActionText = "Terug naar de hal"
	exitPrompt.ObjectText = "Deur"
	exitPrompt.HoldDuration = 0.5
	exitPrompt.MaxActivationDistance = 12
	exitPrompt.RequiresLineOfSight = false
	exitPrompt.Parent = model:FindFirstChild("FrontDoor", true)

	local sectionsFolder = Instance.new("Folder")
	sectionsFolder.Name = "Sections"
	sectionsFolder.Parent = model

	local sections: { [string]: SectionData } = {}
	local usedSlots = { [1] = 0, [2] = 0 }
	for _, entry in Config.RoomSections(room) do
		local section = entry.Section
		usedSlots[section.Floor] += 1
		sections[section.Code] = buildSection(sectionsFolder, section, entry.Index, usedSlots[section.Floor], room.BooksPerSection)
	end

	-- Leestafels op de overgebleven plekken in het rooster
	local furniture = Instance.new("Folder")
	furniture.Name = "Furniture"
	furniture.Parent = model
	local slotCount = #Map.GridX * #Map.GridZ
	for floor = 1, room.Floors do
		for slot = usedSlots[floor] + 1, slotCount do
			local col = (slot - 1) % #Map.GridX + 1
			local row = math.floor((slot - 1) / #Map.GridX) + 1
			local y = if floor == 1 then 0 else F2
			buildTable(furniture, Vector3.new(Map.GridX[col], y, Map.GridZ[row]))
		end
	end
	-- Extra tafels in de hal bij de ingang
	buildTable(furniture, Vector3.new(-60, 0, 62))
	buildTable(furniture, Vector3.new(60, 0, 62))
	if room.Floors >= 2 then
		buildTable(furniture, Vector3.new(-60, F2, 62))
		buildTable(furniture, Vector3.new(40, F2, 62))
	end

	-- Planten
	local plantSpots = {
		Vector3.new(-115, 0, 75),
		Vector3.new(115, 0, 75),
		Vector3.new(115, 0, -75),
		Vector3.new(-30, 0, 76),
		Vector3.new(30, 0, 76),
		Vector3.new(-11, 0, 58),
		Vector3.new(11, 0, 58),
		Vector3.new(-115, F2, 75),
		Vector3.new(115, F2, 75),
		Vector3.new(115, F2, -75),
		Vector3.new(0, F2, 76),
		Vector3.new(-60, F2, -77),
		Vector3.new(-115, F2, 0),
		Vector3.new(60, 0, -77),
	}
	for _, spot in plantSpots do
		if spot.Y < 1 or room.Floors >= 2 then
			buildPlant(furniture, spot)
		end
	end

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
		{ Vector3.new(117, F2, -60), Vector3.new(-1, 0, 0) },
		{ Vector3.new(80, F2, 77), Vector3.new(0, 0, -1) },
	}
	for _, spot in lockerSpots do
		if spot[1].Y < 1 or room.Floors >= 2 then
			local locker = buildLocker(lockersFolder, spot[1], spot[2])
			locker.Inside += offset
			locker.Outside += offset
			table.insert(lockers, locker)
		end
	end

	local books = Instance.new("Folder")
	books.Name = "Books"
	books.Parent = model

	-- Patrouillepunten voor het monster (in de gangpaden, beide verdiepingen)
	local waypoints = {}
	for floor = 1, room.Floors do
		local y = (if floor == 1 then 0 else F2) + 3
		for _, x in { -108, -60, -20, 20, 60 } do
			for _, z in { 50, 20, -10, -40, -70 } do
				table.insert(waypoints, Vector3.new(x, y, z))
			end
		end
	end
	table.insert(waypoints, Vector3.new(116, 3, 0))
	if room.Floors >= 2 then
		table.insert(waypoints, Vector3.new(106, 3, 76))
		table.insert(waypoints, Vector3.new(106, F2 + 3, 18))
	end
	for i, point in waypoints do
		waypoints[i] = point + offset
	end

	local keySpots = if room.Floors >= 2
		then {
			Crimson = Vector3.new(106, 1.5, 40), -- onder de oprit
			Golden = Vector3.new(-116, F2 + 1.5, -77), -- achterste hoek boven
			Azure = Vector3.new(-80, 1.5, -77), -- achter de laatste kastenrij beneden
			Emerald = Vector3.new(-40, F2 + 1.5, -58.5), -- achter het Verboden Archief
		}
		else {
			Crimson = Vector3.new(110, 1.5, 40),
			Golden = Vector3.new(-118, 1.5, 20),
			Azure = Vector3.new(-80, 1.5, -77),
			Emerald = Vector3.new(40, 4.8, -55), -- op een leestafel
		}
	for id, spot in keySpots do
		keySpots[id] = spot + offset
	end
	for _, section in sections do
		section.Center += offset
	end

	-- Alles naar de plek van deze zaal schuiven en pas dan in de wereld zetten,
	-- zodat het in één keer bij de spelers aankomt
	model.WorldPivot = CFrame.new()
	model:PivotTo(CFrame.new(offset))
	model.Parent = parent

	local library = {
		Model = model,
		Books = books,
		Offset = offset,
		SpawnCFrame = CFrame.new(Vector3.new(0, 3.5, 66) + offset),
		ExitPrompt = exitPrompt,
		Sections = sections,
		Lockers = lockers,
		Waypoints = waypoints,
		KeySpots = keySpots,
		MonsterSpawn = Vector3.new(0, (if room.Floors >= 2 then F2 else 0) + 6, -70) + offset,
	}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { model }

	local function blockedSpot(probe: Vector3): boolean
		return isInsideRect(probe, 97, 115, 20, 76) -- oprit
			or isInsideRect(probe, -9, 9, 55, 80) -- balie en spawn
	end

	-- x en z zijn hier coördinaten binnen de zaal (zonder offset)
	local function surfaceAt(x: number, z: number, topY: number, params: RaycastParams): CFrame?
		if blockedSpot(Vector3.new(x, 0, z)) then
			return nil
		end
		local result = Workspace:Raycast(Vector3.new(x, topY, z) + offset, Vector3.new(0, -30, 0), params)
		if not result then
			return nil
		end
		local hit = result.Instance
		if hit:GetAttribute("BookSurface") or hit:GetAttribute("IsBook") then
			local yaw = math.rad(math.random(0, 359))
			return CFrame.new(result.Position) * CFrame.Angles(0, yaw, 0)
		end
		return nil
	end

	-- Zoekt een willekeurige plek op een vloer of tafel voor een boek.
	-- Geeft de CFrame van het oppervlak terug (het boek zet zichzelf erop).
	function library.RandomBookSpot(_self: Library): CFrame
		for _ = 1, 60 do
			local floor = math.random(1, room.Floors)
			local x = math.random(-Map.HalfX + 3, Map.HalfX - 3) + math.random()
			local z = math.random(-Map.HalfZ + 3, Map.HalfZ - 3) + math.random()
			local topY = if floor == 1 then F2 - 3 else Map.WallHeight - 4
			local spot = surfaceAt(x, z, topY, rayParams)
			if spot then
				return spot
			end
		end
		return CFrame.new(Vector3.new(0, 0, 50) + offset)
	end

	-- Plek in de buurt van een punt; met `extra` (bijv. de map met boeken) erbij
	-- kunnen boeken op elkaar komen te liggen, zodat er stapels ontstaan.
	function library.BookSpotNear(_self: Library, center: Vector3, radius: number, extra: Instance?): CFrame?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = if extra then { model, extra } else { model }
		local localCenter = center - offset
		local floorY = if localCenter.Y >= F2 - 1 then F2 else 0
		local topY = if floorY == 0 then F2 - 3 else Map.WallHeight - 4
		for _ = 1, 12 do
			local angle = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * radius
			local spot = surfaceAt(localCenter.X + math.cos(angle) * r, localCenter.Z + math.sin(angle) * r, topY, params)
			if spot and spot.Position.Y - offset.Y < floorY + 6 then
				return spot
			end
		end
		return nil
	end

	return library
end

return LibraryBuilder
