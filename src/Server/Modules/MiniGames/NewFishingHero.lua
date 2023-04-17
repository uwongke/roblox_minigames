--[[
    FishingHero.lua
    Author: seyai_one

]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local Modules = script.Parent.Parent
local MiniGameUtils = require(Modules.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames:WaitForChild(script.Name)
local Extras = ReplicatedStorage.Assets.MiniGameExtras[script.Name]
-- // establish comms
local FishComm = ServerComm.new(ReplicatedStorage, "FishComm")
local CaughtFishEvent = FishComm:CreateSignal("CaughtFishEvent")

local TAU = math.pi * 2
local RANDOM = Random.new(os.time())

local module = {}

function module:Init(janitor, SpawnLocation)
    self.MiniGame = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    janitor:Add(self.MiniGame.Game)
   
    -- should clean this up with janitor
    -- removes players that leave during the game from the pool of players
    janitor:Add(Players.PlayerRemoving:Connect(function(player)
        if self.MiniGame.Players[player] then
            self.MiniGame.Players[player] = nil
        end
    end))

    self._janitor = janitor
end

function module:Start()
    local offsets = {}
    for _, rod in self.Game.Rods:GetChildren() do
        local pole = rod:WaitForChild("FishingRod")
        local pivot = pole:FindFirstChild("Anchor").WorldCFrame

        local offset = pivot:toObjectSpace(pole.CFrame) -- Get the offset from the part to the pivot
        -- while wait() do
        -- newpivot = newpivot * CFrame.Angles(0, math.rad(1), 0) -- Rotate the pivot
        -- part.CFrame = newpivot * offset -- Re-offset the part from the new rotation
        offsets[rod] = offset
        CollectionService:AddTag(rod, "FishingRod")
        
        rod:SetAttribute("Caught", 0)
        -- // create ProximityPrompt
        local newPrompt = Instance.new("ProximityPrompt")
        newPrompt.Name = "ReelPrompt"
        newPrompt.ActionText = "Reel"
        newPrompt.ObjectText = "Fish Hooked!"
        newPrompt.RequiresLineOfSight = false
        newPrompt.Enabled = false
        newPrompt.HoldDuration = 1
        newPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
        newPrompt.MaxActivationDistance = 10
         
        newPrompt.Parent = rod:WaitForChild("FishingRod").Anchor
        newPrompt.Triggered:Connect(function(player)
            local fish = rod:GetAttribute("HasFish")
            if fish then
                rod:SetAttribute("Caught", rod:GetAttribute("Caught") + 1)
                -- // TODO: add points
                self.MiniGame.Players[player] = self.MiniGame.Players[player] + fish
                CaughtFishEvent:Fire(player, self.MiniGame.Players[player])
                print(player.Name .. " caught a " .. FISHDEX[fish] .. " worth " .. fish .. " points!")
                print(player.Name .. " has " .. self.MiniGame.Players[player] .. " points!") 
                print(" ")
                rod:SetAttribute("HasFish", nil)
            end
        end)

        rod.AttributeChanged:Connect(function(attributeName)
            if attributeName == "HasFish" then
                if not rod:GetAttribute("HasFish") then
                    newPrompt.Enabled = false
                    rod:SetAttribute("OnCooldown", true)

                    local fish = rod:FindFirstChild("Fish", true)
                    if fish then
                        task.delay(1, function()
                            if fish then
                                fish:Destroy()
                            end
                        end)
                    end

                    task.delay(RANDOM:NextNumber(0.1, 3), function()
                        rod:SetAttribute("OnCooldown", nil)
                    end)
                end
            end
        end)
    end
    
    return 60
end

function module:Update(players, dt, timeElapsed)
    -- // start timer
    -- // create fishing loop
    local _timeElapsed = 0
    self._janitor:Add(RunService.PostSimulation:Connect(function(dt)
        for _, rod in self.Game.Rods:GetChildren() do
            local bobber = rod:WaitForChild("Bobber")
            if not rod:GetAttribute("HasFish") and _timeElapsed >= 1 and not rod:GetAttribute("OnCooldown") then
                if RANDOM:NextInteger(0, 99) < FISH_CHANCE then
                    -- apply fish
                    local fishNum = RANDOM:NextInteger(1, #FISHDEX)
                    rod:SetAttribute("HasFish", fishNum)
                    rod:SetAttribute("OnCooldown", true)
                    rod:FindFirstChild("ReelPrompt", true).Enabled = true

                    local fishModel = Extras[FISHDEX[fishNum]]:Clone()
                    fishModel.CFrame = bobber.Bobber.CFrame
                    fishModel.Name = "Fish"
                    local rigid = Instance.new("RigidConstraint")
                    rigid.Parent = fishModel
                    rigid.Attachment0 = bobber.Bobber
                    rigid.Attachment1 = fishModel.Attachment
                    fishModel.Parent = bobber

                    task.delay(6, function()
                        rod:SetAttribute("HasFish", nil)
                    end)
                    _timeElapsed = 0
                end
            end
        end
        _timeElapsed += dt
    end))
end

--- Called when a player joins during intermission
function module:JoinGame(player : Player)
    if player.Character then
        MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.Spawn, player.Character)

        self._janitor:Add(function()
            if player then
                if player.Character then
                    if player.Character.PrimaryPart then
                        player.Character.PrimaryPart.Anchored = false
                    end
                end
            end
        end)

        self.MiniGame.Players[player] = 0
    end
end

--- Return a sorted list of players and how many places from the top to award points
-- up to developer how to implement this list, how many places to award etc.
function module:GetWinners()
    -- get all players that played
    local justPlayers = TableUtil.Keys(self.MiniGame.Players)

    for i = #justPlayers, 1, -1 do
        if justPlayers[i] == nil then
            table.remove(justPlayers, i)
        end
    end

    -- sort by players
    table.sort(justPlayers, function(a, b)
        local a_score = self.MiniGame.Players[a]
        local b_score = self.MiniGame.Players[b]

        return a_score > b_score
    end)

    return justPlayers, 3
end

function module:Destroy()
    self.MiniGame = nil
end

return module