--[[
    PixelArtist.luau
    Author: Justin (synnull)
    Description: Client-sided stuff for pixel artist
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm

local Extras = ReplicatedStorage.Assets.MiniGameExtras.PixelArtist
local WinCheckEvent:RemoteEvent = Extras.WinCheck

local lPlayer = game:GetService("Players").LocalPlayer

local DefaultTarget = {
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0}
}
local GridSize = {7, 7}
local InactiveColor = Color3.fromRGB(255, 135, 36)
local ActiveColor = Color3.fromRGB(0, 255, 0)


local module = {}

function module:Init(newJanitor)
    -- return display info
    return "Pixel Artist!",
    "Jump on the tiles on the floor to match the picture on the wall.",
    "rbxassetid://12716822940"
end


function module:Start(janitor)
	

    --setup comms
    local PixelComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "PixelComm")
    local RoundOverEvent = PixelComm:GetSignal("RoundOverEvent")
    local TargetChosenEvent = PixelComm:GetSignal("TargetChosenEvent")
    local RoomReadyEvent = PixelComm:GetSignal("RoomReadyEvent")

    self.PlayerArray = DefaultTarget
    self:ClearPlayerArray()
    self.CanPlay = false
    self._janitor = janitor

    janitor:Add(RoomReadyEvent:Connect(function()
        print("room ready")
		self:SetupButtons()
        Players.LocalPlayer.Character.Humanoid.JumpHeight = 12.5
	end))
    janitor:Add(TargetChosenEvent:Connect(function(target)
        print("target chosen")
		self.Target = target
        self.CanPlay = true
	end))
    janitor:Add(RoundOverEvent:Connect(function(target)
        print("round over")
		self.Target = nil
        self.CanPlay = false
        self:ClearPlayerArray()
	end))


end

function module:ClearPlayerArray()
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            self.PlayerArray[y][x] = 0
        end
    end

    if not self.Room then return end
    local buttons = self.Room:FindFirstChild("Buttons")
    if buttons then
        for _, button in ipairs(buttons:GetChildren()) do
          button.Color = InactiveColor
        end
    end
end

function module:EndGame()
    Players.LocalPlayer.Character.Humanoid.JumpHeight = 7.2
end
function module:SetupButtons()
    self.Room = workspace.PixelArtist.Rooms:FindFirstChild("Room_" .. lPlayer.Name)
    if not self.Room then return end
    for _, button in ipairs(self.Room.Buttons:GetChildren()) do
       
        --button touch
        self._janitor:Add(button.Touched:Connect(function(hit)
            local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if hit.Name == "HitBox" and button:GetAttribute("CanSwitch") == true and self.CanPlay == true then
                local x = button:GetAttribute("XPos")
                local y = button:GetAttribute("YPos")
            if button.Color.R == 0 then
                button.Color = InactiveColor
                    self.PlayerArray[y][x] = 0
            else
                button.Color = ActiveColor
                self.PlayerArray[y][x] = 1
            end
            --print(self.PlayerArrays[player.Name])
            button:SetAttribute("CanSwitch", false)
                self:WinCheck(player)
            end
        end))

        --button touch end
        self._janitor:Add(button.TouchEnded:Connect(function(hit)
            local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if hit.Name == "HitBox" and button:GetAttribute("CanSwitch") == false and self.CanPlay == true then
            print("touch end")
            task.spawn(function()
                task.wait(.5)
                print("can switch")
                button:SetAttribute("CanSwitch", true)
                end)
            end
        end))
    end
end
function module:WinCheck()
    task.spawn(function()
        if self.Target then
            print("win check for " .. lPlayer.Name)
            print(self.Target)
            print(self.PlayerArray)
            print("Target:")
           
            for x = 1, GridSize[1], 1 do
                for y = 1, GridSize[2], 1 do
                    if self.PlayerArray[y][x] ~= self.Target[y][x] then
                        return
                    end
                end
                
            end
           print(lPlayer.Name .. " checking server")
           WinCheckEvent:FireServer(self.PlayerArray)
           --self.CanPlay = false
        end
       
        

    end)
end

--clears the player array and button visuals
function module:ClearPlayerGrids()
        local buttons = self.Room:FindFirstChild("Buttons")
        if buttons then
            for _, button in ipairs(buttons:GetChildren()) do
              button.Color = InactiveColor
            end
        end
        self:ClearPlayerArray()
end


function module:Destroy()
    self:EndGame()
end


return module



