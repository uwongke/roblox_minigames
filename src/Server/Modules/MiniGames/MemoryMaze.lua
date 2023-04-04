local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.MemoryMaze
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 300

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
    local messageData = {
        Message="",
        Timer=""
    }
    --listen for when a player crosses the finish line
    self.GoalListener = self.Game.GameFinish.Touched:Connect(function(part)
        if self.GameOver.Value then
            return
        end
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = self.Players[player]
            if playerData then
                -- could be adjusted to allow multiple players to reach the end
                self.GameOver.Value = true
                self.GoalListener:Disconnect()
                self.GoalListener = nil
                self.Winners[player] = playerData
                self.Players[player] = nil
                -- you won!
                self.MessageTarget.Value = player.UserId
                messageData.Message="You Won!"
                self.Message.Value = HttpService:JSONEncode(messageData)
                task.wait()
                -- everyone else lost (adding "-," to the front means every one except those listed)
                self.MessageTarget.Value = "-,"..player.UserId
                messageData.Message="You lost."
                self.Message.Value = HttpService:JSONEncode(messageData)
            end
        end
    end)

    --bring those who fall through back to the start
    self.FallListener = self.Game.FallCheck.Touched:Connect(function(part)
        local Character = part.Parent
        local player = Players:GetPlayerFromCharacter(Character)
        if player then
            task.wait(1)
            MiniGameUtils.SpawnAroundPart(self.Game.GameStart, Character)
        end
    end)

    --choose random start point
    local rows = self.Game:WaitForChild("Tiles"):GetChildren()
    local row = rows[1]
    local cols = row:GetChildren()
    local y = math.random(1,#cols)
    local nextStep = cols[y]
    nextStep.CanCollide = true
    --nextStep.Transparency = 0 -- uncomment to see the path

    self.Path = {
        Rows = rows,
        Cols = cols,
        CurrentX = 1,
        CurrentY = y,
        LastY = y,
        HorizontalWeighting = 2
    }
    --loop through until you reach the end
    local nextSteps = self:CheckNextStep()
    while nextSteps do
        --choose random direction
        nextStep = nextSteps[math.random(1,#nextSteps)]
        --get tile in that direction
        nextStep = self:TakeNextStep(nextStep)
        --make it solid
        nextStep.CanCollide = true
        --nextStep.Transparency = 0 -- uncomment to see the path
        --get next possibly set of directions
        nextSteps = self:CheckNextStep()
    end

    self.MessageTarget.Value = ""
    messageData.Message = self.Game.Name .. " is ready"
    self.Message.Value = HttpService:JSONEncode(messageData)
    self.CanJoin.Value = true
    task.wait(3)
    messageData.Message = "players have joined"
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Find the path of real tiles to the end."
    self.Message.Value = HttpService:JSONEncode(messageData)
    task.wait(3)
    messageData.Message = "Race will Start in ..."
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
    self.Game.Barrier:Destroy()--remove invinsible barrier so players can begin freely
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)
    count = duration
    --count down until a player passes the finish line
    while count >= 0 do
        if self.GameOver.Value then
            return
        end
        self.MessageTarget.Value = ""
        messageData.Timer = count
        self.Message.Value = HttpService:JSONEncode(messageData)
        task.wait(1)
        count -= 1
    end

    self.GameOver.Value = true
    self.GoalListener:Disconnect()
    self.GoalListener = nil

    messageData.Message="Times up!"
    self.Message.Value = HttpService:JSONEncode(messageData)
end

function module:CheckNextStep()
    local possibleNextSteps = {}
    -- as long as you don't reach the final row before the finish moving forward is an option
    if self.Path.CurrentX < #self.Path.Rows then
        table.insert(possibleNextSteps,"Forward")
    else
        --once you reach the final row the path is finished
        return nil
    end
    local i = 0
    -- as long as you are not all the way to the right and you did not just move left, moving right is an option
    if self.Path.CurrentY < #self.Path.Cols and self.Path.CurrentY ~= self.Path.LastY - 1 then
        -- favor horizontal options to make paths more varied
        while i < self.Path.HorizontalWeighting do
            table.insert(possibleNextSteps,"Right")
            i+= 1
        end
    end
    -- as long as you are not all the way left and you did not just move right, moving left is an option
    if self.Path.CurrentY > 1 and self.Path.CurrentY ~= self.Path.LastY + 1 then
        i = 0
        while i < self.Path.HorizontalWeighting do
            -- favor horizontal options to make paths more varied
            table.insert(possibleNextSteps,"Left")
            i+= 1
        end
    end
   return possibleNextSteps
end

function module:TakeNextStep(direction)
    if direction == "Forward" then
        self.Path.CurrentX +=  1
        --when moving forward your last y is equal to itself
        self.Path.LastY = self.Path.CurrentY
        -- move to next row and update its status
        local cols = self.Path.Rows[self.Path.CurrentX]
        self.Path.Cols = cols:GetChildren()
    end
    if direction == "Left" then
        self.Path.LastY = self.Path.CurrentY
        self.Path.CurrentY -=  1
    end
    if direction == "Right" then
        self.Path.LastY = self.Path.CurrentY
        self.Path.CurrentY +=  1
    end
    -- return the next determined tile
    local nextTile = self.Path.Cols[self.Path.CurrentY]
    return nextTile
end

function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = 1
        }
        self.Players[player] = data
        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        return true
    end
    return false
end

function module:Destroy()
    --clean up
    self.Game:Destroy()
    self = nil
end

return module