--!nonstrict

--[[
    PlayerContainer.lua
    Author: Aaron Jay (seyai)
    17 June 2021
    Create a container that handles Profile+ReplicaService, used for containing and mutating PlayerData
    Edit the `TEMPLATE_DATA` variable to setup expected PlayerData. Additions to this template will be propogated to returning
    players' data on join via `profile:Reconcile()`
]]

local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")
local ReplicaService = require(Modules.ReplicaService)
local ProfileService = require(Modules.ProfileService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Maid = require(game.ReplicatedStorage.Packages.Maid)


local PlayerContainer = {}
PlayerContainer.__index = PlayerContainer

PlayerContainer.Tag = "PlayerContainer"

local DATA_VERSION = 1

-- // Edit your player data here!
local TEMPLATE_DATA = {
    Currency = 10;
    Inventory = {

    };
}

local FORCE_MOCK_STORE = false

local DATASTORE_NAME = "PlayerData_testing"
local CURRENT_DATA_VERSION = 1
local ProfileStore = ProfileService.GetProfileStore(DATASTORE_NAME .. CURRENT_DATA_VERSION, TEMPLATE_DATA)
if game:GetService("RunService"):IsStudio() or FORCE_MOCK_STORE then
    ProfileStore = ProfileStore.Mock
    print("Using mock Profiles")
end

local PlayerProfileClassToken = ReplicaService.NewClassToken("PlayerProfile")

export type PlayerContainer = {
    _instance: Player
}

function PlayerContainer.new(player: Player?): PlayerContainer
    local self = setmetatable({
        _instance = player,
        _maid = Maid.new(),
        lastHit = {-1, "none", {}},

        Profile = nil,
        Replica = nil
    }, PlayerContainer)
    
    local profile = ProfileStore:LoadProfileAsync(tostring(player.UserId), "ForceLoad")
    if profile ~= nil then
        -- update data according to template
        profile:Reconcile()
        profile:SetMetaTag('DATA_VERSION', CURRENT_DATA_VERSION)

        -- setup disconnect
        profile:ListenToRelease(function()
            self.Replica:Destroy()
            player:Kick()
        end)

        -- check first time load
        local firstTimeLoad = profile:GetMetaTag("FirstTimeLoad")
        if firstTimeLoad == nil then
            profile:SetMetaTag("FirstTimeLoad", true)
        elseif firstTimeLoad == true then
            profile:SetMetaTag("FirstTimeLoad", false) -- any future checks to this metatag mean they have loaded in before
        end
        if player:IsDescendantOf(game.Players) == true then

            self.Profile = profile
            self.Replica = ReplicaService.NewReplica({
                ClassToken = PlayerProfileClassToken,
                Tags = {Player = player},
                Data = profile.Data,
                Replication = {[player] = true},
                WriteLib = Shared.ReplicaWriteLibs.DataWriteLib
            })
            self._maid:Add(function()
                if self.Profile ~= nil then
                    self.Profile:Release()
                end
            end)

            -- setup listener
            self.Replica:ConnectOnServerEvent(function(player, write_lib, ...)
                self.Replica:Write(write_lib, ...)
            end)
        else
            profile:Release()
        end
    else
        player:Kick('Data profile could not be loaded. Are you already playing somewhere else?')
    end

    print("[PlayerContainer] Created new container:", player.Name)

    return self    
end

function PlayerContainer:GetDataAtPath(originalPath)
    local path = string.split(originalPath, ".")
    local currentPoint = self.Profile.Data
    for i = 1, #path do
       if(currentPoint[path[i]]) then
            currentPoint = currentPoint[path[i]]
       else
            return nil
       end
    end

    if(currentPoint ~= self.Profile.Data) then
        return currentPoint
    end

    return nil
end

function PlayerContainer:Contains(path, id): boolean
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

function PlayerContainer:ContainsAtLeast(path, qty): boolean
    local data = self:GetDataAtPath(path)

    if(data and type(data) == "number") then
        return data >= qty
    end

    return false
end

function PlayerContainer:Destroy()
    self._maid:Destroy()
end

return PlayerContainer