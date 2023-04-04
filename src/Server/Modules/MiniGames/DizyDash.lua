local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.DizzyDash
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

    --bring those who fall through back to the start
    self.FallListener = self.Game.FallCheck.Touched:Connect(function(part)
        local Character = part.Parent
        local player = Players:GetPlayerFromCharacter(Character)
        if player then
            task.wait(1)
            MiniGameUtils.SpawnAroundPart(self.Game.GameStart, Character)
        end
    end)
    
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Is left right and forwards backwards? This map can't make up its mind."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "First player to reach the end wins!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Game will Start in ..."
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
    self.Game.Barrier:Destroy()
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.GameStarted = true
    messageData.Message = nil--don't want a blank message to override any other messages that may come up during game play

    task.spawn(function()
        while self.GameOver.Value == false do
            task.wait(math.random(2,3))
            self.MessageTarget.Value = ""
            self.Message.Value = "Inverse"
        end
    end)

    -- count down 
    count = duration
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

    messageData.Message="Times up!"
    self.Message.Value = HttpService:JSONEncode(messageData)

    task.wait(1)

    messageData.Timer = ""
    messageData.Message = "Subjects Win!"

    self.Message.Value = HttpService:JSONEncode(messageData)
end

--initialize data and handle potential clean up
function  module:JoinGame(player)
    if self.CanJoin.Value then
        --local ball = Extras.HamsterBall:Clone()
        --ball.Parent = player.Character
        
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = 1
        }
        self.Players[player] = data
        local humanoid = player.Character:FindFirstChild("Humanoid")
        humanoid.WalkSpeed = 32

        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)

        self.GameOver.Changed:Connect(function(newVal)
            if newVal and player.Character then
                
                humanoid.WalkSpeed = 16
            end
        end)
        
        return true
    end
    return false
end

function module:AttachPotatoToPlayer(player)
    local character = player.Character
    local hatAttach = character:FindFirstChild("HatAttachment", true)
    if hatAttach then
        local constraint = self.HotPotato:WaitForChild("RigidConstraint")
        constraint.Enabled = false
        self.HotPotato.Parent = character
        constraint.Attachment1 = hatAttach
        task.wait()
        constraint.Enabled = true
    end
end

function module:Destroy()
    self.Game:Destroy()
    self = nil
end

return module