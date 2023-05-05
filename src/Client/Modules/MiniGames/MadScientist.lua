local module = {}
module.__index = module
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local HttpsService = game:GetService("HttpService")
local Template = ReplicatedStorage.Assets.UI.MiniGames.MadScientistUI
local Player = game:GetService("Players").LocalPlayer
local UI = Player:WaitForChild("PlayerGui")

module.ID = script.Name
local ScientistControls = {
    Forward = Enum.KeyCode.W,
    Left = Enum.KeyCode.A,
    Back = Enum.KeyCode.S,
    Right = Enum.KeyCode.D,
    Jump = Enum.KeyCode.Space
}

function module:Init(newJanitor)
    print("Init")
    -- return display info
    return "Mad Scientist!",
    "The Mad Scientist is testing out their new Lasers! The rest are just trying to survive!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    print("Start")
    local MadScientistComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "MadScientistComm")
    local MadScientistCommEvent = MadScientistComm:GetSignal("MadScientistCommEvent")
    janitor:Add(MadScientistCommEvent:Connect(function(value)
        self:HandleMessage(value)
    end))
    self.GUI = Template:Clone()
    self.GUI.Parent = UI
    self.TitleBar = self.GUI.Frame.TitleBar
    self.Controls = self.GUI.Frame.Controls
    janitor:Add(self.GUI)
    self:DisableMovement()
    self.Event = MadScientistCommEvent
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
        if message == "Scientist" then
            self.Scientist = true
            self:DisableMovement()
            --[[self.Controls.Visible = true
            task.spawn(function()
                task.wait(10)
                self.Controls:Destroy()
            end)]]
        end
    end
end

function module:Destroy()
    if self.Scientist then
        self:EnableMovement()
    end
    self = nil
end

function module:SinkInput(actionName, inputState)
    local key = string.sub(actionName,9)

    --print(key,ScientistControls[key], inputState)
    if key ~= "Jump" then
        local message = {}
        message.Direction = key
        message.State = inputState
        --self.Controller:MessageServer(message)
        --print(message)
        self.Event:Fire(message)
    end

    return Enum.ContextActionResult.Sink
    -- Sinks the key so that no action is taken.
    -- Since this will be the most recent bind to the key, it takes priority over default movement.
end

-- Disables movement.
function module:DisableMovement()
    for Context, key in pairs(ScientistControls) do
        ContextActionService:BindAction("Override"..Context, function(actionName, inputState, inputObj)
            return self:SinkInput(actionName, inputState, inputObj)
        end, false,key)
    end
end

-- Unbinds our "disable movement" so that the default keybinds are activated.
function module:EnableMovement()
    for Context, key in pairs(ScientistControls) do
        ContextActionService:UnbindAction("Override"..Context)
    end
end

return module