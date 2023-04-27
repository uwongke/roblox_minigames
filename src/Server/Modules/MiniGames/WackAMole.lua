local module = {}
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
-- Encode
--local StringOfYourTable = HttpsService:JSONEncode(YourTable)
-- Decode
--local Decode  =  HttpsService:JSONDecode(StringOfYourTable)

-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local MoleComm = ServerComm.new(ReplicatedStorage, "MoleComm")
local WhackMoleEvent = MoleComm:CreateSignal("WhackMoleEvent")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.WackAMole
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 60
local Extras = ReplicatedStorage.Assets.MiniGameExtras.WackAMole
local respawnTime = 5

--- Called when the round is initialized, 10s preview with game info is displayed on the client
function module:Init(janitor, SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.PlayersJoined = 0
    data.Red = {
        Players = {},
        Score = 0,
        MoleContainer = data.Game.RedSpawn.Model.Fog,
        MoleSpawns = {},
        GoldRarity = 10,
        BadRarity  = 10,
        BuffRarity = 10
    }
    data.Blue = {
        Players = {},
        Score = 0,
        MoleContainer = data.Game.BlueSpawn.Model.Fog,
        MoleSpawns = {},
        GoldRarity = 10,
        BadRarity  = 10,
        BuffRarity = 10
    }
    janitor:Add(data.Game)
   
    -- should clean this up with janitor
    -- removes players that leave during the game from the pool of players
    janitor:Add(Players.PlayerRemoving:Connect(function(player)
        if data.Red.Players[player] then
            data.Red.Players[player] = nil
        else
            if data.Blue.Players[player] then
                data.Blue.Players[player] = nil
            end
        end
    end))

    local RedSpawnLocations = data.Red.MoleContainer:GetChildren()
    local BlueSpawnLocations = data.Blue.MoleContainer:GetChildren()
    local i = 1
    -- same amount of spawn points for each team so the amount is whats important
    while i <= #RedSpawnLocations do
        --create spawn point info so each spawn point has an origin and a Spawn value
        --the Spawn value is used to track if it is currently occupied by one of its spawns
        --Spawn will default to nil meaning it is unoccupied and can be spawned into

        --red team spawn info
        local spawnPoint = RedSpawnLocations[i]
        spawnPoint.PrimaryPart = spawnPoint:GetChildren()[1]
        table.insert(data.Red.MoleSpawns , {
            Origin = spawnPoint.PrimaryPart
        })
        --blue team spawn info
        spawnPoint = BlueSpawnLocations[i]
        spawnPoint.PrimaryPart = spawnPoint:GetChildren()[1]
        table.insert(data.Blue.MoleSpawns , {
            Origin = spawnPoint.PrimaryPart
        })
        i+= 1
    end

    self.MiniGame = data

    self._janitor = janitor
end

function module:Start()
    local spawns = math.ceil(#self.MiniGame.Red.MoleSpawns / 5)
    while spawns > 0 do
        spawns -= 1
        self:SpawnMole(self.MiniGame.Red)
        self:SpawnMole(self.MiniGame.Blue)
    end
    return duration
end

function module:SpawnMole(origin)
    if self.MiniGame.GameOver.Value then
        return
    end
    -- look for a spawn point not already occupied with a spawn
    local spawns = origin.MoleSpawns
    local spawned = true
    local spawnPoint = nil
    while spawned do
        spawnPoint = spawns[math.random(1, #spawns)]
        spawned = spawnPoint.Spawn
    end
    -- determine if the spawned mole is "Gold" or Normal
    local goldRarity = origin.GoldRarity
    local badRarity  = origin.BadRarity
    local buffRarity = origin.BuffRarity
    local value = math.random(1, 100)
    local molePrefix = ""
    if value < goldRarity then
        molePrefix = "Gold"
    else
        if value > 100 - badRarity then
            molePrefix = "Bad"
        else
            if value < goldRarity + buffRarity then
                molePrefix = "Buff"
            end
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
function module:RemoveMole(mole, origin)
    --find the spawn point for the corresponding team and make sure it knows it is being despawned and replace it
    for _,spawnPoint in ipairs(origin.MoleSpawns) do
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
    --if self.CanJoin.Value then
        --doesn't exist server side
        --local controls = require(player.PlayerScripts.PlayerModule):GetControls()
        --assign players back and forth to keep teams even
    self.MiniGame.PlayersJoined += 1
    local team = self.MiniGame.PlayersJoined%2 == 0 and "Red" or "Blue"
    table.insert(self.MiniGame[team].Players,player)
    local data = {
        Team = team,
        Score = 0
    }
    self.MiniGame.Players[player] = data
    MiniGameUtils.SpawnAroundPart(self.MiniGame.Game[team.."Spawn"], player.Character)
    --give player a mallet
    local mallet = Extras.Mallet:Clone()
    self._janitor:Add(mallet)
    -- check if mallet hits something
    mallet.Handle.Touched:Connect(function(hit)
        if self.MiniGame.GameOver.Value then
            return
        end
        local value = hit:FindFirstChild("Value")
        -- if you hit a mole which has a value then award yourself and your team points
        if value and mallet.Swinging.Value then
            print("Hit "..hit.Name .. " for ".. value.Value.." points!")
            mallet.hit:Play()
            self:RemoveMole(hit, self.MiniGame[team])
            if hit.Name == "BadMole" then
                --temp disable player
                print("stun")
                task.spawn(function()
                    WhackMoleEvent:Fire(player, "Disable")
                    task.wait(1)
                    WhackMoleEvent:Fire(player, "Enable")
                end)
            else
                if hit.Name == "BuffMole" then
                    --buffs chances of gold moles and reduces chances of bad and buffs
                    -- starts at 10%,10%,10% split between the 3 types and will end with 30%,0%,0%
                    self.MiniGame[team].GoldRarity += 2
                    self.MiniGame[team].BadRarity  -= 1
                    self.MiniGame[team].BuffRarity -= 1
                    --adds 2 additional moles that will spawn for your side (stacks)
                    self:SpawnMole(self.MiniGame[team])
                    self:SpawnMole(self.MiniGame[team])
                end
            end
            --update my personal info
            --self.MessageTarget.Value = player.UserId
            data.Score += value.Value
            -- update team info
            local messageData  = {}
            --self.MessageTarget.Value = ""--everybody
            self.MiniGame[team].Score += value.Value
            messageData[team.."Score"] = self.MiniGame[team].Score
            WhackMoleEvent:FireAll(HttpService:JSONEncode(messageData))
            --self.Message.Value = HttpService:JSONEncode(messageData)
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

    mallet.Parent = player.Character
    --end
    --return false
end

function module:GetWinners()
    local winners = nil

    if self.MiniGame.Red.Score > self.MiniGame.Blue.Score then
        winners = self.MiniGame.Red.Players
    else
        if self.MiniGame.Blue.Score > self.MiniGame.Red.Score then
            winners = self.MiniGame.Blue.Players
        end
    end

    return winners
end


function module:Update()
    -- no need to update anything in real-time for this game
end

return module