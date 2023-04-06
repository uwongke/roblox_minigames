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
local GameTemplate = ReplicatedStorage.Assets.MiniGames.WackAMole
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 60
local Extras = ReplicatedStorage.Assets.MiniGameExtras.WackAMole
local respawnTime = 5

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.PlayersJoined = 0
    data.Red = {
        Players = {},
        Score = 0,
        MoleContainer = data.Game.RedSpawn.Model.Fog,
        MoleSpawns = {}
    }
    data.Blue = {
        Players = {},
        Score = 0,
        MoleContainer = data.Game.BlueSpawn.Model.Fog,
        MoleSpawns = {}
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
        Timer=""
    }
    -- set up spawn points for each team
    local RedSpawnLocations = self.Red.MoleContainer:GetChildren()
    local BlueSpawnLocations = self.Blue.MoleContainer:GetChildren()
    local i = 1
    -- same amount of spawn points for each team so the amount is whats important
    while i <= #RedSpawnLocations do
        --create spawn point info so each spawn point has an origin and a Spawn value
        --the Spawn value is used to track if it is currently occupied by one of its spawns
        --Spawn will default to nil meaning it is unoccupied and can be spawned into

        --red team spawn info
        local spawnPoint = RedSpawnLocations[i]
        spawnPoint.PrimaryPart = spawnPoint:GetChildren()[1]
        table.insert(self.Red.MoleSpawns , {
            Origin = spawnPoint.PrimaryPart
        })
        --blue team spawn info
        spawnPoint = BlueSpawnLocations[i]
        spawnPoint.PrimaryPart = spawnPoint:GetChildren()[1]
        table.insert(self.Blue.MoleSpawns , {
            Origin = spawnPoint.PrimaryPart
        })
        i+= 1
    end

    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Whack as many moles as possible, Gold moles are worth 5X the points!"
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
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)

    local spawns = math.ceil(#self.Red.MoleSpawns / 5)
    while spawns > 0 do
        spawns -= 1
        self:SpawnMole(self.Red.MoleSpawns)
        self:SpawnMole(self.Blue.MoleSpawns)
    end

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

    if self.Red.Score > self.Blue.Score then
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
--spawn a mole for a team where origin is the set of spawn points available for a team
function module:SpawnMole(origin)
    if self.GameOver.Value then
        return
    end
    -- look for a spawn point not already occupied with a spawn
    local spawned = true
    local spawnPoint = nil
    while spawned do
        spawnPoint = origin[math.random(1, #origin)]
        spawned = spawnPoint.Spawn
    end
    -- determine if the spawned mole is "Gold" or Normal
    local goldRarity = 10 -- percent
    local badRarity = 10
    local value = math.random(1, 100)
    local molePrefix = ""
    if value < goldRarity then
        molePrefix = "Gold"
    else
        if value > 100 - badRarity then
            molePrefix = "Bad"
        end
    end
    local mole = Extras[molePrefix.."Mole"]:Clone()
    spawnPoint.Spawn = mole
    mole.Position = spawnPoint.Origin.Position
    mole.Parent = spawnPoint.Origin
    -- after a random amount of time despawn and replace with another mole
    task.spawn(function()
        task.wait(math.random(respawnTime/2,respawnTime))
        if spawnPoint.Spawn then
            spawnPoint.Spawn:Destroy()
            spawnPoint.Spawn = nil
            self:SpawnMole(origin)
        end
    end)
end
-- hit a mole with a mallet
function module:RemoveMole(mole)
    --determine if the mole was a part of the red or blue team
    local origin = mole.Parent.Parent.Parent == self.Red.MoleContainer
    and self.Red.MoleSpawns or self.Blue.MoleSpawns
    --find the spawn point for the corresponding team and make sure it knows it is being despawned and replace it
    for _,spawnPoint in ipairs(origin) do
        if spawnPoint.Spawn == mole then
            mole:Destroy()
            spawnPoint.Spawn = nil
            self:SpawnMole(origin)
            return
        end
    end
end
--initialize data and give mallets to players
function  module:JoinGame(player)
    if self.CanJoin.Value then
        --doesn't exist server side
        --local controls = require(player.PlayerScripts.PlayerModule):GetControls()
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
        --give player a mallet
        local mallet = Extras.Mallet:Clone()
        -- check if mallet hits something
        mallet.Handle.Touched:Connect(function(hit)
            if self.GameOver.Value then
                return
            end
            local value = hit:FindFirstChild("Value")
            -- if you hit a mole which has a value then award yourself and your team points
            if value and mallet.Swinging.Value then
                print("Hit "..hit.Name .. " for ".. value.Value.." points!")
                mallet.hit:Play()
                self:RemoveMole(hit)
                if value.Value == 0 then
                    --temp disable player
                    print("stun")
                    task.spawn(function()
                        self.MessageTarget.Value = ""..player.UserId
                        self.Message.Value = "Disable"
                        task.wait(1)
                        self.MessageTarget.Value = ""..player.UserId
                        self.Message.Value = "Enable"
                    end)
                end
                --update my personal info
                self.MessageTarget.Value = player.UserId
                data.Score += value.Value
                --[[ format message
                local messageData = {}
                messageData["MyScore"] = data.Score
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait()
                ]]
                -- update team info
                local messageData  = {}
                self.MessageTarget.Value = ""--everybody
                self[team].Score += value.Value
                messageData[team.."Score"] = self[team].Score
                self.Message.Value = HttpService:JSONEncode(messageData)
            end
        end)
        --swing the mallet
        mallet.Activated:Connect(function()
            -- don't swing again if you are still swinging
            if mallet.Swinging.Value then
                return
            end
            local str = Instance.new("StringValue")
            str.Name = "toolanim"
            str.Value = "Slash"
            str.Parent = mallet
            mallet.swing:Play()
            mallet.Swinging.Value = true
            task.wait(.5)
            -- nil check for the rare case you swing just as the game ends
            if mallet then
                mallet.Swinging.Value = false
            end
        end)
        --when the game is over remove the mallet from the player
        self.GameOver.Changed:Connect(function(newValue)
            if newValue then
                mallet:Destroy()
                mallet = nil
            end
        end)

        mallet.Parent = player.Character
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