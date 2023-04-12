local module = {}
module.__index = module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpsService = game:GetService("HttpService")
local Template = ReplicatedStorage.Assets.UI.MiniGames.DefaultUI
local Player = game:GetService("Players").LocalPlayer
local UI = Player:WaitForChild("PlayerGui")
local playerScripts = Player:WaitForChild("PlayerScripts")
local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
local movementController = playerModule:GetControls()
module.ID = script.Name
local cam = workspace.CurrentCamera
local offset = Vector3.new(0,1,3)

function module.new(controller)
    local ui = {}
    ui.Controller = controller
    ui.ID = module.ID
    ui.GUI = Template:Clone()
    ui.GUI.Parent = UI
    ui.TitleBar = ui.GUI.Frame.TitleBar
    ui.Direction = 1
    setmetatable(ui,module)
    ui:DisableMovement()
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
                if val == "Go!" then
                    --self:DisableMovement()
                else
                    if string.find(val, "Inverse") and textField.Text ~= val then
                        self.Direction *= -1
                    end
                end
                textField.Text = val
            end
        end
    end
end

function module:Destroy()
    self:EnableMovement()
    self.GUI:Destroy()
    self = nil
end

-- Disables movement.
function module:DisableMovement()
    cam.CameraType = Enum.CameraType.Scriptable
    self.tick = RunService.Stepped:Connect(function(time, deltaTime)
        module:UpdateCamera()
    end)
    movementController.moveFunction = function(player, direction, relative)
        Player.Move(player, direction * self.Direction, relative)
    end
end

function module:UpdateCamera()
    cam.CFrame = CFrame.new(Player.Character.PrimaryPart.CFrame.Position + offset * 5) * CFrame.new(-offset)
end

-- Unbinds our "disable movement" so that the default keybinds are activated.
function module:EnableMovement()
    if self.tick then
        self.tick:Disconnect()
        self.tick = nil
    end
    cam.CameraType = Enum.CameraType.Custom
    movementController.moveFunction = Player.Move
end

return module