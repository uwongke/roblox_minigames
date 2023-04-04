local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)
local Scripts = Player:WaitForChild("PlayerScripts")
local UIModules = Scripts.Modules.UI
local UIViews = {
    DefaultUI = require(UIModules.DefaultUI)
}

local Controller = Knit.CreateController({
    Name = script.Name
})

function Controller:DisplayMessage(Message)
    if self.UI then
        self.UI:HandleMessage(Message)
    end
end

function Controller:GetMiniGameUI(MiniGameId)
    print(MiniGameId)
    if MiniGameId == nil then
        if self.UI then
            self.UI = self.UI:Destroy()
        end
        return
    end
    local Template = UIViews[MiniGameId]
    if Template == nil then
        Template = UIModules:FindFirstChild(MiniGameId.."UI")
        if Template == nil then
            Template = UIViews["DefaultUI"]
        else
            Template = require(Template)
            UIViews[MiniGameId] = Template
        end
    end
    if self.UI then
        if self.UI.ID ~= Template.ID then
            self.UI:Destroy()
        else
            self.UI:Reset()
            return
        end
    end
    self.UI = Template.new(self)
end

function Controller:KnitInit()
    self.Service = Knit.GetService("MiniGameService")
end

function Controller:MessageServer(message)
    self.Service:HandleMessage(message)
end

function Controller:KnitStart()
    self.Service.MiniGameUpdate:Connect(function(MiniGameId)
        Controller:GetMiniGameUI(MiniGameId)
    end)
    self.Service.MessageUpdate:Connect(function(Message)
        Controller:DisplayMessage(Message)
    end)
    Player.CharacterAdded:Connect(function(character)
        if self.UI then
            self.UI:Destroy()
            self.UI = nil
        end
    end)
end

return Controller