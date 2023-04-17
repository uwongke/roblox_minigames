--[[
    MiniGameService.lua
    Author: Aaron Jay (se_yai)

    Description: Facilitate running minigames, as well as handling game state
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Modules = ServerStorage:WaitForChild("Modules")
local MiniGames = ServerStorage.Modules.MiniGames
local PlayerManager = require(ServerStorage.Modules.PlayerData)
local LoadedGames = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FSM = require(Shared.FSM)
local Utils = require(Shared.Utils)

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local TableUtil = require(Packages.TableUtil)
local Janitor = require(Packages.Janitor)

local RANDOM = Random.new(os.time())
local GameSpawn = workspace.GameSpawn
local Lobby = workspace.SpawnLocation

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

function MiniGameService:GetMinigameJanitor()
    return self._janitor
end

--- Moves players to a new location
function MiniGameService:MovePlayersTo(location)
    local pos = Lobby.CFrame
    if location == "Arena" then
        pos = GameSpawn.CFrame
    end
    
    for _, player in game.Players:GetPlayers() do
        local Character = player.Character
        if not Character then continue end
        Character:PivotTo(Utils.getRandomInPart(pos + CFrame.new(0, 3, 0)))
    end
end

function MiniGameService:KnitStart()
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
                self._timer = 0
                self.GameStateChanged:Fire(event, from, to, ...)
                self.Client.GameStateChanged:FireAll(from, to)

                -- move players depending on round
                if to == "roundInit" then
                    self:MovePlayersTo("Arena")
                elseif to == "intermission" then
                    self:MovePlayersTo("Lobby")
                end
            end,

            -- this is a state callback instead of event callback because reset goes here
            on_enter_intermission = function(this, event, from, to, ...)
                -- handle winners, but only if the round ended naturally
                if self._minigame and event == "endRound" then
                    local sortedPlayers, places = self._minigame:GetWinners()
                    -- TODO: setup client listner to display winners screen       
                end

                -- cleanup janitor
                if self._janitor then
                    self._janitor:Destroy()
                    self._janitor = nil
                end

                -- select next minigame preemptively
                local minigameNames = TableUtil.Keys(LoadedGames)
                local nextModule = LoadedGames[minigameNames[RANDOM:NextInteger(1, #minigameNames)]]
                self._minigame = nextModule
            end,

            on_initRound = function(this, event, from, to, ...)
                local newJanitor = Janitor.new()
                self._minigame:Init(newJanitor)
                self._janitor = newJanitor

                -- make players join the game
                PlayerManager.ActivatePlayers()
                for _, player in  PlayerManager.GetListOfActivePlayers() do
                    
                end
            end,

            on_startRound = function(this, event, from, to, ...)
                -- module:Start()
                local roundTime = self._minigame:Start() or 60
                TIMES["roundStarted"] = roundTime
            end,
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
            return -- return here so we don't run any extra update code
        end

        if currentState == "roundStarted" then
            if self._minigame then
                self._minigame:Update(dt, self._timer)
            else
                self.FSM.reset()
            end
        end
    end)

    -- start the game loop once players exist
    repeat
        task.wait()
    until #PlayerManager.GetPlayers() >= 1
    self.active = true
end

function MiniGameService:KnitInit()
    self.active = false

    for _,game in MiniGames:GetChildren() do
        local success, loadedGame = pcall(function()
            return require(game)
        end)
        if success and loadedGame then
            LoadedGames[game.Name] = loadedGame
        else
            warn("Error loading minigame " .. game.Name .. ": " .. loadedGame)
        end
    end

    local function onPlayerAdded(player)
        if not player.Character then
            player.CharacterAdded:Wait()
        end
        PlayerManager.new(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
end


return MiniGameService