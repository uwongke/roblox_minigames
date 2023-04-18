--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: Biggest cube minigame.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.BiggestCube
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.BiggestCube
local CubeCharacter: Model = GameExtras.CubeCharacter
local Food = GameExtras:WaitForChild("Food")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PivotTween = require(ReplicatedStorage.PivotTween)

local GAME_DURATION = 60

local BiggestCube = {}
BiggestCube.__index = BiggestCube

function BiggestCube.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, BiggestCube)

	data.Janitor = Janitor.new()
	data.ActiveStores = 0

	task.delay(3, function()
		data:PrepGame()
	end)

	return data
end

function BiggestCube:SetScore(player: Player, increment: number)
	self.Players[player].Score += increment

	if self.Players[player].Score < 0 then
		self.Players[player].Score = 0
	end

	pcall(function()
		player.Character.Head.BillboardGui.TextLabel.Text = tostring(self.Players[player].Score)
	end)
end

function BiggestCube:BroadcastWinner()
	local highScore = -100
	local winner

	for player: Player, data in self.Players do
		if data and data.Score > highScore then
			winner = player
			highScore = player
		end
	end

	self:SetMessage(winner.Name .. " is the winner!", nil, 3)
end

function BiggestCube:SetMessage(message: string?, timer: number?, yieldTime: number?)
	if message then
		self.MessageData.Message = message
	end

	if timer then
		self.MessageData.Timer = tostring(timer)
	end

	self.Message.Value = HttpService:JSONEncode(self.MessageData)

	if yieldTime then
		task.wait(yieldTime)
	end
end

function BiggestCube:PrepGame()
	self.MessageData = {
		Message = "",
		Timer = "",
	}

	self.MessageTarget.Value = ""

	local newCharacter: Model = CubeCharacter:Clone()
	self.Janitor:Add(newCharacter)
	newCharacter.Name = "StarterCharacter"
	newCharacter.Parent = game.StarterPlayer

	self.CanJoin.Value = true
	self:SetMessage(self.Game.Name .. " is ready", nil, 3)
	self:SetMessage("players have joined", nil, 3)
	self:SetMessage("GO!", nil, 1)
	self:SetMessage("")

	local foodSpawnZone: BasePart = self.Game.FeedSpawn
	local foodPosition: CFrame = foodSpawnZone:GetPivot()
	local foodAreaSize: Vector3 = foodSpawnZone.Size

	local lastFeed = os.clock()
	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			self:SetMessage("Times Up!", nil, 2)
			self:BroadcastWinner()
			heartbeatConn:Disconnect()
			return
		end

		-- generate new food.
		if os.clock() - lastFeed > 0.1 then
			lastFeed = os.clock()
			local val = math.random(1,10)
			local foodName = "GoodFood"
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
			newFood.Parent = self.Game
			newFood:PivotTo(
				foodPosition
					+ Vector3.new(
						math.random(-foodAreaSize.X / 2, foodAreaSize.X / 2),
						foodAreaSize.Y / 2 + newFood.Size.Y / 2,
						math.random(-foodAreaSize.Z / 2, foodAreaSize.Z / 2)
					)
			)
		end

		self:SetMessage("", math.floor(endTime - os.time()))
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function BiggestCube:JoinGame(player)
	if self.CanJoin.Value then
		local data = {
			Score = 0,
			Name = player.DisplayName,
		}
		self.Players[player] = data

		-- set cube characters
		self.Janitor:Add(player.CharacterAdded:Connect(function(character)
			character.PrimaryPart.Touched:Connect(function(otherPart)
				local value = otherPart:FindFirstChild("Value")
				if value then
					self:SetScore(player, value.Value)
					otherPart:Destroy()
					character.PrimaryPart.Size = Vector3.one + Vector3.new(0.1, 0.1, 0.1) * self.Players[player].Score
				end
			end)

			task.wait(1)
			MiniGameUtils.SpawnAroundPart(self.Game.Spawn, character)
		end))

		player:LoadCharacter()
		return true
	end
	return false
end

function BiggestCube:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()

	-- reload characters
	for _, player: Player in Players:GetPlayers() do
		player:LoadCharacter()
	end

	self = nil
end

return BiggestCube
