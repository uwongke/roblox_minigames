local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.MismatchMayhem
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.MismatchMayhem
local Decals = GameExtras.Decals
local Shapes = Decals:GetChildren()
local ExtraShapes = GameExtras.ExtraDecals:GetChildren()
local Colors = {
           { "Red", Color3.new(0.980392, 0, 0)},
           { "Green", Color3.new(0, 0.4549019607843137, 0.09803921568627451)},
           { "Blue", Color3.new(0, 0.01568627450980392, 0.9803921568627451)},
           {"Yellow", Color3.new(0.9803921568627451, 0.9647058823529412, 0)}
        }
local ExtraColors = {
            { "Purple", Color3.new(0.6470588235294118, 0, 0.615686274509804)},
            { "Orange", Color3.new(0.968627, 0.627450, 0)},
            { "Teal", Color3.new(0, 0.980392, 0.898039)}
         }

local DefaultTileColor:Color3 = Color3.fromRGB(163, 162, 165)

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
   
    print("PREP GAME")
    self.WaitTime = 3 --how long it takes for object to get game area
    self.TimeBetweenDrops = 2 --how long it takes for object to get game area
    self.ElapsedTime = 0 --elapsed game time
    self.ActivePlayers = {}
    self.Phase = 1  -- 3 phases, 1 = color, 2 = shape, 3 = both
    self.RoundsPerPhase = 1 -- how many rounds of color and shape before both start
    self.RoundCount = 0 -- how many rounds of color and shape before both start
    self.ShowSafeTileTime = 2
    self.TimeBetweenDrops = 5
    self.MemorizationTime = 3
    self.MoveTime = 3
    self.Game.Broadcast.Back.Timer1.Frame.ScaleMe:GetPropertyChangedSignal("Size"):Connect(function()
        self.Game.Broadcast.Back.Timer1.Frame.ScaleMe.BackgroundColor3 = Color3.new(0.780392, 0, 0):Lerp(Color3.new(0, 0.6745098039215687, 0.11372549019607843), self.Game.Broadcast.Back.Timer1.Frame.ScaleMe.Size.Y.Scale / 1)
    end)
    self.Game.Broadcast.Back.Timer2.Frame.ScaleMe:GetPropertyChangedSignal("Size"):Connect(function()
        self.Game.Broadcast.Back.Timer2.Frame.ScaleMe.BackgroundColor3 = Color3.new(0.780392, 0, 0):Lerp(Color3.new(0, 0.6745098039215687, 0.11372549019607843), self.Game.Broadcast.Back.Timer2.Frame.ScaleMe.Size.Y.Scale / 1)
    end)


    self.Game.DeathPart.Touched:Connect(function(hit)
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player then
            print(player.Name .. " is eliminated.")
            MiniGameUtils.SpawnAroundPart(workspace.LobbySpawn, player.Character)
            local foundplayer  = table.find(self.ActivePlayers,player)
            local canDie = player.Character:FindFirstChild("MismatchMayhem_CanDie")
            if self.ActivePlayers[foundplayer] and canDie then
                table.remove(self.ActivePlayers,table.find(self.ActivePlayers,player))
                player.Character.Humanoid.WalkSpeed = 16
                print("players left: " .. #self.ActivePlayers)
                if #self.ActivePlayers <= 1 then
                     if self.ActivePlayers[1] then
                         print(self.ActivePlayers[1].Name .. " wins.")
                     end
                     self.GameOver.Value = true
                end
                canDie.Value = false
                canDie:Destroy()
            end
           
        end
    end)



    local messageData = {
        Message="",
        Timer=""
    }
    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Stand on the same tile that is shown."
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

    print(self.ActivePlayers)
    print(#self.ActivePlayers)


    self.DropThread = task.spawn(function()
        while true do
           -- task.wait(math.random(self.TimeBetweenDrops-self.TimeBetweenDrops*.2,self.TimeBetweenDrops+self.TimeBetweenDrops*.2))
           
           self:RandomizeTiles()
           task.wait(self.MemorizationTime)
           self:ChooseSafeTile()
           task.wait(self.ShowSafeTileTime)
           self:ClearTiles()
            task.wait(self.MoveTime)
           self:DropPlatforms()
           task.wait(3)
           self:ClearBroadcastTile()
           self:ClearTileTags()
           self:ResetTiles()
           task.wait(self.TimeBetweenDrops)

        end
    end)
end

function module:ClearBroadcastTile()
    --clear broadcast
    self.Game.Broadcast.BroadcastPart:ClearAllChildren()
    self.Game.Broadcast.BroadcastPart.Color = Color3.new(0,0,0)
    self:RemoveTags(self.Game.Broadcast.BroadcastPart)

end

function module:ChooseRandomColor(platform)
    local randomColor = Colors[math.random(1,#Colors)]
    platform.Color = randomColor[2]
    CollectionService:AddTag(platform,randomColor[1])
end

function module:ChooseRandomShape(platform)
    local randomShape = Shapes[math.random(1,#Shapes)]:Clone()
    randomShape.Parent = platform
    CollectionService:AddTag(platform,randomShape.Name)
end

function module:RandomizeTiles()
    local colorAndShape = false
    if self.Phase == 3 then
        if math.random(1,10) >= 5 then
            colorAndShape = true
        end
    end
    for _, platform:Part in ipairs(self.Game.Platforms:GetChildren()) do
         --phase 1
         if self.Phase == 1 then
           self:ChooseRandomColor(platform)
         end

        -- phase 2
        if self.Phase == 2 then
            self:ChooseRandomShape(platform)
        end

        --phase 3
        if self.Phase == 3 then

            if colorAndShape then
                self:ChooseRandomColor(platform)
                self:ChooseRandomShape(platform)
            else
                if math.random(1,10) >= 5 then
                    self:ChooseRandomColor(platform)
                else
                    self:ChooseRandomShape(platform)
                end
            end
            
        end
        

       
    end
end
function module:ChooseSafeTile()
    local tiles = self.Game.Platforms:GetChildren()
    local randomTile = tiles[math.random(1,#tiles)]
    self.SafeTags = CollectionService:GetTags(randomTile)
    if #self.SafeTags >= 2 then
        if math.random(1,5) >= 5 then
            table.remove(self.SafeTags,math.random(1,#self.SafeTags))
        end
    end
    for _, tag in ipairs(self.SafeTags) do
        for _, color in Colors do
            if tag == color[1] then
                self.Game.Broadcast.BroadcastPart.Color = color[2]
            end
        end
        for _, shape in Shapes do
            if tag == shape.Name then
                shape:Clone().Parent =  self.Game.Broadcast.BroadcastPart
            end

        end
    end
    TweenService:Create(self.Game.Broadcast.Back.Timer1.Frame.ScaleMe, TweenInfo.new(self.ShowSafeTileTime + self.MoveTime ), { Size = UDim2.new(1,0,0,0),
                                                                                                 Position = UDim2.new(0,0,1,0)}):Play()
     TweenService:Create(self.Game.Broadcast.Back.Timer2.Frame.ScaleMe, TweenInfo.new(self.ShowSafeTileTime + self.MoveTime ), { Size = UDim2.new(1,0,0,0),
                                                                                                 Position = UDim2.new(0,0,1,0)}):Play()
end
function module:RemoveTags(instance)
    for _, tag in ipairs(CollectionService:GetTags(instance)) do
        CollectionService:RemoveTag(instance, tag)
    end
end
function module:DropPlatforms()
    for _, platform:Part in ipairs(self.Game.Platforms:GetChildren()) do
        local platformTag = CollectionService:GetTags(platform)
        local matches = 0
       for _, platTag in ipairs(platformTag) do
            for _, safeTag in ipairs(self.SafeTags) do
                if platTag == safeTag then
                    matches += 1
                end
            end
       end
       if matches ~= #self.SafeTags then
            platform.CanCollide = false
            platform.Transparency = 1
        end
        matches = 0
    end
end
function module:ClearTiles()
    --clear platforms
    for _, platform:Part in ipairs(self.Game.Platforms:GetChildren()) do
        platform:ClearAllChildren()
        platform.Color = DefaultTileColor
        platform.CanCollide = true
        platform.Transparency = 0
    end
   
end
function module:ResetTiles()
    --clear platforms
    for _, platform:Part in ipairs(self.Game.Platforms:GetChildren()) do
        platform.CanCollide = true
        platform.Transparency = 0
    end
    --increase round/phase
    self.RoundCount += 1

    --reset the timers
    self.Game.Broadcast.Back.Timer1.Frame.ScaleMe.Size = UDim2.new(1,0,1,0)
    self.Game.Broadcast.Back.Timer1.Frame.ScaleMe.Position = UDim2.new(0,0,0,0)
    self.Game.Broadcast.Back.Timer2.Frame.ScaleMe.Size = UDim2.new(1,0,1,0)
    self.Game.Broadcast.Back.Timer2.Frame.ScaleMe.Position = UDim2.new(0,0,0,0)

    --reduce times by 25%

    self.ShowSafeTileTime = self.ShowSafeTileTime - (self.ShowSafeTileTime * .25)
    self.TimeBetweenDrops = self.TimeBetweenDrops - (self.TimeBetweenDrops * .25)
    self.MemorizationTime = self.MemorizationTime - (self.MemorizationTime * .25)

    for _, player in ipairs(self.ActivePlayers) do
        if player.Character.Humanoid.WalkSpeed < 40 then
            player.Character.Humanoid.WalkSpeed = player.Character.Humanoid.WalkSpeed + (player.Character.Humanoid.WalkSpeed * .2)
        end
    end

    if self.RoundCount == self.RoundsPerPhase and self.Phase < 3 then
        self.Phase += 1
        self.RoundCount = 0
        self.ShowSafeTileTime = 3
        self.TimeBetweenDrops = 5
        self.MemorizationTime = 3
        self.MoveTime = 3
        
    end

    --add extras for more difficulty
    if self.Phase == 3 and self.RoundCount == 3 then
       Colors = self:CombineTables(Colors, ExtraColors)
       Shapes = self:CombineTables(Shapes, ExtraShapes)
        local messageData = {
        Message="",
        Timer=""
    }
    messageData.Message = "Difficulty Increased"
    self.Message.Value = HttpService:JSONEncode(messageData)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    end
end

function module:CombineTables(a1, a2)
    for _, tableItem in ipairs(a2) do
        table.insert(a1, tableItem)
    end
    return a1
end
function module:ClearTileTags()
    --clear platforms
    for _, platform:Part in ipairs(self.Game.Platforms:GetChildren()) do
        self:RemoveTags(platform)
       
    end
end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Time = 0,
            Name = player.DisplayName,
        }
        self.Players[player] = data
        local canDie = player.Character:FindFirstChild("MismatchMayhem_CanDie")
        if not canDie then
            canDie = Instance.new("BoolValue")
            canDie.Name = "MismatchMayhem_CanDie"
            canDie.Parent = player.Character
        end
        canDie.Value = true

        table.insert(self.ActivePlayers, player)
        --Knit.GetService("DropDodgeService").Client.PrepGame:Fire(player) --fire to set up client stuff
        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        print(player.DisplayName .. " has Joined the game")

        --send join event for camera controller
        --Knit.GetService("MiniGameService").Client.PlayerJoinedMiniGame:Fire(player)

        return true
    end
    return false
end

function module:Destroy()
    --clean up
    task.cancel(self.DropThread)
    self.Game:Destroy()
    self = nil
end

return module