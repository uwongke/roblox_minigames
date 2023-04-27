--[[
    SkyClimbersService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local SkyClimbersService = Knit.CreateService {
    Name = "SkyClimbersService";
    Client = {
        JoinedGame = Knit.CreateSignal(),
        StartGame = Knit.CreateSignal(),
        StopJumping = Knit.CreateSignal(),
        EndGame = Knit.CreateSignal()
};
}


function SkyClimbersService:KnitStart()
end

function SkyClimbersService:KnitInit()
    
end


return SkyClimbersService