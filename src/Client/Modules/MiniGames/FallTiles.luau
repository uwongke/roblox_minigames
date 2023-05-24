--[[
    FallTiles.luau
    Author: Justin Kelly (Synnull)
    Description: Client-sided info for FallTiles under the new minigame engine
]]
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Template = ReplicatedStorage.Assets.UI.MiniGames.FallTilesUI

local module = {}
module.__index = module

local previousJump = tick()
local hasDived = false
local triggerStandUp = false

local diveAnimation = Instance.new("Animation")
diveAnimation.AnimationId = "rbxassetid://13527872261"



local TIME_TO_GET_UP = .5
local DIVE_POWER = 45

function module:Init(newJanitor)
    self:PrepGame()
    -- return display info
    return "Fall Tiles!",
    "Keep moving! Touching a tile will cause it to disappear. Be the last player alive.",
    "rbxassetid://12716822940"
end

function module:PrepGame()
    --load animations
    local player =  game.Players.LocalPlayer
    local animator =  player.Character.Humanoid:WaitForChild("Animator")
    self.DiveAnimationTrack = animator:LoadAnimation(diveAnimation)
end

function module:Dive()
    local character = game.Players.LocalPlayer.Character
    local humanoid = character.Humanoid
    if tick() - previousJump >= .2 then
        if humanoid:GetState() == Enum.HumanoidStateType.Freefall and not hasDived then
            hasDived = true
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(4,.1,4) * 10000
            bodyVelocity.Velocity = character.HumanoidRootPart.CFrame.LookVector * DIVE_POWER
            bodyVelocity.Parent = character.HumanoidRootPart
            self.DiveAnimationTrack:Play()
            self:LockInput(true)
            for i = 1, 5, 1 do
                task.wait(.1)
                bodyVelocity.Velocity *= .7
            end
            bodyVelocity:Destroy()
        end
    end
end
function module:Start(janitor)

    -- create ui link
    local FallTileComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "FallTileComm")
    local PlayerEliminatedEvent = FallTileComm:GetSignal("PlayerEliminatedEvent")
    local StartGameEvent = FallTileComm:GetSignal("StartGameEvent")
    -- create score display
    local GUI = Template:Clone()
    GUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    janitor:Add(PlayerEliminatedEvent:Connect(function(value)
        GUI.Frame.PlayersLeft.Text = value .. " / " .. self.TotalPlayers
        self.TotalPlayers = value
    end))
    janitor:Add(StartGameEvent:Connect(function(value)
        print(value)
        GUI.Frame.PlayersLeft.Text = value .. " / " .. value
        self.TotalPlayers = value
    end))
    janitor:Add(GUI)

    local character = game.Players.LocalPlayer.Character
    local humanoid = character.Humanoid

    --check for dive state
    humanoid.StateChanged:Connect(function(old, new)
        if new == Enum.HumanoidStateType.Landed then
            --hasDived = false
        elseif new == Enum.HumanoidStateType.Jumping then
            previousJump = tick()
        end
    end)
    --this lets player dive
    UserInputService.JumpRequest:Connect(function()
        self:Dive()
    end)

    --this lets player stand back up
    local hitBox = character.HumanoidRootPart:WaitForChild("FallTiles_HitBox")
    hitBox.Touched:Connect(function(otherPart)
        if CollectionService:HasTag(otherPart, "DisappearingPlatform") and triggerStandUp == false and hasDived == true then
            triggerStandUp = true
            task.spawn(function()
                task.wait(TIME_TO_GET_UP)
                self.DiveAnimationTrack:Stop()
                self:LockInput(false)
                triggerStandUp = false
                hasDived = false
            end)
          
        end
    end)
end



function module:LockInput(lock:boolean)

    --[[
    local ContextActionService = game:GetService("ContextActionService")
    local FREEZE_ACTION = "freezeMovement"

    if lock then
        local actions = {}
        for _, action in ipairs(Enum.PlayerActions:GetEnumItems()) do
            table.insert(actions, action)
        end
        ContextActionService:BindAction(
            FREEZE_ACTION,
            function() return Enum.ContextActionResult.Sink end,
            false,
            unpack(actions)
        )
    else
        ContextActionService:UnbindAction(FREEZE_ACTION)
    end
    ]]--#region
    local humanoid = game.Players.LocalPlayer.Character.Humanoid
    if lock then
        humanoid.WalkSpeed = 0
        humanoid.JumpHeight = 0
    else
        humanoid.WalkSpeed = 16
        humanoid.JumpHeight = 7.2
    end
end


function module:Destroy()
    self = nil
end

return module