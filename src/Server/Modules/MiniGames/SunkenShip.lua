--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This is the Sunken Ship minigame.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.SunkenShip
local ShipTemplate = GameExtras.ShipTemplate

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PivotTween = require(ReplicatedStorage.PivotTween)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm

local SunkenShipComm = ServerComm.new(ReplicatedStorage, "ShipComm")
local FeedbackEvent = SunkenShipComm:CreateSignal("Feedback")

local GAME_DURATION = 60
local POINT_PER_CUSTOMER = 1

local SunkenShip = {}
SunkenShip.__index = SunkenShip

function SunkenShip.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(nil, SpawnLocation)
	setmetatable(data, SunkenShip)

	data.Janitor = Janitor.new()
	data.ActiveStores = 0

	task.delay(3, function()
		data:PrepGame()
	end)

	return data
end

-- would be best to move this to client side
function SunkenShip:ProjectScore(object: BasePart, score: number)
	local tempScoreProjector: BillboardGui = Instance.new("BillboardGui")
	self.Janitor:Add(tempScoreProjector)
	local scoreTextLabel: TextLabel = Instance.new("TextLabel")
	scoreTextLabel.Size = UDim2.new(1, 0, 1, 0)
	scoreTextLabel.Text = "+" .. tostring(score)
	scoreTextLabel.Parent = tempScoreProjector
	scoreTextLabel.TextScaled = true
	scoreTextLabel.TextColor3 = Color3.new(1, 1, 1)
	scoreTextLabel.BackgroundTransparency = 1
	scoreTextLabel.TextStrokeTransparency = 0

	tempScoreProjector.Size = UDim2.fromScale(2, 2)
	tempScoreProjector.AlwaysOnTop = true

	tempScoreProjector.Parent = object

	local tween =
		TweenService:Create(tempScoreProjector, TweenInfo.new(3), { ExtentsOffsetWorldSpace = Vector3.new(0, 25, 0) })

	tween.Completed:Connect(function(playbackState)
		tempScoreProjector:Destroy()
	end)

	tween:Play()
end

function SunkenShip:SetMessage(message: string?, timer: number?, yieldTime: number?)
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

function SunkenShip:CreateHole(playerData)
	if playerData and playerData.Ship then
		local holes = playerData.Ship.Holes:GetChildren()
		if #holes > 0 then
			local randomHole = holes[math.random(1, #holes)]

			randomHole.ParticleEmitter.Enabled = true
			randomHole.Transparency = 1

			local proximityPrompt = Instance.new("ProximityPrompt")
			proximityPrompt.ActionText = "Fix"
			proximityPrompt.ObjectText = "Big Hole"
			proximityPrompt.RequiresLineOfSight = false
			proximityPrompt.Parent = randomHole

			proximityPrompt.Triggered:Connect(function(playerWhoTriggered)
				playerData.Score += 1

				randomHole.Transparency = 0
				randomHole.ParticleEmitter.Enabled = false
				randomHole.Parent = playerData.Ship.Holes

				self:ProjectScore(proximityPrompt.Parent, 1)

				proximityPrompt:Destroy()
			end)

			randomHole.Parent = playerData.Ship.ActiveHoles
		end
	end
end

function SunkenShip:CreateShip(player: Player)
	local startCF = CFrame.new(500, 100, 500)

	-- create ship
	local shipTemplate: Model = ShipTemplate:Clone()
	self.Janitor:Add(shipTemplate)
	shipTemplate.Parent = workspace
	self.ActiveStores += 1

	local storeSize = shipTemplate:GetExtentsSize()
	local canRotate: boolean = self.ActiveStores % 2 == 0
	local zIncrement = math.ceil(self.ActiveStores / 2)

	if canRotate then
		shipTemplate:PivotTo(
			startCF * CFrame.Angles(0, math.pi, 0) + Vector3.new(storeSize.X, storeSize.Y / 2, storeSize.Z * zIncrement)
		)
	else
		shipTemplate:PivotTo(startCF + Vector3.new(-storeSize.X, storeSize.Y / 2, storeSize.Z * zIncrement))
	end

	MiniGameUtils.SpawnAroundPart(shipTemplate.Spawn, player.Character)

	return shipTemplate
end

function SunkenShip:PrepGame()
	self.MessageData = {
		Message = "",
		Timer = "",
	}

	self.MessageTarget.Value = ""

	self.CanJoin.Value = true
	self:SetMessage(script.Name .. " is ready", nil, 3)
	self:SetMessage("players have joined", nil, 3)
	self:SetMessage("GO!", nil, 1)
	self:SetMessage("")

	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	local lastHoleTime = os.time()
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			heartbeatConn:Disconnect()
			return
		end

		-- check if the player has holes active in the boat then move the water up. If the water exceeds max height then end game and give them a score(end - start). create a new hole.
		if os.time() - lastHoleTime >= 3 then
			lastHoleTime = os.time()
			for _, playerData in self.Players do
				if playerData.Alive then
					self:CreateHole(playerData)

					local activeHoles = #playerData.Ship.ActiveHoles:GetChildren()
					if playerData.Ship and playerData.Ship and activeHoles > 0 then
						local ship = playerData.Ship
						if ship then
							ship.Water.Size += Vector3.new(0, activeHoles, 0)

							if ship.Water.Size.Y > 55 then
								playerData.Alive = false
							end
						end
					end
				end
			end
		end

		self:SetMessage("", math.floor(endTime - os.time()))
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function SunkenShip:JoinGame(player)
	if self.CanJoin.Value then
		local ship = self:CreateShip(player)

		local data = {
			Score = 0,
			Name = player.DisplayName,
			Ship = ship,
			Alive = true,
			ActiveHoles = {},
		}
		self.Players[player] = data
		return true
	end
	return false
end

function SunkenShip:Destroy()
	--clean up
	self.Janitor:Destroy()
	self = nil
end

return SunkenShip
