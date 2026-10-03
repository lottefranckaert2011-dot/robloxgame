-- Alle schermelementen: timer, voortgang, gedragen boeken, sleutels,
-- knoppen, meldingen, gevaar-rand en de jumpscare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Hud = {}
Hud.Buttons = {} :: { [string]: TextButton }

local PANEL = Color3.fromRGB(18, 14, 22)
local TEXT = Color3.fromRGB(235, 225, 210)
local ACCENT = Color3.fromRGB(200, 40, 50)

local gui: ScreenGui
local timerLabel: TextLabel
local messageLabel: TextLabel
local progressFill: Frame
local progressLabel: TextLabel
local inventoryTitle: TextLabel
local inventoryList: Frame
local staminaFill: Frame
local notifyHolder: Frame
local dangerFrames: { Frame } = {}
local hiddenOverlay: Frame
local bigBanner: TextLabel
local keyIcons: { [string]: Frame } = {}
local cooldownOverlays: { [string]: Frame } = {}

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent: Instance, color: Color3?, thickness: number?)
	make("UIStroke", {
		Color = color or Color3.fromRGB(70, 40, 50),
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function buildTop()
	local top = make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(380, 92),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	corner(top, 10)
	stroke(top)

	timerLabel = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 4),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		TextSize = 34,
		TextColor3 = ACCENT,
		Text = "--:--",
		Parent = top,
	})
	messageLabel = make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 38),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = TEXT,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = top,
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundColor3 = Color3.fromRGB(40, 30, 40),
		Parent = top,
	})
	corner(bar, 6)
	progressFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(110, 200, 120),
		Parent = bar,
	})
	corner(progressFill, 6)
	progressLabel = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		Text = "",
		ZIndex = 2,
		Parent = bar,
	})
end

local function buildKeys()
	local holder = make("Frame", {
		Name = "Keys",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(200, 64),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	corner(holder, 10)
	stroke(holder)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = TEXT,
		Text = "🔑 Sleutels",
		Parent = holder,
	})
	for i, info in Config.Keys do
		local icon = make("Frame", {
			Position = UDim2.fromOffset(14 + (i - 1) * 46, 24),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = info.Color,
			BackgroundTransparency = 0.8,
			Rotation = if info.Id == "Golden" then 45 else 0,
			Parent = holder,
		})
		corner(icon, if info.Id == "Azure" or info.Id == "Emerald" then 16 else 4)
		stroke(icon, info.Color, 2)
		keyIcons[info.Id] = icon
	end
end

local function buildInventory()
	local holder = make("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(340, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	corner(holder, 10)
	stroke(holder)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = holder,
	})
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	inventoryTitle = make("TextLabel", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = TEXT,
		Text = "📚 Je draagt 0/" .. Config.BaseCapacity,
		Parent = holder,
	})
	inventoryList = make("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inventoryList })

	-- Uithoudingsbalk
	local bar = make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Color3.fromRGB(40, 30, 40),
		Parent = holder,
	})
	corner(bar, 3)
	staminaFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(240, 200, 80),
		Parent = bar,
	})
	corner(staminaFill, 3)
end

local function buildButtons()
	local holder = make("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(142, 218),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local defs = {
		{ "Sprint", "🏃", "Shift", 0, 0 },
		{ "Flashlight", "🔦", "F", 1, 0 },
		{ "Insight", "👁", "Q", 0, 1 },
		{ "ShelfGuide", "🧭", "T", 1, 1 },
		{ "Drop", "⬇", "G", 0, 2 },
	}
	for _, def in defs do
		local name, icon, key, col, row = def[1], def[2], def[3], def[4], def[5]
		local button = make("TextButton", {
			Name = name,
			Position = UDim2.fromOffset(col * 76, row * 76),
			Size = UDim2.fromOffset(66, 66),
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.15,
			Text = icon,
			TextSize = 28,
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT,
			AutoButtonColor = true,
			Parent = holder,
		})
		corner(button, 33)
		stroke(button, Color3.fromRGB(120, 60, 70), 2)
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.fromOffset(60, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(190, 170, 160),
			Text = key,
			Parent = button,
		})
		local cooldown = make("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 3,
			Parent = button,
		})
		corner(cooldown, 33)
		cooldownOverlays[name] = cooldown
		Hud.Buttons[name] = button
	end
end

local function buildHelp()
	make("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(300, 110),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(170, 160, 160),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "E  boek oppakken / terugzetten / verstoppen\nShift  sprinten (maakt lawaai!)\nF  zaklamp (zij ziet jou ook beter)\nQ  Inzicht: toon boeken in de buurt\nT  Kastgids: wijst de juiste kast aan\nG  boeken laten vallen",
		Parent = gui,
	})
end

local function buildOverlays()
	-- Rode rand als het monster dichtbij is
	local sides = {
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), -90 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
	}
	for _, s in sides do
		local frame = make("Frame", {
			Size = s[1],
			Position = s[2],
			BackgroundColor3 = Color3.fromRGB(160, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = gui,
		})
		make("UIGradient", {
			Rotation = s[3],
			Transparency = NumberSequence.new(0, 1),
			Parent = frame,
		})
		table.insert(dangerFrames, frame)
	end

	-- Uitzicht vanuit een kluisje
	hiddenOverlay = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	for i = 1, 3 do
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.35 + i * 0.06),
			Size = UDim2.fromScale(0.5, 0.012),
			BackgroundColor3 = Color3.fromRGB(70, 60, 80),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = hiddenOverlay,
		})
	end
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.65),
		Size = UDim2.fromOffset(500, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(180, 180, 220),
		Text = "Je zit verstopt... houd E ingedrukt om eruit te gaan",
		ZIndex = 6,
		Parent = hiddenOverlay,
	})

	-- Grote tekst voor begin/einde van een ronde
	bigBanner = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0.9, 0, 0, 80),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = ACCENT,
		TextStrokeTransparency = 0.2,
		Text = "",
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})

	notifyHolder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
		ZIndex = 9,
		Parent = gui,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notifyHolder,
	})
end

function Hud.SetInventory(list: { any }, capacity: number)
	inventoryTitle.Text = string.format("📚 Je draagt %d/%d", #list, capacity)
	for _, child in inventoryList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, book in list do
		local section, index = Config.FindSection(book.Code)
		local row = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = book.Color,
			BackgroundTransparency = 0.3,
			Parent = inventoryList,
		})
		corner(row, 5)
		make("TextLabel", {
			Size = UDim2.new(0, 44, 1, 0),
			BackgroundColor3 = if index then Config.SectionColor(index) else Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextColor3 = Color3.new(0, 0, 0),
			Text = book.Code,
			Parent = row,
		})
		make("TextLabel", {
			Position = UDim2.fromOffset(50, 0),
			Size = UDim2.new(1, -54, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = book.Title .. (if section then "  →  " .. section.Name else ""),
			Parent = row,
		})
	end
end

function Hud.Notify(text: string, color: Color3?)
	local label = make("TextLabel", {
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = color or TEXT,
		Text = "  " .. text .. "  ",
		ZIndex = 9,
		Parent = notifyHolder,
	})
	corner(label, 8)
	stroke(label, color or Color3.fromRGB(70, 40, 50), 1.5)
	local children = notifyHolder:GetChildren()
	local count = 0
	for i = #children, 1, -1 do
		if children[i]:IsA("TextLabel") then
			count += 1
			if count > 4 then
				children[i]:Destroy()
			end
		end
	end
	task.delay(3.5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.5)
			label:Destroy()
		end
	end)
end

function Hud.SetStamina(fraction: number)
	staminaFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

function Hud.SetCooldown(name: string, fraction: number)
	local overlay = cooldownOverlays[name]
	if overlay then
		overlay.Size = UDim2.fromScale(1, math.clamp(fraction, 0, 1))
	end
end

function Hud.SetActive(name: string, active: boolean)
	local button = Hud.Buttons[name]
	if button then
		button.BackgroundColor3 = if active then Color3.fromRGB(110, 40, 50) else PANEL
	end
end

function Hud.SetDanger(amount: number)
	for _, frame in dangerFrames do
		frame.BackgroundTransparency = 1 - math.clamp(amount, 0, 1) * 0.75
	end
end

function Hud.SetHidden(hidden: boolean)
	hiddenOverlay.Visible = hidden
end

function Hud.Jumpscare()
	local scare = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 20,
		Parent = gui,
	})
	local face = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.8),
		BackgroundColor3 = Color3.fromRGB(205, 200, 190),
		ZIndex = 21,
		Parent = scare,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 0.85, Parent = face })
	corner(face, 40)
	for _, x in { 0.28, 0.72 } do
		local eye = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromScale(0.24, 0.14),
			BackgroundColor3 = Color3.fromRGB(255, 20, 20),
			ZIndex = 22,
			Parent = face,
		})
		corner(eye, 30)
	end
	local mouth = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.5, 0.2),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 22,
		Parent = face,
	})
	corner(mouth, 40)
	make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(1, 0.18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Creepster,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 30, 30),
		Text = "SSSSHHHHH!!",
		ZIndex = 23,
		Parent = scare,
	})
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 1.2 do
			face.Position = UDim2.new(0.5, math.random(-18, 18), 0.5, math.random(-18, 18))
			face.Size = UDim2.fromScale(0.45 + (os.clock() - start) * 0.25, 0.8 + (os.clock() - start) * 0.4)
			task.wait(0.03)
		end
		TweenService:Create(scare, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		for _, d in scare:GetDescendants() do
			if d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
			end
		end
		task.wait(0.9)
		scare:Destroy()
	end)
end

local function updateKeys()
	for id, icon in keyIcons do
		local has = player:GetAttribute("Key_" .. id) == true
		icon.BackgroundTransparency = if has then 0 else 0.8
	end
end

local function updateRound()
	local state = Workspace:GetAttribute("RoundState") or "Waiting"
	local timeLeft = Workspace:GetAttribute("TimeLeft") or 0
	local placed = Workspace:GetAttribute("Placed") or 0
	local total = Workspace:GetAttribute("Total") or Config.TotalBooks()
	local message = Workspace:GetAttribute("Message") or ""

	if state == "Playing" then
		timerLabel.Text = formatTime(timeLeft)
		timerLabel.TextColor3 = if timeLeft <= 60 then Color3.fromRGB(255, 40, 40) else ACCENT
	elseif state == "Intermission" then
		timerLabel.Text = "Pauze " .. formatTime(timeLeft)
		timerLabel.TextColor3 = TEXT
	else
		timerLabel.Text = if state == "Won" then "GEWONNEN" elseif state == "Lost" then "VERLOREN" else "..."
		timerLabel.TextColor3 = if state == "Won" then Color3.fromRGB(110, 255, 130) else ACCENT
	end
	messageLabel.Text = message
	progressFill.Size = UDim2.fromScale(if total > 0 then placed / total else 0, 1)
	progressLabel.Text = string.format("%d / %d boeken", placed, total)

	if state == "Won" or state == "Lost" then
		bigBanner.Visible = true
		bigBanner.Text = message
		bigBanner.TextColor3 = if state == "Won" then Color3.fromRGB(120, 255, 140) else ACCENT
	else
		bigBanner.Visible = false
	end
end

function Hud.Init()
	gui = make("ScreenGui", {
		Name = "LibraryHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildOverlays()
	buildTop()
	buildKeys()
	buildInventory()
	buildButtons()
	buildHelp()

	for _, name in { "RoundState", "TimeLeft", "Placed", "Total", "Message" } do
		Workspace:GetAttributeChangedSignal(name):Connect(updateRound)
	end
	updateRound()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Key_" then
			updateKeys()
		end
	end)
	updateKeys()
end

return Hud
