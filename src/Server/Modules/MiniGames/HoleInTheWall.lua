local module = {}
module.__index = module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.HoleInTheWall
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Obstacles = ReplicatedStorage.Assets.MiniGameExtras.HoleInTheWall:GetChildren()
local duration = 60
local TotalPlayers = 0

function module:Init(janitor, SpawnLocation, endSignal)
    TotalPlayers = 0
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.RemainingPlayers = 0
    self.Janitor = janitor
    self.MiniGame = data
    janitor:Add(data.Game)

    print("Init Hole In The Wall")

    janitor:Add(data.Game.GameFinish.Touched:Connect(function(part)
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = data.Players[player]
            if playerData then
                data.RemainingPlayers -= 1
                data.Winners[player] = playerData
                playerData.Place = TotalPlayers - data.RemainingPlayers
                data.Players[player] = nil
                if data.RemainingPlayers <= 0 then
                    endSignal:Fire()
                end
            end
        end
    end))

    local doors = data.Game:WaitForChild("Doors")
    for _,wall in ipairs(doors:GetChildren()) do
        local children = wall.Doors:GetChildren()
        local index = math.random(1,#children)
        local child = children[index]
        for _,doorPart in ipairs(child:GetChildren()) do
            doorPart.Anchored = false
        end
    end

    local fallChecker = data.Game:WaitForChild("FallCheck")
    if fallChecker then
        fallChecker.Touched:Connect(function(other)
            local player = Players:GetPlayerFromCharacter(other.Parent)
            if player then
                local lastCheckPoint = data.Players[player].CheckPoint
                MiniGameUtils.SpawnAroundPart(lastCheckPoint, player.Character)
            end
        end)

        local checkPoints = data.Game:WaitForChild("CheckPoints")
        for _,checkPoint in pairs(checkPoints:GetChildren()) do
            local obstacleIndex = math.random(1,#Obstacles)
            local obstacle = Obstacles[obstacleIndex]:Clone()
            obstacle:SetPrimaryPartCFrame(checkPoint.CFrame)
            obstacle.Parent = data.Game
            checkPoint.Touched:Connect(function(other)
                local player = Players:GetPlayerFromCharacter(other.Parent)
                if player then
                    data.Players[player].CheckPoint = checkPoint
                end
            end)
        end
    end
end

function module:Start()
    TotalPlayers = self.MiniGame.RemainingPlayers
    self.MiniGame.Game.Barrier:Destroy()
    return duration
end

function module:GetWinners()
    table.sort(self.MiniGame.Winners,function(a, b)
        local a_score = self.Minigame.Winners[a].Place
        local b_score = self.Minigame.Winners[b].Place

        return a_score > b_score
    end)
    return self.MiniGame.Winners, 3
end

function module:Update()
    
end

function  module:JoinGame(player)
    local data = {
        Name = player.DisplayName,
        Place = 0,
        CheckPoint = self.MiniGame.Game.GameStart
    }
    self.MiniGame.Players[player] = data
    MiniGameUtils.SpawnAroundPart(data.CheckPoint, player.Character)
end

function module:Destroy()
    self = nil
end

return module