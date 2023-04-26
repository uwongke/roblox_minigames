local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local knit = require(ReplicatedStorage.Packages.Knit)

local MemoryClassController = knit.CreateController({
	Name = "MemoryClassController",
})

local player = game:GetService("Players").LocalPlayer
local upAnimation = Instance.new("Animation")
upAnimation.AnimationId = "rbxassetid://12884352932"
local leftAnimation = Instance.new("Animation")
leftAnimation.AnimationId = "rbxassetid://12884440855"
local rightAnimation = Instance.new("Animation")
rightAnimation.AnimationId = "rbxassetid://12884475081"
local downAnimation = Instance.new("Animation")
downAnimation.AnimationId = "rbxassetid://12884503461"
local idleAnimation = Instance.new("Animation")
idleAnimation.AnimationId = "rbxassetid://12928571428"

local MiniGameExtras = ReplicatedStorage.Assets.MiniGameExtras.MemoryClass
local PlayerRecitedEvent:RemoteEvent = MiniGameExtras.PlayerRecited

function MemoryClassController:KnitInit()
	--// services
	self.MemoryClassService = knit.GetService("MemoryClassService")

end

function MemoryClassController:KnitStart()
    self.MemoryClassService.JoinedGame:Connect(function()
		self:JoinedGame()
	end)
    self.MemoryClassService.BeginReciting:Connect(function(sequenceLength)
        self.Sequence = {}
        self.SentSequence = false
        self.SequenceLength = sequenceLength
		self.CanRecite = true
        self.BubblesFrame.Visible = true
        
	end)
    self.MemoryClassService.StopReciting:Connect(function()
        --if player hasn't sent the full squence in time, send what they have
        if not self.SentSequence then
            self.CanRecite = false
            self:StopAnimationTracks()
            PlayerRecitedEvent:FireServer(self.Sequence)
            self.SentSequence = true
        end
		self:ClearBubbles()

	end)

    self.MemoryClassService.EndGame:Connect(function()
        self:EndGame()
    end)
    self.MemoryClassService.PlayerGotEliminated:Connect(function()
        self:EndGame()
    end)
    

end
function MemoryClassController:JoinedGame()
    -- set up animations
    self:LockInput(true)
   
    self.BubblesFrame = workspace.MemoryClass.Blackboard.board.SurfaceGui.Bubbles
    self.CanRecite = false
    local animator = player.Character.Humanoid:WaitForChild("Animator")
    self.Sequence = {}
    
    self.UpAnimationTrack = animator:LoadAnimation(upAnimation)
    self.DownAnimationTrack = animator:LoadAnimation(downAnimation)
    self.LeftAnimationTrack = animator:LoadAnimation(leftAnimation)
    self.RightAnimationTrack = animator:LoadAnimation(rightAnimation)
    self.IdleAnimationTrack = animator:LoadAnimation(idleAnimation)
    self.Tracks = { self.UpAnimationTrack, self.DownAnimationTrack, self.RightAnimationTrack, self.LeftAnimationTrack, self.IdleAnimationTrack}
    self.IdleAnimationTrack:Play()
end

function MemoryClassController:FillBubble()
    local bubble = self.BubblesFrame:FindFirstChild("Bubble" .. #self.Sequence)
    if not bubble then return end
    bubble.ImageColor3 = Color3.new(0, 0, 0)

end
function MemoryClassController:LockInput(lock:boolean)

    local ContextActionService = game:GetService("ContextActionService")
    local FREEZE_ACTION = "freezeMovement"

    if lock then
        local nonJumpActions = {}
        for _, action in ipairs(Enum.PlayerActions:GetEnumItems()) do
            if action == Enum.PlayerActions.CharacterJump then
                table.insert(nonJumpActions, action)
            end
        end
        ContextActionService:BindAction(
            FREEZE_ACTION,
            function() return Enum.ContextActionResult.Sink end,
            false,
            unpack(nonJumpActions)
        )
        local animator:Animator = player.Character.Humanoid:WaitForChild("Animator")
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            track:Stop()
        end
        task.wait()
        player.Character.HumanoidRootPart.Anchored = true;

        self.InputCheck = UIS.InputBegan:Connect(function(input, typing)
            if typing then return end
            if input.KeyCode == Enum.KeyCode.W and self.CanRecite == true then
                --play animaiton
               
                table.insert(self.Sequence, "↑")
                self:StopAnimationTracks()
                self:FillBubble()
                self.UpAnimationTrack:Play()
                
            end
            if input.KeyCode == Enum.KeyCode.S and self.CanRecite == true then
                --play animaiton
                table.insert(self.Sequence, "↓")
                self:StopAnimationTracks()
                self:FillBubble()
                self.DownAnimationTrack:Play()
                
            end
            if input.KeyCode == Enum.KeyCode.A and self.CanRecite == true then
                --play animaiton
                table.insert(self.Sequence, "←")
                self:StopAnimationTracks()
                self:FillBubble()
                self.LeftAnimationTrack:Play()
            end
            if input.KeyCode == Enum.KeyCode.D and self.CanRecite == true then
                --play animaiton
                table.insert(self.Sequence, "→")
                self:StopAnimationTracks()
                self:FillBubble()
                self.RightAnimationTrack:Play()
            end
            if input.KeyCode == Enum.KeyCode.I and self.CanRecite == true then
                self:StopAnimationTracks()
                self.IdleAnimationTrack:Play()
            end

            
            end)
            self.InputUpCheck = UIS.InputEnded:Connect(function(input, typing)
                if typing then return end
                if (input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D or
                input.KeyCode == Enum.KeyCode.A) and self.CanRecite == true then
                    --play animaiton
                    self:StopAnimationTracks()
                    self.IdleAnimationTrack:Play()
                    
                end
                if #self.Sequence == self.SequenceLength then
                    task.wait(.2)
                    self.CanRecite = false
                    self.SentSequence = true
                    PlayerRecitedEvent:FireServer(self.Sequence)
                end
                end)

    else
        ContextActionService:UnbindAction(FREEZE_ACTION)
        if self.InputCheck then
            self.InputCheck:Disconnect()
        end
        if self.InputUpCheck then
            self.InputUpCheck:Disconnect()
        end
        local animator:Animator = player.Character.Humanoid:WaitForChild("Animator")
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            track:Stop()
        end
        player.Character.HumanoidRootPart.Anchored = false;
    end
end
function MemoryClassController:ClearBubbles()
    self.BubblesFrame.Visible = false
    for _, bubble in ipairs(self.BubblesFrame:GetChildren()) do
        if bubble:IsA("ImageLabel") then
            bubble.ImageColor3 = Color3.new(1, 1, 1)
        end
    end
end
function MemoryClassController:StopAnimationTracks()
   
    for _, track:AnimationTrack in ipairs(self.Tracks) do
        track:Stop()
    end
    --self.IdleAnimationTrack:Play()
    --task.wait()
end
function MemoryClassController:EndGame()

    --print("End game")
    --stop animations
    self:StopAnimationTracks()
    --unlock input
    self:LockInput(false)

    local camera = workspace.CurrentCamera
    camera.CameraSubject = game.Players.LocalPlayer.Character.Humanoid
    camera.CameraType = Enum.CameraType.Custom

    --stop input check
    --self.InputCheck:Disconnect()

    --destroy ui
    --self.UI:Destroy()

end

return MemoryClassController