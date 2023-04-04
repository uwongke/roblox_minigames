local module = {}
module.__index = module
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- what will be spawned
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTemplate = ReplicatedStorage.Assets.MiniGames.DropDodge
local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

--things needed for the game
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.DropDodge
local DroppableObjects = GameExtras.Drops
local Telegraph_Circle = GameExtras.Telegraph_Circle
local Telegraph_Square = GameExtras.Telegraph_Square

function module.new(SpawnLocation)
    local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    setmetatable(data,module)
    task.spawn(function()
        task.wait(3)
        data:PrepGame()
    end)
    return data
end
local function tweenPivot(Object: BasePart | Model, CF: CFrame, tweenTime: number)
	if Object then
		local CFrameValue = Instance.new("CFrameValue")
		CFrameValue.Value = Object:GetPivot()

		local TweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Exponential, Enum.EasingDirection.In, 0)

		CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
			Object:PivotTo(CFrameValue.Value)
		end)

		local tween = TweenService:Create(CFrameValue, TweenInfo, { Value = CF })
		tween:Play()

		tween.Completed:Connect(function()
            CFrameValue:Destroy()
        end)
		
	end
end
local function TweenModelTransparency(Object: Model, transparency: number, time: number, deleteAfter:boolean)
    if Object then
        local children = Object:GetChildren()
	
        local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear, Enum.EasingDirection.In) 

        for _, childPart in pairs(children) do
            local tweentrans = game:GetService("TweenService"):Create(childPart,tweenInfo,{Transparency = transparency})
            if deleteAfter then
                tweentrans.Completed:Connect(function()
                    childPart:Destroy()
                end)
            end
            tweentrans:Play()
        end
    end
end
local function ScaleModel(model,a)
	local base = model.PrimaryPart.Position
	for _,part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Position = base:Lerp(part.Position,a)
			part.Size *= a
		end
	end
end
function module:PrepGame()
   
    self.DropTime = 2 --how long it takes for object to get game area
    self.TimeBetweenDrops = 5 --how long it takes for object to get game area
    self.NumberOfHits = 3 -- how many hits a player can take before elimination
    self.ElapsedTime = 0 --elapsed game time
    self.ActivePlayers = {}


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
    task.wait(1)
    messageData.Message = ""
    self.Message.Value = HttpService:JSONEncode(messageData)


    


    self.ElapsedTimeThread = task.spawn(function()
        while true do
            task.wait(1)
            self.ElapsedTime += 1
            if self.ElapsedTime % 5 == 0 and self.TimeBetweenDrops > .9 then
                self.TimeBetweenDrops = (self.TimeBetweenDrops * .8)
            end
        end
     
    end)
    self.DropThread = task.spawn(function()
        while true do
            print(self.TimeBetweenDrops)
            task.wait(math.random(self.TimeBetweenDrops-(self.TimeBetweenDrops*.2),self.TimeBetweenDrops+(self.TimeBetweenDrops*.2)))
            self:SpawnDrop(1)

        end
    end)
end
function module:SpawnDrop(amount)
    for i = 1, amount, 1 do
        local drops = DroppableObjects:GetChildren()
        local drop: Model = drops[math.random(1, #drops)]:Clone()
        ScaleModel(drop, math.random(1,1.5))
        local bounds = self.Game.Bounds.GameArea
        print(bounds.Size)
        print(drop.HitBox.Size)
        local randomPosition = Vector3.new( math.random(bounds.Position.X - (bounds.Size.X/2) + drop.HitBox.Size.X, bounds.Position.X + (bounds.Size.X/2) - drop.HitBox.Size.X),
                                            bounds.Position.Y + 40,
                                            math.random(bounds.Position.Z - (bounds.Size.Z/2) + drop.HitBox.Size.Z, bounds.Position.Z + (bounds.Size.Z/2) - drop.HitBox.Size.Z))
        drop:PivotTo(CFrame.new() + randomPosition)
        drop.Parent = self.Game

        -- touch (damage)
        drop.HitBox.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                --check if we can do damage to player
                local canHit = player.Character:FindFirstChild("DropDodge_CanHit")
                if not canHit then return end
                if canHit.Value == true then
                    local playerHealth = player.Character:FindFirstChild("DropDodge_Health")
                    if playerHealth then
                        print(player.Name .. " hit!")
                        playerHealth.Value -= 1
                        canHit.Value = false
                        Knit.GetService("DropDodgeService").Client.PlayerHit:Fire(player,playerHealth.Value, drop.HitBox)
                        if playerHealth.Value == 0 then
                            --player is eliminated
                            print(player.Name .. " is eliminated.")
                            MiniGameUtils.SpawnAroundPart(workspace.LobbySpawn, player.Character)
                            --send event to reset camera
                            Knit.GetService("MiniGameService").Client.PlayerGotEliminated:Fire(player, true)
                            Knit.GetService("DropDodgeService").Client.PlayerEliminated:Fire(player)
                           table.remove(self.ActivePlayers,table.find(self.ActivePlayers,player))
                           if #self.ActivePlayers <= 1 then
                                if self.ActivePlayers[1] then
                                    print(self.ActivePlayers[1].Name .. " wins.")
                                end
                                self.GameOver.Value = true
                           end
                        end
                        --hit cool down
                        task.spawn(function()
                            --this could probably be sent client side
                            --local transparencyTween = TweenService:Cre
                            task.wait(3)
                            canHit.Value = true
                            print(player.Name .. " can be hit again.")
                        end)
                    end
                end
                
            end
        end)
        local endPosition = Vector3.new(drop.PrimaryPart.Position.X,bounds.Position.Y,drop.PrimaryPart.Position.Z)
        tweenPivot(drop, CFrame.new(endPosition),self.DropTime)

        --telegraph
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {self.Game.Bounds.GameArea}
        raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
       
        local raycastResult = workspace:Raycast(drop.PrimaryPart.Position,Vector3.new(0,-100,0), raycastParams)
        if raycastResult then
            local telegraph
            if drop:GetAttribute("TelegraphShape") == "Circle" then
                telegraph = Telegraph_Circle:Clone()
            else
                telegraph = Telegraph_Square:Clone()
            end
            telegraph.Parent = self.Game
            telegraph.Position  = raycastResult.Position
            local telegraphDecalTween:Tween = TweenService:Create(telegraph.Decal,TweenInfo.new(self.DropTime),{Transparency = 0})
            telegraphDecalTween:Play()
            local telegraphSizeTween:Tween = TweenService:Create(telegraph,TweenInfo.new(self.DropTime),{Size = Vector3.new(.15,drop.HitBox.Size.X,drop.HitBox.Size.Y)})
            --clean up drop after a few seconds
            telegraphDecalTween.Completed:Connect(function()
                --stop in case it hasn't already
                telegraphSizeTween:Cancel()
                telegraph:Destroy()
                task.spawn(function()
                    TweenModelTransparency(drop,1,3,true)
                end)

            end)

            telegraphSizeTween:Play()
            telegraphDecalTween:Play()
        else
            print("ray cast failed")
            print(drop.PrimaryPart.Position)
        end
    end
end
function  module:JoinGame(player)
    if self.CanJoin.Value then
        local data = {
            Time = 0,
            Name = player.DisplayName,
            Position = 1
        }
        self.Players[player] = data
        table.insert(self.ActivePlayers, player)
        Knit.GetService("DropDodgeService").Client.PrepGame:Fire(player) --fire to set up client stuff
        MiniGameUtils.SpawnAroundPart(self.Game.GameStart, player.Character)
        print(player.DisplayName .. " has Joined the game")

        --set health tag
        local health = player.Character:FindFirstChild("DropDodge_Health")
        if not health then
            health = Instance.new("NumberValue")
            health.Name = "DropDodge_Health"
            health.Parent = player.Character
        end
        health.Value = self.NumberOfHits
      
       
        --set can hit tag
        local canHit = player.Character:FindFirstChild("DropDodge_CanHit")
        if not canHit then
            canHit = Instance.new("BoolValue")
            canHit.Name = "DropDodge_CanHit"
            canHit.Parent = player.Character
        end
        canHit.Value = true
        --send join event for camera controller
        Knit.GetService("MiniGameService").Client.PlayerJoinedMiniGame:Fire(player)

        return true
    end
    return false
end

function module:Destroy()
    --clean up
    task.cancel(self.ElapsedTimeThread)
    task.cancel(self.DropThread)
    self.Game:Destroy()
    self = nil
end

return module