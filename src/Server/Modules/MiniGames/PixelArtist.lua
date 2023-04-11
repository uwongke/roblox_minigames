local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.PixelArtist
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.PixelArtist
local Button = GameExtras.Button
local ScreenButton = GameExtras.ScreenButton
local HitBox = GameExtras.HitBox

local GridSize = {7, 7}
local GridBuffer = .5

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

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    setmetatable(data,module)
    task.spawn(function()
        task.wait(3)
        data:PrepGame()
    end)
    return data
end


function module:PrepGame()

    self.RoomCount = 0
    self.ActivePlayers = {}
    self.CanPlay = false  --this lets players toggle buttons
    self.PlayerArrays = {}
    self.Target = {}
    local messageData = {
        Message="",
        Timer=""
    }

    self.WinCheckEvent = GameExtras:FindFirstChild("WinCheck")
    self.WinCheckEvent.OnServerEvent:Connect(function(player, playerArray)
       self:WinCheck(player, playerArray)
    end)
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Jump on tiles to match the picture."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Game will Start in ..."
    self.CanJoin.Value = false-- it is now too late to join
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    local count =3
    while count > 0 do
        messageData.Message =count
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait(1)
        count -= 1
    end
    messageData.Message = "Go!"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)

    self:StartNextRound()

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
        local data = self.Players[player]
        if playerArray and data then
            print("win check for " .. player.Name)
            for x = 1, GridSize[1], 1 do
                for y = 1, GridSize[2], 1 do
                    if playerArray[y][x] ~= self.Target[data.Wins+1][y][x] then
                        return
                    end
                end
                
            end
            local messageData = {
                Message="",
                Timer=""
            }
            messageData.Message = player.Name .. " won that round!"
            self.Message.Value = HttpService:JSONEncode(messageData)
            self.Players[player].Wins += 1
            if self.Players[player].Wins == 3 then
                messageData.Message = player.Name .. " wins!"

                --#region
                for _, player in ipairs(self.ActivePlayers) do
                    local hitBox = player.Character.HumanoidRootPart:FindFirstChild("HitBox")
                    if hitBox then
                        hitBox:Destroy()
                    end
                end
                self.Message.Value = HttpService:JSONEncode(messageData)
                self.GameOver.Value = true
                Knit.GetService("PixelArtistService").Client.EndGame:FireAll()
                return
            end
            Knit.GetService("PixelArtistService").Client.RoundOver:FireAll() --fire to set up client stuff
            self.CanPlay = false
            task.wait(1.5)
            self:ClearScreens()
            --self:ClearPlayerGrids()
    
            messageData.Message = "Next round will Start in ..."
            self.Message.Value = HttpService:JSONEncode(messageData)
            task.wait(1)
            local count =3
            while count > 0 do
                messageData.Message =count
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait(1)
                count -= 1
            end
            messageData.Message = "Go!"
            self.Message.Value = HttpService:JSONEncode(messageData)
            task.wait(1)
            messageData.Message = ""
            self.Message.Value = HttpService:JSONEncode(messageData)
    
            self:StartNextRound()
        end
       
        

    end)
end

--select the next pattern and turn on the screens
function module:StartNextRound()
    self.Target[1] = Patterns["Level1"][math.random(1,Patterns["Level1"].Total)]
    self.Target[2] = Patterns["Level2"][math.random(1,Patterns["Level2"].Total)]
    self.Target[3] = Patterns["Level3"][math.random(1,Patterns["Level3"].Total)]
    Knit.GetService("PixelArtistService").Client.TargetChosen:FireAll(self.Target) --fire to set up client stuff
    for _, player in ipairs(self.ActivePlayers) do
        local data = self.Players[player]
        if data then
            Knit.GetService("PixelArtistService").Client.TargetChosen:Fire(player, self.Target[data.Wins+1])
            self:TurnOnScreens(player.Name, self.Target[data.Wins+1])
        end
    end

end

--show the target on screens
function module:TurnOnScreens(playerName, target)

    local room = self.Game.Rooms:FindFirstChild("Room_" .. playerName)
    if not room then return end
    local screen = room:FindFirstChild("Screen")
    if not screen then return end
    for x = 1, GridSize[1], 1 do
        for y = 1, GridSize[2], 1 do
            local screenButton = screen:FindFirstChild("Screen" .. x .. y)
            if screenButton then
                if target[y][x] == 1 then
                    screenButton.Color = Color3.new(0,0,0)
                else
                    screenButton.Color = Color3.new(1, 1, 1)
                end
            end
        end
    end
    self.CanPlay = true
end

--clears the screen showing the target
function module:ClearScreens()
    for _, room in ipairs(self.Game.Rooms:GetChildren()) do
        local screen = room:FindFirstChild("Screen")
        if screen then
            for x = 1, GridSize[1], 1 do
                for y = 1, GridSize[2], 1 do
                    local screenButton = screen:FindFirstChild("Screen" .. x .. y)
                    if screenButton then
                        screenButton.Color = Color3.new(1, 1, 1)
                    end
                end
            end
        end
    end
end

--clears the player array and button visuals
function module:ClearPlayerGrids()
    for _, room in ipairs(self.Game.Rooms:GetChildren()) do
        local buttons = room:FindFirstChild("Buttons")
        if buttons then
            for _, button in ipairs(buttons:GetChildren()) do
              button.Color = Color3.new(1, 1, 1)
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

     Knit.GetService("PixelArtistService").Client.RoomReady:Fire(player) --fire to set up client stuff


end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Wins = 0,
            Name = player.DisplayName,
        }
        self.Players[player] = data
       
        table.insert(self.ActivePlayers, player)

        --set target and clear to be safe
        self.PlayerArrays[player.Name] = DefaultTarget
        self:ClearPlayerArray(self.PlayerArrays[player.Name])

        --Knit.GetService("DropDodgeService").Client.PrepGame:Fire(player) --fire to set up client stuff
        --MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        print(player.DisplayName .. " has Joined the game")

        local newRoom:Model = GameExtras.Room:Clone()
        newRoom.Parent = self.Game.Rooms
        newRoom.Name = "Room_" .. player.Name
        local firstRoomPosition = self.Game.RoomSpawn.Position
        local xPos = self.RoomCount

        local yPos = (math.floor((self.RoomCount / 3) + .3)) + 1
        --print("xpos: " .. xPos .. " ypos: " .. yPos)
        --print(firstRoomPosition.X + ((newRoom.PrimaryPart.Size.Y + 0)* xPos))
        --print((newRoom.PrimaryPart.Size.Y + 0)*  xPos)
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
        --send join event for camera controller
        --Knit.GetService("MiniGameService").Client.PlayerJoinedMiniGame:Fire(player)

        return true
    end
    return false
end

function module:Destroy()
    --clean up
     --clear arrays
     for _, player in ipairs(self.ActivePlayers) do
        self:ClearPlayerArray(self.PlayerArrays[player.Name])
    end
    table.clear(self.PlayerArrays)

    self.Game:Destroy()
    self = nil
end

return module