--[[
    DataController.lua
    Author: Aaron Jay (seyai)
    17 June 2021
    
    Stores and manages PlayerData Replica, listening to changes that can then be
    relayed to other controllers on the client
]]
local LocalPlayer = game.Players.LocalPlayer
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
--local Modules = PlayerScripts:WaitForChild("Modules")

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicaController = require(ReplicatedStorage.ReplicaController)
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local Maid = require(Packages.Maid)
local Timer = require(Packages.Timer)
local Promise = require(Packages.Promise)

local DataController = Knit.CreateController { Name = "DataController" }

-- // Knit Singletons
local ReplicatorController
local PlayerService

function DataController:HasProfileReplica()
    return self._profileReplica ~= nil
end

function DataController:GetPromisedData()
    return Promise.new(function(resolve, reject, onCancel)
        if self._profileReplica == nil then
            repeat task.wait(1) until self._profileReplica ~= nil
        end
        resolve(self._profileReplica.Data)
        return self._profileReplica.Data
    end):timeout(10)
end

-- // Custom getter methods can be written below this line

function DataController:GetData()
    if self._profileReplica == nil then
        local to = 10
        local w = 0
        repeat task.wait(1) w += 1 until self._profileReplica ~= nil or w >= to
    end

    return self._profileReplica.Data
end

function DataController:GetPromisedReplica()
    return Promise.try(function()
        return self:GetReplica()
    end)
end

function DataController:GetReplica()
    return self._profileReplica
end

function DataController:ListenToReplica(replica)
    if self._listeningToReplica then
        warn("Already listening to a PlayerProfile Replica")
        return
    end    
    self._listeningToReplica = true

    -- // write additional "listeners" here! (https://madstudioroblox.github.io/ReplicaService/api/#client-replicacontroller)

    warn('[DataController] listening to PlayerProfile Replica')
end



function DataController:GetDataAtPath(originalPath)
    local path = string.split(originalPath, ".")
    local currentPoint = self._profileReplica.Data
    for i = 1, #path do
       if(currentPoint[path[i]]) then
            currentPoint = currentPoint[path[i]]
       else
            return nil
       end
    end

    if(currentPoint ~= self._profileReplica.Data) then
        return currentPoint
    end

    return nil
end

function DataController:Contains(path, id): boolean
    local data = self:GetDataAtPath(path)

    if(data) then
        if(type(data) == "table") then
            for i, v in pairs(data) do
                if(v == id) then
                    return true
                end
            end
        else
            return true
        end
    end

    return false
end

function DataController:KnitStart()
    ReplicatorController.PlayerProfileReplicated:Connect(function(replica)
        self._profileReplica = replica
        self:ListenToReplica(replica)

        PlayerService:DidLoadReplica()
        warn('[DataController] loaded initial player profile!')
    end)


    if not self._profileReplica then
        -- check ReplicatorController first
        repeat
            warn('waiting for player profile replica...')
            if #ReplicatorController.PlayerProfileReplicas == 1 then
                self._profileReplica = ReplicatorController.PlayerProfileReplicas[1]
                self:ListenToReplica(self._profileReplica)
            end
            task.wait(1)
        until self._profileReplica
        print("Got profile replica!!")
        self.ReplicaFoundSignal:Fire(self._profileReplica)
    end
end


function DataController:KnitInit()
    self.Events = {}
    self.ReplicaFoundSignal = Signal.new()
    self._listeningToReplica = false
    ReplicatorController = Knit.GetController("ReplicatorController")

    -- // Knit Services
    PlayerService = Knit.GetService("PlayerService")
end


return DataController