local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
-- Encode
--local StringOfYourTable = HttpsService:JSONEncode(YourTable)
-- Decode
--local Decode  =  HttpsService:JSONDecode(StringOfYourTable)

-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.MemoryClass
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.MemoryClass
local BubbleImage = GameExtras.Bubble
local PlayerRecitedEvent:RemoteEvent = GameExtras.PlayerRecited
local Ruler:Part = GameExtras.Ruler
local HealthBBGui:BillboardGui = GameExtras.HealthBBGui
local WrongTrackerBBGui:BillboardGui = GameExtras.WrongTrackerBBGui
-- game vars
local Directions = {"↑","↓","←","→"}
local upAnimation = Instance.new("Animation")
upAnimation.AnimationId = "rbxassetid://13073136027"
local leftAnimation = Instance.new("Animation")
leftAnimation.AnimationId = "rbxassetid://13073144158"
local rightAnimation = Instance.new("Animation")
rightAnimation.AnimationId = "rbxassetid://13073147548"
local downAnimation = Instance.new("Animation")
downAnimation.AnimationId = "rbxassetid://13073139581"
local hurtAnimation = Instance.new("Animation")
hurtAnimation.AnimationId = "rbxassetid://13073153646"
local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "rbxassetid://13073150848"
local ReciteWaitTime = 7

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
    self.Sequence = {}
    self.PlayerSequences = {}
    self.AnimationTracks = {}
    self.BlackBoardText = self.Game.Blackboard.board.SurfaceGui.Frame.TextLabel
    self.BubblesFrame = self.Game.Blackboard.board.SurfaceGui.Bubbles
    self.StopGame = false
    --self.TeacherText = self.Game.Teacher.Head.BillboardGui.TextLabel
    local messageData = {
        Message="",
        Timer=""
    }
   
    PlayerRecitedEvent.OnServerEvent:Connect(function(player, playerSequence)
            --store player's sequence 
            self.PlayerSequences[player.Name] = playerSequence
            
    end)
   
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Memorize and copy the teacher."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Game will Start in ..."
    self.CanJoin.Value = false-- it is now too late to join
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    local count = 3
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

    for i = 1, 3, 1 do
        local randomDirection = Directions[math.random(1,#Directions)]
        table.insert(self.Sequence,randomDirection)
    end

    for i = 1, 5, 1 do
        if self.StopGame == false then
            self:StartSequence()
       
            local tweenInfo = TweenInfo.new(ReciteWaitTime/2, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
            local clockTween:Tween = TweenService:Create(self.Game.Clock.TweenPart, tweenInfo, {CFrame = self.Game.Clock.TweenPart.CFrame * CFrame.Angles(0,0,math.rad(180))})
            clockTween:Play()
            clockTween.Completed:Connect(function()
                local clockTween2 = TweenService:Create(self.Game.Clock.TweenPart, tweenInfo, {CFrame = self.Game.Clock.TweenPart.CFrame * CFrame.Angles(0,0,math.rad(180))})
                clockTween2:Play()
            end)
            
            task.wait(ReciteWaitTime)
            Knit.GetService("MemoryClassService").Client.StopReciting:FireAll()
            self:CheckPlayerSequences()
        end
      
    end
   
    if self.StopGame == false then
        messageData.Timer = ""
        messageData.Message = self:GetWinner().Name .. " won!"
    
        self.Message.Value = HttpService:JSONEncode(messageData)

        task.wait(3)
        self.GameOver.Value = true
        Knit.GetService("MemoryClassService").Client.EndGame:FireAll(self.ActivePlayers)
    end
    
end
function module:RotatePlayers(towardsCamera)
    local direction = -1
    if towardsCamera then
        direction = 1
    end
    for _, player in ipairs(self.ActivePlayers) do
        player.Character.HumanoidRootPart.CFrame *= CFrame.Angles(0, math.rad(180 * direction), 0)
    end

end
function module:StopAnimationTracks(player, dontIdle)
    for _, dir in ipairs(Directions) do
        self.AnimationTracks[player.Name][dir]:Stop()
    end
    self.AnimationTracks[player.Name]["Hurt"]:Stop()
    if not dontIdle then
        self.AnimationTracks[player.Name]["Idle"]:Play()
    end
   
    task.wait(.2)
end

function module:PlayerIncorrect(player)
    print("Incorrect!")
    local newRuler = Ruler:Clone()
    newRuler.Parent = player.Character.HumanoidRootPart
    newRuler.Position = player.Character.HumanoidRootPart.Position + Vector3.new(0,4,0)
    local rulerTweenInfo = TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
    local rulerTweenUp:Tween = TweenService:Create(newRuler, rulerTweenInfo, {Orientation = Vector3.new(-60, 164.176, -89.998)})
    rulerTweenUp.Completed:Connect(function()
        
        local rulerTweenInfo2 = TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)
        local rulerTweenDown:Tween = TweenService:Create(newRuler, rulerTweenInfo2, {Orientation = Vector3.new(-90, 74.177, 0)})
        rulerTweenDown.Completed:Connect(function()
            task.spawn(function()
                local hitSound:Sound = newRuler.HitSound
                hitSound.Parent = player.Character.HumanoidRootPart
                hitSound:Play()
                self.AnimationTracks[player.Name]["Hurt"]:Play()
                task.spawn(function()
                    self.Players[player].Health -= 10
                    if self.Players[player].Health <= 0 then
                        table.remove(self.ActivePlayers,table.find(self.ActivePlayers,player))
                        MiniGameUtils.SpawnAroundPart(workspace.LobbySpawn, player.Character)
                        Knit.GetService("MiniGameService").Client.PlayerGotEliminated:Fire(player)
                        Knit.GetService("MemoryClassService").Client.PlayerGotEliminated:Fire(player)
                        self:StopAnimationTracks(player)
                        local healthBB = player.Character.Head:FindFirstChild("HealthBBGui")
                        local wrongTracker = player.Character.Head:FindFirstChild("WrongTrackerBBGui")
                        if healthBB then
                            healthBB:Destroy()
                        end
                        if wrongTracker then
                            wrongTracker:Destroy()
                        end
                        if #self.ActivePlayers <= 1 then
                            if self.ActivePlayers[1] then
                                print(self.ActivePlayers[1].Name .. " wins.")
                            end
                            self.StopGame = true
                            task.wait(3)
                            self.GameOver.Value = true
                            Knit.GetService("MemoryClassService").Client.EndGame:FireAll(self.ActivePlayers)
                        end
                    else
                        local healthBB = player.Character.Head.HealthBBGui
                        healthBB.Frame.ScaleMe.Size = UDim2.new(self.Players[player].Health/100,0,1,0)
                        healthBB.Frame.ScaleMe.BackgroundColor3 = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), self.Players[player].Health/100)

                        local wrongTracker = player.Character.Head.WrongTrackerBBGui
                        wrongTracker.Frame.TextLabel.Text = wrongTracker.Frame.TextLabel.Text .. "X "
                        wrongTracker.Enabled = true
                        healthBB.Enabled = true
                        --task.wait(1)
                        --healthBB.Enabled = false
                        --wrongTracker.Enabled = false
                    end
                    
                end)
                
                task.wait(hitSound.TimeLength)
                hitSound:Destroy()
            end)
            --task.wait(.)
            newRuler:Destroy()
        end)
        rulerTweenDown:Play()
    end)
    rulerTweenUp:Play()
end
function module:TurnOffAllHealthBars()
    for _, player in ipairs(self.ActivePlayers) do
        local healthBB = player.Character.Head:FindFirstChild("HealthBBGui")
        local wrongTracker = player.Character.Head:FindFirstChild("WrongTrackerBBGui")
        if healthBB then
            healthBB.Enabled = false
        end
        if wrongTracker then
            wrongTracker.Enabled = false
        end
    end
end
function module:CheckPlayerSequences()
    --self:ClearBubbles()
    --rotate players to camera
    self:RotatePlayers(true)
    task.wait(1)
    for i = 1, #self.Sequence, 1 do
        if self.StopGame == false then
             --self.TeacherText.Text = self.Sequence[i]
        for _, player in ipairs(self.ActivePlayers) do
            local playerSequence = self.PlayerSequences[player.Name]
            if playerSequence then
                if playerSequence[i] then
                   
                    --mirror these since we flip the camera to show the sequence
                    if playerSequence[i] == "←" then
                        self.AnimationTracks[player.Name]["→"]:Play()
                    elseif playerSequence[i] == "→" then
                        self.AnimationTracks[player.Name]["←"]:Play()

                     else
                        self.AnimationTracks[player.Name][playerSequence[i]]:Play()
                    end
                   

                    if self.Sequence[i] == playerSequence[i] then
                       --player correct
                    else
                        --player incorrect
                       self:PlayerIncorrect(player)
                    end
                else
                    --player didnt finish input, this is considered wrong
                    self:PlayerIncorrect(player)
                end
                
            end
        end
        task.wait(.75)
        for _, player in ipairs(self.ActivePlayers) do
            self:StopAnimationTracks(player)
        end
        end
       
        --self.TeacherText.Text = ""
        --task.wait(.2)
    end

    --rotate players to front
    self:RotatePlayers(false)

    --turn off health/wrong trackers
    self:TurnOffAllHealthBars()
end

function module:StartSequence()

    --clear player sequences
    self.PlayerSequences = {}
    for _, player in ipairs(self.ActivePlayers) do
        local wrongTracker = player.Character.Head.WrongTrackerBBGui
        wrongTracker.Frame.TextLabel.Text = ""
    end
    --add 1 to sequence
    local randomDirection = Directions[math.random(1,#Directions)]
    table.insert(self.Sequence,randomDirection)

    local messageData = {
        Message="",
        Timer=""
    }
    self.MessageTarget.Value = ""
    messageData.Message = "Remember this"
    self.Message.Value = HttpService:JSONEncode(messageData)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    for i = 1, #self.Sequence, 1 do
        self.BlackBoardText.Text = self.Sequence[i]
        self.BlackBoardText.Visible = true
        self.Game.Teacher.HumanoidRootPart.ShowDirection:Play()
        print(self.Sequence[i])
        task.wait(1)
        self.BlackBoardText.Visible = false
        task.wait(.2)
    end
    messageData.Message = "Enter the pattern"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.BlackBoardText.Text = ""
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)

    local newBubble = BubbleImage:Clone()
    newBubble.Name = "Bubble" .. #self.Sequence
    newBubble.Parent = self.BubblesFrame

    self.BubblesFrame.Visible = true
    Knit.GetService("MemoryClassService").Client.BeginReciting:FireAll(#self.Sequence)
    

end
function module:GetWinner()
    local winner = nil
    local highestHealth = 0
    print(self.ActivePlayers)
    for _, player in ipairs(self.ActivePlayers) do

       --turn on health to show
       player.Character.Head.HealthBBGui.Enabled = true
        if self.Players[player].Health > highestHealth then
            winner = player
            highestHealth = self.Players[player].Health
        end
    end
    return winner
end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        table.insert(self.ActivePlayers, player)
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Health = 100
        }
        self.Players[player] = data
        local spawn = self.Game.PlayerSpawns:FindFirstChild("Spawn"..#self.ActivePlayers)
        for _, child in spawn:GetChildren() do
            child.Transparency = 0
        end
       player.Character:SetPrimaryPartCFrame(CFrame.new(spawn.Spawn.Position + Vector3.new(0,3,0)))

       --set up animations
       local animator = player.Character.Humanoid:WaitForChild("Animator")
       self.AnimationTracks[player.Name] = {}
       self.AnimationTracks[player.Name]["↑"] = animator:LoadAnimation(upAnimation)
       self.AnimationTracks[player.Name]["↓"] = animator:LoadAnimation(downAnimation)
       self.AnimationTracks[player.Name]["←"] = animator:LoadAnimation(leftAnimation)
       self.AnimationTracks[player.Name]["→"] = animator:LoadAnimation(rightAnimation)
       self.AnimationTracks[player.Name]["Hurt"] = animator:LoadAnimation(hurtAnimation)
       self.AnimationTracks[player.Name]["Idle"] = animator:LoadAnimation(idleAnimation)

       --add health bar
       HealthBBGui:Clone().Parent = player.Character.Head

       --add wrong tracker
       WrongTrackerBBGui:Clone().Parent = player.Character.Head

        --send join event for camera controller
        Knit.GetService("MiniGameService").Client.PlayerJoinedMiniGame:Fire(player)
        Knit.GetService("MemoryClassService").Client.JoinedGame:Fire(player)

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