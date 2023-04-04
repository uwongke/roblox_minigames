local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local knit = require(ReplicatedStorage.Packages.Knit)
local UI = ReplicatedStorage.Assets.UI.MiniGames.SkyClimbers.SkyClimbersUI
local Extras = ReplicatedStorage.Assets.MiniGameExtras.SkyClimbers
local BezierTween = require(Extras.BezierTweens)
local Waypoints = BezierTween.Waypoints

local SentHeightEvent:RemoteEvent = Extras.SentHeightEvent

local jumpAnimation = Instance.new("Animation")
jumpAnimation.AnimationId = "rbxassetid://12784752964"
local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "rbxassetid://12784778843"
local fallAnimation = Instance.new("Animation")
fallAnimation.AnimationId = "rbxassetid://12786901163"

local ClimberControls = {
    Left = Enum.KeyCode.A,
    Right = Enum.KeyCode.D,
    LeftArrow = Enum.KeyCode.Left,
    RightArrow = Enum.KeyCode.Right
}
local SkyClimbersController = knit.CreateController({
	Name = "SkyClimbersController",
})

local player = game:GetService("Players").LocalPlayer


function SkyClimbersController:KnitInit()
	--// services
	self.SkyClimbersService = knit.GetService("SkyClimbersService")

end

function SkyClimbersController:KnitStart()
    self.GameOver = false
    self.SkyClimbersService.JoinedGame:Connect(function(laneLength, lane, platformPoints)
		self:JoinedGame(laneLength, lane, platformPoints)
	end)
    self.SkyClimbersService.StartGame:Connect(function( players)
		self:StartGame( players)
	end)
    self.SkyClimbersService.StopJumping:Connect(function()
		self.GameOver = true
        SentHeightEvent:FireServer(player.Character.HumanoidRootPart.Position)
	end)

    self.SkyClimbersService.EndGame:Connect(function()
		self:EndGame()
	end)

   

end
function SkyClimbersController:JoinedGame(laneLength, lane, platformPoints)
   
    
    self.CanJump = false
    self.CurrentPlatform = 0
    --add ui
     self.UI = UI:Clone()
     self.UI.Parent = game.Players.LocalPlayer.PlayerGui


    --set up animation
    local animator = player.Character.Humanoid:WaitForChild("Animator")
    self.JumpAnimationTrack = animator:LoadAnimation(jumpAnimation)
    self.FallAnimationTrack = animator:LoadAnimation(fallAnimation)
    --self.IdleAnimationTrack = animator:LoadAnimation(idleAnimation)
    local fallAnim = player.Character.Animate.fall:FindFirstChild("FallAnim")
	if fallAnim then
		fallAnim.AnimationId = idleAnimation.AnimationId
	end

     self.LaneLength = laneLength

     self.Lane = workspace.SkyClimbers.Lanes:FindFirstChild("Lane"..lane)

     self.PlatformPoints = platformPoints

    self:DisableMovement()

    -- track height
    self.HeightTracker = player.Character.HumanoidRootPart:GetPropertyChangedSignal("Position"):Connect(function()
        local distance = math.floor(player.Character.HumanoidRootPart.Position.Y - self.Lane.PlayerSpawn.Position.Y)
        self.UI.Frame.TextLabel.Text = distance .. "m"
    end)
        
    
   
     

end
function SkyClimbersController:StartGame(players)
    self.ActivePlayers = players
    --[[
    for _, opponent in ipairs(players) do
        if opponent.Name ~= player.Name then
            local newOpponentGui = OpponentGuiImage:Clone()
            newOpponentGui.Name = opponent.Name
            newOpponentGui.Parent = self.UI.RaceTrackerFrame.Frame
        end
       
    end
    ]]--

    player = game:GetService("Players").LocalPlayer
    self.Humanoid = player.Character.Humanoid
    self.CanJump = true
    self.GameOver = false


end

function SkyClimbersController:Fall(side)
    if self.PlatformPoints[self.CurrentPlatform] == side then
        local rootPart = player.Character.HumanoidRootPart
        self.JumpAnimationTrack:Play()
        local goalCFrame = CFrame.new(rootPart.Position + Vector3.new(0,3,0))
        local goal = {CFrame = goalCFrame}

        local tweeninfo =TweenInfo.new(.3,Enum.EasingStyle.Quad, Enum.EasingDirection.Out,0, true)
                local tween = TweenService:Create(rootPart, tweeninfo, goal)
        
        tween:Play()
        tween.Completed:Connect(function()
            self.CanJump = true
        end)
        return
    end

    for i = self.CurrentPlatform, 0, -1 do
        if self.PlatformPoints[i] == side then
            self.CurrentPlatform = i
            local fallToPlatform = self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform)
            --if side == "L" then
                local rootPart = player.Character.HumanoidRootPart
                local goalCFrame = CFrame.new(Vector3.new(fallToPlatform.Position.X,rootPart.Position.Y,fallToPlatform.Position.Z))
                local goal = {CFrame = goalCFrame}
        
                local tweeninfo =TweenInfo.new(.3,Enum.EasingStyle.Quad, Enum.EasingDirection.Out,0, false)
                        local tween = TweenService:Create(rootPart, tweeninfo, goal)
                
                tween:Play()
                tween.Completed:Connect(function()
                    task.wait(.4)
                    self:MoveToPlatform(true, fallToPlatform)
                end)
            --end

            
            return
        end
    end
    self.CurrentPlatform = 0
end
function SkyClimbersController:MoveToPlatform(falling:boolean, platform:Part)
    local offset:Vector3 = Vector3.new(0,3,0)
    local tweenTime = .2
if not falling then
    --play jump animation
    self.JumpAnimationTrack:Play()
    
else
    --play fall animation
    self.FallAnimationTrack:Play()
    --slow tween as punishment
    tweenTime = .4
end

local rootPart = player.Character.HumanoidRootPart
local goalCFrame = CFrame.new(platform.Position + offset)
local goal = {CFrame = goalCFrame}

local tweeninfo =TweenInfo.new(tweenTime)

local tween = TweenService:Create(rootPart, tweeninfo, goal)

tween:Play()
tween.Completed:Connect(function()
    self.CanJump = true
    self.FallAnimationTrack:Stop()
end)
--rootPart.Anchored = false


end
function SkyClimbersController:SinkInput(actionName, inputState)
    if inputState == Enum.UserInputState.Begin then
        local key = string.sub(actionName,9)

        --print(key,ScientistControls[key], inputState)
        if self.CanJump and not self.GameOver then
            if key == "Left" then
                self.CanJump = false
                if self.PlatformPoints[self.CurrentPlatform+1] == "L" then
                    self.CurrentPlatform += 1
                    self:MoveToPlatform(false,self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform))
                    
                else
                    self:Fall("L")
                end
            end

            if key == "Right" then
                self.CanJump = false
                  if self.PlatformPoints[self.CurrentPlatform+1] == "R" then
                    self.CurrentPlatform += 1
                    self:MoveToPlatform(false,self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform))
                else
                    self:Fall("R")
                end
            end
        
        
        return Enum.ContextActionResult.Sink
        end
    end
    
    return Enum.ContextActionResult.Sink
    -- Sinks the key so that no action is taken.
    -- Since this will be the most recent bind to the key, it takes priority over default movement.
end

-- Disables movement.
function SkyClimbersController:DisableMovement()

   
    --player.Character.HumanoidRootPart.CFrame *= CFrame.Angles(0,math.rad(180),0)
     --set camera
     local cameraPart:Part = Instance.new("Part")
     local camera = workspace.CurrentCamera
     camera.CameraType = Enum.CameraType.Attach
     self.OriginalMinZoom = player.CameraMinZoomDistance
     self.OriginalMaxZoom = player.CameraMaxZoomDistance
     player.CameraMinZoomDistance = 30
     player.CameraMaxZoomDistance = 30
     --camera.CFrame = CFrame.new(Vector3.new(54,11,111)) * CFrame.Angles(math.rad(-28.86),math.rad(-55.5),0)


    for Context, key in pairs(ClimberControls) do
        ContextActionService:BindAction("Override"..Context, function(actionName, inputState, inputObj)
            return self:SinkInput(actionName, inputState, inputObj)
        end, false,key)
    end
    
end
-- Unbinds our "disable movement" so that the default keybinds are activated.
function SkyClimbersController:EnableMovement()

    
    for Context, key in pairs(ClimberControls) do
        ContextActionService:UnbindAction("Override"..Context)
    end
    local fallAnim = player.Character.Animate.fall:FindFirstChild("FallAnim")
	if fallAnim then
		fallAnim.AnimationId = "http://www.roblox.com/asset/?id=10921262864"
	end
end
function SkyClimbersController:EndGame()

    --stop updates
    self.HeightTracker:Disconnect()

    --reset camera
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom

    player.CameraMaxZoomDistance = self.OriginalMaxZoom
    player.CameraMinZoomDistance = self.OriginalMinZoom
   

    --unlock input
    self:EnableMovement()

    --destroy ui
    self.UI:Destroy()

end

return SkyClimbersController