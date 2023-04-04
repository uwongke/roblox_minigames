--[[
    ReplicatorController.lua
    Author: Aaron Jay (seyai)

    Custom middleware for ReplicaService (https://madstudioroblox.github.io/ReplicaService/) that ensures data for a
    player is loaded before they can interact with the game
]]
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
--local Modules = PlayerScripts:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicaController = require(ReplicatedStorage.ReplicaController)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ReplicaTokens = require(Shared.ReplicaTokens)

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Signal = require(game.ReplicatedStorage.Packages.Signal)
local ReplicatorController = Knit.CreateController { Name = "ReplicatorController" }

function ReplicatorController:GetReplicaById(replica_id)
    return ReplicaController.GetReplicaById(replica_id)
end

function ReplicatorController:KnitStart()
     -- request initial data, now that everything is hooked up
     ReplicaController.InitialDataReceivedSignal:Connect(function()
         self._initialDataReceived = true
         print('received data')
     end)
     ReplicaController.RequestData()
end


function ReplicatorController:KnitInit()
    -- create replica dictionaries and events for all tokens
        -- connect them at the same time
    self._initialDataReceived = false
    for _, v in ipairs(ReplicaTokens) do
        self[v .. "Replicas"] = {}
        self[v .. "Replicated"] = Signal.new()

        ReplicaController.ReplicaOfClassCreated(v, function(replica)
            table.insert(self[v .. "Replicas"], replica)
            self[v .. "Replicated"]:Fire(replica)
            print("[ReplicatorController] ReplicaOfClassCreated " .. v)
        end)
    end
end


return ReplicatorController