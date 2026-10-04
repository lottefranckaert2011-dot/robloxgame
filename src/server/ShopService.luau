-- Winkel, magie en de assistent: kopen met munten en de vaardigheden uitvoeren.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local KeyService = require(script.Parent.KeyService)
local RoomService = require(script.Parent.RoomService)

local ShopService = {}

local GOOD = Color3.fromRGB(120, 255, 140)
local BAD = Color3.fromRGB(255, 110, 110)

local cooldowns: { [Player]: { [string]: number } } = {}

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

local function buy(player: Player, kind: string, id: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if kind == "Shop" then
		local item = Config.FindShopItem(id)
		if not item then
			return
		end
		local level = profile.Upgrades[id] or 0
		if level >= item.MaxLevel then
			notify(player, item.Name .. " is al op het hoogste niveau.", BAD)
			return
		end
		local cost = Config.ShopCost(item, level)
		if not DataService.SpendCoins(player, cost) then
			notify(player, "Niet genoeg munten! Je hebt er " .. cost .. " nodig.", BAD)
			return
		end
		profile.Upgrades[id] = level + 1
		notify(player, string.format("%s %s gekocht! (niveau %d)", item.Icon, item.Name, level + 1), GOOD)
	elseif kind == "Magic" then
		local info = Config.FindMagic(id)
		if not info then
			return
		end
		if profile.Magic[id] then
			notify(player, "Die magie heb je al.", BAD)
			return
		end
		if not DataService.SpendCoins(player, info.Cost) then
			notify(player, "Niet genoeg munten! Je hebt er " .. info.Cost .. " nodig.", BAD)
			return
		end
		profile.Magic[id] = true
		local slot = table.find(Config.Magic, info) or 0
		notify(player, string.format("%s %s ontgrendeld! Druk op %d.", info.Icon, info.Name, slot), GOOD)
	elseif kind == "Assistant" then
		local nextLevel = profile.Assistant + 1
		local levelInfo = Config.Assistant.Levels[nextLevel]
		if not levelInfo then
			notify(player, Config.Assistant.Name .. " is al op het hoogste niveau.", BAD)
			return
		end
		if not DataService.SpendCoins(player, levelInfo.Cost) then
			notify(player, "Niet genoeg munten! Je hebt er " .. levelInfo.Cost .. " nodig.", BAD)
			return
		end
		profile.Assistant = nextLevel
		notify(player, string.format("🦉 %s helpt je nu (niveau %d)!", Config.Assistant.Name, nextLevel), GOOD)
	else
		return
	end
	KeyService.Refresh(player)
end

local function useAbility(player: Player, id: string)
	local profile = DataService.Get(player)
	local info = Config.FindMagic(id)
	if not profile or not info or not profile.Magic[id] then
		return
	end
	local mine = cooldowns[player]
	if not mine then
		mine = {}
		cooldowns[player] = mine
	end
	local now = os.clock()
	-- Een klein beetje speling, de client houdt de afkoeltijd ook bij
	if (mine[id] or 0) > now + 0.5 then
		return
	end
	-- De afkoeltijd telt alleen als de magie echt iets deed
	local books = RoomService.GetBooks(player)
	if id == "Assemble" then
		local got = if books then books:Assemble(player, Config.AssembleRadius) else 0
		if got > 0 then
			mine[id] = now + info.Cooldown
			player:SetAttribute("Cooldown_" .. id, Workspace:GetServerTimeNow() + info.Cooldown)
		end
		notify(player, if got > 0 then string.format("🧲 %d boek%s verzameld!", got, if got == 1 then "" else "en") else "🧲 Geen boeken in de buurt (of je handen zijn vol).", Color3.fromRGB(150, 210, 255))
	elseif id == "AutoShelf" then
		local placed = if books then books:AutoShelf(player) else 0
		if placed > 0 then
			mine[id] = now + info.Cooldown
			player:SetAttribute("Cooldown_" .. id, Workspace:GetServerTimeNow() + info.Cooldown)
		end
		notify(player, if placed > 0 then string.format("✨ %d boek%s vliegen naar hun kast!", placed, if placed == 1 then "" else "en") else "✨ Je draagt geen boeken.", Color3.fromRGB(255, 230, 140))
	end
end

function ShopService.Init()
	Remotes.Action.OnServerEvent:Connect(function(player, action, a, b)
		if action == "Buy" and type(a) == "string" and type(b) == "string" then
			buy(player, a, b)
		elseif action == "Ability" and type(a) == "string" then
			useAbility(player, a)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)

	-- De assistent: zet om de zoveel seconden een boek terug voor elke speler die er een heeft
	task.spawn(function()
		local timers: { [Player]: number } = {}
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				local level = if profile then profile.Assistant else 0
				local levelInfo = Config.Assistant.Levels[level]
				local books = RoomService.GetBooks(player)
				if levelInfo and books and books.Active then
					timers[player] = (timers[player] or 0) + 1
					if timers[player] >= levelInfo.Interval then
						timers[player] = 0
						task.spawn(books.AssistantPlace, books, player)
					end
				end
			end
			for player in timers do
				if not player.Parent then
					timers[player] = nil
				end
			end
		end
	end)
end

return ShopService
