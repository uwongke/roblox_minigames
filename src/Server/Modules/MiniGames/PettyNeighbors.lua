local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.PettyNeighbors
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 60
local Extras = ReplicatedStorage.Assets.MiniGameExtras.PettyNeighbors:GetChildren()
local TrashAmount = 25
local ThrowPower = 100
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local PettyNeighborsComm = ServerComm.new(ReplicatedStorage, "PettyNeighborsComm")
local PettyNeighborsCommEvent = PettyNeighborsComm:CreateSignal("PettyNeighborsCommEvent")

function module:Init(janitor, SpawnLocation, endSignal)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.PlayersJoined = 0
    self.Janitor = janitor
    self.MiniGame = data

    data.Red = {
        Players = {},
        Score = TrashAmount,
        Spawn = data.Game.RedSpawn
    }
    data.Blue = {
        Players = {},
        Score = TrashAmount,
        Spawn = data.Game.BlueSpawn
    }

    janitor:Add(data.Red.Spawn.Touched:Connect(function(part)
        self:ChangeSides(data.Red,part)
    end))

    janitor:Add(data.Blue.Spawn.Touched:Connect(function(part)
        self:ChangeSides(data.Blue,part)
    end))
end

function module:Start()
    local i = 0
    while i < TrashAmount do
        self:SpawnTrash(self.MiniGame.Red.Spawn)
        self:SpawnTrash(self.MiniGame.Blue.Spawn)
        i+= 1
    end
    local messageData = {
        BlueScore = TrashAmount,
        RedScore  = TrashAmount
    }
    PettyNeighborsCommEvent:FireAll(HttpService:JSONEncode(messageData))
    return duration
end

function module:GetWinners()
    local winners = {}
    if self.MiniGame.Red.Score < self.MiniGame.Blue.Score then
        winners = self.MiniGame.Red.Players
    else
        if self.MiniGame.Red.Score > self.MiniGame.Blue.Score then
            winners = self.MiniGame.Blue.Players
        end
    end

    return winners
end

function module:ChangeSides(side, trash) 
    local team = trash:FindFirstChild("Team")
    if team and team.Value ~= side.Spawn.Name then
        --ignore initial spawn collisions
        if team.Value ~= "" then
            side.Score += 1
            if side == self.MiniGame.Red then
                self.MiniGame.Blue.Score -= 1
            else
                self.MiniGame.Red.Score -= 1
            end
            -- update scores for all players
            local messageData = {}
            messageData["BlueScore"] = self.MiniGame.Blue.Score
            messageData["RedScore"] = self.MiniGame.Red.Score
            PettyNeighborsCommEvent:FireAll(HttpService:JSONEncode(messageData))
        end
        team.Value = side.Spawn.Name
    end
end

--spawn a mole for a team where origin is the set of spawn points available for a team
function module:SpawnTrash(origin)
    local trash = Extras[math.random(1,#Extras)]:Clone()
    self.Janitor:Add(trash)
    -- default tool pickup behaviour allowed infinite pick ups to the point of despawning if picking up too many
    -- worked around by changing the name to and from Handle and NotHandle depending on desired functionality
    local handle = trash:FindFirstChild("NotHandle")
    local onCoolDown = false
    self.Janitor:Add(handle.Touched:Connect(function(other)
        if onCoolDown then
            return
        end
        local character = other.Parent
        local player = Players:GetPlayerFromCharacter(character)
        -- if actually a player
        if player then
            -- only allow the player to hold one tool at a time
            if character:FindFirstChildWhichIsA("Tool") == nil then
                handle.Name = "Handle"
                trash.Parent = character
            end
        end
    end))
    self.Janitor:Add(trash.Activated:Connect(function()
        --play a throwing animation
        local str = Instance.new("StringValue")
        str.Name = "toolanim"
        str.Value = "Slash"
        str.Parent = trash
        --after animation reaches its upswing yeet the tool
        task.wait(.5)
        -- add cool down so player doesn't immediately pick up the tool after throwing it
        onCoolDown = true
        local direction = trash.Parent.PrimaryPart.CFrame.LookVector
        handle.Name = "NotHandle"
        trash.Parent = self.MiniGame.Game
        handle.CanCollide = true
        --throw tool in the direction the player is facing with some arch to it
        handle.Velocity = direction * ThrowPower + Vector3.yAxis * ThrowPower
        task.wait(1)
        onCoolDown = false
    end))
    trash.Parent = self.MiniGame.Game
    MiniGameUtils.SpawnAroundPart(origin,handle)
end

--initialize data and handle potential clean up
function  module:JoinGame(player)
    self.MiniGame.PlayersJoined += 1
    local team = self.MiniGame.PlayersJoined%2 == 0 and "Red" or "Blue"
    table.insert(self.MiniGame[team].Players,player)
    local data = {
        Team = team,
        Score = 0
    }
    self.MiniGame.Players[player] = data
    MiniGameUtils.SpawnAroundPart(self.MiniGame.Game[team.."Spawn"], player.Character)
end

function module:Update()
    
end

function module:Destroy()
    self = nil
end

return module