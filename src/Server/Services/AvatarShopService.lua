--[[
    AvatarShopService.lua
    Author: Aaron Jay (se_yai)

    Description: Facilitates transactions for the Avatar Shop, namely UGC items like
    accessories and layered clothing
]]
local MarketplaceService = game:GetService("MarketplaceService")

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UGCData = require(Shared.UGCData)

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local AvatarShopService = Knit.CreateService {
    Name = "AvatarShopService";
    Client = {
        RequestPurchase = Knit.CreateSignal()
    };
}

-- // Prompt a purchase using the catalogId of an item in-game
-- // Catalog ID should be stored on the server to prevent mistaken purchase of incorrect items

function AvatarShopService:KnitStart()
    -- // listen for requests to purchase an item
    self.Client.RequestPurchase:Connect(function(player, itemId)
        local catalogId = UGCData:Get(itemId)
        if not catalogId then
            warn("Could not find Catalog ID for " .. itemId)
        end
        MarketplaceService:PromptPurchase(player, catalogId)
    end)
end


function AvatarShopService:KnitInit()
    
end


return AvatarShopService