--[[
    MiniGameService.lua
    Author: Aaron Jay (se_yai)

    Description: Facilitate running minigames, as well as handling game state
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FSM = require(Shared.FSM)

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local MiniGameService = Knit.CreateService {
    Name = "NewMiniGameService";
    Client = {};
}

local TIMES = {
    ["intermission"] = 10,
    ["roundInit"] = 5,
    ["roundStarted"] = 120
}

local TRANSITIONS = {
    ["intermission"] = "initRound",
    ["roundInit"] = "startRound",
    ["roundStarted"] = "endRound"
}

function MiniGameService:ToggleLoop()
    self.active = not self.active
    return self.active
end

function MiniGameService:KnitStart()

    if true then return end

    self.FSM = FSM.create({
        initial = "intermission",
        events = {
            {name = "initRound", from = "intermission", to = "roundInit"},
            {name = "startRound", from = "roundInit", to = "roundStarted"},
            {name = "endRound", from = "roundStarted", to = "intermission"},
            {name = "reset", from = "*", to = "intermission"}
        },
        callbacks = {
            on_event = function(this, event, from, to, ...)
                print(to)
                self._timer = 0
                self.GameStateChanged:Fire(event, from, to, ...)
                self.Client.GameStateChanged:FireAll(from, to)

                -- move players depending on round
                if to == "roundInit" then
                    self:MovePlayersTo("Arena")
                elseif to == "intermission" then
                    self:MovePlayersTo("Lobby")
                end

                -- reset timer
            end,

            on_enter_intermission = function(this, event, from, to, ...)

            end
        }
    })

    RunService.Heartbeat:Connect(function(dt)
        if not self.active then return end
        self._timer += dt

        local currentState = self.FSM.current
        local stateTimer = TIMES[currentState]
        local event = TRANSITIONS[currentState]

        if self._timer >= stateTimer then
            self.FSM[event]()
            print("did event", event)
        end
    end)
end

function MiniGameService:KnitInit()
    
end


return MiniGameService