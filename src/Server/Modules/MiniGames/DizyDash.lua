local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.DizzyDash
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local DizzyComm = ServerComm.new(ReplicatedStorage, "DizzyComm")
local DizzyCommEvent = DizzyComm:CreateSignal("DizzyCommEvent")
local duration = 60
local TotalPlayers = 0

function module:Init(janitor, SpawnLocation, endSignal)
    TotalPlayers = 0
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.RemainingPlayers = 0
    self.Janitor = janitor
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

    janitor:Add(data.Game.FallCheck.Touched:Connect(function(part)
        local Character = part.Parent
        local player = Players:GetPlayerFromCharacter(Character)
        if player then
            task.wait(1)
            MiniGameUtils.SpawnAroundPart(data.Game.GameStart, Character)
        end
    end))

    janitor:Add(data.Game)

    self.MiniGame = data
end

function module:Update()
    
end

function module:Start()
    TotalPlayers = self.MiniGame.RemainingPlayers
    self.MiniGame.Game.Barrier:Destroy()
    local messageData = {}
    self.Janitor:Add(task.spawn(function()
        while true do
            task.wait(math.random(.5,2.5))
            local countDown =3
            while countDown > 0 do
                messageData.Message = countDown
                DizzyCommEvent:FireAll(HttpService:JSONEncode(messageData))
                task.wait(.5)
                countDown -= 1
            end
            messageData.Message = "Inverse"
            DizzyCommEvent:FireAll(HttpService:JSONEncode(messageData))
            task.wait(.5)
            messageData.Message = ""
            DizzyCommEvent:FireAll(HttpService:JSONEncode(messageData))
        end
    end))

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

--initialize data and handle potential clean up
function  module:JoinGame(player)
    local data = {
        Place = 0,
        Name = player.DisplayName,
    }
    self.MiniGame.Players[player] = data
    self.MiniGame.RemainingPlayers += 1
    local humanoid = player.Character:FindFirstChild("Humanoid")
    humanoid.WalkSpeed = 32

    MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.GameStart, player.Character)

    self.Janitor:Add(function()
        humanoid.WalkSpeed = 16
    end)
end

return module