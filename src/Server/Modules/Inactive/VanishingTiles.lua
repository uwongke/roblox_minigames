--[[
	Author: Aaron Tole(RealistEntertainment)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.VanishTiles

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local GAME_DURATION = 60

local VanishingTiles = {}
VanishingTiles.__index = VanishingTiles

local function SelectRandomTiles(tiles)
	local tilesTable = table.clone(tiles)
	local selectedTiles = {}

	for _ = 1, 12 do
		local indexV = math.random(1, #tilesTable)
		table.insert(selectedTiles, tilesTable[indexV])
		table.remove(tilesTable, indexV)
	end

	local finishedTileChange = false
	local ChangeTimeDelay = 5
	for _, randomTile: BasePart in selectedTiles do
		task.spawn(function()
			for i = 1, ChangeTimeDelay do
				if randomTile then
					task.wait(1)
					randomTile.Transparency = i / ChangeTimeDelay
					if i == ChangeTimeDelay then
						randomTile.CanCollide = false

						task.wait(2)

						if randomTile then
							randomTile.CanCollide = true
							randomTile.Transparency = 0
						end
					end
				end
			end

			finishedTileChange = true
		end)
	end

	task.wait(2)

	for _, randomTile: BasePart in tilesTable do
		task.spawn(function()
			local lastColor = randomTile.Color
			randomTile.Color = Color3.new(0, 1, 0)
			randomTile.Material = Enum.Material.Neon

			task.wait(2)
			randomTile.Color = lastColor
			randomTile.Material = Enum.Material.Plastic
		end)
	end

	repeat
		task.wait()
	until finishedTileChange == true

	return selectedTiles
end

function VanishingTiles.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, VanishingTiles)

	data.Janitor = Janitor.new()

	task.delay(3, function()
		data:PrepGame()
	end)

	return data
end

function VanishingTiles:SetMessage(message: string?, timer: number?, yieldTime: number?)
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

function VanishingTiles:PrepGame()
	self.ActivePlayers = {}

	self.Game.Loss.Touched:Connect(function(otherPart: BasePart?)
		local isPlayer: Player? = if otherPart and otherPart.Parent
			then Players:GetPlayerFromCharacter(otherPart.Parent)
			else nil
		if isPlayer then
			MiniGameUtils.SpawnAroundPart(workspace.LobbySpawn, isPlayer.Character)
			table.remove(self.ActivePlayers, table.find(self.ActivePlayers, isPlayer))

			if #self.ActivePlayers <= 1 then
				self.GameOver.Value = true
			end
		end
	end)

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

	local CanChange = true
	local tiles = self.Game.Tiles:GetChildren()
	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			heartbeatConn:Disconnect()
			return
		end

		if CanChange then
			CanChange = false
			SelectRandomTiles(tiles)

			CanChange = true
		end

		self:SetMessage("", math.floor(endTime - os.time()))
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function VanishingTiles:JoinGame(player)
	if self.CanJoin.Value then
		table.insert(self.ActivePlayers, player)
		MiniGameUtils.SpawnAroundPart(self.Game.Spawn, player.Character)
		return true
	end
	return false
end

function VanishingTiles:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()
	self = nil
end

return VanishingTiles
