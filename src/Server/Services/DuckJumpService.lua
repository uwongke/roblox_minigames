--[[
    DuckJumpService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local DuckJumpService = Knit.CreateService {
    Name = "DuckJumpService";
    Client = {
        JoinedGame = Knit.CreateSignal(),
        Eliminated = Knit.CreateSignal(),
        EndGame = Knit.CreateSignal()
};
}


function DuckJumpService:KnitStart()
end
function DuckJumpService.Client:Test()
    return self.Server:Test()
end
function DuckJumpService:Test()
    print("Hallo")
end
function DuckJumpService:KnitInit()
    
end


return DuckJumpService