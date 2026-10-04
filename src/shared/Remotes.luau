-- Alle RemoteEvents op één plek. De server maakt ze aan, de client wacht erop.
--   Inventory (server -> client): welke boeken je draagt
--   Notify    (server -> client): korte melding in beeld
--   Caught    (server -> client): je bent gepakt (jumpscare)
--   Action    (client -> server): "Drop", "Leave", "PlayRoom" (zaal), "Buy" (soort, id) of "Ability" (id)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Inventory", "Notify", "Caught", "Action" }

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	Inventory = get("Inventory"),
	Notify = get("Notify"),
	Caught = get("Caught"),
	Action = get("Action"),
}
