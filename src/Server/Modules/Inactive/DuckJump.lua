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
local GameTemplate = ReplicatedStorage.Assets.MiniGames.DuckJump
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local Extras = ReplicatedStorage.Assets.MiniGameExtras.DuckJump
local Hurdles = Extras.Hurdles

--game vars
local duration = 90
local laneLength = 990
local pushBackAmount = 3

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

		local TweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0)

		CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
			Object:PivotTo(CFrameValue.Value)
		end)

		local tween = TweenService:Create(CFrameValue, TweenInfo, { Value = CF })
		tween:Play()

		tween.Completed:Connect(function()
            CFrameValue:Destroy()
            Object:Destroy()
        end)
		
	end
end


function module:PrepGame()

    self.ActivePlayers = {}
    self.SpawnTime = 2
    self.MinTimeBewtweenHurdles = .3
    self.LaneCount = 1
    self.ElapsedTime = 0
    local messageData = {
        Message="",
        Timer=""
    }

    self.ActivePlayers = {}
    --set up death part
    self.Game.DeathPit.DeathPart.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            print(player.Name .. " is eliminated.")
            MiniGameUtils.SpawnAroundPart(workspace.LobbySpawn, player.Character)
            local canDie = player.Character:FindFirstChild("DuckJump_CanDie")
            local foundplayer  = table.find(self.ActivePlayers,player)
            if self.ActivePlayers[foundplayer] and canDie then
                Knit.GetService("MiniGameService").Client.PlayerGotEliminated:Fire(player, true)
                table.remove(self.ActivePlayers,table.find(self.ActivePlayers,player))
                print("players remain: " .. #self.ActivePlayers)
                if #self.ActivePlayers <= 1 then
                     if self.ActivePlayers[1] then
                         print(self.ActivePlayers[1].Name .. " wins.")
                     end
                     self.GameOver.Value = true
                     Knit.GetService("DuckJumpService").Client.EndGame:FireAll()
                end
                canDie.Value = false
                canDie:Destroy()
            end
           
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
    messageData.Message = "Jump over red. Duck (left control) under blue."
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
    for _, player in ipairs(self.ActivePlayers) do 
        --Knit.GetService("HurdleRaceService").Client.StartGame:Fire(player, self.Players[player].Position, self.ActivePlayers)
    end
    self.ElapsedTimeThread = task.spawn(function()
        while true do
            task.wait(1)
            self.ElapsedTime += 1
            if self.ElapsedTime % 5 == 0 and self.SpawnTime > .0 then
                self.SpawnTime = (self.SpawnTime * .8)
                messageData.Message = "Faster!"
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait(1)
                messageData.Message = ""
                self.Message.Value = HttpService:JSONEncode(messageData)
            end
        end
     
    end)
   
    self.HurdleThread = task.spawn(function()
        while true do
            task.wait(self.SpawnTime + self.MinTimeBewtweenHurdles)
            self:SpawnHurdle()

        end
    end)
    count = duration
    while count > 0 do
        if self.GameOver.Value then
            return
        end
        self.MessageTarget.Value = ""
        messageData.Timer =count
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait(1)
        count -= 1
    end

    --[[
    for _, player in ipairs(self.ActivePlayers) do 
        Knit.GetService("HurdleRaceService").Client.EndGame:Fire(player)
    end
    ]]--
    Knit.GetService("DuckJumpService").Client.EndGame:FireAll()
    self.GameOver.Value = true
    self.GoalListener:Disconnect()
    self.GoalListener = nil

    messageData.Message="Times up!"
    self.Message.Value = HttpService:JSONEncode(messageData)

 
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

        local canDie = player.Character:FindFirstChild("DuckJump_CanDie")
        if not canDie then
            canDie = Instance.new("BoolValue")
            canDie.Name = "DuckJump_CanDie"
            canDie.Parent = player.Character
        end
        canDie.Value = true


        table.insert(self.ActivePlayers, player)
       --Knit.GetService("HurdleRaceService").Client.JoinedGame:Fire(player, laneLength)
       local lane = self.Game.Lanes:FindFirstChild("Lane"..data.Position)
       player.Character:SetPrimaryPartCFrame(CFrame.new(lane.Start.Position))
    local HRP =  player.Character.HumanoidRootPart
    local finish = self.Game.Lanes:FindFirstChild("Lane"..data.Position).Finish
    HRP.CFrame = CFrame.lookAt(HRP.Position, Vector3.new(finish.Position.X, HRP.Position.Y, finish.Position.Z))
    Knit.GetService("DuckJumpService").Client.JoinedGame:Fire(player)
    Knit.GetService("MiniGameService").Client.PlayerJoinedMiniGame:Fire(player)
    

    return true
    end
    return false
end

function module:HitHurdle(player, hurdle)
  
	if not hurdle:GetAttribute(player.Name) then
          -- Knit.GetService("HurdleRaceService").Client.PlayerHitHurdle:Fire(player)
        print(player.Name .. " hit a hurdle.")
        player.Character.HumanoidRootPart.Position += Vector3.new(0,0,pushBackAmount)
        hurdle:SetAttribute(player.Name, true)
    end
 

end

function module:SpawnHurdle()
    local hurdles = Hurdles:GetChildren()

        local hurdle: Model = hurdles[math.random(1, #hurdles)]:Clone()

        local orientation = self.Game.JumpSpawn.Orientation
        local startPosition = self.Game.JumpSpawn.Position
        local endPosition = self.Game.JumpEndPosition.Position
        if string.match(hurdle.Name,"Duck") then
            startPosition = self.Game.DuckSpawn.Position
            endPosition = self.Game.DuckEndPosition.Position
        end
        hurdle:PivotTo((CFrame.new() + startPosition)*CFrame.Angles(math.rad(orientation.X),math.rad(orientation.Y),math.rad(orientation.Z)))
        
        hurdle.Parent = self.Game

        -- touch (damage)
        hurdle.HitBox.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then
               self:HitHurdle(player, hurdle)
            end
        end)
        --[[
        task.spawn(function()
        while true do
            task.wait()
            hurdle.PrimaryPart.Position += Vector3.new(0,0,.2)
        end
        end)
        --]]
        tweenPivot(hurdle, CFrame.new(endPosition ) *CFrame.Angles(math.rad(orientation.X),math.rad(orientation.Y),math.rad(orientation.Z)) ,5)
end

function module:Destroy()
    --clean up
    task.cancel(self.ElapsedTimeThread)
    task.cancel(self.HurdleThread)
    self.Game:Destroy()
    self = nil
end

return module