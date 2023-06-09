local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.HotPotato
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Extras = ReplicatedStorage.Assets.MiniGameExtras.HotPotato
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

    for _, object in pairs(CollectionService:GetTagged("JumpPad")) do
        if object:IsA("BasePart") then
            object.Touched:Connect(function(other)
                local humanoid = other.Parent:FindFirstChild("Humanoid")
                humanoid.UseJumpPower = true
                humanoid.JumpPower = 100 --The Default JumpPower for a Humanoid is 50
                humanoid.Jump = true
                task.wait(1)
                humanoid.JumpPower = 50
            end)
        end
    end

    self.Players = {}
    
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Last player to hold the potato when time ends loses!"
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
    self.Players[self.CurrentHotPotato].StartTime = DateTime.now().UnixTimestampMillis
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.GameStarted = true
    messageData.Message = nil--don't want a blank message to override any other messages that may come up during game play

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

    local function Sort(Value1, Value2)
        return Value1.Total > Value2.Total
    end
    
    table.sort(self.Players, Sort)
    print(self.Players)

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
        --assign players back and forth to keep teams even
        local team = self.CurrentHotPotato and "Subjects" or "HotPotato"

        local messageData = {}
        messageData.Message = "You are now holding the Hot Potato! Pass it off QUICK!"

        if team == "HotPotato" then
            self.CurrentHotPotato = player
            self.HotPotato = Extras.Potato:Clone()
            self:AttachPotatoToPlayer(player)
            self.MessageTarget.Value = ""..player.UserId
            self.Message.Value = HttpService:JSONEncode(messageData)
        end

        self.Players[player] = {
            Total = 0
        }

        MiniGameUtils.SpawnAroundPart(self.Game.Origin, player.Character)

        local hitbox = Extras.HitBox:Clone()
        hitbox.Position = player.Character.HumanoidRootPart.Position
        local weld = hitbox:FindFirstChild("WeldConstraint")
        weld.Part1 = player.Character.HumanoidRootPart
        hitbox.Parent = player.Character

        hitbox.Touched:Connect(function(other)
            if not self.GameStarted or player ~= self.CurrentHotPotato then
                return
            end
            local character = other.Parent
            local otherPlayer = Players:GetPlayerFromCharacter(character)
            if otherPlayer then
                if otherPlayer ~= self.LastHotPotato and otherPlayer ~= self.CurrentHotPotato then
                    local now = DateTime.now().UnixTimestampMillis
                    local startTime = self.Players[player].StartTime
                    self.Players[player].Total += now - startTime
                    self.LastHotPotato = player
                    local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
                    humanoid.WalkSpeed /=2
                    self.CurrentHotPotato = otherPlayer
                    self.Players[otherPlayer].StartTime = now
                    self:AttachPotatoToPlayer(otherPlayer)
                    -- message the player that they now are holding the hot potato
                    self.MessageTarget.Value = ""..otherPlayer.UserId
                    self.Message.Value = HttpService:JSONEncode(messageData)
                    -- clear out the message
                    task.wait(3)
                    local md = {Message = ""}
                    self.MessageTarget.Value = ""..otherPlayer.UserId
                    self.Message.Value = HttpService:JSONEncode(md)
                end
            end
        end)

        self.GameOver.Changed:Connect(function(newVal)
            if newVal then
                if player == self.CurrentHotPotato then
                    local now = DateTime.now().UnixTimestampMillis
                    local startTime = self.Players[player].StartTime
                    self.Players[player].Total += now - startTime
                    local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
                    humanoid.Health = 0
                else
                    hitbox:Destroy()
                end
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
        local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
        humanoid.WalkSpeed *=2
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