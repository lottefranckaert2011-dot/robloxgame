-- Besturing: sprinten met uithoudingsvermogen, boeken laten vallen,
-- menu-toetsen (F/C/M/Z) en de vier magie-vakjes (1-4).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
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
local cooldownUntil: { [string]: number } = {}

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Het model van de zaal waar je nu bent (nil = in de hal)
local function roomModel(): Instance?
	local id = player:GetAttribute("Room")
	local rooms = Workspace:FindFirstChild("Rooms")
	if type(id) ~= "string" or not rooms then
		return nil
	end
	return rooms:FindFirstChild(id)
end

local function drop()
	if #Controls.Inventory > 0 then
		Remotes.Action:FireServer("Drop")
	end
end

-- Inzicht: laat even alle losse boeken in de buurt oplichten
local function insight(): boolean
	local root = getRoot()
	local room = roomModel()
	local books = room and room:FindFirstChild("Books")
	if not root or not books then
		Hud.Notify("Enter a hall first.", Color3.fromRGB(220, 220, 220))
		return false
	end
	local markers = {}
	local found = 0
	for _, book in books:GetChildren() do
		if book:IsA("BasePart") and (book.Position - root.Position).Magnitude <= Config.InsightRadius then
			found += 1
			local bb = Instance.new("BillboardGui")
			bb.Name = "InsightMarker"
			bb.AlwaysOnTop = true
			bb.Size = UDim2.fromOffset(46, 22)
			bb.StudsOffset = Vector3.new(0, 1, 0)
			bb.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(255, 225, 120)
			label.BackgroundTransparency = 0.15
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
	Hud.Notify(string.format("👁 Insight: %d books nearby", found), Color3.fromRGB(255, 225, 120))
	task.delay(Config.InsightDuration, function()
		for _, bb in markers do
			bb:Destroy()
		end
	end)
	return true
end

-- Kastgids: een lichtstraal naar de kast van het eerste boek dat je draagt
local function shelfGuide(): boolean
	local book = Controls.Inventory[1]
	if not book then
		Hud.Notify("Pick up a book first.", Color3.fromRGB(220, 220, 220))
		return false
	end
	local root = getRoot()
	local room = roomModel()
	local sections = room and room:FindFirstChild("Sections")
	local sectionModel = sections and sections:FindFirstChild("Section_" .. book.Code)
	local zone = sectionModel and sectionModel:FindFirstChild("PromptZone") :: BasePart?
	if not root or not zone then
		return false
	end
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
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = Vector3.new(0, 8, 0)
	bb.Adornee = zone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = "▼ " .. book.Code .. " " .. (if section then section.Name else "")
	label.Parent = bb
	bb.Parent = player:WaitForChild("PlayerGui")

	Hud.Notify("🧭 Follow the light to " .. book.Code, color)
	task.delay(Config.ShelfGuideDuration, function()
		beam:Destroy()
		a0:Destroy()
		a1:Destroy()
		bb:Destroy()
	end)
	return true
end

local function useAbility(id: string)
	local info = Config.FindMagic(id)
	if not info then
		return
	end
	if not player:GetAttribute("Magic_" .. id) then
		Hud.Notify(string.format("🔒 %s is still locked. Buy it in Magic (C).", info.Name), Color3.fromRGB(255, 200, 120))
		return
	end
	local now = os.clock()
	local wait = (cooldownUntil[id] or 0) - now
	if wait > 0 then
		Hud.Notify(string.format("⏳ %s: wait %d more seconds", info.Name, math.ceil(wait)), Color3.fromRGB(200, 200, 220))
		return
	end
	if not roomModel() then
		Hud.Notify("Magic only works inside a hall. Choose a hall first!", Color3.fromRGB(220, 220, 220))
		return
	end
	local used = true
	if id == "Insight" then
		used = insight()
	elseif id == "ShelfGuide" then
		used = shelfGuide()
	elseif id == "AutoShelf" then
		-- Zonder boeken in je handen heeft het geen zin (en verspil je de afkoeltijd niet)
		if #Controls.Inventory == 0 then
			Hud.Notify("✨ Pick up some books first, then they will fly to their shelves.", Color3.fromRGB(255, 230, 140))
			return
		end
		Remotes.Action:FireServer("Ability", id)
		used = false -- de server zet de afkoeltijd als het gelukt is
	else
		-- Verzamelen gebeurt op de server
		Remotes.Action:FireServer("Ability", id)
		used = false
	end
	if used then
		cooldownUntil[id] = now + info.Cooldown
	end
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

	-- Geen rugzak-balk: de cijfertoetsen zijn voor magie
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	ContextActionService:BindAction("Sprint", function(_, inputState)
		sprintHeld = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	bindKey("DropBooks", drop, Enum.KeyCode.G, Enum.KeyCode.ButtonB)

	for name, key in Config.MenuKeys do
		bindKey("Menu" .. name, function()
			Hud.TogglePanel(name)
		end, key)
	end

	local gamepad = { Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2 }
	for i, info in Config.Magic do
		bindKey("Magic" .. info.Id, function()
			useAbility(info.Id)
		end, info.Key, gamepad[i])
		Hud.AbilitySlots[info.Id].Activated:Connect(function()
			useAbility(info.Id)
		end)
	end

	-- Afkoeltijd van magie die op de server gebeurt (alleen als het echt gelukt is)
	for _, info in Config.Magic do
		player:GetAttributeChangedSignal("Cooldown_" .. info.Id):Connect(function()
			local endsAt = player:GetAttribute("Cooldown_" .. info.Id)
			if type(endsAt) == "number" then
				cooldownUntil[info.Id] = os.clock() + (endsAt - Workspace:GetServerTimeNow())
			end
		end)
	end

	if Hud.Buttons.Sprint then
		Hud.Buttons.Sprint.Activated:Connect(function()
			sprintToggled = not sprintToggled
			Hud.SetActive("Sprint", sprintToggled)
		end)
	end
	if Hud.Buttons.Drop then
		Hud.Buttons.Drop.Activated:Connect(drop)
	end

	Remotes.Inventory.OnClientEvent:Connect(function(list, capacity)
		Controls.Inventory = list
		Hud.SetInventory(list, capacity)
	end)

	player.CharacterAdded:Connect(function()
		stamina = Config.MaxStamina
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, info in Config.Magic do
			Hud.SetCooldown(info.Id, ((cooldownUntil[info.Id] or 0) - now) / info.Cooldown)
		end
		local humanoid = getHumanoid()
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
		local walkSpeed = player:GetAttribute("WalkSpeed") or Config.WalkSpeed
		local sprintSpeed = player:GetAttribute("SprintSpeed") or Config.SprintSpeed
		humanoid.WalkSpeed = if sprinting then sprintSpeed else walkSpeed
		Hud.SetStamina(stamina / Config.MaxStamina)
	end)
end

return Controls
