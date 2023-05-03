--[[
    SkyClimbers.luau
    Author: Justin (synnull)
    Description: Client-sided stuff for SkyClimbers
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Template = ReplicatedStorage.Assets.UI.MiniGames.SkyClimbersUI


--extras
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.SkyClimbers
local PlayerLeaderboard = GameExtras.PlayerLeaderboard
local BezierTween = require(GameExtras.BezierTweens)
local Waypoints = BezierTween.Waypoints
local SentHeightEvent:RemoteEvent = GameExtras.SentHeightEvent


local jumpAnimation = Instance.new("Animation")
jumpAnimation.AnimationId = "rbxassetid://13073159238"
local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "rbxassetid://13073164321"
local fallAnimation = Instance.new("Animation")
fallAnimation.AnimationId = "rbxassetid://13073167290"


local ClimberControls = {
    Left = Enum.KeyCode.A,
    Right = Enum.KeyCode.D,
    LeftArrow = Enum.KeyCode.Left,
    RightArrow = Enum.KeyCode.Right
}


local module = {}

function module:Init(newJanitor)
    self:PrepGame()
    return "Sky cLimbers!", 
    "Jump as high as you can! Wait too long and platforms will fall beneath you.",
    "rbxassetid://12716822940"
end

function module:PrepGame()
    local player =  game.Players.LocalPlayer
    player.Character.HumanoidRootPart.Anchored = true
    self.CanJump = false
    self.CurrentPlatform = 0
     --set up animation
    local animator =  player.Character.Humanoid:WaitForChild("Animator")
    self.JumpAnimationTrack = animator:LoadAnimation(jumpAnimation)
    self.FallAnimationTrack = animator:LoadAnimation(fallAnimation)
    local fallAnim = player.Character.Animate.fall:FindFirstChild("FallAnim")
    if fallAnim then
        fallAnim.AnimationId = idleAnimation.AnimationId
    end

    self:DisableMovement()
   
    -- track height
   self.HeightTrackers = {}
end

function module:Start(janitor)
   print("START")
    -- create ui link
    local SkyClimbComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "SkyClimbComm")
    local StartGameEvent = SkyClimbComm:GetSignal("StartGameEvent")
    local JoinedGameEvent = SkyClimbComm:GetSignal("JoinedGameEvent")
    self.GUI = Template:Clone()
    self.GUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

   

    janitor:Add(JoinedGameEvent:Connect(function(laneLength, platformPoints)
        print("JOINED GAME")
       
        self.LaneLength = laneLength

        self.Lane = workspace.SkyClimbers.Lanes:FindFirstChild("Lane_".. game.Players.LocalPlayer.Name)

        self:TurnOnAdjacentBillboards()

        self.PlatformPoints = platformPoints
   

    end))

    janitor:Add(StartGameEvent:Connect(function(players)
       self:StartGame(players)
    end))


    --janitor:Add(GUI)
end
function module:StartGame(players)
    self.ActivePlayers = players
    local player = game:GetService("Players").LocalPlayer

    print(players)
    for _, opponent in players do
        --if opponent.Name ~= player.Name then
            local newOpponentGui = PlayerLeaderboard:Clone()
            newOpponentGui.Name = opponent.Name
            if opponent.Name == player.Name then
                newOpponentGui.Text = "YOU: 0m"
                newOpponentGui.TextColor3 = Color3.new(0.011764, 0.486274, 0.094117)
            else
                newOpponentGui.Text = opponent.Name .. ": 0m"
            end
           
            newOpponentGui.Parent = self.GUI.Frame

           local playerHeightTracker = opponent.Character.HumanoidRootPart:GetPropertyChangedSignal("Position"):Connect(function()
                local playerLane = workspace.SkyClimbers.Lanes:FindFirstChild("Lane_"..opponent.Name)
                if playerLane then
                    local distance = math.floor(opponent.Character.HumanoidRootPart.Position.Y - playerLane.PlayerSpawn.Position.Y)
                    local playerUi = self.GUI.Frame:FindFirstChild(opponent.Name)
                    if playerUi then
                        playerUi.Text = opponent.Name .. ":" .. distance .. "m"
                    end
                    
                end
            end)
            table.insert(self.HeightTrackers, playerHeightTracker)
       -- end
       
    end

   
    self.Humanoid = player.Character.Humanoid
    self.CanJump = true
    self.GameOver = false
    self:TurnOnAdjacentBillboards()


end
function module:TurnOnAdjacentBillboards()
    local currentPlat = self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform)
    if currentPlat then
        local currentBB:BillboardGui = currentPlat:FindFirstChild("DirectionBB")
        if currentBB then
            currentBB.Enabled = false
        end
    end
  
    local nextPlat = self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform+1)
    if nextPlat then
        local nextBB:BillboardGui = nextPlat:FindFirstChild("DirectionBB")
        if nextBB then
            nextBB.Enabled = true
        end
    end
    local nextNextPlat = self.Lane.Platforms:FindFirstChild("Platform" .. self.CurrentPlatform+2)
    if nextNextPlat then
        local nextNextBB:BillboardGui = nextNextPlat:FindFirstChild("DirectionBB")
        if nextNextBB then
            nextNextBB.Enabled = true
        end
    end
   
   
   

end


function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Fall(side)
    local player = game.Players.LocalPlayer
    if self.PlatformPoints[self.CurrentPlatform] == side then
        local rootPart = player.Character.HumanoidRootPart
        self.JumpAnimationTrack:Play()
        local goalCFrame = CFrame.new(rootPart.Position + Vector3.new(0,3,0))
        local goal = {CFrame = goalCFrame}

        local tweeninfo =TweenInfo.new(.3,Enum.EasingStyle.Quad, Enum.EasingDirection.Out,0, true)
                local tween = TweenService:Create(rootPart, tweeninfo, goal)
        
        tween:Play()
        tween.Completed:Connect(function()
            SentHeightEvent:FireServer(player.Character.HumanoidRootPart.Position)
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
function module:MoveToPlatform(falling:boolean, platform:Part)
    local player = game.Players.LocalPlayer
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
    --player.Character:PivotTo(goalCFrame)
    tween:Play()
    tween.Completed:Connect(function()
        player.Character:PivotTo(goalCFrame)
        self.CanJump = true
        self.FallAnimationTrack:Stop()
        --player.Character:PivotTo(goalCFrame)
        SentHeightEvent:FireServer(player.Character.HumanoidRootPart.Position)
        self:TurnOnAdjacentBillboards()
    end)
--rootPart.Anchored = false


end

function module:SinkInput(actionName, inputState)
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
function module:DisableMovement()
    local player = game.Players.LocalPlayer
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
function module:EnableMovement()

    
    for Context, key in pairs(ClimberControls) do
        ContextActionService:UnbindAction("Override"..Context)
    end
    local fallAnim = game.Players.LocalPlayer.Character.Animate.fall:FindFirstChild("FallAnim")
	if fallAnim then
		fallAnim.AnimationId = "http://www.roblox.com/asset/?id=10921262864"
	end
end


function module:Destroy()
  --stop updates
  for _, thread in ipairs(self.HeightTrackers) do
    thread:Disconnect()
    end
    --reset camera
    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom
    local player = game.Players.LocalPlayer
    player.CameraMaxZoomDistance = self.OriginalMaxZoom
    player.CameraMinZoomDistance = self.OriginalMinZoom

    --unlock input
    self:EnableMovement()

end

return module