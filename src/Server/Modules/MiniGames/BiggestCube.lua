--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: Biggest cube minigame.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.BiggestCube
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.BiggestCube
local CubeCharacter: Model = GameExtras.CubeCharacter
local Food = GameExtras:WaitForChild("Food")
local BaseSpeed = 16

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local GAME_DURATION = 60

local BiggestCube = {}
BiggestCube.__index = BiggestCube

function BiggestCube:Init(janitor, SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	data.ActiveStores = 0
	janitor:Add(data.Game)

	self.Janitor = janitor
	data.spawnTimer = 0
	local newCharacter: Model = CubeCharacter:Clone()
	janitor:Add(newCharacter)
	newCharacter.Name = "StarterCharacter"
	newCharacter.Parent = game.StarterPlayer
	self.Minigame = data
end

function BiggestCube:Start()
	return GAME_DURATION
end

function BiggestCube:SetScore(player: Player, increment: number)
	self.Minigame.Players[player].Score += increment

	if self.Minigame.Players[player].Score < 0 then
		self.Minigame.Players[player].Score = 0
	end

	pcall(function()
		player.Character.Head.BillboardGui.TextLabel.Text = tostring(self.Minigame.Players[player].Score)
	end)
	return self.Minigame.Players[player].Score
end

function BiggestCube:GetWinners()
	-- sort by players
    table.sort(self.Minigame.Players, function(a, b)
        local a_score = self.Minigame.Players[a]
        local b_score = self.Minigame.Players[b]

        return a_score > b_score
    end)

	return self.Minigame.Players, 3
end

function BiggestCube:Update(dt, timeElapsed)
	if self.Minigame == nil or self.Janitor == nil then
		return
	end
	self.Minigame.spawnTimer += dt
	if self.Minigame.spawnTimer > .1 then
		self.Minigame.spawnTimer = 0
		local foodName = "GoodFood"
		local val = math.random(1,10)
		if val == 1 then
			foodName = "BadFood"
		else
			if val == 10 then
				foodName = "GreatFood"
			end
		end
		local foodObject = Food:FindFirstChild(foodName)
		local newFood = foodObject:Clone()
		self.Janitor:Add(newFood)
		newFood.Parent = self.Minigame.Game
		MiniGameUtils.SpawnAroundPart(self.Minigame.Game.FeedSpawn, newFood)
	end
end

function BiggestCube:JoinGame(player)
	local data = {
		Score = 0,
		Name = player.DisplayName,
	}
	self.Minigame.Players[player] = data

	-- set cube characters
	self.Janitor:Add(player.CharacterAdded:Connect(function(character)
		
		character.PrimaryPart.Touched:Connect(function(otherPart)
			local value = otherPart:FindFirstChild("Value")
			if value then
				local score = self:SetScore(player, value.Value)
				otherPart:Destroy()
				character.Humanoid.WalkSpeed = BaseSpeed * 100 / (100 + score)
				character.PrimaryPart.Size = Vector3.one + Vector3.new(0.1, 0.1, 0.1) * score
			end
		end)
		
		task.wait(1)
		
		for _, v in ipairs(character:GetChildren()) do
			if v:IsA("BasePart") then
				v.CollisionGroup = "Default" -- // useful for disabling player-player collisions
			end
		end
		MiniGameUtils.SpawnAroundPart(self.Minigame.Game.Spawn, character)
	end))
	player:LoadCharacter()
end

return BiggestCube