--[[
    MiniGameService.lua
    Author: Aaron Jay (se_yai)

    Description: Facilitate running minigames, as well as handling game state
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local MiniGameService = Knit.CreateService {
    Name = "MiniGameService";
    Client = {};
}


function MiniGameService:KnitStart()
    
end


function MiniGameService:KnitInit()
    
end


return MiniGameService