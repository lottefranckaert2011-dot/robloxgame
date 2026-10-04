-- Bouwt de hal waar je begint: blauwe muren met boogramen, een paars gewelf
-- met houten ribben en een kroonluchter, een reuzenboek als kleed, en
-- achterin een deur met een gloeiende portaalring voor elke zaal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LobbyBuilder = {}

export type Door = {
	Room: Config.RoomInfo,
	Prompt: ProximityPrompt,
	Zone: BasePart,
	Info: TextLabel,
}

export type Lobby = {
	Model: Model,
	SpawnCFrame: CFrame,
	Doors: { [string]: Door },
}

local HX, HZ = 70, 50 -- halve breedte en diepte
local WALL_H = 26 -- hoogte van de zijmuren
local RIDGE_H = 44 -- hoogte van de nok

local WALL = Color3.fromRGB(72, 94, 128)
local WAINSCOT = Color3.fromRGB(110, 58, 34)
local TRIM = Color3.fromRGB(214, 128, 66)
local CEILING = Color3.fromRGB(96, 78, 176)
local RIB = Color3.fromRGB(196, 110, 58)
local FLOOR = Color3.fromRGB(182, 92, 44)
local GOLD = Color3.fromRGB(230, 186, 96)
local CREAM = Color3.fromRGB(240, 226, 196)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
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

local function deco(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props)
end

-- Grote tekst met een rand, zoals de borden in het origineel
local function signText(p: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(25, 20, 40)
	stroke.Thickness = 4
	stroke.Parent = label
	return label
end

local function buildShell(folder: Folder)
	part({
		Name = "Floor",
		Size = Vector3.new(HX * 2, 2, HZ * 2),
		Position = Vector3.new(0, -1, 0),
		Color = FLOOR,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	-- Zijmuren (met ramen) en voor-/achtermuur tot aan de nok
	for _, side in { -1, 1 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(2, WALL_H + 2, HZ * 2 + 4),
			Position = Vector3.new(side * (HX + 1), WALL_H / 2 - 1, 0),
			Color = WALL,
			Material = Enum.Material.Plaster,
			Parent = folder,
		})
		part({
			Name = "EndWall",
			Size = Vector3.new(HX * 2 + 4, RIDGE_H + 4, 2),
			Position = Vector3.new(0, RIDGE_H / 2, side * (HZ + 1)),
			Color = WALL,
			Material = Enum.Material.Plaster,
			Parent = folder,
		})
	end

	-- Lambrisering en lijsten langs alle muren
	local runs = {
		{ Vector3.new(HX * 2, 0, 0), Vector3.new(0, 0, HZ - 0.3), Vector3.new(1, 0, 0) },
		{ Vector3.new(HX * 2, 0, 0), Vector3.new(0, 0, -HZ + 0.3), Vector3.new(1, 0, 0) },
		{ Vector3.new(0, 0, HZ * 2), Vector3.new(HX - 0.3, 0, 0), Vector3.new(0, 0, 1) },
		{ Vector3.new(0, 0, HZ * 2), Vector3.new(-HX + 0.3, 0, 0), Vector3.new(0, 0, 1) },
	}
	for _, run in runs do
		local length = run[1].Magnitude
		local alongX = run[3].X ~= 0
		local function band(name: string, height: number, y: number, depth: number, color: Color3)
			deco({
				Name = name,
				Size = if alongX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length),
				Position = run[2] + Vector3.new(0, y, 0),
				Color = color,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
		band("Wainscot", 4, 2, 0.6, WAINSCOT)
		band("ChairRail", 0.5, 4.2, 0.9, TRIM)
		band("Crown", 1.4, WALL_H - 0.7, 1.2, TRIM)
	end

	-- Gewelf: twee schuine helften met de nok in het midden (langs Z)
	local rise = RIDGE_H - WALL_H
	local slopeLength = math.sqrt(HX * HX + rise * rise)
	local angle = math.atan2(rise, HX)
	for _, side in { -1, 1 } do
		local center = Vector3.new(side * HX / 2, WALL_H + rise / 2, 0)
		local tilt = CFrame.new(center) * CFrame.Angles(0, 0, side * -angle)
		part({
			Name = "Vault",
			Size = Vector3.new(slopeLength + 2, 1, HZ * 2 + 2),
			CFrame = tilt * CFrame.new(0, 0.5, 0),
			Color = CEILING,
			Material = Enum.Material.Plaster,
			Parent = folder,
		})
		-- Houten ribben over het gewelf
		for z = -HZ + 5, HZ - 5, 12.5 do
			deco({
				Name = "Rib",
				Size = Vector3.new(slopeLength, 1.2, 1.4),
				CFrame = tilt * CFrame.new(0, -0.6, z),
				Color = RIB,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
		-- Schuine kruisribben
		for _, dir in { -1, 1 } do
			local a = Vector3.new(side * HX, WALL_H, dir * HZ)
			local b = Vector3.new(0, RIDGE_H - 0.6, 0)
			local mid = (a + b) / 2
			deco({
				Name = "CrossRib",
				Size = Vector3.new(1, 1, (b - a).Magnitude),
				CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -1.2, 0),
				Color = RIB,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	deco({ Name = "Ridge", Size = Vector3.new(2, 1.5, HZ * 2), Position = Vector3.new(0, RIDGE_H - 0.6, 0), Color = RIB, Material = Enum.Material.Wood, Parent = folder })
end

-- Hoog boograam met een raamkruis
local function buildWindow(folder: Folder, x: number, z: number)
	local side = math.sign(x)
	local face = x - side * 0.1
	local function at(y: number, depth: number): CFrame
		return CFrame.new(face - side * depth, y, z) * CFrame.Angles(0, math.rad(90), 0)
	end
	local width, top = 8, 18
	deco({ Name = "WindowFrame", Size = Vector3.new(width + 1.6, top - 5 + 0.8, 0.3), CFrame = at((5 + top) / 2, 0.05), Color = GOLD, Material = Enum.Material.Wood, Parent = folder })
	deco({
		Name = "WindowFrameTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, width + 1.6, width + 1.6),
		CFrame = at(top, 0.05) * CFrame.Angles(0, math.rad(90), 0),
		Color = GOLD,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({
		Name = "Glass",
		Size = Vector3.new(width, top - 5, 0.2),
		CFrame = at((5 + top) / 2, 0.2),
		Color = Color3.fromRGB(170, 215, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		Parent = folder,
	})
	deco({
		Name = "GlassTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, width, width),
		CFrame = at(top, 0.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(170, 215, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		Parent = folder,
	})
	-- Raamkruis en waaier bovenin
	deco({ Name = "Mullion", Size = Vector3.new(0.4, top - 5 + width / 2, 0.2), CFrame = at((5 + top + width / 2) / 2, 0.35), Color = CREAM, Parent = folder })
	for _, y in { 9, 13.5 } do
		deco({ Name = "Transom", Size = Vector3.new(width, 0.4, 0.2), CFrame = at(y, 0.35), Color = CREAM, Parent = folder })
	end
	for i = -2, 2 do
		deco({
			Name = "Fan",
			Size = Vector3.new(0.3, width / 2, 0.2),
			CFrame = at(top, 0.35) * CFrame.Angles(0, 0, math.rad(i * 30)) * CFrame.new(0, width / 4, 0),
			Color = CREAM,
			Parent = folder,
		})
	end
end

local function buildChandelier(folder: Folder, position: Vector3)
	local chain = RIDGE_H - 1 - (position.Y + 1)
	deco({ Name = "Chain", Size = Vector3.new(0.2, chain, 0.2), Position = position + Vector3.new(0, 1 + chain / 2, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	deco({ Name = "Stem", Size = Vector3.new(0.8, 3, 0.8), Position = position, Color = CREAM, Material = Enum.Material.Metal, Parent = folder })
	deco({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = CFrame.new(position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = CREAM,
		Material = Enum.Material.Metal,
		Parent = folder,
	})
	for i = 1, 8 do
		local a = math.rad(i * 45)
		local p = position + Vector3.new(math.cos(a) * 3.4, -0.2, math.sin(a) * 3.4)
		deco({ Name = "Candle", Size = Vector3.new(0.35, 1.2, 0.35), Position = p, Color = Color3.fromRGB(250, 245, 230), Parent = folder })
		deco({
			Name = "Flame",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.4, 0.4, 0.4),
			Position = p + Vector3.new(0, 0.8, 0),
			Color = Color3.fromRGB(255, 210, 120),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
	end
	local glow = deco({ Name = "Glow", Size = Vector3.new(1, 1, 1), Position = position - Vector3.new(0, 1.5, 0), Transparency = 1, Parent = folder })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Range = 50
	light.Brightness = 1.8
	light.Shadows = true
	light.Parent = glow
end

-- Schilderij boven de deuren
local function buildPainting(folder: Folder)
	local frame = deco({
		Name = "PaintingFrame",
		Size = Vector3.new(46, 11, 0.4),
		Position = Vector3.new(0, 35, -HZ + 0.3),
		Color = GOLD,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	local canvas = deco({
		Name = "Painting",
		Size = Vector3.new(44, 9, 0.2),
		Position = Vector3.new(0, 35, -HZ + 0.55),
		Color = Color3.new(1, 1, 1),
		Parent = folder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0.3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = canvas
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(120, 150, 210), Color3.fromRGB(240, 196, 200))
	gradient.Parent = sky
	-- Heuvels en een kasteel als silhouet
	local function shape(x: number, y: number, w: number, h: number, color: Color3, rotation: number?)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.Parent = sky
		return f
	end
	local hill = Color3.fromRGB(80, 90, 110)
	shape(0.2, 0.95, 0.6, 0.5, hill, 8)
	shape(0.75, 0.98, 0.7, 0.5, Color3.fromRGB(70, 80, 100), -6)
	shape(0.62, 0.62, 0.05, 0.3, Color3.fromRGB(60, 62, 80))
	shape(0.7, 0.58, 0.06, 0.38, Color3.fromRGB(60, 62, 80))
	shape(0.78, 0.64, 0.05, 0.26, Color3.fromRGB(60, 62, 80))
	shape(0.7, 0.72, 0.2, 0.2, Color3.fromRGB(60, 62, 80))
	local sun = shape(0.22, 0.3, 0.07, 0.3, Color3.fromRGB(255, 236, 190))
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = sun
	return frame
end

-- Reuzenboek als kleed in het midden
local function buildBigBook(folder: Folder)
	local center = Vector3.new(0, 0, 8)
	-- Laag gehouden zodat je er gewoon overheen loopt
	deco({ Name = "BigBookPages", Size = Vector3.new(33, 0.3, 23.4), Position = center + Vector3.new(0.6, 0.15, 0), Color = CREAM, Parent = folder })
	local cover = part({
		Name = "BigBookCover",
		Size = Vector3.new(34, 0.15, 24),
		Position = center + Vector3.new(0, 0.37, 0),
		Color = Color3.fromRGB(40, 104, 80),
		Material = Enum.Material.Fabric,
		Parent = folder,
	})
	deco({ Name = "BigBookSpine", Size = Vector3.new(2, 0.2, 24), Position = center + Vector3.new(-16.5, 0.4, 0), Color = Color3.fromRGB(28, 80, 60), Material = Enum.Material.Fabric, Parent = folder })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = cover
	for _, y in { 0.1, 0.86 } do
		local band = Instance.new("Frame")
		band.Position = UDim2.fromScale(0.08, y)
		band.Size = UDim2.fromScale(0.84, 0.03)
		band.BorderSizePixel = 0
		band.BackgroundColor3 = GOLD
		band.Parent = gui
	end
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0.1, 0.2)
	title.Size = UDim2.fromScale(0.8, 0.6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Garamond
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.Text = "Shush!\nThe Midnight\nLibrary"
	title.Parent = gui
end

local function buildPlant(folder: Folder, position: Vector3)
	part({
		Name = "Vase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.2, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(160, 178, 112),
		Material = Enum.Material.Marble,
		Parent = folder,
	})
	for i = 1, 9 do
		local len = math.random(35, 55) / 10
		deco({
			Name = "Leaf",
			Size = Vector3.new(0.8, len, 0.12),
			CFrame = CFrame.new(position + Vector3.new(0, 3.2, 0))
				* CFrame.Angles(0, math.rad(i * 40), 0)
				* CFrame.Angles(math.rad(math.random(15, 40)), 0, 0)
				* CFrame.new(0, len / 2, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(70, 150, 70) else Color3.fromRGB(110, 175, 80),
			Parent = folder,
		})
	end
end

-- Kraam met een zwevend bord (Winkel / Magie). De prompt opent het venster op de client.
local function buildStand(folder: Folder, position: Vector3, facing: Vector3, title: string, color: Color3, panel: string)
	local base = CFrame.lookAt(position, position + facing)
	local counter = part({
		Name = "Stand",
		Size = Vector3.new(12, 3.5, 4),
		CFrame = base * CFrame.new(0, 1.75, 0),
		Color = TRIM,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({ Name = "StandTop", Size = Vector3.new(12.6, 0.4, 4.6), CFrame = base * CFrame.new(0, 3.7, 0), Color = color, Parent = folder })
	local sign = deco({ Name = "StandSign", Size = Vector3.new(14, 4, 0.2), CFrame = base * CFrame.new(0, 10, 0), Transparency = 1, Parent = folder })
	signText(sign, Enum.NormalId.Front, title, color)
	signText(sign, Enum.NormalId.Back, title, color)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenPanel", panel)
	prompt.Parent = counter
end

local function buildDoor(folder: Folder, room: Config.RoomInfo, x: number): Door
	local z = -HZ
	local base = CFrame.new(x, 0, z + 0.4) -- voorkant (naar de hal) is +Z
	local doorW, doorH = 11, 15
	-- Gloeiende rand in de kleur van de zaal
	deco({
		Name = "DoorGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, doorW + 3, doorW + 3),
		CFrame = base * CFrame.new(0, doorH, 0.05) * CFrame.Angles(0, math.rad(90), 0),
		Color = room.Color,
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	deco({ Name = "DoorGlowRect", Size = Vector3.new(doorW + 3, doorH, 0.2), CFrame = base * CFrame.new(0, doorH / 2, 0.05), Color = room.Color, Material = Enum.Material.Neon, Parent = folder })
	-- Houten kozijn
	deco({
		Name = "DoorFrameTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, doorW + 1.6, doorW + 1.6),
		CFrame = base * CFrame.new(0, doorH, 0.2) * CFrame.Angles(0, math.rad(90), 0),
		Color = TRIM,
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({ Name = "DoorFrame", Size = Vector3.new(doorW + 1.6, doorH, 0.3), CFrame = base * CFrame.new(0, doorH / 2, 0.2), Color = TRIM, Material = Enum.Material.Wood, Parent = folder })
	-- De deur zelf (twee deurvleugels)
	local door = part({
		Name = "Door",
		Size = Vector3.new(doorW, doorH, 0.4),
		CFrame = base * CFrame.new(0, doorH / 2, 0.45),
		Color = Color3.fromRGB(90, 46, 26),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({
		Name = "DoorTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, doorW, doorW),
		CFrame = base * CFrame.new(0, doorH, 0.45) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(90, 46, 26),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	deco({ Name = "DoorSplit", Size = Vector3.new(0.2, doorH + doorW / 2, 0.1), CFrame = base * CFrame.new(0, (doorH + doorW / 2) / 2, 0.7), Color = Color3.fromRGB(50, 24, 14), Parent = folder })
	for _, side in { -1, 1 } do
		deco({
			Name = "Knob",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = base * CFrame.new(side * 1, 7, 0.8),
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = folder,
		})
	end

	-- Bord met de naam en een regel met live informatie
	local sign = deco({ Name = "DoorSign", Size = Vector3.new(30, 5, 0.2), CFrame = base * CFrame.new(0, 26, 0.3), Transparency = 1, Parent = folder })
	signText(sign, Enum.NormalId.Back, room.Name, room.Color)
	local infoPart = deco({ Name = "DoorInfo", Size = Vector3.new(30, 4.2, 0.2), CFrame = base * CFrame.new(0, 22, 0.3), Transparency = 1, Parent = folder })
	local description = signText(infoPart, Enum.NormalId.Back, room.Description, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	description.Size = UDim2.fromScale(1, 0.45)
	local info = signText(infoPart, Enum.NormalId.Back, "", Color3.fromRGB(255, 240, 160), Enum.Font.GothamBlack)
	info.Size = UDim2.fromScale(1, 0.45)
	info.Position = UDim2.fromScale(0, 0.52)

	-- Portaalring op de vloer: erin stappen = naar binnen
	local ringCenter = Vector3.new(x, 0, z + 10)
	deco({
		Name = "PortalRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 11, 11),
		CFrame = CFrame.new(ringCenter + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = room.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Parent = folder,
	})
	deco({
		Name = "PortalInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 9, 9),
		CFrame = CFrame.new(ringCenter + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = room.Color,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		Parent = folder,
	})
	local zone = part({
		Name = "PortalZone",
		Size = Vector3.new(9, 6, 9),
		Position = ringCenter + Vector3.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = folder,
	})
	zone:SetAttribute("RoomId", room.Id)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(room.Color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 25
	particles.Speed = NumberRange.new(3, 6)
	particles.SpreadAngle = Vector2.new(15, 15)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Parent = zone
	local light = Instance.new("PointLight")
	light.Color = room.Color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = zone

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = room.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	return { Room = room, Prompt = prompt, Zone = zone, Info = info }
end

function LobbyBuilder.Build(parent: Instance): Lobby
	local model = Instance.new("Model")
	model.Name = "Lobby"
	local folder = Instance.new("Folder")
	folder.Name = "Structure"
	folder.Parent = model

	buildShell(folder)
	for _, side in { -1, 1 } do
		for _, z in { -30, -10, 10, 30 } do
			buildWindow(folder, side * HX, z)
		end
	end
	buildChandelier(folder, Vector3.new(0, 30, 8))
	buildPainting(folder)
	buildBigBook(folder)
	for _, spot in { Vector3.new(-64, 0, 44), Vector3.new(64, 0, 44), Vector3.new(-64, 0, -44), Vector3.new(64, 0, -44), Vector3.new(-20, 0, -46), Vector3.new(20, 0, -46) } do
		buildPlant(folder, spot)
	end

	buildStand(folder, Vector3.new(-58, 0, 12), Vector3.new(1, 0, 0), "SHOP", Color3.fromRGB(255, 110, 200), "Shop")
	buildStand(folder, Vector3.new(58, 0, 12), Vector3.new(-1, 0, 0), "MAGIC", Color3.fromRGB(110, 190, 255), "Magic")

	-- Welkomstbord boven de ingang
	local welcome = deco({ Name = "Welcome", Size = Vector3.new(40, 6, 0.2), Position = Vector3.new(0, 20, HZ - 0.3), Transparency = 1, Parent = folder })
	signText(welcome, Enum.NormalId.Front, "Choose a hall!", Color3.fromRGB(255, 220, 120))

	local doors = {}
	local count = #Config.Rooms
	for i, room in Config.Rooms do
		local x = (i - (count + 1) / 2) * 40
		doors[room.Id] = buildDoor(folder, room, x)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 8)
	spawn.Position = Vector3.new(0, -0.45, 36)
	spawn.Transparency = 1
	spawn.CanQuery = false
	spawn.Parent = model

	model.Parent = parent
	return {
		Model = model,
		SpawnCFrame = CFrame.new(0, 3.5, 36),
		Doors = doors,
	}
end

return LobbyBuilder
