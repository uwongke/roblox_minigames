local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.MadScientist
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 60
local laserSpeed = 8
-- i feel like this would only create confusion as to the function of the laser
-- based on color when it doesn't have any effect on it at all
local LaserColors = {
    BrickColor.Red(),
    BrickColor.Blue(),
    BrickColor.Green()
}

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.PlayersJoined = 0
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
    self.Subjects = {}
    self.ScientistChair = self.Game.Seat
    self.LaserVelocity = Vector3.zero
    self.Started = false
    self.LastAlpha = 0
    
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    -- provide the 2 different win conditions to the players
    if self.Scientist then
        self.Started = true
        self.MessageTarget.Value = ""..self.Scientist.UserId
        messageData.Message = "Hit All the players with the lasers before times up to win!"
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait()
        self.MessageTarget.Value = "-,"..self.MessageTarget.Value
    end
    messageData.Message = "Avoid the lasers until times up to win!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    self.MessageTarget.Value = ""
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
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    messageData.Message = nil--don't want a blank message to override any other messages that may come up during game play

    self:FireLaser(self.Game.LaserX)
    self:FireLaser(self.Game.LaserZ)

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

function module:FireLaser(laser)
    local tweenInfo = TweenInfo.new(
        2, -- Time
        Enum.EasingStyle.Linear, -- EasingStyle
        Enum.EasingDirection.Out, -- EasingDirection
        0, -- RepeatCount (when less than zero the tween will loop indefinitely)
        true, -- Reverses (tween will reverse once reaching it's goal)
        2 -- DelayTime
    )

    local tween = TweenService:Create(laser, tweenInfo, { Transparency = 0})
    tween.Completed:Connect(function()
        laser.BrickColor = LaserColors[math.random(1,#LaserColors)]
        self:FireLaser(laser)
    end)

    tween:Play()
end

--initialize data and handle potential clean up
function  module:JoinGame(player)
    if self.CanJoin.Value then
        --assign players back and forth to keep teams even
        self.PlayersJoined += 1
        local team = self.PlayersJoined == 1 and "Scientist" or "Subjects"

        if team == "Subjects" then
            table.insert(self.Subjects,player)
            MiniGameUtils.SpawnAroundPart(self.Game[team], player.Character)
        else
            local success, image = pcall(function()
                return game.Players:GetUserThumbnailAsync(
                    player.UserId,
                    Enum.ThumbnailType.AvatarBust,
                    Enum.ThumbnailSize.Size60x60
                )
            end)
            print(image)
            if success and image then
                for _,monitor in pairs(self.Game.Monitors:GetChildren()) do
                    monitor.Texture.Texture = image
                end
            end
            self.MessageTarget.Value = ""..player.UserId
            self.Message.Value = team
            self.Scientist = player
            self.ScientistChair:Sit(player.Character:FindFirstChild("Humanoid"))
            self.UpdateListener = RunService.Heartbeat:Connect(function(deltaTime)
                self:Update(deltaTime)
            end)
            self.GameOver.Changed:Connect(function(newVal)
                if newVal and player.Character then
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    humanoid.Sit = false
                end
            end)
        end
        
        return true
    end
    return false
end

function module:Update(time)
    if not self.GameOver.Value and self.Started then
        -- start turning on the laser when it is moving in a more visible direction
        local rampingUp = self.Game.LaserX.Transparency - self.LastAlpha < 0
        self.Game.LaserX.ParticleEmitter.Enabled = rampingUp
        self.Game.LaserZ.ParticleEmitter.Enabled = rampingUp
        self.LastAlpha = self.Game.LaserX.Transparency

        local laserOn = self.Game.LaserX.Transparency < .5
        
        if laserOn then
            local parts = self.Game.LaserX:GetTouchingParts()
            for _,v in pairs(parts) do
                if v == self.Game.LaserZ then
                    continue
                end
                self:KillPlayer(v.Parent)
            end

            parts = self.Game.LaserZ:GetTouchingParts()
            for _,v in pairs(parts) do
                if v == self.Game.LaserX then
                    continue
                end
                self:KillPlayer(v.Parent)
            end
            return
        end

        if self.LaserVelocity.X > 0 and self.Game.LaserX.Position.X < self.Game.Walls.Right.Position.X or
            self.LaserVelocity.X < 0 and self.Game.LaserX.Position.X > self.Game.Walls.Left.Position.X then
            self.Game.LaserX.Position += Vector3.xAxis * self.LaserVelocity.X * laserSpeed * time
        end
        -- the z axis is a little wonky due to perspective of the scientist
        if self.LaserVelocity.Z > 0 and self.Game.LaserZ.Position.Z > self.Game.Walls.Back.Position.Z or
            self.LaserVelocity.Z < 0 and self.Game.LaserZ.Position.Z < self.Game.Walls.Front.Position.Z then
            self.Game.LaserZ.Position += Vector3.zAxis * self.LaserVelocity.Z * -laserSpeed * time
        end
    end
end

function module:KillPlayer(Character)
    if Character == nil then
        return
    end
    local humanoid:Humanoid = Character:FindFirstChild("Humanoid")
    if humanoid == nil then
        return
    end
    local player = Players:GetPlayerFromCharacter(Character)
    local index = table.find(self.Subjects,player)
    if index then
        table.remove(self.Subjects, index)
        humanoid.Health = 0
        if #self.Subjects == 0 then
            self.GameOver.Value = true
            local messageData = {}
            messageData.Message = "The Mad Scientist Won!"
            self.Message.Value = HttpService:JSONEncode(messageData)
        end
    end
end

function module:HandleMessage(player, message)
    if player == self.Scientist then
        local axis = (message.Direction == "Forward" or message.Direction == "Back") and "Z" or "X"
        local direction = (axis == "X" and message.Direction == "Right" or axis == "Z" and message.Direction == "Forward") and 1 or -1
        if message.State == Enum.UserInputState.End then
            direction *= -1
        end
        local x = axis == "X" and self.LaserVelocity.X + direction or self.LaserVelocity.X
        local z = axis == "Z" and self.LaserVelocity.Z + direction or self.LaserVelocity.Z
        self.LaserVelocity = Vector3.new(x,0,z)
    end
end

function module:Destroy()
    --clean up
    self.UpdateListener:Disconnect()
    self.Game:Destroy()
    self = nil
end

return module