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
local TweenService = game:GetService("TweenService")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.SkyClimbers
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local Extras = ReplicatedStorage.Assets.MiniGameExtras.SkyClimbers
local Lane = Extras.Lane
local Platform = Extras.Platform
local SentHeightEvent:RemoteEvent = Extras.SentHeightEvent
local DirectionBB:BillboardGui = Extras.DirectionBB
--game vars
local duration = 30000
local laneLength = 2300
local distanceBetweenPlatforms = 10
local laneBuffer = 80
local platformPoints = {}

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

    self.ActivePlayers = {}
    self.LaneCount = 0
    platformPoints = {}
    local messageData = {
        Message="",
        Timer=""
    }


    self:SetPlatformPoints()
    self.GotScoreCount = 0
    self.Winner = nil
    self.HighestDistance = 0
    SentHeightEvent.OnServerEvent:Connect(function(sender, position)
        self.GotScoreCount += 1
        sender.Character:PivotTo(CFrame.new(position))
        local height = position.Y
        if height > self.HighestDistance then
            self.Winner = sender
            self.HighestDistance = height
        end
        if self.GotScoreCount >= #self.ActivePlayers then
            messageData.Timer = ""
            messageData.Message = self.Winner.Name .. " won!"
        
            self.Message.Value = HttpService:JSONEncode(messageData)

            self.GameOver.Value = true
            Knit.GetService("SkyClimbersService").Client.EndGame:FireAll(self.ActivePlayers)
        end
    end)

    
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Be the highest player. Jump with either left or right."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
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
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    Knit.GetService("SkyClimbersService").Client.StartGame:FireAll(self.ActivePlayers)


       --main timer
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

     messageData.Message="Times up!"
     self.Message.Value = HttpService:JSONEncode(messageData)
     
     Knit.GetService("SkyClimbersService").Client.StopJumping:FireAll(self.ActivePlayers)

   
  

     task.wait(1)
     
     --[[
     messageData.Timer = ""
     messageData.Message = self:GetWinner().Name .. " won!"
 
     self.Message.Value = HttpService:JSONEncode(messageData)

     self.GameOver.Value = true
     Knit.GetService("SkyClimbersService").Client.EndGame:FireAll(self.ActivePlayers)
     ]]--


 
end
function  module:GetWinner()
    local highestDistance = 0
    local winner = nil

    for _, player in ipairs(self.ActivePlayers) do
        local char = player.Character
        if char then
            if char.HumanoidRootPart.Position.Y > highestDistance then
                winner = player
                highestDistance = char.HumanoidRootPart.Position.Y
            end
        end
    end
    return winner
end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        self.LaneCount += 1
        table.insert(self.ActivePlayers, player)
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = self.LaneCount,
            Height = 0
        }
        
        self.Players[player] = data
       -- MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)

       local newLane = Extras.Lane:Clone()
       newLane.Name = "Lane" .. data.Position
       newLane.Parent = self.Game.Lanes
       newLane:PivotTo(CFrame.new(self.Game:FindFirstChild("StartingLane").Position + Vector3.new(-laneBuffer * self.LaneCount,0,0)))

       Knit.GetService("SkyClimbersService").Client.JoinedGame:Fire(player, laneLength, data.Position, platformPoints)
       --local lane = self.Game.Lanes:FindFirstChild("Lane"..data.Position)
       player.Character:SetPrimaryPartCFrame(CFrame.new(newLane.PlayerSpawn.Position))
       --player.Character.HumanoidRootPart.Anchored = true
        --local HRP =  player.Character.HumanoidRootPart
        --local finish = self.Game.Lanes:FindFirstChild("Lane"..data.Position).Finish
        --HRP.CFrame = CFrame.lookAt(HRP.Position, Vector3.new(finish.Position.X, HRP.Position.Y, finish.Position.Z))
    
     self:PrepLane(newLane)

    return true
    end
    return false
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
    --print(hurdlePoints)
end

function module:PrepLane(lane)
    local positionTracker = 0
    local platformNumber = 0
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
    end
end

function module:Destroy()
    --clean up
    platformPoints = {}
    self.Game:Destroy()
    self = nil
end

return module