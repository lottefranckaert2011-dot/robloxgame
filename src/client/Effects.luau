-- Effecten: flikkerende lampjes, rode rand en hartslag-schudden als
-- het monster dichtbij is, de jumpscare, en gevonden sleutels verbergen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Effects = {}

local Hud
local flickerLights: { { part: BasePart, light: Light } } = {}

local function collectFlickers(library: Instance)
	table.clear(flickerLights)
	for _, d in library:GetDescendants() do
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

-- Sleutels die je al hebt worden (alleen voor jou) onzichtbaar
local function updateKeys(library: Instance)
	local keys = library:FindFirstChild("Keys")
	if not keys then
		return
	end
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

function Effects.Init(hud)
	Hud = hud

	local library = Workspace:WaitForChild("Library")
	collectFlickers(library)
	task.spawn(flickerLoop)

	updateKeys(library)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Key_" then
			updateKeys(library)
		elseif name == "Hidden" then
			Hud.SetHidden(player:GetAttribute("Hidden") == true)
		end
	end)
	-- De sleutels kunnen net na de bibliotheek binnenkomen
	library.ChildAdded:Connect(function(child)
		if child.Name == "Keys" then
			task.wait(0.5)
			updateKeys(library)
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
		local monster = Workspace:FindFirstChild(Config.Monster.Name)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local monsterRoot = monster and monster:FindFirstChild("HumanoidRootPart") :: BasePart?
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
