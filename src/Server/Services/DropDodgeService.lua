--[[
    DropDodgeService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local DropDodgeService = Knit.CreateService {
    Name = "DropDodgeService";
    Client = {
        PlayerHit = Knit.CreateSignal(),
        PrepGame = Knit.CreateSignal(),
        PlayerEliminated = Knit.CreateSignal()
};
}


function DropDodgeService:KnitStart()
end
function DropDodgeService.Client:Test()
    return self.Server:Test()
end
function DropDodgeService:Test()
    print("Hallo")
end
function DropDodgeService:KnitInit()
    
end


return DropDodgeService