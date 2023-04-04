--[[
    CharacterController.lua
    Author: Aaron (se_yai)

    Description: Manage character state
]]
local LocalPlayer = game.Players.LocalPlayer
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local Modules = PlayerScripts:WaitForChild("PlayerModule")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Promisified = require(Shared.Promisified)
local AnimationPlayer = require(Shared.AnimationPlayer)

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local WaitFor = require(Packages.WaitFor)

local CharacterController = Knit.CreateController { Name = "CharacterController" }

function CharacterController:PlayAnimation(trackName)
    assert(self._animationPlayer:GetTrack(trackName), "Could not find animation: " .. trackName)
    self._animationPlayer:StopAllTracks()
    task.wait()
    self._animationPlayer:PlayTrack(trackName)
end

function CharacterController:EnableControls(enable)
    if enable then
        Modules:Enable()
    else
        Modules:Disable()
    end
end

function CharacterController:KnitStart()
    LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", true)
        -- example: load animations using Promises
        WaitFor.Child(humanoid, "Animator"):andThen(function(animator) -- // Animator being available typically means character is loaded
            -- // do things after finding the Animator object like loading animations
        end):finally(function() -- // use Promises to ensure that this eventually happens
            self.CharacterAddedEvent:Fire(character) -- // fire when loading the character is complete
        end)
    end)
end


function CharacterController:KnitInit()
    self.CharacterAddedEvent = Signal.new() -- // Knit Controllers should connect to this event if the character is needed
end


return CharacterController