-- De vier verborgen sleutels. Elke sleutel geeft een permanente upgrade
-- en wordt per speler opgeslagen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local KeyService = {}

-- Berekent alle upgrades (sleutels, winkel, magie, assistent) en zet ze als attributen
local function applyUpgrades(player: Player)
	local profile = DataService.Get(player)
	local keys = if profile then profile.Keys else {}
	local upgrades = if profile then profile.Upgrades else {}
	for _, info in Config.Keys do
		player:SetAttribute("Key_" .. info.Id, keys[info.Id] == true)
	end
	for _, item in Config.Shop do
		player:SetAttribute("Up_" .. item.Id, upgrades[item.Id] or 0)
	end
	for _, info in Config.Magic do
		player:SetAttribute("Magic_" .. info.Id, profile ~= nil and profile.Magic[info.Id] == true)
	end
	player:SetAttribute("Assistant", if profile then profile.Assistant else 0)

	local capacity = Config.BaseCapacity + (upgrades.Capacity or 0)
	if keys.Golden then
		capacity += 3
	end
	if keys.Azure then
		capacity += 3
	end
	local bonusSpeed = (upgrades.Speed or 0) * Config.SpeedPerLevel
	player:SetAttribute("Capacity", capacity)
	player:SetAttribute("WalkSpeed", Config.WalkSpeed + bonusSpeed)
	player:SetAttribute("SprintSpeed", (if keys.Emerald then Config.EmeraldSprintSpeed else Config.SprintSpeed) + bonusSpeed)
	player:SetAttribute("JumpHeight", if keys.Crimson then Config.CrimsonJumpHeight else Config.BaseJumpHeight)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = player:GetAttribute("JumpHeight")
	end
end

local function buildKey(info: Config.KeyInfo, position: Vector3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "Key_" .. info.Id
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = info.Color
	p.CFrame = CFrame.new(position)
	if info.Id == "Crimson" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.4, 1.6, 1.6)
	elseif info.Id == "Golden" then
		p.Size = Vector3.new(1.1, 1.1, 1.1)
		p.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	elseif info.Id == "Azure" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.4, 1.4, 1.4)
	else
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.2, 1.2, 1.2)
	end
	p:SetAttribute("KeyId", info.Id)

	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = p

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Oprapen"
	prompt.ObjectText = info.Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	prompt.Triggered:Connect(function(player)
		local profile = DataService.Get(player)
		if not profile then
			return
		end
		if profile.Keys[info.Id] then
			Remotes.Notify:FireClient(player, "Deze sleutel heb je al.", Color3.fromRGB(200, 200, 200))
			return
		end
		profile.Keys[info.Id] = true
		applyUpgrades(player)
		Remotes.Notify:FireClient(player, string.format("🔑 %s gevonden! %s", info.Name, info.Description), info.Color)
	end)

	-- Langzaam ronddraaien en zweven
	p.Parent = parent
	local tween = TweenService:Create(
		p,
		TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = p.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(180), 0) }
	)
	tween:Play()
end

function KeyService.Refresh(player: Player)
	applyUpgrades(player)
end

-- Elke zaal heeft zijn eigen vier sleutels; je hoeft ze maar één keer te vinden
function KeyService.AddLibrary(library)
	local folder = Instance.new("Folder")
	folder.Name = "Keys"
	folder.Parent = library.Model
	for _, info in Config.Keys do
		local spot = library.KeySpots[info.Id]
		if spot then
			buildKey(info, spot, folder)
		end
	end
end

function KeyService.Init()
	DataService.OnLoaded = function(player)
		applyUpgrades(player)
	end
	local function onPlayer(player: Player)
		applyUpgrades(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			applyUpgrades(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return KeyService
