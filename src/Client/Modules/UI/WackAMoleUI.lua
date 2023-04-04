local module = {}
module.__index = module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpsService = game:GetService("HttpService")
local Template = ReplicatedStorage.Assets.UI.MiniGames.WackAMoleUI
local Player = game:GetService("Players").LocalPlayer
local UI = Player:WaitForChild("PlayerGui")
module.ID = script.Name

function module.new()
    local ui = {}
    ui.ID = module.ID
    ui.GUI = Template:Clone()
    ui.GUI.Parent = UI
    ui.TitleBar = ui.GUI.Frame.TitleBar
    setmetatable(ui,module)
    return ui
end

function module:Reset()
    for _, child in pairs(self.TitleBar:GetChildren()) do
        child.Visible = false
    end
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
        self.TitleBar.Message.Visible = message ~= ""
        self.TitleBar.Message.Text = message
    end
end

function module:Destroy()
    self.GUI:Destroy()
    self = nil
end

return module