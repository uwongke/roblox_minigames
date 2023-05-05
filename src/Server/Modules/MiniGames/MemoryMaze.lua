local module = {}
module.__index = module
local Players = game:GetService("Players")
-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.MemoryMaze
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local duration = 300
local TotalPlayers = 0

function module:Init(janitor, SpawnLocation, endSignal)
    TotalPlayers = 0
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.RemainingPlayers = 0
    janitor:Add(data.Game)
    self.MiniGame = data
    self.Janitor = janitor

    janitor:Add(data.Game.GameFinish.Touched:Connect(function(part)
        local player = Players:GetPlayerFromCharacter(part.Parent)
        if player then
            local playerData = data.Players[player]
            if playerData then
                data.RemainingPlayers -= 1
                data.Winners[player] = playerData
                playerData.Place = TotalPlayers - data.RemainingPlayers
                data.Players[player] = nil
                if data.RemainingPlayers <= 0 then
                    endSignal:Fire()
                end
            end
        end
    end))

    --bring those who fall through back to the start
    janitor:Add(data.Game.FallCheck.Touched:Connect(function(part)
        local Character = part.Parent
        local player = Players:GetPlayerFromCharacter(Character)
        if player then
            task.wait(1)
            MiniGameUtils.SpawnAroundPart(data.Game.GameStart, Character)
        end
    end))

    --choose random start point
    local rows = data.Game:WaitForChild("Tiles"):GetChildren()
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
        nextStep:SetAttribute("Valid",true)
        --nextStep.Transparency = 0 -- uncomment to see the path
        --get next possibly set of directions
        nextSteps = self:CheckNextStep()
    end

    for _, falseFloor in pairs(CollectionService:GetTagged("FalseFloor")) do
        self:HandleFalseFloor(falseFloor)
    end
end

function module:Start()
    TotalPlayers = self.MiniGame.RemainingPlayers
    self.MiniGame.Game.Barrier:Destroy()--remove invinsible barrier so players can begin freely
    return duration
end

function module:HandleFalseFloor(part)
    local touched = false
    self.Janitor:Add(part.Touched:Connect(function(other)
        local char = other.Parent
        if char:FindFirstChild("Humanoid") then
            if not touched then
                touched = true
                local tweenInfo = TweenInfo.new(
                    1, -- Time
                    Enum.EasingStyle.Linear, -- EasingStyle
                    Enum.EasingDirection.Out, -- EasingDirection
                    0, -- RepeatCount (when less than zero the tween will loop indefinitely)
                    true -- Reverses (tween will reverse once reaching it's goal)
                )
                local target = part:GetAttribute("Valid") and 0 or 1
                local tween = TweenService:Create(part, tweenInfo, { Transparency = target})

                tween.Completed:Connect(function()
                    touched = false
                end)

                tween:Play()
            end
        end
    end))
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

function module:GetWinners()
    table.sort(self.MiniGame.Winners,function(a, b)
        local a_score = self.Minigame.Winners[a].Place
        local b_score = self.Minigame.Winners[b].Place

        return a_score > b_score
    end)
    return self.MiniGame.Winners, 3
end

function module:Update()
    
end

function  module:JoinGame(player)
    local data = {
        Place = 0,
        Name = player.DisplayName
    }
    self.MiniGame.Players[player] = data
    MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.GameStart, player.Character)
end

function module:Destroy()
    self = nil
end

return module