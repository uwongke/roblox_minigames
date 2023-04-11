local module = {}
module.__index = module
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

function module.new(controller)
    local ui = {}
    ui.Controller = controller
    ui.ID = module.ID
    ui.GUI = Template:Clone()
    ui.GUI.Parent = UI
    ui.TitleBar = ui.GUI.Frame.TitleBar
    ui.Controls = ui.GUI.Frame.Controls
    setmetatable(ui,module)
    return ui
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
            self.Controls.Visible = true
            task.spawn(function()
                task.wait(6)
                self.Controls:Destroy()
            end)
        end
    end
end

function module:Destroy()
    if self.Scientist then
        self:EnableMovement()
    end
    self.GUI:Destroy()
    self = nil
end

function module:SinkInput(actionName, inputState)
    local key = string.sub(actionName,9)

    --print(key,ScientistControls[key], inputState)
    if key ~= "Jump" then
        local message = {}
        message.Direction = key
        message.State = inputState
        self.Controller:MessageServer(message)
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