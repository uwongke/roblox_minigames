--[[
    PixelArtist.luau
    Author: Justin (synnull)
    Description: Pixel Artist game (server-sided)
]]

local module = {}
module.__index = module

-- services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local GameTemplate = ReplicatedStorage.Assets.MiniGames.PixelArtist
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--comms
local PixelComm = ServerComm.new(ReplicatedStorage, "PixelComm")
local RoundOverEvent = PixelComm:CreateSignal("RoundOverEvent")
local TargetChosenEvent = PixelComm:CreateSignal("TargetChosenEvent")
local RoomReadyEvent = PixelComm:CreateSignal("RoomReadyEvent")

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.PixelArtist
local Button = GameExtras.Button
local ScreenButton = GameExtras.ScreenButton
local HitBox = GameExtras.HitBox

local ROUND_TIME = 120               --round time
local GridSize = {7, 7}
local GridBuffer = 1.5
local InactiveColor = Color3.fromRGB(255, 135, 36)
local ActiveColor = Color3.fromRGB(0, 255, 0)

local Patterns = require(game:GetService("ReplicatedStorage"):WaitForChild("PixelArtistPatterns"))

local DefaultTarget = { 
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0},
    {0,0,0,0,0,0,0}
}


function module:Init(janitor, SpawnLocation)
    self.MiniGame = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    janitor:Add(self.MiniGame.Game)
   
    -- should clean this up with janitor
    -- removes players that leave during the game from the pool of players
    janitor:Add(Players.PlayerRemoving:Connect(function(player)
        if self.MiniGame.Players[player] then
            self.MiniGame.Players[player] = nil
        end
    end))
   
    self._janitor = janitor

    self:PrepGame()
    
end


function module:PrepGame()
    self.RoomCount = 0
    self.ActivePlayers = {}
    self.CanPlay = false  --this lets players toggle buttons
    self.PlayerArrays = {}
    self.Target = {}

end

function module:Start()

    self.MiniGameService = Knit.GetService("MiniGameService")
     --make sure this game gets cleaned up
    self._janitor:Add(function()
        self:Destroy()
     end)

    self.WinCheckEvent = GameExtras:FindFirstChild("WinCheck")
    self.WinCheckEvent.OnServerEvent:Connect(function(player, playerArray)
       self:WinCheck(player, playerArray)
    end)

    self:StartNextRound()

    return ROUND_TIME

end

--clears the player data for the game to check against
function module:ClearPlayerArray(playerArray)
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            playerArray[y][x] = 0
        end
    end
end


function module:WinCheck(player, playerArray)
    task.spawn(function()
        local wins = self.MiniGame.Players[player]
        if playerArray and wins then
            print("win check for " .. player.Name)
            for x = 1, GridSize[1], 1 do
                for y = 1, GridSize[2], 1 do
                    if playerArray[y][x] ~= self.Target[wins+1][y][x] then
                        return
                    end
                end
                
            end
            local messageData = {
                Message="",
                Timer=""
            }
           print(player.Name .. " won that round!")
            self.MiniGame.Players[player] += 1
            if self.MiniGame.Players[player] == 1 then
               print(player.Name .. " wins!")

                --#region
                for player, score in self.MiniGame.Players do
                    local hitBox = player.Character.HumanoidRootPart:FindFirstChild("HitBox")
                    if hitBox then
                        hitBox:Destroy()
                    end
                end
                --end game here
                --self.GameOver.Value = true
                --Knit.GetService("PixelArtistService").Client.EndGame:FireAll()
                self.Winner = player
                self.MiniGameService.FSM["endRound"]("PixelArtist")
                return
            end
           -- Knit.GetService("PixelArtistService").Client.RoundOver:FireAll() --fire to set up client stuff
            RoundOverEvent:FireAll()
            self.CanPlay = false
            task.wait(1.5)
            self:ClearScreens()
    
            print("Next round will Start in ...")
            task.wait(1)
            local count =3
            while count > 0 do
                print(count)
                task.wait(1)
                count -= 1
            end
            print("Go!")
            task.wait(1)
    
            self:StartNextRound()
        end
       
        

    end)
end
function module:GetWinners()
    return self.Winner
end
--select the next pattern and turn on the screens
function module:StartNextRound()
    self.Target[1] = Patterns["Level1"][math.random(1,Patterns["Level1"].Total)]
    self.Target[2] = Patterns["Level2"][math.random(1,Patterns["Level2"].Total)]
    self.Target[3] = Patterns["Level3"][math.random(1,Patterns["Level3"].Total)]
    --Knit.GetService("PixelArtistService").Client.TargetChosen:FireAll(self.Target) --fire to set up client stuff
    for player, score in self.MiniGame.Players do
        --Knit.GetService("PixelArtistService").Client.TargetChosen:Fire(player, self.Target[data.Wins+1])
        local wins = self.MiniGame.Players[player]
        TargetChosenEvent:Fire(player,self.Target[wins+1])
        self:TurnOnScreens(player.Name, self.Target[wins+1])

    end

end

--show the target on screens
function module:TurnOnScreens(playerName, target)

    local room = self.MiniGame.Game.Rooms:FindFirstChild("Room_" .. playerName)
    if not room then return end
    local screen = room:FindFirstChild("Screen")
    if not screen then return end
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            local screenButton = screen:FindFirstChild("Screen" .. x .. y)
            if screenButton then
                if target[y][x] == 1 then
                    screenButton.Color = ActiveColor
                else
                    screenButton.Color = InactiveColor
                end
            end
        end
    end
    self.CanPlay = true
end

--clears the screen showing the target
function module:ClearScreens()
    for _, room in ipairs(self.MiniGame.Game.Rooms:GetChildren()) do
        local screen = room:FindFirstChild("Screen")
        if screen then
            for x = 1, GridSize[1], 1 do
                for y = 1, GridSize[2], 1 do
                    local screenButton = screen:FindFirstChild("Screen" .. x .. y)
                    if screenButton then
                        screenButton.Color = InactiveColor
                    end
                end
            end
        end
    end
end

--clears the player array and button visuals
function module:ClearPlayerGrids()
    for _, room in ipairs(self.MiniGame.Game.Rooms:GetChildren()) do
        local buttons = room:FindFirstChild("Buttons")
        if buttons then
            for _, button in ipairs(buttons:GetChildren()) do
              button.Color = InactiveColor
            end
        end
    end

    --clear arrays
    for _, player in ipairs(self.ActivePlayers) do
        self:ClearPlayerArray(self.PlayerArrays[player.Name])
        print(self.PlayerArrays[player.Name])
    end
end
function module:SetUpRoom(room, player)

    --add the floor buttons
    local buttonSpawn = room.Buttons:FindFirstChild("ButtonSpawn")
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            local newButton:Part = Button:Clone()
            newButton:SetAttribute("XPos", x)
            newButton:SetAttribute("YPos", y)
            newButton.Parent = room.Buttons
            newButton.Position = Vector3.new(buttonSpawn.Position.X + ((buttonSpawn.Size.X + GridBuffer)* -x) , buttonSpawn.Position.Y, buttonSpawn.Position.Z + ((buttonSpawn.Size.Z + GridBuffer) * -y))
            --[[
            local clickDetect:ClickDetector = newButton.ClickDetector
            clickDetect.MouseClick:Connect(function()
                if newButton:GetAttribute("CanSwitch") == true and self.CanPlay == true then
                if newButton.Color.R == 0 then
                    newButton.Color = Color3.new(1,1,1)
                    self.PlayerArrays[player.Name][y][x] = 0
                else
                    newButton.Color = Color3.new(0,0,0)
                    self.PlayerArrays[player.Name][y][x] = 1
                end
                --print(self.PlayerArrays[player.Name])
                newButton:SetAttribute("CanSwitch", false)
                self:WinCheck(player, self.PlayerArrays[player.Name])
                task.spawn(function()
                    task.wait(1)
                    newButton:SetAttribute("CanSwitch", true)
                    end)
                end
            end)
            ]]--
        end
    end

    buttonSpawn:Destroy()
    --add the screen buttons to display the target pattern
    local screenButtonSpawn = room.Screen:FindFirstChild("ButtonSpawn")
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            local newButton:Part = ScreenButton:Clone()
            newButton.Parent = room.Screen
            newButton.Name = "Screen"..x..y
            newButton.Position = Vector3.new(screenButtonSpawn.Position.X + ((screenButtonSpawn.Size.Y + (GridBuffer/2))* -x) , screenButtonSpawn.Position.Y + ((screenButtonSpawn.Size.Y + (GridBuffer/2)) * -y), screenButtonSpawn.Position.Z )
        end
    end

    -- Knit.GetService("PixelArtistService").Client.RoomReady:Fire(player) --fire to set up client stuff
    RoomReadyEvent:Fire(player)

end
--- Called every frame by the server during gameplay
function module:Update(players, dt, timeElapsed)
    -- self._timeElapsed += dt
 end
function  module:JoinGame(player)

        --set target and clear to be safe
        self.PlayerArrays[player.Name] = DefaultTarget
        self.MiniGame.Players[player] = 0
        self:ClearPlayerArray(self.PlayerArrays[player.Name])

        print(player.DisplayName .. " has Joined the game")

        local newRoom:Model = GameExtras.Room:Clone()
        newRoom.Parent = self.MiniGame.Game.Rooms
        newRoom.Name = "Room_" .. player.Name
        local firstRoomPosition = self.MiniGame.Game.RoomSpawn.Position
        local xPos = self.RoomCount
        local yPos = (math.floor((self.RoomCount / 3) + .3)) + 1
        local roomCFrame = CFrame.new(Vector3.new( (firstRoomPosition.X + ((newRoom.PrimaryPart.Size.X + 0)* xPos)), firstRoomPosition.Y , firstRoomPosition.Z ))
        newRoom:PivotTo(roomCFrame)
        self:SetUpRoom(newRoom, player)
        task.wait()
        local roomSpawn = newRoom:WaitForChild("PlayerSpawn")
        player.Character:SetPrimaryPartCFrame(CFrame.new(roomSpawn.Position))

        --add hit hitbox for buttons
        if HitBox then
            local newHitBox = HitBox:Clone()
            newHitBox.Parent = player.Character.HumanoidRootPart
            newHitBox.Position = player.Character.HumanoidRootPart.Position + Vector3.new(0,-4,0)
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = newHitBox
            weld.Part1 = player.Character.HumanoidRootPart
            weld.Parent = newHitBox
        end

        self.RoomCount += 1
end

function module:Destroy()
    --clean up
     --clear arrays
     for _, player in ipairs(self.ActivePlayers) do
        self:ClearPlayerArray(self.PlayerArrays[player.Name])
    end
    table.clear(self.PlayerArrays)
end

return module