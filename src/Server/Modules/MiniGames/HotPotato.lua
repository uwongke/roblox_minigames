local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local HotPotatoComm = ServerComm.new(ReplicatedStorage, "HotPotatoComm")
local HotPotatoEvent = HotPotatoComm:CreateSignal("HotPotatoEvent")
local CollectionService = game:GetService("CollectionService")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.HotPotato
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Extras = ReplicatedStorage.Assets.MiniGameExtras.HotPotato
local duration = 60

function module:Init(janitor, SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    self.Janitor = janitor
    self.MiniGame = data

    janitor:Add(data.Game)

    for _, object in pairs(CollectionService:GetTagged("JumpPad")) do
        if object:IsA("BasePart") then
            janitor:Add(object.Touched:Connect(function(other)
                local humanoid = other.Parent:FindFirstChild("Humanoid")
                humanoid.UseJumpPower = true
                humanoid.JumpPower = 100 --The Default JumpPower for a Humanoid is 50
                humanoid.Jump = true
                task.wait(1)
                humanoid.JumpPower = 50
            end))
        end
    end
end

function module:Start()
    self.MiniGame.Players[self.MiniGame.CurrentHotPotato].StartTime = DateTime.now().UnixTimestampMillis
    return duration
end

function module:GetWinners()
    local function Sort(Value1, Value2)
        return Value1.Total < Value2.Total
    end
    table.sort(self.MiniGame.Players, Sort)
    return self.MiniGame.Players, 3
end
--initialize data and handle potential clean up
function  module:JoinGame(player)
    local team = self.MiniGame.CurrentHotPotato and "Subjects" or "HotPotato"

    local messageData = {}
    messageData.Message = "You are now holding the Hot Potato! Pass it off QUICK!"

    if team == "HotPotato" then
        self.MiniGame.CurrentHotPotato = player
        self.MiniGame.HotPotato = Extras.Potato:Clone()
        self.Janitor:Add(self.MiniGame.HotPotato)
        self:AttachPotatoToPlayer(player)
        HotPotatoEvent:Fire(player, HttpService:JSONEncode(messageData))
    end

    self.MiniGame.Players[player] = {
        Total = 0
    }

    MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.Origin, player.Character)

    local hitbox = Extras.HitBox:Clone()
    self.Janitor:Add(hitbox)
    hitbox.Position = player.Character.HumanoidRootPart.Position
    local weld = hitbox:FindFirstChild("WeldConstraint")
    weld.Part1 = player.Character.HumanoidRootPart
    hitbox.Parent = player.Character

    self.Janitor:Add(hitbox.Touched:Connect(function(other)
        local character = other.Parent
        local otherPlayer = Players:GetPlayerFromCharacter(character)
        if otherPlayer then
            if otherPlayer ~= self.MiniGame.LastHotPotato and otherPlayer ~= self.MiniGame.CurrentHotPotato then
                local now = DateTime.now().UnixTimestampMillis
                local startTime = self.Players[player].StartTime
                self.Players[player].Total += now - startTime
                self.MiniGame.LastHotPotato = player
                local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
                humanoid.WalkSpeed /=2
                self.MiniGame.CurrentHotPotato = otherPlayer
                self.MiniGame.Players[otherPlayer].StartTime = now
                self:AttachPotatoToPlayer(otherPlayer)
                -- message the player that they now are holding the hot potato
                HotPotatoEvent:Fire(otherPlayer, HttpService:JSONEncode(messageData))
                -- clear out the message
                task.wait(3)
                local md = {Message = ""}
                HotPotatoEvent:Fire(otherPlayer, HttpService:JSONEncode(md))
            end
        end
    end))

    self.Janitor:Add(function()
        if player == self.MiniGame.CurrentHotPotato then
            local now = DateTime.now().UnixTimestampMillis
            local startTime = self.MiniGame.Players[player].StartTime
            self.MiniGame.Players[player].Total += now - startTime
            local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
            humanoid.Health = 0
        end
    end)
end

function module:Update()
    
end

function module:AttachPotatoToPlayer(player)
    local character = player.Character
    local hatAttach = character:FindFirstChild("HatAttachment", true)
    if hatAttach then
        local humanoid:Humanoid = player.Character:FindFirstChild("Humanoid")
        humanoid.WalkSpeed *=2
        local constraint = self.MiniGame.HotPotato:WaitForChild("RigidConstraint")
        constraint.Enabled = false
        self.MiniGame.HotPotato.Parent = character
        constraint.Attachment1 = hatAttach
        task.wait()
        constraint.Enabled = true
    end
end

function module:Destroy()
    self = nil
end

return module