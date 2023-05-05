local module = {}
module.__index = module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local HttpsService = game:GetService("HttpService")
local Template = ReplicatedStorage.Assets.UI.MiniGames.WackAMoleUI
local Player = game:GetService("Players").LocalPlayer
local UI = Player:WaitForChild("PlayerGui")

function module:Init(newJanitor)
    -- return display info
    return "Petty Neighbors",
    "The team with the least amount of trash on their side of the fence wins!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    -- create ui link
    local PettyNeighborsComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "PettyNeighborsComm")
    local PettyNeighborsCommEvent = PettyNeighborsComm:GetSignal("PettyNeighborsCommEvent")

    -- create score display
    self.GUI = Template:Clone()
    self.GUI.Parent = UI
    self.TitleBar = self.GUI.Frame.TitleBar
    janitor:Add(PettyNeighborsCommEvent:Connect(function(value)
        self:HandleMessage(value)
    end))
    janitor:Add(self.GUI)
end

function module:HandleMessage(message)
    self.TitleBar:WaitForChild("Message")
    if message:find("{") then
        local data = HttpsService:JSONDecode(message)
        --print(data)
        for key, val in pairs(data) do
            local textField = self.TitleBar:FindFirstChild(key)
            if textField then
                textField.Visible = val ~= ""
                textField.Text = val
            end
        end
    end
end

function module:Destroy()
    self = nil
end

return module