--[[
    FallTiles.luau
    Author: Justin (synnull)
    Description: Game where tiles disappear upon touch
]]


local module = {}
module.__index = module
local Players = game:GetService("Players")


-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ReplicatedTween = require(ReplicatedStorage.ReplicatedTweening)
local CollectionService = game:GetService("CollectionService")
local GameTemplate = workspace.FallTiles --ReplicatedStorage.Assets.MiniGames.FallTiles
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--comms
local FallTileComm = ServerComm.new(ReplicatedStorage, "FallTileComm")
local JoinedGameEvent = FallTileComm:CreateSignal("JoinedGameEvent")
local StartGameEvent = FallTileComm:CreateSignal("StartGameEvent")
local PlayerEliminatedEvent = FallTileComm:CreateSignal("PlayerEliminatedEvent")
local EndGameEvent = FallTileComm:CreateSignal("EndGameEvent")

--local Extras = ReplicatedStorage.Assets.MiniGameExtras.SkyClimbers


--game vars
local ROUND_TIME = 45
local TILE_DISAPPEAR_TIME = 1


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
    self.ActivePlayers = {}
    for _, platform in self.MiniGame.Game.Platforms:GetDescendants() do
        if CollectionService:HasTag(platform, "DisappearingPlatform") then
            platform:SetAttribute("Touched", false)
        end
    end
end


function module:Start()

     --make sure this game gets cleaned up
    self._janitor:Add(function()
        self:Destroy()
     end)

    -- set up the kill part at the bottom of water
    local killPart = self.MiniGame.Game:FindFirstChild("KillPart")
    if not killPart then return end
    killPart.Touched:Connect(function(hit)
        local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if player then
            local playerInTable = table.find(self.ActivePlayers,player)
            table.remove(self.ActivePlayers, playerInTable)
            PlayerEliminatedEvent:FireAll(#self.ActivePlayers)
            
        end
    end)
    print("HELLO?")
    print(#self.ActivePlayers)
    StartGameEvent:FireAll(#self.ActivePlayers)
    return ROUND_TIME

end



function  module:GetWinners()
    local highScore = 0
    local winner = nil

    for player, score in self.MiniGame.Players do
        if score > highScore then
            highScore = score
            winner = player
        end
    end
    return winner
end

function  module:JoinGame(player)
    table.insert(self.ActivePlayers, player)
    --Knit.GetService("SkyClimbersService").Client.JoinedGame:Fire(player, laneLength, data.Position, platformPoints)
    JoinedGameEvent:Fire(player)
    local spawnPoint = self.MiniGame.Game.Spawns:FindFirstChild("Spawn"..#self.ActivePlayers)
    spawnPoint.Transparency = 0
    spawnPoint.CanCollide = true
    player.Character:SetPrimaryPartCFrame(CFrame.new(spawnPoint.Position))

    local hitBox:Part = Instance.new("Part")
    hitBox.Name = "FallTiles_HitBox"
    hitBox.Massless = true
    hitBox.Size = Vector3.new(4,6,4)
    hitBox.CanCollide = false
    hitBox.Parent = player.Character.HumanoidRootPart
    hitBox:PivotTo(CFrame.new(player.Character.HumanoidRootPart.Position) + Vector3.new(0,-1,0))
    hitBox.Transparency = 1
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hitBox
    weld.Part1 = player.Character.HumanoidRootPart
    weld.Parent = hitBox

    hitBox.Touched:Connect(function(otherPart)
        if CollectionService:HasTag(otherPart, "DisappearingPlatform") and otherPart:GetAttribute("Touched") == false then
            task.spawn(function()
                otherPart:SetAttribute("Touched", true)
                local tweenInfo = TweenInfo.new(TILE_DISAPPEAR_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
                otherPart.Material = Enum.Material.Neon
                local tween = ReplicatedTween:Create(otherPart, tweenInfo, {Transparency = 1})
                tween:Play(true)
                otherPart:Destroy()
            end)
            
        end
    end)

end




function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Destroy()
    --clean up
end

return module