--[[
    MicroRacers.lua
    Author: Aaron Jay (seyai)
]]

local module = {}
module.__index = module
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GenerateSpline = require(ReplicatedStorage.Shared.GenerateSpline)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Modules = script.Parent.Parent
local MiniGameUtils = require(Modules.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames:WaitForChild(script.Name)

--// minigame specific constants or whatever
local TRACK_WIDTH = 3
function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    data.Racers = {}
    data.Cars = {}
    data.TrackSize = 0
    local newJanitor = Janitor.new()
    newJanitor:Add(data.Game)
    data._janitor = newJanitor
    --// opt for delay based gameplay bc it's a basic 2 button input game
    --// just reflect to client what the inputs are for each player's cart
    
    --// handle disconnects
    Players.PlayerRemoving:Connect(function(player)
        --// right now, track will remain and car will just stop moving
        --// because no new events are sent
        local i = table.find(data.Racers, player)
        if i then
            table.remove(data.Racers, i)
        end
    end)
    
    setmetatable(data, module)
    task.delay(3, function()
        data:InitGame()
    end)

    return data
end

function module:Destroy()
    self._janitor:Destroy()
end

function module:InitGame()
    --// generate spline based off one of the preselected tracks
    --// select track
    local tracks = self.Game:WaitForChild("Tracks"):GetChildren()
    local nextTrack = tracks[math.random(1, #tracks)]
    local trackFolder = Instance.new("Folder")
    trackFolder.Name = "RenderedTrack"
    trackFolder.Parent = self.Game

    print("Using " .. nextTrack.Name)

    for _, track in tracks do
        if track ~= nextTrack then
            track:Destroy()
        end
    end

    local points = {}
    -- order the points properly
    local folder = nextTrack
    for i = 1, #folder:GetChildren() do
        local p = folder:FindFirstChild("P" .. i)
        if p then
            table.insert(points, p.Position)
            p.Transparency = 1
            p.CanCollide = false
        else
            warn("Could not find P" .. tostring(i) .. " for " .. nextTrack.Name .. v)
            break
        end
    end
    

    -- do not generate spline if the spline is broken
    if #points < #nextTrack:GetChildren() then
        warn("Broken spline, something didn't get counted in " .. nextTrack.name)
    end

    local newSpline = GenerateSpline(
        nextTrack.Name,
        points,
        trackFolder,
        nextTrack:GetAttribute("Tension")
    )

    self._spline = newSpline

    local length = 0
    local numPoints = newSpline.NumPoints

    for i = 1, numPoints do
        local t1 = (i - 1) / (numPoints)
        local t2 = i / numPoints

        local p1 = newSpline.Spline:CalculatePositionRelativeToLength(t1)
        local p2 = newSpline.Spline:CalculatePositionRelativeToLength(t2)
        length += (p1 - p2).Magnitude
    end
    self._splineLength = length

    --// when this is done, setup a heartbeat to process commands
    self._janitor:Add(RunService.PostSimulation:Connect(function(dt)
        -- iterate through unprocessed commands and set car values accordingly

        -- // iterate through cars and update their stuff
        for _, player in self.Racers do
            local carData = self.Cars[player]
            print("found carData")
            if carData then
                local v = carData.Speed
                if v > 0 then
                    -- convert position and length to [0, 1], then get distance
                    local totalDistance = self._splineLength

                    local squashedV = (v / totalDistance) -- * cmd.deltaTime

                    local currentPosition = carData.Position
                    local step = squashedV * dt
                    local t = currentPosition + step-- add new distance based on speed

                    local posOnSpline = self:GetSplinePosition(t)
                    local lastPos = self:GetSplinePosition(currentPosition)
                    if posOnSpline and lastPos then
                        -- get new velocity from new cf
                        -- local movingTo = CFrame.lookAt(
                        --     lastPos,
                        --     posOnSpline
                        -- )
                        
                        carData.Part.CFrame = CFrame.new(lastPos, posOnSpline)
                        if t > 0.99 then
                            t = 0.01
                        end
                        carData.Position = t
                    end
                end
            end
        end
    end))


    self.CanJoin.Value = true
end

-- // offset shift = math.floor(#Racers/2) ex. racer 3 of 5 should be track 0 in the center
function module:JoinGame(player)
    if self.CanJoin.Value then
        -- anchor player
        if player.Character then
            player.Character.PrimaryPart.Anchored = true
            self._janitor:Add(function()
                if player.Character.PrimaryPart then
                    player.Character.PrimaryPart.Anchored = false
                end
            end)
        end
    
        MiniGameUtils.SpawnAroundPart(self.Game.Origin, player.Character)

        -- add to track size
        table.insert(self.Racers, player)
        self.TrackSize = TRACK_WIDTH * #self.Racers

        -- create new car data + part
        local newCar = {
            Speed = 20,
            Acceleration = 0.1, -- adjust this since it's supposed to be the rate to reach 1
            Position = 0.01, -- this increments to 1 then loops back
            Laps = 0,
        }

        local carPart = Instance.new("Part")
        carPart.Size = Vector3.new(2,2,2)
        carPart.Anchored = true
        carPart.Parent = self.Game
        carPart.Name = player.Name
        newCar.Part = carPart
        self.Cars[player] = newCar
    end
end

function module:HandleClientEvent(command)
    if command and typeof(command) == "table" then
        --Sanitize
        if command.userId == nil or typeof(command.userId) ~= "number" or command.userId ~= command.userId then
            return
        end
        if command.x == nil or typeof(command.x) ~= "number" or command.x ~= command.x then
            return
        end
        if
            command.serverTime == nil
            or typeof(command.serverTime) ~= "number"
            or command.serverTime ~= command.serverTime
        then
            return
        end
        if
            command.deltaTime == nil
            or typeof(command.deltaTime) ~= "number"
            or command.deltaTime ~= command.deltaTime
        then
            return
        end

        -- if clean then put into the processor
        table.insert(self.unprocessedCommands, command)
    end
end

function module:GetSplinePosition(t)
    local spline = self._spline
    if spline then
        return spline.Spline:CalculatePositionRelativeToLength(t)
    end
    return nil
end

--// todo: load map from selected spline track

return module