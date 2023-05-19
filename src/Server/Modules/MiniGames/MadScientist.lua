local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local MadScientistComm = ServerComm.new(ReplicatedStorage, "MadScientistComm")
local MadScientistCommEvent = MadScientistComm:CreateSignal("MadScientistCommEvent")
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

function module:Init(janitor, SpawnLocation,endSignal)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    janitor:Add(MadScientistCommEvent:Connect(function(player, message)
        self:HandleMessage(player, message)
    end))
    data.PlayersJoined = 0
    data.Subjects = {}
    data.ScientistChair = data.Game.Seat
    data.LaserVelocity = Vector3.zero
    data.Started = false
    data.LastAlpha = 0
    janitor:Add(data.Game)
    self.Janitor = janitor
    self.MiniGame = data
    self.GameOver = endSignal
    print("Init")
end

function module:Start()
    self.MiniGame.Winners = self.MiniGame.Subjects
    self.Janitor:Add(task.spawn(function()
        self:FireLaser(self.MiniGame.Game.LaserX)
        self:FireLaser(self.MiniGame.Game.LaserZ)
    end))
    print("Start")
    return duration
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
    self.MiniGame.PlayersJoined += 1
    local team = self.MiniGame.PlayersJoined == 1 and "Scientist" or "Subjects"

    if team == "Subjects" then
        table.insert(self.MiniGame.Subjects,player)
        MiniGameUtils.SpawnAroundPart(self.MiniGame.Game[team], player.Character)
    else
        local success, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                player.UserId,
                Enum.ThumbnailType.AvatarBust,
                Enum.ThumbnailSize.Size60x60
            )
        end)
        if success and image then
            for _,monitor in pairs(self.MiniGame.Game.Monitors:GetChildren()) do
                monitor.Texture.Texture = image
            end
        end
        self.MiniGame.Scientist = player
        MadScientistCommEvent:Fire(player, team)
        self.MiniGame.ScientistChair:Sit(player.Character:FindFirstChild("Humanoid"))
        self.Janitor:Add(function()
            if player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                humanoid.Sit = false
            end
        end)
    end
end

function module:GetWinners()
    return self.MiniGame.Winners
end

function module:Update(dt, time)
    local rampingUp = self.MiniGame.Game.LaserX.Transparency - self.MiniGame.LastAlpha < 0
    self.MiniGame.Game.LaserX.ParticleEmitter.Enabled = rampingUp
    self.MiniGame.Game.LaserZ.ParticleEmitter.Enabled = rampingUp
    self.MiniGame.LastAlpha = self.MiniGame.Game.LaserX.Transparency

    local laserOn = self.MiniGame.Game.LaserX.Transparency < .5
    
    if laserOn then
        local parts = self.MiniGame.Game.LaserX:GetTouchingParts()
        for _,v in pairs(parts) do
            if v == self.MiniGame.Game.LaserZ then
                continue
            end
            self:KillPlayer(v.Parent)
        end

        parts = self.MiniGame.Game.LaserZ:GetTouchingParts()
        for _,v in pairs(parts) do
            if v == self.MiniGame.Game.LaserX then
                continue
            end
            self:KillPlayer(v.Parent)
        end
        return
    end

    if self.MiniGame.LaserVelocity.X > 0 and self.MiniGame.Game.LaserX.Position.X < self.MiniGame.Game.Walls.Right.Position.X or
        self.MiniGame.LaserVelocity.X < 0 and self.MiniGame.Game.LaserX.Position.X > self.MiniGame.Game.Walls.Left.Position.X then
        self.MiniGame.Game.LaserX.Position += Vector3.xAxis * self.MiniGame.LaserVelocity.X * laserSpeed * dt
    end
    -- the z axis is a little wonky due to perspective of the scientist
    if self.MiniGame.LaserVelocity.Z > 0 and self.MiniGame.Game.LaserZ.Position.Z > self.MiniGame.Game.Walls.Back.Position.Z or
        self.MiniGame.LaserVelocity.Z < 0 and self.MiniGame.Game.LaserZ.Position.Z < self.MiniGame.Game.Walls.Front.Position.Z then
        self.MiniGame.Game.LaserZ.Position += Vector3.zAxis * self.MiniGame.LaserVelocity.Z * -laserSpeed * dt
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
    local index = table.find(self.MiniGame.Subjects,player)
    if index then
        table.remove(self.MiniGame.Subjects, index)
        humanoid.Health = 0
        if #self.MiniGame.Subjects == 0 then
            self.MiniGame.Winners = {self.MiniGame.Scientist}
            self.GameOver:Fire()
        end
    end
end

function module:HandleMessage(player, message)
    if player == self.MiniGame.Scientist then
        local axis = (message.Direction == "Forward" or message.Direction == "Back") and "Z" or "X"
        local direction = (axis == "X" and message.Direction == "Right" or axis == "Z" and message.Direction == "Forward") and 1 or -1
        if message.State == Enum.UserInputState.End then
            direction *= -1
        end

        local x = axis == "X" and self.MiniGame.LaserVelocity.X + direction or self.MiniGame.LaserVelocity.X
        local z = axis == "Z" and self.MiniGame.LaserVelocity.Z + direction or self.MiniGame.LaserVelocity.Z
        self.MiniGame.LaserVelocity = Vector3.new(x,0,z)
    end
end

function module:Destroy()
    self = nil
end

return module