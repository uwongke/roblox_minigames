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
local DuckCooldown = .2
local DuckJumpController = knit.CreateController({
	Name = "DuckJumpController",
})

local player = game:GetService("Players").LocalPlayer
local duckAnimation = Instance.new("Animation")
--duckAnimation.AnimationId = "rbxassetid://12635660851"  --crouch
--duckAnimation.AnimationId = "rbxassetid://12635704901"  --prone
duckAnimation.AnimationId = "rbxassetid://12707923089"

function DuckJumpController:KnitInit()
	--// services
	self.DuckJumpService = knit.GetService("DuckJumpService")

end

function DuckJumpController:KnitStart()
    self.DuckJumpService.JoinedGame:Connect(function()
		self:JoinedGame()
	end)
    self.DuckJumpService.EndGame:Connect(function()
		self:EndGame()
	end)
    self.DuckJumpService.Eliminated:Connect(function()
		self:LockInput(false)
	end)
   

end
function DuckJumpController:JoinedGame()
    print("joined game")
    --lock input except jump
    self:LockInput(true)
    self.CanDuck = true
    local animator = player.Character.Humanoid:WaitForChild("Animator")
    self.HitHurdleAnimationTrack = animator:LoadAnimation(duckAnimation)
    self.HitHurdleAnimationTrack:GetMarkerReachedSignal("can_duck"):Connect(function(paramString)
        task.wait(DuckCooldown)
        print("can duck")
        self.CanDuck = true
    end)

end


function DuckJumpController:LockInput(lock:boolean)

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

        self.CrouchCheck = UIS.InputBegan:Connect(function(input, typing)
            if typing then return end
            if input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.LeftControl  and self.CanDuck == true then
                --play animaiton
                self.HitHurdleAnimationTrack:Play()
                self.CanDuck = false

            end
            end)

    else
        ContextActionService:UnbindAction(FREEZE_ACTION)
        if self.CrouchCheck then
            self.CrouchCheck:Disconnect()
        end
    end
end

function DuckJumpController:EndGame()

    --unlock input
    self:LockInput(false)

    --destroy ui
    --self.UI:Destroy()

end

return DuckJumpController
