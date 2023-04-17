--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This is a minigame about a RainbowHill objects fall at the top and put players in a ragdoll state. once they hit the finish line they win. 
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.RainbowHill
local DroppingObjects = ReplicatedStorage.Assets.MiniGameExtras.RainbowHill

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RagdollService

local GAME_DURATION = 60

local RainbowHill = {}
RainbowHill.__index = RainbowHill

function TempRagdoll(player: Player)
	local character = player.Character
	if not character then
		return
	end

	RagdollService:SetRagdollState(player, true)

	task.wait()
	local BaseParts = {}
	for _, v in pairs(character:GetDescendants()) do --ragdoll
		if v:IsA("Motor6D") then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame = v.C0
			a1.CFrame = v.C1
			a0.Parent = v.Part0
			a1.Parent = v.Part1
			local b = Instance.new("BallSocketConstraint")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Parent = v.Part0
			v.Enabled = false
		end
	end

	for _, v in pairs(character:GetDescendants()) do --ragdoll
		if v:IsA("BasePart") then
			--[[if v.Name == "Head" then
				local OrienForce = Instance.new("BodyAngularVelocity")
				OrienForce.AngularVelocity = Vector3.new(0, 0, 0)
				OrienForce.MaxTorque = Vector3.new(50, 50, 50)
				OrienForce.Parent = v
				table.insert(BaseParts, OrienForce)
			end]]
			local Collider = Instance.new("Part")
			Collider.Size = v.Size / Vector3.new(15, 15, 15)
			Collider.CFrame = v.CFrame
			Collider.CanCollide = true
			Collider.Anchored = false
			Collider.Transparency = 1
			local w = Instance.new("Weld")
			w.Part0 = v
			w.Part1 = Collider
			w.C0 = CFrame.new()
			w.C1 = w.Part1.CFrame:ToObjectSpace(w.Part0.CFrame)
			w.Parent = Collider
			Collider.Parent = v
			table.insert(BaseParts, Collider)
		end
	end

	task.wait(1.5)
	if character then
		for _, v in pairs(character:GetDescendants()) do --unragdoll
			for _, v in pairs(BaseParts) do
				if v then
					v:Destroy()
				end
			end
			if v:IsA("Motor6D") then
				v.Enabled = true
			end
			if v.Name == "BallSocketConstraint" then
				v:Destroy()
			end
			if v.Name == "Attachment" then
				v:Destroy()
			end
		end
		BaseParts = {}
	end

	task.wait(0.3)
	RagdollService:SetRagdollState(player, false)
end

function RainbowHill.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, RainbowHill)

	data.Janitor = Janitor.new()
	data.RagdollTracker = {}
	if not RagdollService then
		RagdollService = Knit.GetService("RagdollService")
	end

	task.delay(3, function()
		data:PrepGame()
	end)

	return data
end

function RainbowHill:SetMessage(message: string?, timer: number?, yieldTime: number?)
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

function RainbowHill:PrepGame()
	self.MessageData = {
		Message = "",
		Timer = "",
	}

	self.MessageTarget.Value = ""

	local finishLine: BasePart = self.Game.FinishLine
	finishLine.Touched:Connect(function(otherPart: BasePart?)
		local isPlayer = if otherPart and otherPart.Parent
			then Players:GetPlayerFromCharacter(otherPart.Parent)
			else nil
		if isPlayer and self.GameOver.Value == false then
			self.GameOver.Value = true
			self:SetMessage(isPlayer.DisplayName .. " is the winner!")
		end
	end)

	self.CanJoin.Value = true
	self:SetMessage(self.Game.Name .. " is ready", nil, 3)
	self:SetMessage("players have joined", nil, 3)
	self:SetMessage("GO!", nil, 1)
	self:SetMessage("")

	local function connectTouched(object)
		object.Touched:Connect(function(otherPart)
			local isPlayer = if otherPart and otherPart.Parent
				then Players:GetPlayerFromCharacter(otherPart.Parent)
				else nil
			if isPlayer and not table.find(self.RagdollTracker, isPlayer) then
				task.spawn(function()
					table.insert(self.RagdollTracker, isPlayer)
					TempRagdoll(isPlayer)
					local indexValue = table.find(self.RagdollTracker, isPlayer)
					if indexValue then
						table.remove(self.RagdollTracker, indexValue)
					end
				end)

				object:Destroy()
			end
		end)
	end

	local dropLocations = self.Game.DropLocations:GetChildren()
	local dropObjects = DroppingObjects:GetChildren()
	local lastDropTime = os.time()
	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			heartbeatConn:Disconnect()
			return
		end

		self:SetMessage("", math.floor(endTime - os.time()))

		--start dropping objects
		local canDrop = if os.time() - lastDropTime > 1 then true else false
		if canDrop then
			lastDropTime = os.time()
			local dropLocation = dropLocations[math.random(1, #dropLocations)]
			local dropObject = dropObjects[math.random(1, #dropObjects)]

			local newObject = dropObject:Clone()
			Debris:AddItem(newObject, 10)
			newObject:PivotTo(dropLocation:GetPivot())
			newObject.Parent = workspace

			if newObject:IsA("BasePart") then
				connectTouched(newObject)
			else
				for _, parts in newObject:GetChildren() do
					if parts:IsA("BasePart") then
						connectTouched(parts)
					end
				end
			end
		end
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function RainbowHill:JoinGame(player)
	if self.CanJoin.Value then
		MiniGameUtils.SpawnAroundPart(self.Game.PrimaryPart, player.Character)
		return true
	end
	return false
end

function RainbowHill:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()
	self = nil
end

return RainbowHill
