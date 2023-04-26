--[[
    CoinArenaService.lua
    Author: Justin (Synnull)

    Description:
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local CoinArenaService = Knit.CreateService {
    Name = "CoinArenaService";
    Client = {
        GotCoin = Knit.CreateSignal(),
        UpdateCoinAmount = Knit.CreateSignal(),
        PrepGame = Knit.CreateSignal(),
        StartGame = Knit.CreateSignal(),
        EndGame = Knit.CreateSignal(),
        FellInWater = Knit.CreateSignal()
        
};
}
function CoinArenaService.Client:GamePrepped(game)
    return self.Server:GamePrepped(game)
end
function CoinArenaService:GamePrepped(game)
    self.Game = game
end
function CoinArenaService.Client:UpdateCoinDisplay(player, coins)
    return self.Server:UpdateCoinDisplay(player, coins)
 end
function CoinArenaService:UpdateCoinDisplay(player, coins)
   self.Game:UpdateCoinDisplay(player, coins)
end
function CoinArenaService:KnitStart()
end

function CoinArenaService:KnitInit()
    
end


return CoinArenaService