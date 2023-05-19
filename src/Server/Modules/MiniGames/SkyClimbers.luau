--[[
    SkyClimbers.luau
    Author: Justin (synnull)
    Description: Server-sided game
]]


local module = {}
module.__index = module
local Players = game:GetService("Players")


-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.SkyClimbers
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--comms
local SkyClimbComm = ServerComm.new(ReplicatedStorage, "SkyClimbComm")
local JoinedGameEvent = SkyClimbComm:CreateSignal("JoinedGameEvent")
local StartGameEvent = SkyClimbComm:CreateSignal("StartGameEvent")
local StopJumpingEvent = SkyClimbComm:CreateSignal("StopJumpingEvent")
local EndGameEvent = SkyClimbComm:CreateSignal("EndGameEvent")

local Extras = ReplicatedStorage.Assets.MiniGameExtras.SkyClimbers
local Lane = Extras.Lane
local Platform = Extras.Platform
local SentHeightEvent:RemoteEvent = Extras.SentHeightEvent
local DirectionBB:BillboardGui = Extras.DirectionBB
local Backgrounds:Folder = Extras.Backgrounds:GetChildren()

--game vars
local ROUND_TIME = 30
local laneLength = 800
local distanceBetweenPlatforms = 10
local laneBuffer = 80
local platformPoints = {}


function module:Init(janitor, SpawnLocation)
    self.MiniGame = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    janitor:Add(self.MiniGame.Game)
   
    -- should clean this up with janitor
    -- removes players that leave during the game from the pool of players
    janitor:Add(Players.PlayerRemoving:Connect(function(player)
        if self.MiniGame.Players[player] then
            self.MiniGame.Players[player] = nil
        end
    end))
   
    self._janitor = janitor

    self:PrepGame()
end


function module:PrepGame()

    self.LaneCount = 0
    platformPoints = {}
    self.ActivePlayers = {}

    self:PrepBackground()
    self:SetPlatformPoints()

    self.GotScoreCount = 0
    self.Winner = nil
    self.HighestDistance = 0
    self.SentHeightEvent = SentHeightEvent.OnServerEvent:Connect(function(sender, position)
        --self.GotScoreCount += 1
        sender.Character:PivotTo(CFrame.new(position))
        self.MiniGame.Players[sender] = position.Y
        local height = position.Y
        
    end)

    
    --Knit.GetService("SkyClimbersService").Client.StartGame:FireAll(self.ActivePlayers)

     
     --Knit.GetService("SkyClimbersService").Client.StopJumping:FireAll(self.ActivePlayers)

   
     
     --Knit.GetService("SkyClimbersService").Client.EndGame:FireAll(self.ActivePlayers)
     


 
end


function module:Start()

     --make sure this game gets cleaned up
    self._janitor:Add(function()
        self:Destroy()
     end)

    print(self.MiniGame.Players)
     StartGameEvent:FireAll(self.ActivePlayers)
    return ROUND_TIME

end



function  module:GetWinners()
    local highScore = 0
    local winner = nil

    for player, score in self.MiniGame.Players do
        if score > highScore then
            highScore = score
            winner = player
        end
    end
    return winner
end
function  module:JoinGame(player)
    self.LaneCount += 1
    self.MiniGame.Players[player] = 0
    table.insert(self.ActivePlayers, player)
    local newLane = Extras.Lane:Clone()
    newLane.Name = "Lane_" .. player.Name
    newLane.Parent = self.MiniGame.Game.Lanes
    newLane:PivotTo(CFrame.new(self.MiniGame.Game:FindFirstChild("StartingLane").Position + Vector3.new(-laneBuffer * self.LaneCount,0,0)))

    --Knit.GetService("SkyClimbersService").Client.JoinedGame:Fire(player, laneLength, data.Position, platformPoints)
    JoinedGameEvent:Fire(player, laneLength, platformPoints)
    player.Character:SetPrimaryPartCFrame(CFrame.new(newLane.PlayerSpawn.Position))
    self:PrepLane(newLane)

end

function module:SetPlatformPoints()
    local lengthTracker = 0
    while lengthTracker < laneLength do
        lengthTracker += distanceBetweenPlatforms
        local randomNumer = math.random(1,10)
        if randomNumer > 5 then
            table.insert(platformPoints, "L")
        else
            table.insert(platformPoints, "R")
        end
        
    end
end


function module:Update()
    -- no need to update anything in real-time for this game
end
function module:PrepBackground()
    self.GeneratedBackground = Instance.new("Model")
    for i = 0, 10, 1 do
        local newBackground:Model = Backgrounds[math.random(1, #Backgrounds)]:Clone()
        newBackground:PivotTo(CFrame.new(Vector3.new(0, 3.5 + (80 * i), 0))  * CFrame.Angles(0,math.rad(180),0))  --3.5
        --newBackground:PivotTo(CFrame.new(Vector3.new(lane.PlayerSpawn.Position.X, 3.5 + (80 * backgroundNumber), lane.PlayerSpawn.Position.Z))  * CFrame.Angles(0,math.rad(180),0))  --3.5
        newBackground.Parent = self.GeneratedBackground
    end
   
end
function module:PrepLane(lane)
    local positionTracker = 0
    local platformNumber = 0
    --local backgroundNumber = 0
    for _, point in ipairs(platformPoints) do
        positionTracker += distanceBetweenPlatforms
        platformNumber += 1
        local newPlatform:Model = Platform:Clone()

        newPlatform.Parent = lane.Platforms
        newPlatform.Name = "Platform" .. platformNumber
        --local orientation = lane.Start.Orientation
        --* CFrame.Angles(math.rad(orientation.X),math.rad(orientation.Y),math.rad(orientation.Z))
        local x
        local newDirectionBB = DirectionBB:Clone()
        if point == "L" then
            x = - 10
            newDirectionBB.Frame.TextLabel.Text = "A"
        else
            x = 10
            newDirectionBB.Frame.TextLabel.Text = "D"
        end
        newDirectionBB.Parent = newPlatform
        local platformPosition = Vector3.new(x, positionTracker,0)
        newPlatform:PivotTo(CFrame.new(lane.PlayerSpawn.Position + platformPosition) )

        --[[
        if platformNumber % 7 == 0 then
            print("new back!")
            local newBackground:Model = Backgrounds[math.random(1, #Backgrounds)]:Clone()
            newBackground:PivotTo(CFrame.new(Vector3.new(lane.PlayerSpawn.Position.X, 3.5 + (80 * backgroundNumber), lane.PlayerSpawn.Position.Z))  * CFrame.Angles(0,math.rad(180),0))  --3.5
            newBackground.Parent = lane.Backgrounds
            backgroundNumber += 1
        end
        ]]--
    end
    local newBackground = self.GeneratedBackground:Clone()
    newBackground:PivotTo(CFrame.new(Vector3.new(lane.PlayerSpawn.Position.X, 457 , lane.PlayerSpawn.Position.Z))  * CFrame.Angles(0,math.rad(180),0))  --3.5
    newBackground.Parent = lane.Backgrounds
  
end

function module:Destroy()
    --clean up
    platformPoints = {}
    self.SentHeightEvent:Disconnect()
end

return module