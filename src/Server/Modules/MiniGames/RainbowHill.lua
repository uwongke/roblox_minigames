--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This is a minigame about a RainbowHill objects fall at the top and put players in a ragdoll state. once they hit the finish line they win. 
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.RainbowHill
local DroppingObjects = ReplicatedStorage.Assets.MiniGameExtras.RainbowHill:GetChildren()

local Knit = require(ReplicatedStorage.Packages.Knit)
local RagdollService

local GAME_DURATION = 60

local RainbowHill = {}
RainbowHill.__index = RainbowHill

local TotalPlayers = 0

function RainbowHill:Init(janitor, SpawnLocation, endSignal)
    TotalPlayers = 0
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.RemainingPlayers = 0
    self.Janitor = janitor
    self.MiniGame = data
	self.lastDropTime = os.time()
	self.dropLocations = data.Game.DropLocations:GetChildren()
    janitor:Add(data.Game)
	data.RagdollTracker = {}
	if not RagdollService then
		RagdollService = Knit.GetService("RagdollService")
	end

    janitor:Add(data.Game.FinishLine.Touched:Connect(function(part)
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = data.Players[player]
            if playerData then
                data.RemainingPlayers -= 1
                data.Winners[player] = playerData
                playerData.Place = TotalPlayers - data.RemainingPlayers
                data.Players[player] = nil
                if data.RemainingPlayers <= 0 then
                    endSignal:Fire()
                end
            end
        end
    end))
end

function RainbowHill:Start()
	TotalPlayers = self.MiniGame.RemainingPlayers
	return GAME_DURATION
end

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

function RainbowHill:ConnectTouched(object)
	object.Touched:Connect(function(otherPart)
		local isPlayer = if otherPart and otherPart.Parent
			then Players:GetPlayerFromCharacter(otherPart.Parent)
			else nil
		if isPlayer and not table.find(self.MiniGame.RagdollTracker, isPlayer) then
			task.spawn(function()
				table.insert(self.MiniGame.RagdollTracker, isPlayer)
				TempRagdoll(isPlayer)
				local indexValue = table.find(self.MiniGame.RagdollTracker, isPlayer)
				if indexValue then
					table.remove(self.MiniGame.RagdollTracker, indexValue)
				end
			end)

			object:Destroy()
		end
	end)
end

function RainbowHill:Update(deltaTime, time)
	self.lastDropTime+= deltaTime
	if self.lastDropTime > 1 then
		self.lastDropTime = 0
		local dropLocation = self.dropLocations[math.random(1, #self.dropLocations)]
		local dropObject = DroppingObjects[math.random(1, #DroppingObjects)]

		local newObject = dropObject:Clone()
		Debris:AddItem(newObject, 10)
		newObject:PivotTo(dropLocation:GetPivot())
		newObject.Parent = workspace

		if newObject:IsA("BasePart") then
			self:ConnectTouched(newObject)
		else
			for _, parts in newObject:GetChildren() do
				if parts:IsA("BasePart") then
					self:ConnectTouched(parts)
				end
			end
		end
	end
end

function RainbowHill:GetWinners()
	table.sort(self.MiniGame.Winners,function(a, b)
        local a_score = self.Minigame.Winners[a].Place
        local b_score = self.Minigame.Winners[b].Place

        return a_score > b_score
    end)
    return self.MiniGame.Winners, 3
end

function RainbowHill:JoinGame(player)
	self.MiniGame.RemainingPlayers += 1
	self.MiniGame.Players[player] = {Place = 0}
	MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.PrimaryPart, player.Character)
end

function RainbowHill:Destroy()
	--clean up
	self.MiniGame.Game:Destroy()
	self = nil
end

return RainbowHill
