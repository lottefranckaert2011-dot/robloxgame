-- "De Bibliothecaresse": het monster dat door de donkere bibliotheek sluipt.
-- Ze patrouilleert, hoort sprintende spelers en fouten, en jaagt op wie ze ziet.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local M = Config.Monster

export type Monster = {
	OnCatch: ((player: Player) -> ())?,
	OnHiddenCatch: ((player: Player) -> ())?,
	Progress: number, -- 0..1, hoe ver de spelers zijn
	SpeedMultiplier: number, -- extra snelheid in Pro Mode
	Spawn: () -> (),
	Despawn: () -> (),
	Noise: (position: Vector3, range: number) -> (),
}

local MonsterService = {}

-- Maakt het monster voor één zaal. `getPlayers` geeft de spelers in die zaal.
function MonsterService.new(room: Config.RoomInfo, library, getPlayers: () -> { Player }): Monster
	local self = {
		OnCatch = nil,
		OnHiddenCatch = nil,
		Progress = 0,
		SpeedMultiplier = 1,
	} :: any

	local model: Model? = nil
	local humanoid: Humanoid? = nil
	local root: BasePart? = nil
	local head: BasePart? = nil
	local shushLabel: TextLabel? = nil
	local running = false
	local loopId = 0

	-- Toestand van de AI
	local state = "Wander" -- Wander | Investigate | Chase | Pause
	local target: Player? = nil
	local lastSeen = 0
	local lastKnown: Vector3? = nil
	local goal: Vector3? = nil
	local waypoints: { PathWaypoint } = {}
	local wpIndex = 1
	local lastPathTime = 0
	local idleUntil = 0
	local stuckCheckPos = Vector3.zero
	local stuckCheckTime = 0
	local sawHide = false
	local hideChaseStart = 0
	local pendingNoise: Vector3? = nil

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 10,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	local function weldPart(parent: Model, rootPart: BasePart, props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		local offset: CFrame = props.Offset
		for key, value in props do
			if key ~= "Offset" then
				(p :: any)[key] = value
			end
		end
		p.CFrame = rootPart.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = p
		weld.Parent = p
		p.Parent = parent
		return p
	end

	local function buildModel(position: Vector3): Model
		local m = Instance.new("Model")
		m.Name = M.Name

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Transparency = 1
		hrp.CanCollide = false
		hrp.CFrame = CFrame.new(position)
		hrp.Parent = m
		m.PrimaryPart = hrp

		local black = Color3.fromRGB(15, 12, 18)
		local skin = Color3.fromRGB(205, 200, 190)

		-- Lang zwart gewaad
		weldPart(m, hrp, {
			Name = "Torso",
			Size = Vector3.new(3, 3.5, 1.4),
			Color = black,
			Material = Enum.Material.Fabric,
			CanCollide = true,
			Massless = false,
			Offset = CFrame.new(0, 1.25, 0),
		})
		weldPart(m, hrp, {
			Name = "Robe",
			Size = Vector3.new(3.4, 4.6, 1.8),
			Color = black,
			Material = Enum.Material.Fabric,
			Offset = CFrame.new(0, -2.6, 0),
		})
		-- Veel te lange armen
		for _, side in { -1, 1 } do
			weldPart(m, hrp, {
				Name = "Arm",
				Size = Vector3.new(0.6, 6.5, 0.6),
				Color = black,
				Material = Enum.Material.Fabric,
				Offset = CFrame.new(side * 1.85, 0, -0.2) * CFrame.Angles(math.rad(-12), 0, math.rad(side * 6)),
			})
			weldPart(m, hrp, {
				Name = "Hand",
				Size = Vector3.new(0.7, 1.2, 0.3),
				Color = skin,
				Offset = CFrame.new(side * 2.1, -3.4, -0.9),
			})
		end
		local headPart = weldPart(m, hrp, {
			Name = "Head",
			Size = Vector3.new(1.8, 2.1, 1.8),
			Color = skin,
			CanCollide = true,
			Massless = false,
			Offset = CFrame.new(0, 4.05, 0),
		})
		-- Haarknot
		weldPart(m, hrp, {
			Name = "Bun",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Color = Color3.fromRGB(60, 60, 64),
			Offset = CFrame.new(0, 5.3, 0.5),
		})
		-- Gloeiende ogen en een bril
		for _, side in { -1, 1 } do
			weldPart(m, hrp, {
				Name = "Eye",
				Size = Vector3.new(0.4, 0.28, 0.1),
				Color = Color3.fromRGB(255, 20, 20),
				Material = Enum.Material.Neon,
				Offset = CFrame.new(side * 0.42, 4.25, -0.92),
			})
			weldPart(m, hrp, {
				Name = "Glasses",
				Size = Vector3.new(0.65, 0.5, 0.05),
				Color = Color3.fromRGB(20, 20, 20),
				Transparency = 0.3,
				Offset = CFrame.new(side * 0.42, 4.25, -0.97),
			})
		end
		weldPart(m, hrp, {
			Name = "Mouth",
			Size = Vector3.new(0.9, 0.12, 0.05),
			Color = Color3.new(0, 0, 0),
			Offset = CFrame.new(0, 3.55, -0.92),
		})

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 40, 40)
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = headPart

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(220, 60)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 80
		billboard.Parent = headPart
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.TextScaled = true
		label.Font = Enum.Font.Creepster
		label.TextColor3 = Color3.fromRGB(255, 50, 50)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard

		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R15
		hum.HipHeight = 4
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.MaxHealth = math.huge
		hum.Health = math.huge
		hum.BreakJointsOnDeath = false
		hum.WalkSpeed = M.WanderSpeed * room.MonsterSpeed * self.SpeedMultiplier
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		hum.Parent = m

		m:SetAttribute("IsMonster", true)
		m.Parent = library.Model
		hrp:SetNetworkOwner(nil)

		model, humanoid, root, head, shushLabel = m, hum, hrp, headPart, label
		return m
	end

	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end

	local function chaseSpeed(): number
		return (M.ChaseSpeedStart + (M.ChaseSpeedEnd - M.ChaseSpeedStart) * math.clamp(self.Progress, 0, 1)) * room.MonsterSpeed * self.SpeedMultiplier
	end

	local function setGoal(position: Vector3)
		if not root then
			return
		end
		goal = position
		waypoints = {}
		wpIndex = 1
		lastPathTime = os.clock()
		local ok = pcall(function()
			path:ComputeAsync(root.Position, position)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			wpIndex = math.min(2, #waypoints)
		end
	end

	-- Loopt de berekende route af. Geeft true terug als het doel bereikt is.
	local function followPath(): boolean
		if not root or not humanoid or not goal then
			return true
		end
		if #waypoints == 0 then
			humanoid:MoveTo(goal)
			return flat(root.Position - goal).Magnitude < 3
		end
		local wp = waypoints[wpIndex]
		if not wp then
			return true
		end
		local delta = wp.Position - root.Position
		if flat(delta).Magnitude < 3 and math.abs(delta.Y) < 7 then
			wpIndex += 1
			wp = waypoints[wpIndex]
			if not wp then
				return true
			end
		end
		humanoid:MoveTo(wp.Position)
		return false
	end

	local function visionParams(): RaycastParams
		local exclude: { Instance } = {}
		if model then
			table.insert(exclude, model)
		end
		local books = library.Books
		if books then
			table.insert(exclude, books)
		end
		for _, player in getPlayers() do
			if player.Character then
				table.insert(exclude, player.Character)
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		return params
	end

	local function characterRoot(player: Player): (BasePart?, Humanoid?)
		local character = player.Character
		if not character then
			return nil, nil
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hum or not hrp or hum.Health <= 0 then
			return nil, nil
		end
		return hrp, hum
	end

	local function canSee(player: Player, params: RaycastParams): boolean
		if not root or not head then
			return false
		end
		local hrp = characterRoot(player)
		if not hrp or player:GetAttribute("Hidden") then
			return false
		end
		local eye = head.Position
		local offset = hrp.Position - eye
		local dist = offset.Magnitude
		if dist > M.SightRange then
			return false
		end
		if dist > M.CloseDetectRange then
			local look = flat(root.CFrame.LookVector).Unit
			local dir = flat(offset)
			if dir.Magnitude > 0.1 then
				local angle = math.deg(math.acos(math.clamp(look:Dot(dir.Unit), -1, 1)))
				if angle > M.FieldOfView / 2 then
					return false
				end
			end
		end
		local result = Workspace:Raycast(eye, offset, params)
		return result == nil
	end

	local function startChase(player: Player)
		if state ~= "Chase" or target ~= player then
			state = "Chase"
			target = player
			sawHide = false
			Remotes.Notify:FireClient(player, "Ze heeft je gezien! RENNEN!", Color3.fromRGB(255, 40, 40))
			if head then
				Sounds.Play("Shush", head, 1)
			end
		end
		lastSeen = os.clock()
	end

	local function investigate(position: Vector3)
		if state == "Chase" then
			return
		end
		state = "Investigate"
		setGoal(position)
	end

	function self.Noise(position: Vector3, range: number)
		if not root or not running then
			return
		end
		-- Wordt in de volgende tick verwerkt (zo rekent er maar één thread routes uit)
		if (root.Position - position).Magnitude <= range then
			pendingNoise = position
		end
	end

	local function catch(player: Player)
		local hrp, hum = characterRoot(player)
		if not hrp or not hum then
			return
		end
		Remotes.Caught:FireClient(player)
		if self.OnCatch then
			self.OnCatch(player)
		end
		Sounds.Play("Caught", hrp, 1)
		task.delay(0.6, function()
			if hum.Parent then
				hum.Health = 0
			end
		end)
		state = "Pause"
		target = nil
		idleUntil = os.clock() + 3
		if humanoid and root then
			humanoid:MoveTo(root.Position)
		end
	end

	local function pickWander()
		local points = library.Waypoints
		setGoal(points[math.random(1, #points)])
	end

	local function step()
		if not root or not humanoid or not shushLabel then
			return
		end
		local now = os.clock()
		local params = visionParams()

		if pendingNoise then
			local position = pendingNoise
			pendingNoise = nil
			if state == "Wander" or state == "Investigate" then
				investigate(position)
			end
		end

		-- Zien
		local best: Player? = nil
		local bestDist = math.huge
		for _, player in getPlayers() do
			if canSee(player, params) then
				local hrp = characterRoot(player)
				if hrp then
					local d = (hrp.Position - root.Position).Magnitude
					if d < bestDist then
						best, bestDist = player, d
					end
				end
			end
		end
		if best and state ~= "Pause" then
			startChase(best)
		end

		-- Horen: sprintende spelers in de buurt
		if state == "Wander" or state == "Investigate" then
			for _, player in getPlayers() do
				local hrp = characterRoot(player)
				if hrp and not player:GetAttribute("Hidden") then
					local speed = flat(hrp.AssemblyLinearVelocity).Magnitude
					local d = (hrp.Position - root.Position).Magnitude
					if speed > Config.WalkSpeed + 2 and d < M.HearSprintRange and math.abs(hrp.Position.Y - root.Position.Y) < 14 then
						if not goal or (goal - hrp.Position).Magnitude > 10 or state == "Wander" then
							investigate(hrp.Position)
						end
						break
					end
				end
			end
		end

		if state == "Pause" then
			humanoid.WalkSpeed = 0
			shushLabel.Text = ""
			if now >= idleUntil then
				state = "Wander"
				pickWander()
			end
			return
		end

		if state == "Chase" then
			humanoid.WalkSpeed = chaseSpeed()
			shushLabel.Text = "SSSSHHHH!"
			local player = target
			local hrp = player and characterRoot(player)
			if not player or not hrp then
				state = "Wander"
				target = nil
				pickWander()
				return
			end

			if player:GetAttribute("Hidden") then
				-- Zag ze je wegkruipen? Dan trekt ze je uit het kluisje!
				if not sawHide then
					sawHide = true
					hideChaseStart = now
					local closeEnough = (hrp.Position - root.Position).Magnitude < 16
					player:SetAttribute("SeenHiding", closeEnough)
					-- Loop naar de plek vlak voor de deur van het kluisje
					setGoal((hrp.CFrame * CFrame.new(0, 0, -4.5)).Position)
				end
				local arrived = followPath() or (hrp.Position - root.Position).Magnitude < 6
				if not arrived and now - hideChaseStart > 10 then
					-- Kwam er niet bij: opgeven
					player:SetAttribute("SeenHiding", nil)
					state = "Investigate"
					target = nil
					goal = nil
					idleUntil = now + 2
					return
				end
				if arrived then
					if player:GetAttribute("SeenHiding") and self.OnHiddenCatch then
						self.OnHiddenCatch(player)
						catch(player)
					else
						state = "Investigate"
						idleUntil = now + 3
						goal = nil
					end
					player:SetAttribute("SeenHiding", nil)
				end
				return
			end
			sawHide = false

			local d = (hrp.Position - root.Position).Magnitude
			if d <= M.CatchDistance and math.abs(hrp.Position.Y - root.Position.Y) < 6 then
				catch(player)
				return
			end

			if best == player then
				lastKnown = hrp.Position
				waypoints = {}
				goal = hrp.Position
				humanoid:MoveTo(hrp.Position)
			else
				if now - lastSeen > M.LoseTargetTime then
					Remotes.Notify:FireClient(player, "Ze is je kwijt... voor nu.", Color3.fromRGB(200, 200, 255))
					state = "Investigate"
					target = nil
					setGoal(lastKnown or hrp.Position)
					return
				end
				-- Ze weet ongeveer waar je bent
				if now - lastPathTime > 1 then
					setGoal(hrp.Position)
				end
				followPath()
			end
			return
		end

		shushLabel.Text = ""
		humanoid.WalkSpeed = M.WanderSpeed * room.MonsterSpeed * self.SpeedMultiplier

		if state == "Investigate" then
			if not goal then
				-- Even rondkijken na een onderzoek
				if now >= idleUntil then
					state = "Wander"
					pickWander()
				end
				return
			end
			if followPath() then
				goal = nil
				idleUntil = now + 2.5
			end
		elseif state == "Wander" then
			if not goal then
				if now >= idleUntil then
					pickWander()
				end
			elseif followPath() then
				goal = nil
				idleUntil = now + math.random(10, 30) / 10
			end
		end

		-- Vastgelopen? Kies een nieuw doel
		if now - stuckCheckTime > 2.5 then
			if goal and (root.Position - stuckCheckPos).Magnitude < 1 then
				pickWander()
			end
			stuckCheckPos = root.Position
			stuckCheckTime = now
		end
	end

	function self.Spawn()
		self.Despawn()
		buildModel(library.MonsterSpawn)
		running = true
		state = "Wander"
		target = nil
		goal = nil
		waypoints = {}
		pendingNoise = nil
		loopId += 1
		local myId = loopId
		for _, player in getPlayers() do
			Remotes.Notify:FireClient(player, M.Name .. " is wakker geworden... wees STIL.", Color3.fromRGB(255, 60, 60))
		end
		task.spawn(function()
			while running and loopId == myId do
				local ok, err = pcall(step)
				if not ok then
					warn("[Monster] " .. tostring(err))
				end
				task.wait(0.15)
			end
		end)
	end

	function self.Despawn()
		running = false
		if model then
			model:Destroy()
		end
		model, humanoid, root, head, shushLabel = nil, nil, nil, nil, nil
	end

	return self
end

return MonsterService
