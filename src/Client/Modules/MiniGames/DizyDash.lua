local module = {}
module.__index = module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
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

function module:Init(newJanitor)
    cam.CameraType = Enum.CameraType.Scriptable
    newJanitor:Add(RunService.Stepped:Connect(function(time, deltaTime)
        module:UpdateCamera()
    end))
    newJanitor:Add(function()
        self:EnableMovement()
    end)
    -- return display info
    return "Dizzy Dash!",
    "Try to make it to the end of a twisty path, when your controls keep getting inversed!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    local DizzyComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "DizzyComm")
    local DizzyCommEvent = DizzyComm:GetSignal("DizzyCommEvent")
    janitor:Add(DizzyCommEvent:Connect(function(value)
        self:HandleMessage(value)
    end))
    self.GUI = Template:Clone()
    self.GUI.Parent = UI
    self.TitleBar = self.GUI.Frame.TitleBar
    self.Direction = 1
    janitor:Add(self.GUI)
    self:DisableMovement()
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

-- Disables movement.
function module:DisableMovement()
    movementController.moveFunction = function(player, direction, relative)
        Player.Move(player, direction * self.Direction, relative)
    end
end

function module:UpdateCamera()
    cam.CFrame = CFrame.new(Player.Character.PrimaryPart.CFrame.Position + offset * 5) * CFrame.new(-offset)
end

-- Unbinds our "disable movement" so that the default keybinds are activated.
function module:EnableMovement()
    cam.CameraType = Enum.CameraType.Custom
    movementController.moveFunction = Player.Move
end

function module:Destroy()
    self = nil
end

return module