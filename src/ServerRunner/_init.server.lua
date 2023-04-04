require(game.ReplicatedStorage.Shared.Ragdoll.RagdollHandler)

-- create collision groups here
game:GetService("PhysicsService"):CreateCollisionGroup("Players")
game:GetService("PhysicsService"):CollisionGroupSetCollidable("Players", "Players", false)

local ServerStorage = game:GetService("ServerStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local ReplicatedTweenign = require(game:GetService("ReplicatedStorage").ReplicatedTweening)

Knit.AddServices(ServerStorage:WaitForChild("Services"))
Knit.Start():catch()
print('loaded knit server')