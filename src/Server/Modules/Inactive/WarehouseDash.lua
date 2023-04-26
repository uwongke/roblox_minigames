--[[
    WarehouseDash.lua
    Author: seyai_one (Aaron)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Timer = require(ReplicatedStorage.Packages.Timer)

local Modules = script.Parent.Parent
local MiniGameUtils = require(Modules.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames:WaitForChild(script.Name)
local Extras = ReplicatedStorage.Assets.MiniGameExtras[script.Name]
local Boxes = Extras:WaitForChild("Boxes", 3):GetChildren()

local BoxComm = ServerComm.new(ReplicatedStorage, "BoxComm")
local GrabbedBoxEvent = BoxComm:CreateSignal("GrabbedBoxEvent")

local TAU = math.pi * 2
local RANDOM = Random.new(os.time())

local module = {}
module.__index = module

function module.new(SpawnLocation)
    local self = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    setmetatable(self, module)
    self.Players = {}
    self._janitor = Janitor.new()
    self._janitor:Add(self.Game)
    task.delay(3, function()
        self:InitGame()
    end)
    return self
end

function module:Destroy()
    self._janitor:Destroy()
end

function module:InitGame()
    local currentlyHolding = {}
    local conveyors = {}
    local drops = self.Game.Drops:GetChildren()
    local dropStatus = {}
    for i, d in drops do
        dropStatus[d] = tonumber(d.Name) % 2 == 0
        if dropStatus[d] then
            d.Transparency = 0.5
        else
            d.Transparency = 1
        end
    end

    for _, conveyor in self.Game.Conveyors:GetChildren() do
        local newConveyor = {
            Dropper = conveyor:WaitForChild("Dropper");
            Spawned = 0;
            Main = conveyor;
        }
        local belt = conveyor:FindFirstChild("Belt")
        belt.AssemblyLinearVelocity = -belt.CFrame.LookVector * 20
        table.insert(conveyors, newConveyor)
    end

    self._janitor:Add(Timer.Simple(3, function()
        --// select a spawn and flip its availability
        for _, nextDrop in drops do
            if dropStatus[nextDrop] ~= nil then
                dropStatus[nextDrop] = not dropStatus[nextDrop]
                nextDrop.CanTouch = dropStatus[nextDrop]
                if dropStatus[nextDrop] then
                    nextDrop.Transparency = 0.5
                else
                    nextDrop.Transparency = 1
                end
            end
        end
    end))

    self._janitor:Add(Timer.Simple(0.75, function()
        --// spawn a box at a random conveyor
        local nextConveyor = conveyors[RANDOM:NextInteger(1, #conveyors)]
        local boxSource = Boxes[RANDOM:NextInteger(1, #Boxes)]
        local nextBox = boxSource:Clone()
        self._janitor:Add(nextBox)
        nextBox.CFrame = nextConveyor.Dropper.CFrame
        nextBox.Parent = self.Game
        -- Debris:AddItem(nextBox, 3)
        task.delay(6, function()
            if nextBox ~= nil then
                if nextBox:GetAttribute("Held") == nil then
                    nextBox:Destroy()
                end
            end
        end)

        -- box connection
        local connection
        connection = nextBox.Touched:Connect(function(hit)
            if table.find(drops, hit) and nextBox:GetAttribute("Held") then
                -- award points to held
                if dropStatus[hit] then
                    local userId = nextBox:GetAttribute("Held")
                    if self.Players[userId] then
                        self.Players[userId] += nextBox:GetAttribute("Points")
                        nextBox:Destroy()
                        currentlyHolding[userId] = nil
                    end
                end
            elseif not nextBox:GetAttribute("Held") then
                -- get player from hit
                local player = game.Players:GetPlayerFromCharacter(hit.Parent)
                if player then
                    if currentlyHolding[player.UserId] == nil then
                    -- if self.Players[player.UserId] then
                        -- bind to character
                        local rigid = Instance.new("RigidConstraint")
                        rigid.Attachment0 = nextBox:FindFirstChildOfClass("Attachment")
                        rigid.Attachment1 = hit.Parent:FindFirstChild("RightGripAttachment", true)
                        rigid.Parent = nextBox
                        
                        currentlyHolding[player.UserId] = true
                        nextBox:SetAttribute("Held", player.UserId)
                        nextBox.Parent = hit.Parent
                        nextBox:SetNetworkOwner(player)
                    end
                end
            end
        end)

        self._janitor:Add(connection)
    end))

    self._janitor:Add(self.Game)
    self.CanJoin.Value = true
    task.delay(60, function()
        for player, points in self.Players do
            print(player, points)
        end
        self.GameOver.Value = true
        connection:Disconnect()
    end)
end

function module:JoinGame(player : Player)
    if self.CanJoin.Value then
        if player.Character then
            MiniGameUtils.SpawnAroundPart(self.Game.Spawn, player.Character)

            self.Players[player.UserId] = 0
        end
    end
end

return module