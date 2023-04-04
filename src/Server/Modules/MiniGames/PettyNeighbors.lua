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

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.PlayersJoined = 0
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
        Timer="",
        BlueScore = TrashAmount,
        RedScore  = TrashAmount
    }

    self.Red.Spawn.Touched:Connect(function(part)
        self:ChangeSides(self.Red,part)
    end)

    self.Blue.Spawn.Touched:Connect(function(part)
        self:ChangeSides(self.Blue,part)
    end)
    
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Team with the least trash on their side wins!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Game will Start in ..."
    self.CanJoin.Value = false-- it is now too late to join
    self.Message.Value = HttpService:JSONEncode(messageData)
    -- clear scores from the message data, because after game starts it will be out of date,
    -- it will be handled specifcially when scores are updated
    messageData["BlueScore"] = nil
    messageData["RedScore"] = nil
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

    -- spawn trash on each teams side
    local i = 0
    while i < TrashAmount do
        self:SpawnTrash(self.Red.Spawn)
        self:SpawnTrash(self.Blue.Spawn)
        i+= 1
    end
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

    if self.Red.Score < self.Blue.Score then
        messageData.Message="Red Team Wins!"
    else
        if self.Red.Score == self.Blue.Score then
            messageData.Message = "Draw!"
        else
            messageData.Message ="Blue Team Wins!"
        end
    end
    self.Message.Value = HttpService:JSONEncode(messageData)
end

function module:ChangeSides(side, trash) 
    local team = trash:FindFirstChild("Team")
    if team and team.Value ~= side.Spawn.Name then
        if self.GameOver.Value then
            return
        end
        --ignore initial spawn collisions
        if team.Value ~= "" then
            side.Score += 1
            if side == self.Red then
                self.Blue.Score -= 1
            else
                self.Red.Score -= 1
            end
            -- update scores for all players
            local messageData = {}
            messageData["BlueScore"] = self.Blue.Score
            messageData["RedScore"] = self.Red.Score
            self.Message.Value = HttpService:JSONEncode(messageData)
        end
        team.Value = side.Spawn.Name
    end
end

--spawn a mole for a team where origin is the set of spawn points available for a team
function module:SpawnTrash(origin)
    local trash = Extras[math.random(1,#Extras)]:Clone()
    -- default tool pickup behaviour allowed infinite pick ups to the point of despawning if picking up too many
    -- worked around by changing the name to and from Handle and NotHandle depending on desired functionality
    local handle = trash:FindFirstChild("NotHandle")
    local onCoolDown = false
    handle.Touched:Connect(function(other)
        if onCoolDown or self.GameOver.Value then
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
    end)
    trash.Activated:Connect(function()
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
        trash.Parent = self.Game
        handle.CanCollide = true
        --throw tool in the direction the player is facing with some arch to it
        handle.Velocity = direction * ThrowPower + Vector3.yAxis * ThrowPower
        task.wait(1)
        onCoolDown = false
    end)
    trash.Parent = self.Game
    MiniGameUtils.SpawnAroundPart(origin,handle)
end

--initialize data and handle potential clean up
function  module:JoinGame(player)
    if self.CanJoin.Value then
        --assign players back and forth to keep teams even
        self.PlayersJoined += 1
        local team = self.PlayersJoined%2 == 0 and "Red" or "Blue"
        table.insert(self[team].Players,player)
        local data = {
            Team = team,
            Score = 0
        }
        self.Players[player] = data
        MiniGameUtils.SpawnAroundPart(self.Game[team.."Spawn"], player.Character)
        self.GameOver.Changed:Connect(function(newVal)
            --you can't take it with you
            if newVal then
                local tool = player.Character:FindFirstChildWhichIsA("Tool")
                if tool then
                    tool:Destroy()
                end
            end
        end)
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