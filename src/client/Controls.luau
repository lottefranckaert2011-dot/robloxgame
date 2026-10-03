-- Besturing: sprinten met uithoudingsvermogen, zaklamp, boeken laten vallen
-- en de twee magische vaardigheden (Inzicht en Kastgids).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Controls = {}
Controls.Inventory = {} :: { any }

local Hud
local stamina = Config.MaxStamina
local sprintHeld = false
local sprintToggled = false -- voor de knop op mobiel
local flashlightOn = false
local cooldownUntil: { [string]: number } = { Insight = 0, ShelfGuide = 0 }

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function setFlashlight(on: boolean)
	flashlightOn = on
	Hud.SetActive("Flashlight", on)
	Remotes.Action:FireServer("Flashlight", on)
end

local function toggleFlashlight()
	setFlashlight(not flashlightOn)
end

local function drop()
	if #Controls.Inventory > 0 then
		Remotes.Action:FireServer("Drop")
	end
end

-- Inzicht: laat even alle losse boeken in de buurt oplichten
local function insight()
	local cfg = Config.Abilities.Insight
	local now = os.clock()
	if now < cooldownUntil.Insight then
		return
	end
	local root = getRoot()
	local books = Workspace:FindFirstChild("Books")
	if not root or not books then
		return
	end
	cooldownUntil.Insight = now + cfg.Cooldown
	local markers = {}
	local found = 0
	for _, book in books:GetChildren() do
		if book:IsA("BasePart") and (book.Position - root.Position).Magnitude <= cfg.Radius then
			found += 1
			local bb = Instance.new("BillboardGui")
			bb.Name = "InsightMarker"
			bb.AlwaysOnTop = true
			bb.Size = UDim2.fromOffset(46, 22)
			bb.StudsOffset = Vector3.new(0, 1, 0)
			bb.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
			label.BackgroundTransparency = 0.25
			label.Font = Enum.Font.GothamBlack
			label.TextSize = 13
			label.TextColor3 = Color3.new(0, 0, 0)
			label.Text = tostring(book:GetAttribute("Code"))
			label.Parent = bb
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = label
			bb.Adornee = book
			bb.Parent = player:WaitForChild("PlayerGui")
			table.insert(markers, bb)
		end
	end
	Hud.Notify(string.format("👁 Inzicht: %d boeken in de buurt", found), Color3.fromRGB(120, 200, 255))
	task.delay(cfg.Duration, function()
		for _, bb in markers do
			bb:Destroy()
		end
	end)
end

-- Kastgids: een lichtstraal naar de kast van het eerste boek dat je draagt
local function shelfGuide()
	local cfg = Config.Abilities.ShelfGuide
	local now = os.clock()
	if now < cooldownUntil.ShelfGuide then
		return
	end
	local book = Controls.Inventory[1]
	if not book then
		Hud.Notify("Pak eerst een boek op.", Color3.fromRGB(200, 200, 200))
		return
	end
	local root = getRoot()
	local library = Workspace:FindFirstChild("Library")
	local sections = library and library:FindFirstChild("Sections")
	local sectionModel = sections and sections:FindFirstChild("Section_" .. book.Code)
	local zone = sectionModel and sectionModel:FindFirstChild("PromptZone") :: BasePart?
	if not root or not zone then
		return
	end
	cooldownUntil.ShelfGuide = now + cfg.Cooldown
	local section, index = Config.FindSection(book.Code)
	local color = if index then Config.SectionColor(index) else Color3.new(1, 1, 1)

	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = zone
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 0.6
	beam.Width1 = 2
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.2, 0.5)
	beam.Parent = zone

	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.Adornee = zone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = "▼ " .. book.Code .. " " .. (if section then section.Name else "")
	label.Parent = bb
	bb.Parent = player:WaitForChild("PlayerGui")

	Hud.Notify("🧭 Volg het licht naar " .. book.Code, color)
	task.delay(cfg.Duration, function()
		beam:Destroy()
		a0:Destroy()
		a1:Destroy()
		bb:Destroy()
	end)
end

local function bindKey(name: string, callback: () -> (), ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			callback()
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

function Controls.Init(hud)
	Hud = hud

	ContextActionService:BindAction("Sprint", function(_, inputState)
		sprintHeld = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	bindKey("Flashlight", toggleFlashlight, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	bindKey("DropBooks", drop, Enum.KeyCode.G, Enum.KeyCode.ButtonB)
	bindKey("Insight", insight, Config.Abilities.Insight.Key, Enum.KeyCode.ButtonL1)
	bindKey("ShelfGuide", shelfGuide, Config.Abilities.ShelfGuide.Key, Enum.KeyCode.ButtonR1)

	Hud.Buttons.Sprint.Activated:Connect(function()
		sprintToggled = not sprintToggled
		Hud.SetActive("Sprint", sprintToggled)
	end)
	Hud.Buttons.Flashlight.Activated:Connect(toggleFlashlight)
	Hud.Buttons.Drop.Activated:Connect(drop)
	Hud.Buttons.Insight.Activated:Connect(insight)
	Hud.Buttons.ShelfGuide.Activated:Connect(shelfGuide)

	Remotes.Inventory.OnClientEvent:Connect(function(list, capacity)
		Controls.Inventory = list
		Hud.SetInventory(list, capacity)
	end)

	player.CharacterAdded:Connect(function()
		stamina = Config.MaxStamina
		flashlightOn = false
		Hud.SetActive("Flashlight", false)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local humanoid = getHumanoid()
		local now = os.clock()
		for name, cfg in Config.Abilities do
			local left = cooldownUntil[name] - now
			Hud.SetCooldown(name, left / cfg.Cooldown)
		end
		if not humanoid then
			return
		end
		local wantsSprint = (sprintHeld or sprintToggled) and not player:GetAttribute("Hidden")
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local sprinting = wantsSprint and moving and stamina > 0
		if sprinting then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
		else
			stamina = math.min(Config.MaxStamina, stamina + Config.StaminaRegen * dt)
		end
		local sprintSpeed = player:GetAttribute("SprintSpeed") or Config.SprintSpeed
		humanoid.WalkSpeed = if sprinting then sprintSpeed else Config.WalkSpeed
		Hud.SetStamina(stamina / Config.MaxStamina)
	end)
end

return Controls
