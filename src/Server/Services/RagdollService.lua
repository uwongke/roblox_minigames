--[[
    Author: Aaron Tole(RealistEntertainment)

    Description: This lets the client know what to do with the humanoid state.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RagdollService = Knit.CreateService({
	Name = "RagdollService",
	Client = {
		UpdateRagdollState = Knit.CreateSignal(),
	},
})

function RagdollService:SetRagdollState(player: Player, state: boolean)
	if player and state ~= nil then
		self.Client.UpdateRagdollState:Fire(player, state)
	end
end

function RagdollService:KnitInit() end

function RagdollService:KnitStart() end

return RagdollService
