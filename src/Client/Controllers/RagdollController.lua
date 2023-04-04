--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: Listens for a signal from the server to change the humanoid state. Because the client owns the character.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)

local RagdollService

local RagdollController = Knit.CreateController({
	Name = "RagdollController",
})

function RagdollController:SetRagdoll(state: boolean)
	if not self.Humanoid then
		return
	end

	if state then
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		self.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function RagdollController:KnitInit()
	self.Player = Players.LocalPlayer
	self.Character = Players.LocalPlayer.Character

	self.Player.CharacterAdded:Connect(function(character)
		self.Character = character

		WaitFor.Child(character, "Humanoid"):andThen(function(humanoid: Humanoid)
			if humanoid then
				self.Humanoid = humanoid
				humanoid.BreakJointsOnDeath = false
				humanoid.RequiresNeck = false
			end
		end)
	end)
end

function RagdollController:KnitStart()
	RagdollService = Knit.GetService("RagdollService")
	RagdollService.UpdateRagdollState:Connect(function(state: boolean)
		self:SetRagdoll(state)
	end)
end

return RagdollController
