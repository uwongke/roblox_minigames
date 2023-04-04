--[[
    PlayerService.lua
    Author: Aaron Jay (se_yai)
    23 July 2022

    Description: Manage player spawning and interactions with the server involving data
]]
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")
local PlayerContainer = require(Modules.PlayerContainer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local buildRagdoll = require(Shared.Ragdoll.buildRagdoll)

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local Promise = require(Packages.Promise)

local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	Client = {
		SendFirstTime = Knit.CreateSignal(),
		CharacterLoaded = Knit.CreateSignal(),
	},
})

-- Get the player's container to interact with it
function PlayerService:GetContainer(player)
	-- ensure player exists
	if not player then
		warn("Cannot get container of nonexistent player")
		return
	end

	local container = self._players[player]
	if container then
		return container
	else
		warn("Could not get container for " .. tostring(player))
	end
end

-- Useful if other things need to be done before/after a character is loaded
function PlayerService:CustomLoadCharacter(player)
	player:LoadCharacter()
end

-- Called when player loads their data replica for the first time, then "yields" until character loads
function PlayerService.Client:DidLoadReplica(player: Player)
	local thisContainer = self.Server._players[player]
	if not player.Character then
		self.Server:CustomLoadCharacter(player, thisContainer.Profile.Data.Kit)
		self.SendFirstTime:Fire(player)
	end
	return true
end

function PlayerService:KnitStart()
	-- instantiate player function
	local function initPlayer(player)
		local newContainer = PlayerContainer.new(player)
		self._players[player] = newContainer
		self.ContainerCreated:Fire(player, newContainer)

		-- create leader stats
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		-- // create individual leaderstat values!

		--[[ // example:
        local sos = Instance.new("IntValue")
        sos.Name = "H/Rs"
        sos.Value = 0
        sos.Parent = leaderstats
        --]]

		-- initialize data
		-- spawn player
		player.CharacterAdded:Connect(function(character)
			local playerHumanoid = character:WaitForChild("Humanoid", 3)
			playerHumanoid.Died:Connect(function()
				task.delay(Players.RespawnTime, function()
					player:LoadCharacter()
				end)
			end)

			task.wait()
			-- buildRagdoll(playerHumanoid)

			for _, v in ipairs(character:GetChildren()) do
				if v:IsA("BasePart") then
					PhysicsService:SetPartCollisionGroup(v, "Players") -- // useful for disabling player-player collisions
				end
			end

			self.CharacterLoadedEvent:Fire(player, character)
			self.Client.CharacterLoaded:Fire(player, character)
		end)
	end

	-- cleanup player function
	local function cleanupPlayer(player)
		-- remove player object
		assert(self._players[player], "Could not find player object for " .. player.Name)
		local playerContainer = self._players[player]
		playerContainer:Destroy()

		self._players[player] = nil
	end

	Players.PlayerAdded:Connect(initPlayer)
	Players.PlayerRemoving:Connect(cleanupPlayer)

	-- load players that joined before
	for _, player in Players:GetPlayers() do
		if not self._players[player] then
			initPlayer(player)
		end
	end
end

function PlayerService:KnitInit()
	self._players = {}

	self.CharacterLoadedEvent = Signal.new()
	self.ContainerCreated = Signal.new()
end

return PlayerService
