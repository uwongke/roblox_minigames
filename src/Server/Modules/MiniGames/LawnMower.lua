--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This the the LawMower minigame.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.LawnMower
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.LawnMower
local LawMowerTool: Tool = GameExtras.LawnMower

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PivotTween = require(ReplicatedStorage.PivotTween)
local Signal = require(ReplicatedStorage.Packages.Signal)

local GAME_DURATION = 60

local LawnMower = {}
LawnMower.__index = LawnMower

function LawnMower.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, LawnMower)

	data.Janitor = Janitor.new()
	data.ActiveStores = 0
	data.ScoreUpdateSignal = Signal.new()

	task.delay(3, function()
		data:PrepGame()
	end)

	data.Janitor:Add(data.ScoreUpdateSignal, "Destroy")
	return data
end

function LawnMower:BroadcastWinner()
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

function LawnMower:CreatePlayerBillboardScore(player: Player)
	local head = if player and player.Character then player.Character:FindFirstChild("Head") else nil
	local playerData = self.Players[player]
	if head and playerData then
		local scoreDisplay: BillboardGui = Instance.new("BillboardGui")
		self.Janitor:Add(scoreDisplay)
		scoreDisplay.AlwaysOnTop = true
		scoreDisplay.StudsOffset = Vector3.new(0, 1, 0)
		scoreDisplay.Size = UDim2.fromScale(4, 2)

		local scoreTextLabel: TextLabel = Instance.new("TextLabel")
		scoreTextLabel.Size = UDim2.new(1, 0, 1, 0)
		scoreTextLabel.Text = playerData.Score
		scoreTextLabel.TextScaled = true
		scoreTextLabel.TextColor3 = Color3.new(1, 1, 1)
		scoreTextLabel.BackgroundTransparency = 1
		scoreTextLabel.TextStrokeTransparency = 0
		scoreTextLabel.Parent = scoreDisplay

		scoreDisplay.Parent = head
	end
end

function LawnMower:SetMessage(message: string?, timer: number?, yieldTime: number?)
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

function LawnMower:PrepGame()
	self.MessageData = {
		Message = "",
		Timer = "",
	}

	self.MessageTarget.Value = ""

	self.CanJoin.Value = true
	self:SetMessage(self.Game.Name .. " is ready", nil, 3)
	self:SetMessage("players have joined", nil, 3)
	self:SetMessage("GO!", nil, 1)
	self:SetMessage("")

	-- listen to score change
	self.ScoreUpdateSignal:Connect(function(player: Player)
		local BillboardGui = if player
				and player.Character
				and player.Character:FindFirstChild("Head")
			then player.Character.Head:FindFirstChildOfClass("BillboardGui")
			else nil
		local playerData = self.Players[player]
		if playerData and BillboardGui then
			BillboardGui.TextLabel.Text = tostring(playerData.Score)
		end
	end)

	for player: Player, data in self.Players do
		local humanoid: Humanoid = if player
				and data
				and player.character
			then player.character:FindFirstChild("Humanoid")
			else nil

		if humanoid then
			local mower: Tool = LawMowerTool:Clone()
			self.Janitor:Add(mower)
			mower.Parent = player.Backpack
			humanoid:EquipTool(mower)

			mower.Handle.Touched:Connect(function(otherPart: BasePart?)
				if otherPart:IsA("BasePart") and otherPart.Name == "Grass" then
					otherPart.Name = "Dirt"
					otherPart.BrickColor = BrickColor.new("Earth yellow")

					if self.Players[player] then
						self.Players[player].Score += 1
						self.ScoreUpdateSignal:Fire(player)
					end

					task.delay(7, function()
						if otherPart then
							otherPart.Name = "Grass"
							otherPart.BrickColor = BrickColor.new("Earth green")
						end
					end)
				end
			end)
		end
	end

	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			self:SetMessage("Times Up!", nil, 2)
			self:BroadcastWinner()
			heartbeatConn:Disconnect()
			return
		end

		self:SetMessage("", math.floor(endTime - os.time()))
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function LawnMower:JoinGame(player)
	if self.CanJoin.Value then
		local data = {
			Score = 0,
			Name = player.DisplayName,
		}
		self.Players[player] = data

		self:CreatePlayerBillboardScore(player)
		MiniGameUtils.SpawnAroundPart(self.Game.Spawn, player.Character)
		return true
	end
	return false
end

function LawnMower:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()
	self = nil
end

return LawnMower
