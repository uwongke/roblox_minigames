--[[
    HurdleRaceService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local HurdleRaceService = Knit.CreateService {
    Name = "HurdleRaceService";
    Client = {
        JoinedGame = Knit.CreateSignal(),
        StartGame = Knit.CreateSignal(),
        PlayerHitHurdle = Knit.CreateSignal(),
        EndGame = Knit.CreateSignal()
};
}


function HurdleRaceService:KnitStart()
end
function HurdleRaceService.Client:Test()
    return self.Server:Test()
end
function HurdleRaceService:Test()
    print("Hallo")
end
function HurdleRaceService:KnitInit()
    
end


return HurdleRaceService