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
local GameTemplate = ReplicatedStorage.Assets.MiniGames.HurdleRace
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local Extras = ReplicatedStorage.Assets.MiniGameExtras.HurdleRace
local Hurdle = Extras.Hurdle

--game vars
local duration = 60
local laneLength = 990
local minDistanceBetweenHurdles = 30
local maxDistanceBetweenHurdles = 60
local hurdleStartBuffer = 20
local hurdlePoints = {}
local hitHurdleAnimation = Instance.new("Animation")
hitHurdleAnimation.AnimationId = "rbxassetid://12603514979"

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)

    setmetatable(data,module)
    task.spawn(function()
        task.wait(3)
        data:PrepGame()
    end)
    return data
end



local function tweenPivot(Object: BasePart | Model, CF: CFrame, tweenTime: number)
	if Object then
		local CFrameValue = Instance.new("CFrameValue")
		CFrameValue.Value = Object:GetPivot()

		local TweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.In, 0)

		CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
			Object:PivotTo(CFrameValue.Value)
		end)

		local tween = TweenService:Create(CFrameValue, TweenInfo, { Value = CF })
		tween:Play()

		tween.Completed:Connect(function()
            CFrameValue:Destroy()
        end)
		
	end
end


function module:PrepGame()

    self.ActivePlayers = {}
    self.LaneCount = 1
    hurdlePoints = {}
    local messageData = {
        Message="",
        Timer=""
    }

    self.GoalListener = self.Game.GameFinish.Touched:Connect(function(part)
        if self.GameOver.Value then
            return
        end
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = self.Players[player]
            if playerData then
                -- could be adjusted to allow multiple players to reach the end
                --for _, player in ipairs(self.ActivePlayers) do 
                    Knit.GetService("HurdleRaceService").Client.EndGame:FireAll(player)
                --end
            
                self.GameOver.Value = true
                self.GoalListener:Disconnect()
                self.GoalListener = nil
                self.Winners[player] = playerData
                self.Players[player] = nil

                self.MessageTarget.Value = player.UserId
                messageData.Message="You Won!"
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait()
                self.MessageTarget.Value = "-,"..player.UserId
                messageData.Message="You lost."
                self.Message.Value = HttpService:JSONEncode(messageData)
            end
        end
    end)

    --setup points for hurdles
    self:SetHurdlePoints()
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Press space when light is green. Jump over hurdles."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    --[[
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
    Knit.GetService("HurdleRaceService").Client.StartGame:FireAll(self.ActivePlayers)
]]--
   
    Knit.GetService("HurdleRaceService").Client.StartGame:FireAll(self.ActivePlayers, math.random(2,5))

 
end

function  module:JoinGame(player)
    if self.CanJoin.Value then
        table.insert(self.ActivePlayers, player)
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = self.LaneCount
        }
        self.LaneCount += 1
        self.Players[player] = data
       -- MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
       print("joined")
       Knit.GetService("HurdleRaceService").Client.JoinedGame:Fire(player, laneLength, data.Position)
       local lane = self.Game.Lanes:FindFirstChild("Lane"..data.Position)
       player.Character:SetPrimaryPartCFrame(CFrame.new(lane.Start.Position))
    local HRP =  player.Character.HumanoidRootPart
    local finish = self.Game.Lanes:FindFirstChild("Lane"..data.Position).Finish
    HRP.CFrame = CFrame.lookAt(HRP.Position, Vector3.new(finish.Position.X, HRP.Position.Y, finish.Position.Z))
    
     self:PrepLane(lane)

    return true
    end
    return false
end

function module:SetHurdlePoints()
    local lengthTracker = hurdleStartBuffer
    while lengthTracker < laneLength - 100 do
        lengthTracker += minDistanceBetweenHurdles + math.random(0,maxDistanceBetweenHurdles)
        table.insert(hurdlePoints, lengthTracker)
    end
    print(hurdlePoints)
end
function module:HitHurlde(player, hurdle)
    print(player.Name .. " hit a hurdle.")

    --play animaiton
	local animator = player.Character.Humanoid:WaitForChild("Animator")
	local hitHurdleAnimationTrack = animator:LoadAnimation(hitHurdleAnimation)
	hitHurdleAnimationTrack:Play()

    Knit.GetService("HurdleRaceService").Client.PlayerHitHurdle:Fire(player)
    hurdle:SetAttribute("Hit", true)

end
function module:PrepLane(lane)
    for _, point in ipairs(hurdlePoints) do
        local newHurdle:Model = Hurdle:Clone()

        newHurdle.HitBox.Touched:Connect(function(hit)
            if newHurdle:GetAttribute("Hit") == false then
                local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
                if player then
                    self:HitHurlde(player, newHurdle)
                    --knock the hurdle over
                    local orient = newHurdle.Hurdle.Orientation
                    local tween = TweenService:Create(newHurdle.Hurdle, TweenInfo.new(.1),{Orientation = Vector3.new(orient.X - 90, orient.Y, orient.Z)})
                    tween:Play()
                   
                end
            end
        end)

        newHurdle.Parent = lane
        local orientation = lane.Start.Orientation
        newHurdle:PivotTo(CFrame.new(lane.Start.Position + (lane.Start.CFrame.LookVector * point)) * CFrame.Angles(math.rad(orientation.X),math.rad(orientation.Y),math.rad(orientation.Z)))
    end
    print(lane.Start.CFrame.LookVector)
end

function module:Destroy()
    --clean up
    hurdlePoints = {}
    self.Game:Destroy()
    self = nil
end

return module