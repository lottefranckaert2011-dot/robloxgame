-- Effecten: donkere sfeer + zaklamp in de Nachtmerriezaal, flikkerende lampjes,
-- rode rand en hartslag-schudden als het monster dichtbij is, de jumpscare,
-- gevonden sleutels verbergen en de kramen in de hal.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Effects = {}

local Hud
local flickerLights: { { part: BasePart, light: Light } } = {}
local savedLighting: { [string]: any }? = nil

local DARK_LIGHTING = {
	ClockTime = 0,
	Brightness = 0,
	Ambient = Color3.fromRGB(30, 26, 40),
	OutdoorAmbient = Color3.fromRGB(10, 10, 16),
	EnvironmentDiffuseScale = 0,
	EnvironmentSpecularScale = 0,
	FogColor = Color3.fromRGB(6, 5, 10),
	FogStart = 10,
	FogEnd = 110,
}

local function roomModel(): Instance?
	local id = player:GetAttribute("Room")
	local rooms = Workspace:FindFirstChild("Rooms")
	if type(id) ~= "string" or not rooms then
		return nil
	end
	return rooms:FindFirstChild(id)
end

-- Nachtmerrie-sfeer aan of uit (alleen voor deze speler)
local function setDark(dark: boolean)
	if dark and not savedLighting then
		local saved = {}
		for key, value in DARK_LIGHTING do
			saved[key] = (Lighting :: any)[key]
			;(Lighting :: any)[key] = value
		end
		savedLighting = saved
	elseif not dark and savedLighting then
		for key, value in savedLighting do
			(Lighting :: any)[key] = value
		end
		savedLighting = nil
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = if dark then 0 else 0.12
	end
end

-- Een zaklamp die alleen jij ziet, in donkere zalen
local function updateFlashlight(dark: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local light = head:FindFirstChild("LocalFlashlight")
	if dark and not light then
		local spot = Instance.new("SpotLight")
		spot.Name = "LocalFlashlight"
		spot.Range = 45
		spot.Angle = 55
		spot.Brightness = 3
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 245, 220)
		spot.Face = Enum.NormalId.Front
		spot.Parent = head
	elseif not dark and light then
		light:Destroy()
	end
end

local function collectFlickers(room: Instance?)
	table.clear(flickerLights)
	if not room then
		return
	end
	for _, d in room:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Flicker") then
			local light = d:FindFirstChildWhichIsA("Light")
			if light then
				table.insert(flickerLights, { part = d, light = light })
			end
		end
	end
end

local function flickerLoop()
	while true do
		task.wait(0.08)
		for _, entry in flickerLights do
			if math.random() < 0.06 then
				local on = not entry.light.Enabled
				entry.light.Enabled = on
				entry.part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			elseif not entry.light.Enabled and math.random() < 0.4 then
				entry.light.Enabled = true
				entry.part.Material = Enum.Material.Neon
			end
		end
	end
end

local updateKeys

local function onRoomChanged()
	updateKeys()
	local room = roomModel()
	local dark = room ~= nil and room:GetAttribute("Dark") == true
	setDark(dark)
	updateFlashlight(dark)
	collectFlickers(if dark then room else nil)
end

-- Sleutels die je al hebt worden (alleen voor jou) onzichtbaar, in alle zalen
function updateKeys()
	local rooms = Workspace:FindFirstChild("Rooms")
	if not rooms then
		return
	end
	for _, room in rooms:GetChildren() do
		local keys = room:FindFirstChild("Keys")
		if keys then
			for _, key in keys:GetChildren() do
				if key:IsA("BasePart") then
					local has = player:GetAttribute("Key_" .. tostring(key:GetAttribute("KeyId"))) == true
					key.LocalTransparencyModifier = if has then 1 else 0
					local prompt = key:FindFirstChildOfClass("ProximityPrompt")
					if prompt then
						prompt.Enabled = not has
					end
					local light = key:FindFirstChildWhichIsA("Light")
					if light then
						light.Enabled = not has
					end
				end
			end
		end
	end
end

local function findMonster(room: Instance?): BasePart?
	if not room then
		return nil
	end
	for _, child in room:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("IsMonster") then
			return child:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
	end
	return nil
end

function Effects.Init(hud)
	Hud = hud

	Workspace:WaitForChild("Rooms")
	task.spawn(flickerLoop)
	updateKeys()
	onRoomChanged()

	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Key_" then
			updateKeys()
		elseif name == "Hidden" then
			Hud.SetHidden(player:GetAttribute("Hidden") == true)
		elseif name == "Room" then
			onRoomChanged()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head")
		onRoomChanged()
	end)
	-- De sleutels komen net na de zalen binnen, en er kunnen later nieuwe kopieën van zalen bijkomen
	task.delay(2, updateKeys)
	Workspace.Rooms.ChildAdded:Connect(function()
		task.delay(1, updateKeys)
	end)

	-- Kramen in de hal openen een venster
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("OpenPanel")
		if type(panel) == "string" then
			Hud.TogglePanel(panel)
		end
	end)

	Remotes.Notify.OnClientEvent:Connect(function(text, color)
		Hud.Notify(text, color)
	end)

	Remotes.Caught.OnClientEvent:Connect(function()
		Hud.Jumpscare()
	end)

	-- Hoe dichter het monster, hoe roder het scherm en hoe meer het beeld trilt
	RunService:BindToRenderStep("MonsterDanger", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local monsterRoot = findMonster(roomModel())
		if not root or not monsterRoot then
			Hud.SetDanger(0)
			return
		end
		local offset = monsterRoot.Position - root.Position
		local distance = offset.Magnitude
		local sameFloor = math.abs(offset.Y) < 14
		local danger = if sameFloor then math.clamp(1 - (distance - 8) / 45, 0, 1) else 0
		-- Hartslag
		local pulse = 0.75 + 0.25 * math.sin(os.clock() * (6 + danger * 8))
		Hud.SetDanger(danger * pulse)
		if danger > 0.55 and Hud.Settings.Shake and not player:GetAttribute("Hidden") then
			local shake = (danger - 0.55) * 0.35
			camera.CFrame *= CFrame.Angles(
				math.rad((math.random() - 0.5) * shake * 4),
				math.rad((math.random() - 0.5) * shake * 4),
				0
			)
		end
	end)
end

return Effects
