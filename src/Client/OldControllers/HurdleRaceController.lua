local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local knit = require(ReplicatedStorage.Packages.Knit)
local UI = ReplicatedStorage.Assets.UI.MiniGames.HurdleRace.HurdleRaceUI
local Extras = ReplicatedStorage.Assets.MiniGameExtras.HurdleRace
local HurdleHitSound = Extras.HurdleHitSound
local OpponentGuiImage = Extras.Opponent
local FalseStartSound = Extras.FalseStartSound
local IceBlock = Extras.Ice

local HurdleRaceController = knit.CreateController({
	Name = "HurdleRaceController",
})

local player = game:GetService("Players").LocalPlayer
local MaxSpeed = 100

function HurdleRaceController:KnitInit()
	--// services
	self.HurdleRaceService = knit.GetService("HurdleRaceService")

end

function HurdleRaceController:KnitStart()
    self.HurdleRaceService.JoinedGame:Connect(function(laneLength, lane)
		self:JoinedGame(laneLength, lane)
	end)
    self.HurdleRaceService.StartGame:Connect(function( players, randomStartTime)
		self:StartGame( players, randomStartTime)
	end)
    self.HurdleRaceService.EndGame:Connect(function()
		self:EndGame()
	end)
    self.HurdleRaceService.PlayerHitHurdle:Connect(function()
		self:HitHurdle()
	end)
   

end
function HurdleRaceController:JoinedGame(laneLength, lane)
    --set camera
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Attach
    camera.CFrame = CFrame.new(Vector3.new(54,11,111)) * CFrame.Angles(math.rad(-28.86),math.rad(-55.5),0)
    
    --lock input except jump
    self:LockInput(true)
    
    --add ui
     self.UI = UI:Clone()
     self.UI.Parent = game.Players.LocalPlayer.PlayerGui


     self.LaneLength = laneLength
     self.CurrentDistance = 0

     self.Lane = workspace.HurdleRace.Lanes:FindFirstChild("Lane"..lane)
     

end
function HurdleRaceController:StartGame(players, randomStartTime)
    self.ActivePlayers = players
    print(players)
    for _, opponent in ipairs(players) do
        if opponent.Name ~= player.Name then
            local newOpponentGui = OpponentGuiImage:Clone()
            newOpponentGui.Name = opponent.Name
            newOpponentGui.Parent = self.UI.RaceTrackerFrame.Frame
        end
       
    end

    local isRunning = false
    local canStart = false
    local isFrozen = false
    player = game:GetService("Players").LocalPlayer
    self.Humanoid = player.Character.Humanoid
    self.Humanoid.JumpHeight = 0

    self.StartRaceCheck = UIS.InputBegan:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.Space and not isRunning and not isFrozen then

            if canStart then
                --correct start
                self.UI.StopLight:Destroy()
                self.RunThread = game:GetService("RunService").RenderStepped:Connect(function()
                    local direction = (self.Lane.Finish.Position-player.Character.HumanoidRootPart.Position).unit
                    player:Move(direction)
                    
                end)
                isRunning = true
                task.wait(1)
                self.Humanoid.JumpHeight = 5.8
            else
                --false start
                print("false start, frozen for 2 seconds")
                FalseStartSound:Play()
                isFrozen = true
                local newIceBlock = IceBlock:Clone()
                newIceBlock.Parent = player.Character
                newIceBlock.Position = player.Character.HumanoidRootPart.Position
                --local iceTween = TweenService:Create(newIceBlock, TweenInfo.new(2), {Size = Vector3.new(newIceBlock.Size.X,0,newIceBlock.Size.Z),
                --                                                                 Position = Vector3.new(newIceBlock.Position.X, newIceBlock.Position.Y - newIceBlock.Size.Y, newIceBlock.Position.Z)})
                local iceTween = TweenService:Create(newIceBlock, TweenInfo.new(2), {Transparency = 1})
                iceTween.Completed:Connect(function()
                    newIceBlock:Destroy()
                end)
                iceTween:Play()
                task.wait(2)
                isFrozen = false

            end

            
           
           
        end
    end)

    task.wait(randomStartTime/3)
        self.UI.StopLight.Light1.ImageTransparency = 0
    task.wait(randomStartTime/3)
        self.UI.StopLight.Light2.ImageTransparency = 0
    task.wait(randomStartTime/3)
        self.UI.StopLight.Light3.ImageTransparency = 0

    canStart = true



    self.SpeedCheck = task.spawn(function()
        while true do
            task.wait()
            local animator:Animator = self.Humanoid:WaitForChild("Animator")
            for _, animation in pairs(animator:GetPlayingAnimationTracks()) do
                if animation.Name == "WalkAnim" or animation.Name == "RunAnim" or animation.Name == "IdleAnim" then
                    self.Humanoid.WalkSpeed += .05
                end
                if animation.Name == "JumpAnim" then
                    --air fruction
                    self.Humanoid.WalkSpeed -= .03
                end
            end
            
        end
    end)

    
    self.UIUpdate = task.spawn(function()
        self:UpdateUI()
    end)
    
end

function HurdleRaceController:UpdateUI()
    
    while true do
        task.wait()
        --speed ui
        self.UI.SpeedFrame.SpeedScale.Size = UDim2.new(1, 0, -(self.Humanoid.WalkSpeed / MaxSpeed), 0)
        self.UI.SpeedFrame.SpeedScale.BackgroundColor3 = Color3.new(1, 0, 0):Lerp(Color3.new(0, 1, 0), self.Humanoid.WalkSpeed / MaxSpeed)

        --calculate distance
        local currentDistance = (player.Character.HumanoidRootPart.Position - self.Lane.Start.Position).magnitude
        local distancePercent = (currentDistance/self.LaneLength)
        self.UI.RaceTrackerFrame.Frame.Player.Position = UDim2.new(distancePercent, self.UI.RaceTrackerFrame.Frame.Player.AbsoluteSize.X/2,0,0)

        for _, opponent in ipairs(self.ActivePlayers) do
            local opponentGuiImage = self.UI.RaceTrackerFrame.Frame:FindFirstChild(opponent.Name)
            if opponentGuiImage then
                local opponentDistance = (opponent.Character.HumanoidRootPart.Position - self.Lane.Start.Position).magnitude
                local opponentDistancePercent = (opponentDistance/self.LaneLength)
                opponentGuiImage.Position = UDim2.new(opponentDistancePercent, opponentGuiImage.AbsoluteSize.X/2,.28,0)
            end
          
        end

        --print("Race percent: " .. (currentDistance/self.LaneLength)*100)
    end
    
end

function HurdleRaceController:HitHurdle()
    --reduce speed
    local humanoid:Humanoid = player.Character.Humanoid
    humanoid.WalkSpeed -= 20
    --play sound
    if HurdleHitSound then
        HurdleHitSound:Play()
    end
end

function HurdleRaceController:LockInput(lock:boolean)

    local ContextActionService = game:GetService("ContextActionService")
    local FREEZE_ACTION = "freezeMovement"

    if lock then
        local nonJumpActions = {}
        for _, action in ipairs(Enum.PlayerActions:GetEnumItems()) do
            if action ~= Enum.PlayerActions.CharacterJump then
                table.insert(nonJumpActions, action)
            end
        end
        ContextActionService:BindAction(
            FREEZE_ACTION,
            function() return Enum.ContextActionResult.Sink end,
            false,
            unpack(nonJumpActions)
        )

    else
        ContextActionService:UnbindAction(FREEZE_ACTION)
    end
end

function HurdleRaceController:EndGame()

    --stop updates
    self.RunThread:Disconnect()
    task.cancel(self.SpeedCheck)
    task.cancel(self.UIUpdate)
    self.StartRaceCheck:Disconnect()

    --reset walk and jump values
    self.Humanoid.WalkSpeed = 16
    self.Humanoid.JumpHeight = 7.2

    --reset camera
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom

    --unlock input
    self:LockInput(false)

    --destroy ui
    self.UI:Destroy()

end

return HurdleRaceController