--[[
    CharacterController.lua
    Author: Justin (synnull)

    Description: Manage camera
]]
local LocalPlayer = game.Players.LocalPlayer
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local Modules = PlayerScripts:WaitForChild("PlayerModule")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Promisified = require(Shared.Promisified)
local AnimationPlayer = require(Shared.AnimationPlayer)

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Signal = require(Packages.Signal)
local WaitFor = require(Packages.WaitFor)


local CameraController = Knit.CreateController { Name = "CameraController" }

function CameraController:KnitStart()
    self.MiniGameService.PlayerJoinedMiniGame:Connect(function()
		self.MiniGameService:GetCurrentGame():andThen(function(game)
            if game.Game:FindFirstChild("FixedCameraTarget") then
                local camera = workspace.CurrentCamera
                local orientation = game.Game.FixedCameraPosition.Orientation
                local newCameraCFrame = CFrame.new(game.Game.FixedCameraPosition.Position)
                newCameraCFrame= CFrame.lookAt(game.Game.FixedCameraPosition.Position, game.Game.FixedCameraTarget.Position)
                --tween instead of setting the camera instantly
                local cameraTween:Tween = TweenService:Create(camera,TweenInfo.new(2), {CFrame = newCameraCFrame})
                camera.CameraSubject = game.Game.FixedCameraTarget
                camera.CameraType = Enum.CameraType.Scriptable
                cameraTween:Play()
            
                end
	    end)
    end)
    self.MiniGameService.PlayerGotEliminated:Connect(function(resetCamera)
        if resetCamera == true then
            local camera = workspace.CurrentCamera
            camera.CameraSubject = game.Players.LocalPlayer.Character.Humanoid
            camera.CameraType = Enum.CameraType.Custom
        end
    end)
end


function CameraController:KnitInit()
    self.MiniGameService = Knit.GetService("MiniGameService")
end


return CameraController