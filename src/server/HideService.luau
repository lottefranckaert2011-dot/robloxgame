-- Verstoppen in kluisjes. Het monster ziet je daar niet...
-- tenzij ze je naar binnen zag kruipen!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HideService = {}

local occupant: { [any]: Player } = {}
local hidingIn: { [Player]: any } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function HideService.Exit(player: Player)
	local locker = hidingIn[player]
	if not locker then
		return
	end
	hidingIn[player] = nil
	occupant[locker] = nil
	locker.Prompt.ActionText = "Hide"
	player:SetAttribute("Hidden", nil)
	local character = player.Character
	local root = getRoot(player)
	if character and root then
		character:PivotTo(locker.Outside)
		root.Anchored = false
	end
end

local function enter(player: Player, locker)
	local character = player.Character
	local root = getRoot(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if occupant[locker] then
		Remotes.Notify:FireClient(player, "Someone is already hiding in here!", Color3.fromRGB(255, 200, 120))
		return
	end
	hidingIn[player] = locker
	occupant[locker] = player
	locker.Prompt.ActionText = "Get out"
	player:SetAttribute("Hidden", true)
	character:PivotTo(locker.Inside)
	root.Anchored = true
	Remotes.Notify:FireClient(player, "You are hiding. Hold your breath...", Color3.fromRGB(180, 180, 255))
end

function HideService.AddLibrary(library)
	for _, locker in library.Lockers do
		locker.Prompt.Triggered:Connect(function(player)
			if hidingIn[player] == locker then
				HideService.Exit(player)
			elseif not hidingIn[player] then
				enter(player, locker)
			end
		end)
	end
end

function HideService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			-- Na respawnen zit je nergens meer in
			local locker = hidingIn[player]
			if locker then
				hidingIn[player] = nil
				occupant[locker] = nil
				locker.Prompt.ActionText = "Hide"
			end
			player:SetAttribute("Hidden", nil)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local locker = hidingIn[player]
		if locker then
			occupant[locker] = nil
			locker.Prompt.ActionText = "Hide"
		end
		hidingIn[player] = nil
	end)
end

return HideService
