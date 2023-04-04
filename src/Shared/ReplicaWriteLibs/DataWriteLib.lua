--[[
    DataWriteLib.lua
    Author: Aaron Jay (seyai)
    Description: Write libs to safely mutate data for player profile through defined
    methods as opposed to direct manipulations. These methods also automatically propogate
    to the client via ReplicaService, and can be listened to using DataController

]]
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Shared = game.ReplicatedStorage.Shared
local ShopData = require(Shared.ShopData)

local DEBUG_TAG = "[" .. script.Name .. "]"

-- verify these on the server and stuff
local DataWriteLib = {
    IncrementCurrency = function(replica, amount)
        replica:IncrementValue({"Currency"}, amount)
    end,

    AddItemToInv = function(replica, itemid, amt)
        local existing = replica.Data.Inventory[itemid]
        if existing then
            replica:IncrementValue("Inventory", itemid, amt)
        else
            replica:SetValue("Inventory", itemid, amt) -- // create new entry
        end
    end,

    PurchaseItem = function(replica, shopid, itemamt)
        --// get price info from ShopInfo module
        local shopInfo = ShopData:Get(shopid)
        if shopInfo then
            local clampedAmt = math.clamp(itemamt, 1, 100)
            local integerAmt = math.floor(clampedAmt) or 1
            local price = shopInfo.Price * integerAmt

            if replica.Data.Currency >= price then
                replica:Write("IncrementCurrency", -price)
                --// get item data to insert (if unique, more work required. generic, just insert item id w/ amount increment)
                replica:Write("AddItemToInv", shopid, itemamt)
                print("Added item to inventory: " .. shopid)
                print(replica.Data.Currency)
                return true
            else
                warn("Not enough currency, missing " .. tostring(price - replica.Data.Currency))
            end
        end
        return false
    end
}

return DataWriteLib