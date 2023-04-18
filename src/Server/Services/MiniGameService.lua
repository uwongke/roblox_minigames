--[[
    MiniGameService.lua
    Author: Scott (Quitequiet91)

    Description: Picking mini games
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ServerStorage = game:GetService("ServerStorage")
local MiniGames = ServerStorage.Modules.MiniGames
local Lobby = workspace.SpawnLocation
local PlayerManager = require(ServerStorage.Modules.PlayerData)
local MiniGameUtils = require(ServerStorage.Modules.MiniGameUtils)
local ActivePlayers = {}
local GameSpawn = workspace.GameSpawn
local Games = MiniGames:GetChildren()

local Module = Knit.CreateService {
    Name = script.Name;
    Client = {
        PlayerJoinedMiniGame = Knit.CreateSignal(),
        PlayerGotEliminated = Knit.CreateSignal(),
        MessageUpdate = Knit.CreateSignal(),
        MiniGameUpdate = Knit.CreateSignal()
    };
}

function Module:ChooseMiniGame(gameName)
    self.Client.MessageUpdate:FireAll("selecting game "..gameName)
    local currentPlayers = PlayerManager.GetPlayers()
    if currentPlayers == nil then
        return
    end
    if self.CurrentGame then
        return
    end

    print("got", Games[gameName])
    if Games[gameName] then
        local game = Games[gameName]
        self.CurrentGame = game.new(GameSpawn)
        --determines when the game is ready for players to join
        self.Start = self.CurrentGame.CanJoin.Changed:Connect(function(newVal)
            if newVal then
                self.Client.MiniGameUpdate:FireAll(gameName)
                self:GameReady()
            else
                self.Start:Disconnect()
                self.Start = nil
                PlayerManager.ActivatePlayers()
            end
        end)
        --determines when game is finished and is time to start clean up and choosing the next game
        self.End = self.CurrentGame.GameOver.Changed:Connect(function(newVal)
            if newVal then
                self.End:Disconnect()
                self.End = nil
                self:MiniGameComplete()
            end
        end)
        --handles deliverying any messages the game wants to convey to its players
        self.Messenger = self.CurrentGame.Message.Changed:Connect(function(newVal)
            local targets = nil 
            if self.CurrentGame.MessageTarget.Value ~= "" then
                targets = self.CurrentGame.MessageTarget.Value:split(",")
            end
            -- if a specific set of players is desired for the message find the inclusive/exclusive list of them
            local exclude = targets and targets[1] == "-" or false
            local players = PlayerManager.GetListOfActivePlayers(targets, exclude)
            for player,data in pairs(players) do
                self.Client.MessageUpdate:Fire(player,newVal)
            end
        end)
    end
end

function Module:GameReady()
    PlayerManager.ActivatePlayers()
    ActivePlayers = PlayerManager.GetPlayers()
    for player, data in pairs(ActivePlayers) do
        self.CurrentGame:JoinGame(player)
    end
end

function Module:MiniGameComplete()
    --handle victory/loose screen
    task.wait(5)-- wait for the respawn timer of players who may have died
    ActivePlayers = PlayerManager.GetPlayers()
    for player, data in pairs(ActivePlayers) do
        -- only actively and alive players should be auto teleported
        if data.Alive then
            self:ReturnToLobby(player)
        end
    end
    self.CurrentGame = self.CurrentGame:Destroy()
    self.Messenger:Disconnect()
    self.Messenger = nil
    self.Client.MiniGameUpdate:FireAll("DefaultUI")
    task.wait(1)
    self.Client.MessageUpdate:FireAll("")
    task.wait(2)
    self:ChooseRandomMiniGame()
end

function Module:ChooseRandomMiniGame()
    -- print(self.ValidGames)
    if #self.ValidGames == 0 then
        self.ValidGames = table.clone(Games)
    end
    local randomIndex = math.random(1, #self.ValidGames)
    local randomItem  = self.ValidGames[randomIndex]
    self.Client.MessageUpdate:FireAll("Choosing Random Mini Game")
    task.wait(3)
    self:ChooseMiniGame(self.FORCE_MINIGAME or randomItem.Name)
    if self.FORCE_MINIGAME then
        self.FORCE_MINIGAME = nil
    else
        table.remove(self.ValidGames, randomIndex)
    end
    -- print(self.ValidGames)
    -- print(self.ValidGames)
end

function Module:ReturnToLobby(player)
    MiniGameUtils.SpawnAroundPart(Lobby, player.Character)
    --make sure player isnt anchored from previous game
    player.Character.HumanoidRootPart.Anchored = false
end

function Module:HandleMessage(player, message)
    if self.CurrentGame then
        self.CurrentGame:HandleMessage(player, message)
    end
end

function Module.Client:HandleMessage(player, message)
    self.Server:HandleMessage(player, message)
end

function Module:KnitStart()
    self.FORCE_MINIGAME = "HoleInTheWall" -- set to nil when not in use
end

function Module:KnitInit()
    for _,game in MiniGames:GetChildren() do
        Games[game.Name] = require(game)
    end

    Players.PlayerAdded:Connect(function(player)
        Module:OnPlayerAdded(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        Module:OnPlayerRemoving(player)
    end)
    self.ValidGames = table.clone(Games)
end

function Module:OnPlayerAdded(player)
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    local chooseGame = PlayerManager.GetPlayers() == nil
    PlayerManager.new(player)
    if chooseGame then
        player:WaitForChild("PlayerGui")
        task.wait(1)
        self.Client.MiniGameUpdate:Fire(player,"DefaultUI")
        task.wait(3)
        self:ChooseRandomMiniGame()
    else
        -- if there is an active game attempt to join
        if self.CurrentGame then
            if self.CurrentGame:JoinGame(player) then
                PlayerManager.ActivatePlayers(player)
                self.Client.MiniGameUpdate:Fire(player,self.CurrentGame.Game.Name)
            else
                self.Client.MiniGameUpdate:Fire(player,"DefaultUI")
            end
        end
    end
end

function Module:OnPlayerRemoving(player)
    PlayerManager.RemovePlayer(player)
end

function Module.Client:GetCurrentGame()
    return self.Server:GetCurrentGame()
end
function Module:GetCurrentGame()
    return self.CurrentGame
end
return Module