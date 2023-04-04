--[[
    ShopService.lua
    Author: Aaron (se_yai)

    Description: Manage player spawning and interactions with the server involving data
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packages = ReplicatedStorage.Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local ShopService = Knit.CreateService {
    Name = "ShopService";
    Client = {};
}

local PlayerService

-- Invoke from client side to purchase
function ShopService.Client:PurchaseItem(player, shopItemId, amount)
    return self.Server:PurchaseItem(player, shopItemId, amount)
end

-- Server sided purchase function
function ShopService:PurchaseItem(player, shopItemId, amount)
    local container = PlayerService:GetContainer(player)
    if container then
        container.Replica:Write("PurchaseItem", shopItemId, amount or 1)
    end
end

function ShopService:KnitStart()
    -- Detect when prompt is triggered
    local function onPromptTriggered(promptObject, player)
        local hasTag = CollectionService:HasTag(promptObject, "ShopPrompt")
        if hasTag then
            -- do stuff
            local shopItemId = promptObject:GetAttribute("ShopId")
            self:PurchaseItem(player, shopItemId, 1)
        end
    end
    
    -- Detect when prompt hold begins
    local function onPromptHoldBegan(promptObject, player)
    
    end
    
    -- Detect when prompt hold ends
    local function onPromptHoldEnded(promptObject, player)
    
    end

    -- Connect prompt events to handling functions
    ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
    ProximityPromptService.PromptButtonHoldBegan:Connect(onPromptHoldBegan)
    ProximityPromptService.PromptButtonHoldEnded:Connect(onPromptHoldEnded)
end


function ShopService:KnitInit()
    PlayerService = Knit.GetService("PlayerService")
end


return ShopService