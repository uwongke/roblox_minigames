local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local Template = ReplicatedStorage.Assets.UI.MiniGames.FishingHeroUI
local module = {}
module.__index = module

function module.new(self)
    -- create ui link
    local data = {}
    data.FishComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "FishComm")
    data.CaughtFishEvent = data.FishComm:GetSignal("CaughtFishEvent")

    data.GUI = Template:Clone()
    data.GUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    data.CaughtFishEvent:Connect(function(value)
        data.GUI.Score.Text = tostring(value)
    end)

    setmetatable(data, module)
    return data
end

function module:HandleMessage()
end

function module:Destroy()
    self.FishComm:Destroy()
    self.GUI:Destroy()
end

return module