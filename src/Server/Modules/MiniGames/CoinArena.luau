--[[
    CoinArena.luau
    Author: Justin (synnull)
    Description: Coin Arena game (server-sided)
]]

local module = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameTemplate = ReplicatedStorage.Assets.MiniGames.CoinArena
local Packages = ReplicatedStorage.Packages
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Knit = require(Packages.Knit)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm


--game vars
local invulTime = 3                 --invul time after player is hit
local ROUND_TIME = 60               --round time
local startingCoins = 5            --how many coins players start with
local normalCoinSpawnTime = 5       --spawn time for single coin
local highValueCoinSpawnTime = 9    --spawn time for bag of coins

--comms
local CoinComm = ServerComm.new(ReplicatedStorage, "CoinComm")
local GotCoinEvent = CoinComm:CreateSignal("GotCoinEvent")
local UpdateCoinAmountEvent = CoinComm:CreateSignal("UpdateCoinAmountEvent")
local FellInWaterEvent = CoinComm:CreateSignal("FellInWaterEvent")
local GotHitEvent = CoinComm:CreateSignal("GotHitEvent")

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.CoinArena
local CoinModel = GameExtras.Coin
local CoinBagModel = GameExtras.CoinBag
local GotHit:RemoteEvent = GameExtras.GotHit
local SpawnPlayerCoins:RemoteEvent = GameExtras.SpawnPlayerCoins
local HitProtection:Part = GameExtras.HitProtection
local CoinBillboardUI:BillboardGui = GameExtras.CoinBillboardGui
local CrownBillboardUI:BillboardGui = GameExtras.CrownBillboardGui


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

    --spawn coins task
    self:SetupCoinSpawns()
    
end

function module:ShieldPlayer(character, playSound)
    local canCollect = character:FindFirstChild("CoinArena_CanCollect")
        if canCollect then
            canCollect.Value = false
        end
        local canHit = character:FindFirstChild("CoinArena_CanHit")
        canHit.Value = false
        
         --add shield
         local newShield = HitProtection:Clone()
         newShield.Parent = character
         local weld = Instance.new("Weld")
         weld.Part0 = newShield
         weld.Part1 = character.HumanoidRootPart
         weld.Parent = newShield
         local sound = newShield:FindFirstChild("HitSound")
         if sound and playSound == true then
            sound:Play()
         end
 
         task.spawn(function()
            task.wait(.3)
            if canCollect then
                canCollect.Value = true
            end
         end)

        task.spawn(function()
            task.wait(invulTime)
            canHit.Value = true
            newShield:Destroy()
        end)
end

function module:Start()
   
    self.CrownBB = CrownBillboardUI:Clone()
    print("start")
   --hazards
   self:SetupHazards()
    self.GotHitThread = GotHit.OnServerEvent:Connect(function(sender, otherCharacter)
        print(otherCharacter)
        local canHit = otherCharacter:FindFirstChild("CoinArena_CanHit")
        if not canHit then return end
        if canHit.Value == false then return end

        local otherPlayer = Players:GetPlayerFromCharacter(otherCharacter)
        local senderCharacter = workspace:FindFirstChild(sender.Name)
        GotHitEvent:Fire(otherPlayer, senderCharacter.HumanoidRootPart)
        self:ShieldPlayer(otherCharacter, true)
        --print("sender: " .. sender.Name .. " hit player: " .. otherPlayer.Name)
       
    
    end)
    self.SpawnCoinsThread = SpawnPlayerCoins.OnServerEvent:Connect(function(sender, position)
        self:SpawnPhysicsCoins(sender, position)
    end)



    --let players hit each other now
    for player, score in self.MiniGame.Players do
        local Character = player.Character
        if not Character then continue end
        local canHit = player.Character:FindFirstChild("CoinArena_CanHit")
        if canHit then
            print(player.Name .." can hit now")
            canHit.Value = true
        end
    end

    --Knit.GetService("CoinArenaService").Client.StartGame:FireAll()
    
    return ROUND_TIME

end
function module:SpawnPhysicsCoins(player, position)
    --drop 30% of coins
    local droppedCoinAmount = math.floor( self.MiniGame.Players[player]*.3)
   
    self.MiniGame.Players[player] -= droppedCoinAmount
    self:UpdateCoinDisplay(player,self.MiniGame.Players[player])

    for i = 1, droppedCoinAmount, 1 do
        local newCoin:BasePart = CoinModel:Clone()
        newCoin.Parent = workspace.CoinArena.Coins
        
        local angle = i * 2 * math.pi / droppedCoinAmount
        local positionOnCircle = Vector3.new(math.sin(angle), 0, math.cos(angle))

        local coinPos = (positionOnCircle * 6 ) + position

        newCoin.Position = coinPos
        newCoin.Anchored = false
        newCoin.CanCollide = true
        CollectionService:RemoveTag(newCoin, "RotateContinuous")
        --newCoin:SetNetworkOwner(sender)
        newCoin:ApplyImpulseAtPosition(Vector3.new(90,-90,90), position)
        newCoin.Touched:Connect(function(hit)
            self:TouchedCoin(newCoin, hit)
        end)

    end
end
function module:TouchedHazard(character, otherPartRoot)
    --if self.GameOver.Value == true then return end
    local canHit = character:FindFirstChild("CoinArena_CanHit")
    if not canHit then return end
    if canHit.Value == false then return end

    local otherPlayer = Players:GetPlayerFromCharacter(character)
   
    local canCollect = character:FindFirstChild("CoinArena_CanCollect")
    if canCollect then
        canCollect.Value = false
    end

    GotHitEvent:Fire(otherPlayer, otherPartRoot)
    self:ShieldPlayer(character, true)
end
function module:GetWinners()
    local highestCoins = 0
    local winner = nil
    for _, player in ipairs(self.MiniGame.Players) do
        
        if self.MiniGame.Players[player] > highestCoins then
            highestCoins = self.MiniGame.Players[player]
            winner = player
        end
    end
    return winner
end
function module:UpdateCoinDisplay(player, coins)
    local billboard = player.Character.Head:FindFirstChild("CoinBillboardGui")
    if billboard then
        billboard.Frame.TextLabel.Text = "x" .. coins
    end
    local winner = self:GetWinners()
    if not winner then return end
    if self.CrownBB.Parent ~= winner.Character.Head then
        self.CrownBB.Parent = winner.Character.Head
    end
    UpdateCoinAmountEvent:Fire(player, coins)

end
function module:TouchedCoin(coin, hit)
    --if self.GameOver.Value == false then
        local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if player then
            local canCollect = player.Character:FindFirstChild("CoinArena_CanCollect")
            if not canCollect then return end
            if canCollect.Value == true then
                    
                self.MiniGame.Players[player] += coin:GetAttribute("Value")
                self:UpdateCoinDisplay(player,self.MiniGame.Players[player])
                GotCoinEvent:Fire(player, self.MiniGame.Players[player], coin:GetAttribute("Value"))
                --Knit.GetService("CoinArenaService").Client.GotCoin:Fire(player, self.MiniGame.Players[player].Coins, coin:GetAttribute("Value"))
                coin:Destroy()
            end     
        end
   -- end
end

function module:SpawnCoin(spawn, highValue)

        local newCoin
        if highValue then
            newCoin = CoinBagModel:Clone()
            newCoin.PrimaryPart.Touched:Connect(function(hit)
                self:TouchedCoin(newCoin, hit)
            end)
        else
            newCoin = CoinModel:Clone()
            newCoin.Touched:Connect(function(hit)
                self:TouchedCoin(newCoin, hit)
            end)
        end

        newCoin.Parent = spawn
       
        MiniGameUtils.SpawnAroundPart(spawn, newCoin)
end
function  module:SetupCoinSpawns()
    self.SpawnerThreads = {}
    for _, spawn in ipairs(self.MiniGame.Game.CoinSpawns:GetChildren()) do
        local newThread = task.spawn(function()
           -- while self.GameOver.Value == false do
                task.wait()
                if #spawn:GetChildren() == 0 then
                    if spawn:GetAttribute("HighValue") then
                        task.wait(highValueCoinSpawnTime)
                        self:SpawnCoin(spawn, true)
                    else
                        task.wait(normalCoinSpawnTime)
                        self:SpawnCoin(spawn, false)
                    end
                end
                
            --end
           
            
        end)
        table.insert(self.SpawnerThreads, newThread)
    end

end
function  module:SetupHazards()
	for _, hazard in ipairs(self.MiniGame.Game.Hazards:GetChildren()) do
		local pp:BasePart = hazard.PrimaryPart
		if pp then
			pp.Touched:Connect(function(hit)
				local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
				if player then -- do stuff end end)
                    self:TouchedHazard(hit.Parent,pp)
				end
			end)
		end
	end

    -- set up the kill part at the bottom of water
    local killPart = self.MiniGame.Game:FindFirstChild("KillPart")
    if not killPart then return end
    killPart.Touched:Connect(function(hit)
        local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
        if player then
            --Knit.GetService("CoinArenaService").Client.FellInWater:Fire(player)
            FellInWaterEvent:Fire(player)
            --teleport player to random spawn
            local spawns = self.MiniGame.Game.PlayerRespawns:GetChildren()
            local randomSpawn = spawns[math.random(1,#spawns)]
            player.Character:PivotTo(CFrame.new(randomSpawn.Position))
            player.Character.HumanoidRootPart.Anchored = true
            --make them lose coins now
            task.spawn(function()
                self:ShieldPlayer(player.Character, false)
                task.wait(.2)
                player.Character.HumanoidRootPart.Anchored = false
                self:SpawnPhysicsCoins(player, player.Character.HumanoidRootPart.Position)
            end)
            
        end
    end)
end

function module:PrepPlayer(player)
    --spawn
    print("prep player")
    local spawns = self.MiniGame.Game.PlayerSpawns:GetChildren()
    local randomSpawn = spawns[math.random(1,#spawns)]
    MiniGameUtils.SpawnAroundPart(randomSpawn, player.Character)
    randomSpawn:Destroy()

    local canHit = player.Character:FindFirstChild("CoinArena_CanHit")
    if not canHit then
        canHit = Instance.new("BoolValue")
        canHit.Name = "CoinArena_CanHit"
        canHit.Parent = player.Character
    end
    canHit.Value = false

    local canCollect = player.Character:FindFirstChild("CoinArena_CanCollect")
    if not canCollect then
        canCollect = Instance.new("BoolValue")
        canCollect.Name = "CoinArena_CanCollect"
        canCollect.Parent = player.Character
    end
    canCollect.Value = true

    local newCoinBillboardUI = CoinBillboardUI:Clone()
    newCoinBillboardUI.Parent = player.Character.Head
    newCoinBillboardUI.Frame.TextLabel.Text = "x" .. startingCoins
    self.MiniGame.Players[player] = startingCoins
end
--- Called when a player joins during intermission
function module:JoinGame(player : Player)
    if player.Character then
        self:PrepPlayer(player)
        self._janitor:Add(function()
            if player then
                if player.Character then
                    if player.Character.PrimaryPart then
                        player.Character.PrimaryPart.Anchored = false
                    end
                end
            end
        end)

        
    end
end


--- Called every frame by the server during gameplay
function module:Update(players, dt, timeElapsed)
   -- self._timeElapsed += dt
end
function module:Destroy()
    --clean up
    for _, thread in ipairs(self.SpawnerThreads) do
        task.cancel(thread)
    end
    self.GotHitThread:Disconnect()
    self.SpawnCoinsThread:Disconnect()
    
    for _, player in ipairs(self.MiniGame.Players) do
        local coinbb = player.Character.Head:FindFirstChild("CoinBillboardGui")
        if coinbb then
            coinbb:Destroy()
        end
        local canHit:BoolValue = player.Character:FindFirstChild("CoinArena_CanHit")
        if canHit then
            canHit:Destroy()
        end
        local canCollect = player.Character:FindFirstChild("CoinArena_CanCollect")
        if canCollect then
            canHit:Destroy()
        end
    end
   
    if self.CrownBB then
        self.CrownBB:Destroy()
    end
    self.SpawnerThreads = {}
    self.MiniGame:Destroy()
end

return module