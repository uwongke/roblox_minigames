--[[
    PixelArtistService.lua
    Author: Justin (Synnull)

    Description: 
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local PixelArtistService = Knit.CreateService {
    Name = "PixelArtistService";
    Client = {
        RoomReady = Knit.CreateSignal(),
        TargetChosen = Knit.CreateSignal(),
        RoundOver = Knit.CreateSignal()
};
}


function PixelArtistService:KnitStart()
end
function PixelArtistService:KnitInit()
    
end



return PixelArtistService