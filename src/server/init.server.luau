-- Startpunt van de server: bouwt de bibliotheek en start alle systemen.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- maakt de RemoteEvents aan

local LibraryBuilder = require(script.LibraryBuilder)
local BookService = require(script.BookService)
local MonsterService = require(script.MonsterService)
local KeyService = require(script.KeyService)
local HideService = require(script.HideService)
local DataService = require(script.DataService)
local RoundService = require(script.RoundService)

-- Nachtmerrie-sfeer: middernacht, bijna geen licht en dichte mist
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(34, 30, 44)
Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 16)
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.GlobalShadows = true
Lighting.FogColor = Color3.fromRGB(6, 5, 10)
Lighting.FogStart = 10
Lighting.FogEnd = 110
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = -0.35
colorCorrection.Contrast = 0.15
colorCorrection.TintColor = Color3.fromRGB(220, 215, 255)
colorCorrection.Parent = Lighting

Players.RespawnTime = Config.RespawnTime
StarterPlayer.CharacterWalkSpeed = Config.WalkSpeed
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = Config.BaseJumpHeight
StarterPlayer.EnableMouseLockOption = false -- Shift is voor sprinten

local library = LibraryBuilder.Build()

BookService.Init(library)
MonsterService.Init(library)
KeyService.Init(library)
HideService.Init(library)
DataService.Init()

MonsterService.OnCatch = function(player)
	BookService.Scatter(player)
end
MonsterService.OnHiddenCatch = function(player)
	HideService.Exit(player)
end

-- Wie de verdieping af valt of vastzit, komt terug bij de balie
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		player:SetAttribute("Flashlight", false)
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		task.spawn(function()
			while character.Parent do
				if root.Position.Y < -20 then
					character:PivotTo(library.SpawnCFrame)
				end
				task.wait(2)
			end
		end)
	end)
end)

-- Flashlight-attribuut voor het monster (de lamp zelf staat op de client en wordt hier gesynchroniseerd)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.Action.OnServerEvent:Connect(function(player, action, value)
	if action == "Flashlight" then
		local on = value == true
		player:SetAttribute("Flashlight", on)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if head then
			local light = head:FindFirstChild("Flashlight") :: SpotLight?
			if not light then
				local newLight = Instance.new("SpotLight")
				newLight.Name = "Flashlight"
				newLight.Range = 45
				newLight.Angle = 50
				newLight.Brightness = 3
				newLight.Shadows = true
				newLight.Color = Color3.fromRGB(255, 245, 220)
				newLight.Face = Enum.NormalId.Front
				newLight.Parent = head
				light = newLight
			end
			if light then
				light.Enabled = on
			end
		end
	end
end)

RoundService.Init()

print(Config.GameName .. " is gestart!")
