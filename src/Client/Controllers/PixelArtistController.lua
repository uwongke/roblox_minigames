local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local knit = require(ReplicatedStorage.Packages.Knit)
local Extras = ReplicatedStorage.Assets.MiniGameExtras.PixelArtist
local WinCheckEvent:RemoteEvent = Extras.WinCheck
local PixelArtistController = knit.CreateController({
	Name = "PixelArtistController",
})

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

function PixelArtistController:KnitInit()
	--// services
	self.PixelArtistService = knit.GetService("PixelArtistService")

    self.PlayerArray = DefaultTarget
    self:ClearPlayerArray()
    self.CanPlay = false

end

function PixelArtistController:KnitStart()
    self.PixelArtistService.RoomReady:Connect(function()
		self:SetupButtons()
        Players.LocalPlayer.Character.Humanoid.JumpHeight = 12.5
	end)
    self.PixelArtistService.TargetChosen:Connect(function(target)
		self.Target = target
        self.CanPlay = true
	end)
    self.PixelArtistService.RoundOver:Connect(function()
		self.Target = nil
        self.CanPlay = false
        self:ClearPlayerArray()
	end)
    self.PixelArtistService.EndGame:Connect(function()
        self:EndGame()
    end)
end
function PixelArtistController:ClearPlayerArray()
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            self.PlayerArray[y][x] = 0
        end
    end

    if not self.Room then return end
    local buttons = self.Room:FindFirstChild("Buttons")
    if buttons then
        for _, button in ipairs(buttons:GetChildren()) do
          button.Color = Color3.new(1, 1, 1)
        end
    end
end

function PixelArtistController:EndGame()
    Players.LocalPlayer.Character.Humanoid.JumpHeight = 7.2
end
function PixelArtistController:SetupButtons()
    self.Room = workspace.PixelArtist.Rooms:FindFirstChild("Room_" .. lPlayer.Name)
    if not self.Room then return end
    for _, button in ipairs(self.Room.Buttons:GetChildren()) do
       
        button.Touched:Connect(function(hit)
            local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if hit.Name == "HitBox" and button:GetAttribute("CanSwitch") == true and self.CanPlay == true then
                local x = button:GetAttribute("XPos")
                local y = button:GetAttribute("YPos")
            if button.Color.R == 0 then
                button.Color = Color3.new(1,1,1)
                    self.PlayerArray[y][x] = 0
            else
                button.Color = Color3.new(0,0,0)
                self.PlayerArray[y][x] = 1
            end
            --print(self.PlayerArrays[player.Name])
            button:SetAttribute("CanSwitch", false)
                self:WinCheck(player)
            end
        end)
        button.TouchEnded:Connect(function(hit)
            local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if hit.Name == "HitBox" and button:GetAttribute("CanSwitch") == false and self.CanPlay == true then
            print("touch end")
            task.spawn(function()
                task.wait(.5)
                print("can switch")
                button:SetAttribute("CanSwitch", true)
                end)
            end
        end)
    end
end
function PixelArtistController:WinCheck()
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
function PixelArtistController:ClearPlayerGrids()
        local buttons = self.Room:FindFirstChild("Buttons")
        if buttons then
            for _, button in ipairs(buttons:GetChildren()) do
              button.Color = Color3.new(1, 1, 1)
            end
        end
        self:ClearPlayerArray()
end
return PixelArtistController



