local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.CoinArena
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--game vars
local coinsPerSpawn = 10 -- +- 5
local invulTime = 3  --invul time after player is hit
local duration = 90
local startingCoins = 25
--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.CoinArena
local CoinModel = GameExtras.Coin
local GotHit:RemoteEvent = GameExtras.GotHit
local SpawnPlayerCoins:RemoteEvent = GameExtras.SpawnPlayerCoins
local HitProtection:Part = GameExtras.HitProtection
local CoinBillboardUI:BillboardGui = GameExtras.CoinBillboardGui

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
   
    self.ActivePlayers = {}
    self.ElapsedTime = 0 --elapsed game time



    GotHit.OnServerEvent:Connect(function(sender, otherCharacter)
        print(otherCharacter)
        local canHit = otherCharacter:FindFirstChild("CoinArena_CanHit")
        if not canHit then return end
        if canHit.Value == false then return end

        local otherPlayer = Players:GetPlayerFromCharacter(otherCharacter)
        print(otherPlayer)
        print("sender: " .. sender.Name .. " hit player: " .. otherPlayer.Name)
       
        local canCollect = otherCharacter:FindFirstChild("CoinArena_CanCollect")
        if canCollect then
            canCollect.Value = false
        end

        GotHit:FireClient(otherPlayer, sender)
        canHit.Value = false

         --add shield
         local newShield = HitProtection:Clone()
         newShield.Parent = otherCharacter
         local weld = Instance.new("Weld")
         weld.Part0 = newShield
         weld.Part1 = otherCharacter.HumanoidRootPart
         weld.Parent = newShield
         local sound = newShield:FindFirstChild("HitSound")
         if sound then
            sound:Play()
            print("play sound")
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
    end)
    SpawnPlayerCoins.OnServerEvent:Connect(function(sender, position)
        --drop 30% of coins
        local droppedCoinAmount = math.floor( self.Players[sender].Coins*.3)
        self.Players[sender].Coins -= droppedCoinAmount
        self:UpdateCoinDisplay(sender,self.Players[sender].Coins)

        for i = 1, droppedCoinAmount, 1 do
            local newCoin = CoinModel:Clone()
            newCoin.Parent = workspace.CoinArena.Coins
            
            local angle = i * 2 * math.pi / droppedCoinAmount
            local positionOnCircle = Vector3.new(math.sin(angle), 0, math.cos(angle))

            local coinPos = (positionOnCircle * 6 ) + position

            newCoin.Position = coinPos
            newCoin.Touched:Connect(function(hit)
                self:TouchedCoin(newCoin, hit)
            end)

        end
    end)

    Knit.GetService("CoinArenaService"):GamePrepped(self)


    --start count down
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
    messageData.Message = "Collect the most coins. Punch other players to drop their coins."
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

    --let players hit each other now
    for _, player in ipairs(self.ActivePlayers) do
        local canHit = player.Character:FindFirstChild("CoinArena_CanHit")
        if canHit then
            canHit.Value = true
        end
    end
    --spawn some coins to start
    self:SpawnCoins()

    self.ElapsedTimeThread = task.spawn(function()
        while true do
            task.wait(1)
            self.ElapsedTime += 1
            if self.ElapsedTime % 4 == 0 and  #self.Game.Coins:GetChildren() < 6 then
                self:SpawnCoins()
            end
        end
     
    end)

   --main timer
     -- count down 
     count = duration
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
     for _, player in ipairs(self.ActivePlayers) do
        local coinbb = player.Character.Head:FindFirstChild("CoinBillboardGui")
        if coinbb then
            coinbb:Destroy()
        end
    end
     Knit.GetService("CoinArenaService").Client.EndGame:FireAll()

     self.GameOver.Value = true
 
     messageData.Message="Times up!"
     self.Message.Value = HttpService:JSONEncode(messageData)
  
     task.wait(1)
 
     messageData.Timer = ""
     messageData.Message = self:GetWinner().Name .. " won!"
 
     self.Message.Value = HttpService:JSONEncode(messageData)
    
    

end
function module:GetWinner()
    local highestCoins = 0
    local winner = nil
    for _, player in ipairs(self.ActivePlayers) do
        
        if self.Players[player].Coins > highestCoins then
            highestCoins = self.Players[player].Coins
            winner = player
        end
    end
    return winner
end
function module:UpdateCoinDisplay(player, coins)
    print(player.Name .. " " .. coins)
    local billboard = player.Character.Head:FindFirstChild("CoinBillboardGui")
    if billboard then
        billboard.Frame.TextLabel.Text = "x" .. coins
    end
    
end
function module:TouchedCoin(coin, hit)
    local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
            if player then
                local canCollect = player.Character:FindFirstChild("CoinArena_CanCollect")
                if not canCollect then return end
                if canCollect.Value == true then
                    
                    self.Players[player].Coins += 1
                    self:UpdateCoinDisplay(player,self.Players[player].Coins)
                    Knit.GetService("CoinArenaService").Client.GotCoin:Fire(player, self.Players[player].Coins)
                    coin:Destroy()
                end
                
            end
end

function  module:SpawnCoins(player)
    local amount = math.random(coinsPerSpawn-2, coinsPerSpawn+2)
    local spawns = self.Game.CoinSpawns:GetChildren()
    for i = 1, amount, 1 do
        local newCoin = CoinModel:Clone()
        newCoin.Parent = self.Game.Coins
        newCoin.Touched:Connect(function(hit)
            self:TouchedCoin(newCoin, hit)
        end)
        MiniGameUtils.SpawnAroundPart(spawns[math.random(1,#spawns)], newCoin)
    end
end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Coins = startingCoins,
            Name = player.DisplayName
        }
        self.Players[player] = data
        table.insert(self.ActivePlayers, player)
        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        print(player.DisplayName .. " has Joined the game")

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

        Knit.GetService("CoinArenaService").Client.PrepGame:Fire(player)

        return true
    end
    return false
end

function module:Destroy()
    --clean up
    task.cancel(self.ElapsedTimeThread)
    self.Game:Destroy()
    self = nil
end

return module