--[[
    MemoryClassService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local MemoryClassService = Knit.CreateService {
    Name = "MemoryClassService";
    Client = {
        JoinedGame = Knit.CreateSignal(),
        PlayerGotEliminated = Knit.CreateSignal(),
        BeginReciting = Knit.CreateSignal(),
        StopReciting = Knit.CreateSignal(),
        EndGame = Knit.CreateSignal()
};
}


function MemoryClassService:KnitStart()
end

function MemoryClassService:KnitInit()
    
end


return MemoryClassService