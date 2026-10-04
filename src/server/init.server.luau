-- Startpunt van de server: bouwt de hal en de zalen en start alle systemen.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- maakt de RemoteEvents aan

local LobbyBuilder = require(script.LobbyBuilder)
local KeyService = require(script.KeyService)
local HideService = require(script.HideService)
local DataService = require(script.DataService)
local RoomService = require(script.RoomService)
local ShopService = require(script.ShopService)

-- Warme, lichte bibliotheek zoals in het origineel
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(150, 124, 118)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.4
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.4
Lighting.FogEnd = 100000
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = 0.12
colorCorrection.Contrast = 0.05
colorCorrection.Brightness = 0.02
colorCorrection.TintColor = Color3.fromRGB(255, 244, 236)
colorCorrection.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.6
bloom.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.12
atmosphere.Haze = 0.5
atmosphere.Color = Color3.fromRGB(255, 225, 235)
atmosphere.Decay = Color3.fromRGB(180, 120, 200)
atmosphere.Parent = Lighting

Players.RespawnTime = Config.RespawnTime
StarterPlayer.CharacterWalkSpeed = Config.WalkSpeed
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = Config.BaseJumpHeight
StarterPlayer.EnableMouseLockOption = false -- Shift is voor sprinten

local lobby = LobbyBuilder.Build(Workspace)

KeyService.Init()
HideService.Init()
DataService.Init()
RoomService.Init(lobby) -- bouwt de zalen
ShopService.Init()

print(Config.GameName .. " has started!")
