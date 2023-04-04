local Players = game:GetService("Players")
local LocalPlayer = game.Players.LocalPlayer
require(game.ReplicatedStorage.Shared.Ragdoll.RagdollHandler)
-- set camera
-- workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

require(game:GetService("ReplicatedStorage").ReplicatedTweening)

local Player = game.Players.LocalPlayer
local PlayerScripts = Player:WaitForChild("PlayerScripts")

local Knit = require(game.ReplicatedStorage.Packages.Knit)

Knit.AddControllers(PlayerScripts:WaitForChild("Controllers"))
-- load interfaces
-- Knit.AddControllers(PlayerScripts.Controllers:WaitForChild("Interface"))
if PlayerScripts:FindFirstChild("Components") then
    for _, component in PlayerScripts.Components:GetChildren() do
        require(component)
    end
end

print("added knit controllers")
Knit.Start():catch()
print("loaded knit client")