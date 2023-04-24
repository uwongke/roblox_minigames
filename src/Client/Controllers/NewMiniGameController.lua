--[[
    NewMiniGameController.lua
    Author: Aaron (se_yai)

    Description: Manage loading of client-sided modules for Minigames
]]
local LocalPlayer = game.Players.LocalPlayer
local PlayerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts")
local Modules = PlayerScripts:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local NewMiniGameController = Knit.CreateController { Name = "NewMiniGameController" }
local MiniGameService

local UIViews = {
    DefaultUI = require(UIModules.DefaultUI)
}

function NewMiniGameController:KnitStart()
    -- listen for state changes for logic code, can also hold UI code
    MiniGameService.GameStateChanged:Connect(function(event, from, to, _minigameName)
        if event == "initRound" then
            if not _minigameName then 
                warn("No minigame name found! This is an error")
                return
            end
            
            local module = Modules.MiniGames:FindFirstChild(_minigameName)
            if module then
                local newJanitor = Janitor.new()
                self._janitor = newJanitor
                self._minigame = require(module)
                self._minigame:Init()
            end
        elseif event == "startRound" then
            if self._minigame then
                self._minigame:Start()
            end
        elseif event == "endRound" then
            if self._minigame then
                self._minigame:Destroy()
            end

            if self._janitor then
                self._janitor:Destroy()
            end

            self._minigame = nil
        end
    end)

    -- UI init
    MiniGameService.MiniGameUpdate:Connect(function(MiniGameId)
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
    end)

    -- legacy UI update
    MiniGameService.MessageUpdate:Connect(function(Message)
        if self.UI then
            self.UI:DisplayMessage(Message)
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(character)
        if self.UI then
            self.UI:Destroy()
            self.UI = nil
        end
    end)
end


function NewMiniGameController:KnitInit()
    MiniGameService = Knit.GetService("MiniGameService")
end


return NewMiniGameController