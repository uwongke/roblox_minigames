local module = {}
module.__index = module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local HttpsService = game:GetService("HttpService")
local Template = ReplicatedStorage.Assets.UI.MiniGames.WackAMoleUI
local Player = game:GetService("Players").LocalPlayer
local UI = Player:WaitForChild("PlayerGui")
local controls = require(Player.PlayerScripts.PlayerModule):GetControls()
module.ID = script.Name

function module:Init(newJanitor)
    -- return display info
    return "Whack-A-Mole!",
    "Work together to whack moles that pop up before they hide back away! Different moles give you different points. Get the most points to win!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    -- create ui link
    local MoleComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "MoleComm")
    local WhackMoleEvent = MoleComm:GetSignal("WhackMoleEvent")

    -- create score display
    self.GUI = Template:Clone()
    self.GUI.Parent = UI
    self.TitleBar = self.GUI.Frame.TitleBar
    janitor:Add(WhackMoleEvent:Connect(function(value)
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
    else
        if message == "Enable" then
            controls:Enable()
        else
            if message == "Disable" then
                controls:Disable()
            end
        end
    end
end

function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Destroy()
    -- no need for external clean up
end

return module