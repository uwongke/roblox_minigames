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
local Signal = require(Packages.Signal)

local RANDOM = Random.new(os.time())
local GameSpawn = workspace.GameSpawn
local Lobby = workspace.SpawnLocation

local MiniGameService = Knit.CreateService {
    Name = "MiniGameService";
    Client = {
        PlayerJoinedMiniGame = Knit.CreateSignal(),
        PlayerGotEliminated = Knit.CreateSignal(),
        MessageUpdate = Knit.CreateSignal(),
        MiniGameUpdate = Knit.CreateSignal(),

        GameStateChanged = Knit.CreateSignal()
    };
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
    local pos = Lobby
    if location == "Arena" then
        pos = GameSpawn
    end
    
    for _, player in game.Players:GetPlayers() do
        local Character = player.Character
        if not Character then continue end
        Character:PivotTo(Utils.getRandomInPart(pos) * CFrame.new(0, 4, 0))
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
                    -- self:MovePlayersTo("Arena")
                elseif to == "intermission" then
                    self:MovePlayersTo("Lobby")
                end

                print("Minigame FSM: " .. event .."!")
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
                local name = minigameNames[RANDOM:NextInteger(1, #minigameNames)]
                local nextModule = LoadedGames[name]
                self._minigame = nextModule
                print("Minigame selected: " .. name .."!")
            end,

            on_initRound = function(this, event, from, to, ...)
                local newJanitor = Janitor.new()
                self._minigame:Init(newJanitor, GameSpawn)
                self._janitor = newJanitor

                -- make players join the game
                PlayerManager.ActivatePlayers()
                print(PlayerManager.GetListOfActivePlayers())
                for player, data in PlayerManager.GetListOfActivePlayers() do
                    self._minigame:JoinGame(player)
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
        if #game.Players:GetPlayers() < 1 then
            return
        end
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

    self.active = true
end

function MiniGameService:KnitInit()
    self.active = false
    self.GameStateChanged = Signal.new()
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

    local initPlayers = {}
    local function onPlayerAdded(player)
        if not player.Character then
            player.CharacterAdded:Wait()
        end
        PlayerManager.new(player)
        table.insert(initPlayers, player)
        print("added new player")
    end

    local function onPlayerRemoving(player)
        local p = table.find(initPlayers, player)
        if p then
            table.remove(initPlayers, p)
        end
        PlayerManager.RemovePlayer(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    Players.PlayerRemoving:Connect(onPlayerRemoving)
end


return MiniGameService