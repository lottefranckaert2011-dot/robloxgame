-- Het scherm, in de stijl van het origineel:
--   links: menuknoppen (Winkel F, Magie C, Assistent M, Instellingen Z)
--   linksonder: timer en de vier magie-vakjes (1-4)
--   rechtsonder: hoeveel boeken er terug staan en hoeveel je draagt
-- Plus meldingen, vensters, gevaar-rand, kast-overlay en de jumpscare.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Hud = {}
Hud.Buttons = {} :: { [string]: GuiButton }
Hud.AbilitySlots = {} :: { [string]: GuiButton }
Hud.Settings = { Shake = true, Danger = true }

local NAVY = Color3.fromRGB(24, 36, 70)
local NAVY_DARK = Color3.fromRGB(16, 24, 50)
local NAVY_EDGE = Color3.fromRGB(90, 110, 160)
local CRIMSON = Color3.fromRGB(128, 18, 52)
local CRIMSON_DARK = Color3.fromRGB(96, 10, 38)
local CRIMSON_EDGE = Color3.fromRGB(220, 90, 120)
local WHITE = Color3.fromRGB(255, 252, 245)
local GOLD = Color3.fromRGB(240, 200, 110)
local SERIF = Enum.Font.Garamond
local ROUND = Enum.Font.FredokaOne

local gui: ScreenGui
local timerLabel: TextLabel
local countersHolder: Frame
local leaveButton: TextButton
local placedLabel: TextLabel
local carriedLabel: TextLabel
local sectionsLeftLabel: TextLabel
local objectiveLabel: TextLabel
local coinsLabel: TextLabel
local inventoryList: Frame
local staminaFill: Frame
local notifyHolder: Frame
local dangerFrames: { Frame } = {}
local hiddenOverlay: Frame
local bigBanner: TextLabel
local resultsLabel: TextLabel
local keyIcons: { [string]: Frame } = {}
local cooldownOverlays: { [string]: Frame } = {}
local lockIcons: { [string]: TextLabel } = {}
local panels: { [string]: Frame } = {}
local panelRefresh: { [string]: () -> () } = {}
local openPanel: string? = nil

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

local function stroke(parent: Instance, color: Color3, thickness: number?, mode: Enum.ApplyStrokeMode?)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Witte tekst met een donkere rand, zoals de timer in het origineel
local function outlined(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or WHITE
	local label = make("TextLabel", props)
	local thick = if props.TextSize and props.TextSize > 30 then 3 else 2
	stroke(label, Color3.fromRGB(20, 14, 20), thick, Enum.ApplyStrokeMode.Contextual)
	return label
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function coins(): number
	return player:GetAttribute("Coins") or 0
end

----------------------------------------------------------------------------
-- Vensters (winkel, magie, assistent, instellingen)
----------------------------------------------------------------------------

local function closePanels()
	for _, panel in panels do
		panel.Visible = false
	end
	openPanel = nil
end

function Hud.TogglePanel(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	local wasOpen = openPanel == name
	closePanels()
	if not wasOpen then
		panel.Visible = true
		openPanel = name
		local refresh = panelRefresh[name]
		if refresh then
			refresh()
		end
	end
end

local function refreshOpenPanel()
	if openPanel and panelRefresh[openPanel] then
		panelRefresh[openPanel]()
	end
end

local function buildPanel(name: string, title: string, accent: Color3): ScrollingFrame
	local panel = make("Frame", {
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 440),
		BackgroundColor3 = NAVY,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	local uiScale = make("UIScale", { Parent = panel })
	corner(panel, 14)
	stroke(panel, accent, 4)
	-- Op kleine schermen (telefoon) het venster kleiner maken
	local function fit()
		local view = Workspace.CurrentCamera.ViewportSize
		uiScale.Scale = math.clamp(math.min((view.X - 20) / 560, (view.Y - 20) / 440), 0.5, 1)
	end
	fit()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	outlined({
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -200, 0, 50),
		Font = SERIF,
		TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title,
		ZIndex = 31,
		Parent = panel,
	})
	local coinLabel = outlined({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 16),
		Size = UDim2.fromOffset(130, 34),
		Font = ROUND,
		TextSize = 26,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "🪙 0",
		ZIndex = 31,
		Parent = panel,
	})
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(42, 42),
		BackgroundColor3 = CRIMSON,
		Font = ROUND,
		TextSize = 24,
		TextColor3 = WHITE,
		Text = "✕",
		ZIndex = 31,
		Parent = panel,
	})
	corner(close, 21)
	close.Activated:Connect(closePanels)

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 31,
		Parent = panel,
	})
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	panels[name] = panel
	panelRefresh[name] = function()
		coinLabel.Text = "🪙 " .. coins()
	end
	return list
end

type RowParts = { Frame: Frame, Button: TextButton, Info: TextLabel }

local function buildRow(parent: Instance, order: number, icon: string, name: string, description: string): RowParts
	local row = make("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundColor3 = NAVY_DARK,
		ZIndex = 32,
		Parent = parent,
	})
	corner(row, 10)
	stroke(row, NAVY_EDGE, 1.5)
	make("TextLabel", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 40,
		Text = icon,
		ZIndex = 33,
		Parent = row,
	})
	outlined({
		Position = UDim2.fromOffset(76, 6),
		Size = UDim2.new(1, -240, 0, 32),
		Font = SERIF,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = name,
		ZIndex = 33,
		Parent = row,
	})
	local info = make("TextLabel", {
		Position = UDim2.fromOffset(76, 38),
		Size = UDim2.new(1, -240, 0, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(200, 205, 225),
		Text = description,
		ZIndex = 33,
		Parent = row,
	})
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 48),
		BackgroundColor3 = Color3.fromRGB(46, 150, 80),
		Font = ROUND,
		TextSize = 20,
		TextColor3 = WHITE,
		Text = "",
		ZIndex = 33,
		Parent = row,
	})
	corner(button, 10)
	stroke(button, Color3.fromRGB(255, 255, 255), 1.5).Transparency = 0.6
	return { Frame = row, Button = button, Info = info }
end

local function setBuyButton(button: TextButton, text: string, enabled: boolean, affordable: boolean)
	button.Text = text
	button.AutoButtonColor = enabled
	button.Active = enabled
	button.BackgroundColor3 = if not enabled
		then Color3.fromRGB(70, 76, 96)
		elseif affordable then Color3.fromRGB(46, 150, 80)
		else Color3.fromRGB(150, 60, 60)
end

-- Voegt extra werk toe aan het verversen van een venster
local function onRefresh(name: string, fn: () -> ())
	local previous = panelRefresh[name]
	panelRefresh[name] = function()
		if previous then
			previous()
		end
		fn()
	end
end

local function buildShopPanel()
	local list = buildPanel("Shop", "Winkel", CRIMSON_EDGE)
	local rows = {}
	for i, item in Config.Shop do
		local row = buildRow(list, i, item.Icon, item.Name, item.Description)
		row.Button.Activated:Connect(function()
			Remotes.Action:FireServer("Buy", "Shop", item.Id)
		end)
		rows[item.Id] = row
	end
	onRefresh("Shop", function()
		for _, item in Config.Shop do
			local row = rows[item.Id]
			local level = player:GetAttribute("Up_" .. item.Id) or 0
			row.Info.Text = string.format("%s  •  niveau %d/%d", item.Description, level, item.MaxLevel)
			if level >= item.MaxLevel then
				setBuyButton(row.Button, "MAX", false, false)
			else
				local cost = Config.ShopCost(item, level)
				setBuyButton(row.Button, "🪙 " .. cost, true, coins() >= cost)
			end
		end
	end)
end

local function buildMagicPanel()
	local list = buildPanel("Magic", "Magie", NAVY_EDGE)
	local rows = {}
	for i, info in Config.Magic do
		local row = buildRow(list, i, info.Icon, string.format("%d · %s", i, info.Name), info.Description)
		row.Button.Activated:Connect(function()
			Remotes.Action:FireServer("Buy", "Magic", info.Id)
		end)
		rows[info.Id] = row
	end
	-- De vier verborgen sleutels
	make("TextLabel", {
		LayoutOrder = 50,
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundTransparency = 1,
		Font = SERIF,
		TextSize = 26,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🔑 Verborgen sleutels",
		ZIndex = 32,
		Parent = list,
	})
	local keyRows = {}
	for i, info in Config.Keys do
		local row = buildRow(list, 50 + i, "🔑", info.Name, info.Description)
		row.Button.Active = false
		row.Button.AutoButtonColor = false
		keyRows[info.Id] = row
	end
	onRefresh("Magic", function()
		for _, info in Config.Magic do
			local row = rows[info.Id]
			if player:GetAttribute("Magic_" .. info.Id) then
				setBuyButton(row.Button, "✔ Ontgrendeld", false, true)
				row.Info.Text = string.format("%s  •  afkoeltijd %ds", info.Description, info.Cooldown)
			else
				setBuyButton(row.Button, "🪙 " .. info.Cost, true, coins() >= info.Cost)
			end
		end
		for _, info in Config.Keys do
			local row = keyRows[info.Id]
			local has = player:GetAttribute("Key_" .. info.Id) == true
			row.Button.Text = if has then "✔ Gevonden" else "❓ Zoek!"
			row.Button.BackgroundColor3 = if has then info.Color else Color3.fromRGB(70, 76, 96)
		end
	end)
end

local function buildAssistantPanel()
	local list = buildPanel("Assistant", "Assistent", NAVY_EDGE)
	local row = buildRow(list, 1, "🦉", Config.Assistant.Name, "")
	row.Button.Activated:Connect(function()
		Remotes.Action:FireServer("Buy", "Assistant", "Owl")
	end)
	make("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, -8, 0, 120),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 215, 235),
		Text = "Je magische uil laat af en toe een boek naar de goede kast zweven. "
			.. "Hoe hoger het niveau, hoe vaker hij helpt. De boeken die hij terugzet tellen voor jou en leveren munten op.",
		ZIndex = 32,
		Parent = list,
	})
	onRefresh("Assistant", function()
		local level = player:GetAttribute("Assistant") or 0
		local current = Config.Assistant.Levels[level]
		local nextInfo = Config.Assistant.Levels[level + 1]
		row.Info.Text = if current
			then string.format("Niveau %d: zet elke %d seconden een boek terug", level, current.Interval)
			else "Nog geen assistent"
		if nextInfo then
			local label = if level == 0 then "Koop" else "Niv. " .. (level + 1)
			setBuyButton(row.Button, label .. " 🪙" .. nextInfo.Cost, true, coins() >= nextInfo.Cost)
		else
			setBuyButton(row.Button, "MAX", false, false)
		end
	end)
end

local function buildSettingsPanel()
	local list = buildPanel("Settings", "Instellingen", NAVY_EDGE)
	local options = {
		{ "Shake", "📳", "Schermschudden", "Het beeld trilt als het monster dichtbij is" },
		{ "Danger", "🟥", "Gevarenrand", "Rode rand als het monster dichtbij is" },
	}
	local rows = {}
	for i, option in options do
		local key = option[1]
		local row = buildRow(list, i, option[2], option[3], option[4])
		row.Button.Activated:Connect(function()
			local settings = Hud.Settings :: any
			settings[key] = not settings[key]
			refreshOpenPanel()
		end)
		rows[key] = row
	end
	make("TextLabel", {
		LayoutOrder = 10,
		Size = UDim2.new(1, -8, 0, 210),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(210, 215, 235),
		Text = "Besturing\n"
			.. "E  boek oppakken / terugzetten / verstoppen\n"
			.. "1-4  magie gebruiken (eerst kopen bij Magie)\n"
			.. "Shift  sprinten (maakt lawaai!)\n"
			.. "G  boeken laten vallen\n"
			.. "F Winkel  •  C Magie  •  M Assistent  •  Z Instellingen\n\n"
			.. "Lees de code op elk boek (bijv. 1H) en breng het naar de kast met hetzelfde groene bordje.",
		ZIndex = 32,
		Parent = list,
	})
	onRefresh("Settings", function()
		for key, row in rows do
			local on = (Hud.Settings :: any)[key] == true
			setBuyButton(row.Button, if on then "AAN" else "UIT", true, on)
		end
	end)
end

----------------------------------------------------------------------------
-- Vaste schermdelen
----------------------------------------------------------------------------

local function buildMenu()
	local holder = make("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(240, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIScale", { Name = "Scale", Parent = holder })
	objectiveLabel = outlined({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 26),
		Font = Enum.Font.Fantasy,
		TextSize = 22,
		Text = "Ruim alle kasten op",
		Parent = holder,
	})
	local items = {
		{ "Shop", "Winkel", "F", true },
		{ "Magic", "Magie", "C", false },
		{ "Assistant", "Assistent", "M", false },
		{ "Settings", "Instellingen", "Z", false },
	}
	for i, item in items do
		local name, label, key, red = item[1], item[2], item[3], item[4]
		local button = make("TextButton", {
			Name = name,
			Position = UDim2.fromOffset(0, 32 + (i - 1) * 74),
			Size = UDim2.fromOffset(240, 64),
			BackgroundColor3 = if red then CRIMSON else NAVY,
			AutoButtonColor = true,
			Text = "",
			Parent = holder,
		})
		corner(button, 6)
		stroke(button, if red then CRIMSON_EDGE else NAVY_EDGE, 2.5)
		outlined({
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, -66, 0, 44),
			Font = SERIF,
			TextSize = 32,
			Text = label,
			Parent = button,
		})
		-- Lijntje met ruitje eronder
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, -33, 0, 50),
			Size = UDim2.new(0.6, 0, 0, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Parent = button,
		})
		make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -33, 0, 51),
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = WHITE,
			Text = "◆",
			Parent = button,
		})
		local keyBox = make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(62, 64),
			BackgroundColor3 = if red then CRIMSON_DARK else NAVY_DARK,
			Parent = button,
		})
		corner(keyBox, 6)
		stroke(keyBox, if red then CRIMSON_EDGE else NAVY_EDGE, 2)
		outlined({
			Size = UDim2.fromScale(1, 1),
			Font = SERIF,
			TextSize = 44,
			Text = key,
			Parent = keyBox,
		})
		button.Activated:Connect(function()
			Hud.TogglePanel(name)
		end)
		Hud.Buttons[name] = button
	end
end

local function buildBottomLeft()
	timerLabel = outlined({
		Name = "Timer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -112),
		Size = UDim2.fromOffset(260, 70),
		Font = ROUND,
		TextSize = 66,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "00:00",
		Parent = gui,
	})

	local bar = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -104),
		Size = UDim2.fromOffset(#Config.Magic * 94 - 10, 6),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.3,
		Parent = gui,
	})
	corner(bar, 3)
	staminaFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(250, 214, 90),
		Parent = bar,
	})
	corner(staminaFill, 3)

	for i, info in Config.Magic do
		local slot = make("TextButton", {
			Name = info.Id,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 14 + (i - 1) * 94, 1, -12),
			Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = Color3.fromRGB(28, 32, 48),
			BackgroundTransparency = 0.1,
			AutoButtonColor = true,
			Font = Enum.Font.GothamBold,
			TextSize = 40,
			TextColor3 = WHITE,
			Text = info.Icon,
			Parent = gui,
		})
		corner(slot, 10)
		stroke(slot, Color3.fromRGB(90, 96, 120), 2)
		local badge = make("TextLabel", {
			Position = UDim2.fromOffset(-4, -10),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.fromRGB(20, 22, 32),
			Font = ROUND,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = tostring(i),
			ZIndex = 4,
			Parent = slot,
		})
		corner(badge, 6)
		local cooldown = make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			ZIndex = 2,
			Parent = slot,
		})
		corner(cooldown, 10)
		local lock = make("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(28, 32, 48),
			BackgroundTransparency = 0.15,
			Font = Enum.Font.GothamBold,
			TextSize = 38,
			Text = "🔒",
			ZIndex = 3,
			Parent = slot,
		})
		corner(lock, 10)
		cooldownOverlays[info.Id] = cooldown
		lockIcons[info.Id] = lock
		Hud.AbilitySlots[info.Id] = slot
	end
end

local function buildBottomRight()
	local holder = make("Frame", {
		Name = "Counters",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(260, 210),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	countersHolder = holder
	sectionsLeftLabel = outlined({
		Size = UDim2.new(1, 0, 0, 56),
		Font = SERIF,
		TextSize = 24,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = holder,
	})
	placedLabel = outlined({
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, -78, 0, 64),
		Font = ROUND,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0/0",
		Parent = holder,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 58),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 56,
		Text = "📚",
		Parent = holder,
	})
	carriedLabel = outlined({
		Position = UDim2.fromOffset(0, 138),
		Size = UDim2.new(1, -78, 0, 64),
		Font = ROUND,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0/" .. Config.BaseCapacity,
		Parent = holder,
	})
	make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 134),
		Size = UDim2.fromOffset(72, 72),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 56,
		Text = "📖",
		Parent = holder,
	})

	-- Lijstje met de boeken die je draagt
	inventoryList = make("Frame", {
		Name = "Carried",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -228),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inventoryList,
	})
end

local function buildTopLeft()
	local holder = make("Frame", {
		Name = "TopLeft",
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.fromOffset(240, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	coinsLabel = outlined({
		Size = UDim2.fromOffset(110, 36),
		Font = ROUND,
		TextSize = 28,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🪙 0",
		Parent = holder,
	})
	for i, info in Config.Keys do
		local icon = make("Frame", {
			Position = UDim2.fromOffset(116 + (i - 1) * 30, 8),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = info.Color,
			BackgroundTransparency = 0.8,
			Rotation = if info.Id == "Golden" then 45 else 0,
			Parent = holder,
		})
		corner(icon, if info.Id == "Azure" or info.Id == "Emerald" then 10 else 3)
		stroke(icon, info.Color, 2)
		keyIcons[info.Id] = icon
	end
end

local function buildLeaveButton()
	leaveButton = make("TextButton", {
		Name = "Leave",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 70),
		Size = UDim2.fromOffset(220, 46),
		BackgroundColor3 = NAVY,
		Font = SERIF,
		TextSize = 26,
		TextColor3 = WHITE,
		Text = "🚪 Terug naar de hal",
		Visible = false,
		Parent = gui,
	})
	corner(leaveButton, 8)
	stroke(leaveButton, NAVY_EDGE, 2.5)
	leaveButton.Activated:Connect(function()
		Remotes.Action:FireServer("Leave")
	end)
end

local function buildTouchButtons()
	if not UserInputService.TouchEnabled then
		return
	end
	local defs = { { "Sprint", "🏃" }, { "Drop", "⬇" } }
	for i, def in defs do
		local button = make("TextButton", {
			Name = def[1],
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.42, (i - 1) * 76),
			Size = UDim2.fromOffset(66, 66),
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.1,
			Font = Enum.Font.GothamBold,
			TextSize = 30,
			TextColor3 = WHITE,
			Text = def[2],
			Parent = gui,
		})
		corner(button, 33)
		stroke(button, NAVY_EDGE, 2)
		Hud.Buttons[def[1]] = button
	end
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
			BackgroundColor3 = Color3.fromRGB(170, 0, 20),
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

	-- Uitzicht vanuit een kast
	hiddenOverlay = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 18, 10),
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
			BackgroundColor3 = Color3.fromRGB(255, 220, 160),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = hiddenOverlay,
		})
	end
	outlined({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.65),
		Size = UDim2.fromOffset(500, 30),
		Font = SERIF,
		TextSize = 26,
		Text = "Je zit verstopt... houd E ingedrukt om eruit te gaan",
		ZIndex = 6,
		Parent = hiddenOverlay,
	})

	-- Grote tekst voor het einde van een ronde
	bigBanner = outlined({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.new(0.8, 0, 0, 80),
		Font = SERIF,
		TextScaled = true,
		Text = "",
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})

	-- Wie zette de meeste boeken terug?
	resultsLabel = outlined({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.35, 50),
		Size = UDim2.new(0.8, 0, 0, 40),
		Font = SERIF,
		TextSize = 30,
		Text = "",
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})

	notifyHolder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(560, 200),
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

----------------------------------------------------------------------------
-- Bijwerken
----------------------------------------------------------------------------

function Hud.SetInventory(list: { any }, capacity: number)
	carriedLabel.Text = string.format("%d/%d", #list, capacity)
	for _, child in inventoryList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, book in list do
		local section = Config.FindSection(book.Code)
		local chip = make("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = NAVY,
			BackgroundTransparency = 0.15,
			Parent = inventoryList,
		})
		corner(chip, 6)
		stroke(chip, book.Color, 2)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
		make("TextLabel", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = WHITE,
			Text = string.format("%s  %s", book.Code, if section then section.Name else ""),
			Parent = chip,
		})
	end
end

function Hud.Notify(text: string, color: Color3?)
	local label = make("TextLabel", {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NAVY_DARK,
		BackgroundTransparency = 0.1,
		Font = SERIF,
		TextSize = 24,
		TextColor3 = WHITE,
		Text = "   " .. text .. "   ",
		ZIndex = 9,
		Parent = notifyHolder,
	})
	corner(label, 8)
	stroke(label, color or NAVY_EDGE, 2)
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

function Hud.SetCooldown(id: string, fraction: number)
	local overlay = cooldownOverlays[id]
	if overlay then
		overlay.Size = UDim2.fromScale(1, math.clamp(fraction, 0, 1))
	end
end

function Hud.SetActive(name: string, active: boolean)
	local button = Hud.Buttons[name]
	if button then
		button.BackgroundColor3 = if active then CRIMSON else NAVY
	end
end

function Hud.SetDanger(amount: number)
	if not Hud.Settings.Danger then
		amount = 0
	end
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
		ZIndex = 50,
		Parent = gui,
	})
	local face = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.8),
		BackgroundColor3 = Color3.fromRGB(205, 200, 190),
		ZIndex = 51,
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
			ZIndex = 52,
			Parent = face,
		})
		corner(eye, 30)
	end
	local mouth = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.5, 0.2),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 52,
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
		ZIndex = 53,
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

local function updatePlayerStats()
	coinsLabel.Text = "🪙 " .. coins()
	for id, icon in keyIcons do
		local has = player:GetAttribute("Key_" .. id) == true
		icon.BackgroundTransparency = if has then 0 else 0.8
	end
	for id, lock in lockIcons do
		lock.Visible = player:GetAttribute("Magic_" .. id) ~= true
	end
	refreshOpenPanel()
end

-- De status-map van de zaal waar je nu in bent (nil = in de hal)
local function currentRoomState(): Instance?
	local id = player:GetAttribute("Room")
	local folder = ReplicatedStorage:FindFirstChild("RoomState")
	if type(id) ~= "string" or not folder then
		return nil
	end
	return folder:FindFirstChild(id)
end

local function updateRound()
	local roomState = currentRoomState()
	if not roomState then
		-- In de hal
		timerLabel.Visible = false
		countersHolder.Visible = false
		leaveButton.Visible = false
		bigBanner.Visible = false
		resultsLabel.Visible = false
		objectiveLabel.Text = "Kies een zaal!"
		return
	end
	timerLabel.Visible = true
	countersHolder.Visible = true
	leaveButton.Visible = true

	local state = roomState:GetAttribute("RoundState") or "Idle"
	local timeLeft = roomState:GetAttribute("TimeLeft") or 0
	local placed = roomState:GetAttribute("Placed") or 0
	local total = roomState:GetAttribute("Total") or 0
	local message = roomState:GetAttribute("Message") or ""
	local playerCount = roomState:GetAttribute("Players") or 1

	timerLabel.Text = formatTime(timeLeft)
	timerLabel.TextColor3 = if state == "Playing" and timeLeft <= 60 then Color3.fromRGB(255, 90, 90) else WHITE
	placedLabel.Text = string.format("%d/%d", placed, total)

	if state == "Playing" then
		local left = total - placed
		sectionsLeftLabel.Text = string.format("nog %d boek%s te gaan", left, if left == 1 then "" else "en")
		objectiveLabel.Text = if playerCount > 1 then string.format("Samen opruimen · 👥 %d", playerCount) else "Ruim alle kasten op"
	elseif state == "Starting" then
		sectionsLeftLabel.Text = "de zaal gaat zo open..."
		objectiveLabel.Text = message
	else
		sectionsLeftLabel.Text = ""
		objectiveLabel.Text = message
	end

	if state == "Won" or state == "Lost" then
		bigBanner.Visible = true
		bigBanner.Text = message
		bigBanner.TextColor3 = if state == "Won" then Color3.fromRGB(150, 255, 160) else Color3.fromRGB(255, 120, 120)
		local results = roomState:GetAttribute("Results") or ""
		resultsLabel.Text = results
		resultsLabel.Visible = results ~= ""
	else
		bigBanner.Visible = false
		resultsLabel.Visible = false
	end
end

local function fitToScreen()
	-- Op een telefoon wordt het menu kleiner
	local view = Workspace.CurrentCamera.ViewportSize
	local menu = gui:FindFirstChild("Menu")
	local scale = menu and menu:FindFirstChild("Scale") :: UIScale?
	if scale then
		scale.Scale = math.clamp(view.Y / 900, 0.55, 1)
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
	buildMenu()
	buildBottomLeft()
	buildBottomRight()
	buildTopLeft()
	buildLeaveButton()
	buildTouchButtons()
	buildShopPanel()
	buildMagicPanel()
	buildAssistantPanel()
	buildSettingsPanel()

	fitToScreen()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

	-- Elke zaal heeft een eigen status-map; we luisteren naar allemaal
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("RoomState")
		local function watch(roomState: Instance)
			roomState.AttributeChanged:Connect(updateRound)
		end
		for _, roomState in folder:GetChildren() do
			watch(roomState)
		end
		folder.ChildAdded:Connect(watch)
		updateRound()
	end)
	updateRound()
	player.AttributeChanged:Connect(function(name)
		if name == "Room" then
			updateRound()
		end
		updatePlayerStats()
	end)
	updatePlayerStats()
end

return Hud
