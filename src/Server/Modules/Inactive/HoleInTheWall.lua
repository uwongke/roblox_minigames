local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
-- Encode
--local StringOfYourTable = HttpsService:JSONEncode(YourTable)
-- Decode
--local Decode  =  HttpsService:JSONDecode(StringOfYourTable)

-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.HoleInTheWall
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 60

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    setmetatable(data,module)
    task.spawn(function()
        task.wait(3)
        data:PrepGame()
    end)
    return data
end

function module:PrepGame()
    local messageData = {
        Message="",
        Timer=""
    }
    --listen for when a player crosses the finish line
    self.GoalListener = self.Game.GameFinish.Touched:Connect(function(part)
        if self.GameOver.Value then
            return
        end
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = self.Players[player]
            if playerData then
                -- could be adjusted to allow multiple players to reach the end
                self.GameOver.Value = true
                self.GoalListener:Disconnect()
                self.GoalListener = nil
                self.Winners[player] = playerData
                self.Players[player] = nil
                -- you won!
                self.MessageTarget.Value = player.UserId
                messageData.Message="You Won!"
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait()
                -- everyone else lost (adding "-," to the front means every one except those listed)
                self.MessageTarget.Value = "-,"..player.UserId
                messageData.Message="You lost."
                self.Message.Value = HttpService:JSONEncode(messageData)
            end
        end
    end)
    --loop through each wall of doors, choose a random door from the set to be passable and have its parts unanchored
    local doors = self.Game:WaitForChild("Doors")
    for _,wall in ipairs(doors:GetChildren()) do
        local children = wall.Doors:GetChildren()
        local index = math.random(1,#children)
        local child = children[index]
        for _,doorPart in ipairs(child:GetChildren()) do
            doorPart.Anchored = false
        end
    end

    --set up check point system 
    local fallChecker = self.Game:WaitForChild("FallCheck")
    if fallChecker then
        fallChecker.Touched:Connect(function(other)
            local player = Players:GetPlayerFromCharacter(other.Parent)
            if player then
                local lastCheckPoint = self.Players[player].CheckPoint
                MiniGameUtils.SpawnAroundPart(lastCheckPoint, player.Character)
            end
        end)

        local checkPoints = self.Game:WaitForChild("CheckPoints")
        for _,checkPoint in pairs(checkPoints:GetChildren()) do
            checkPoint.Touched:Connect(function(other)
                local player = Players:GetPlayerFromCharacter(other.Parent)
                if player then
                    self.Players[player].CheckPoint = checkPoint
                end
            end)
        end
    end

    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Find the doors that won't block your path."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Race will Start in ..."
    self.CanJoin.Value = false-- it is now too late to join
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    local count =3
    while count > 0 do
        messageData.Message =count
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait(1)
        count -= 1
    end
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.Game.Barrier:Destroy()--remove invinsible barrier so players can begin freely
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    count = duration
    --count down until a player passes the finish line
    while count >= 0 do
        if self.GameOver.Value then
            return
        end
        self.MessageTarget.Value = ""
        messageData.Timer = count
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait(1)
        count -= 1
    end

    self.GameOver.Value = true
    self.GoalListener:Disconnect()
    self.GoalListener = nil

    messageData.Message="Times up!"
    self.Message.Value = HttpService:JSONEncode(messageData)
end

function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = 1,
            CheckPoint = self.Game.GameStart
        }
        self.Players[player] = data
        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        return true
    end
    return false
end

function module:Destroy()
    --clean up
    self.Game:Destroy()
    self = nil
end

return module