--[[
    NewFishingHero.luau
    Author: Aaron Jay (seyai)
    Description: Client-sided info for NewFishingHero under the new minigame engine
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Template = ReplicatedStorage.Assets.UI.MiniGames.NewFishingHeroUI

local module = {}

function module:Init(newJanitor)
    -- return display info
    return "Fishing Hero!", 
    "When a rod hooks a fish, run up to and reel it in before it gets away! Different fish give you different points. Get the most points to win!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    -- create ui link
    local FishComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "FishComm")
    local CaughtFishEvent = FishComm:GetSignal("CaughtFishEvent")

    local GUI = Template:Clone()
    GUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    janitor:Add(CaughtFishEvent:Connect(function(value)
        GUI.Score.Text = "Score: " .. tostring(value)
    end))
    GUI.Score.Text = "Score: 0"
    janitor:Add(GUI)
end

function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Destroy()
    -- no need for external clean up
end

return module