local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local knit = require(ReplicatedStorage.Packages.Knit)
local MiniGameExtras = ReplicatedStorage.Assets.MiniGameExtras.CoinArena
local UI = ReplicatedStorage.Assets.UI.MiniGames.CoinArenaUI
local CoinSound:Sound = MiniGameExtras.CoinSound
local CoinBagSound:Sound = MiniGameExtras.CoinBagSound
local WaterSplashSound:Sound = MiniGameExtras.WaterSplash
local UiTransition= require(MiniGameExtras.UiTransitions)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local punchAnimation:Animation = Instance.new("Animation")
punchAnimation.AnimationId = "rbxassetid://13072788048"
local hitAnimation:Animation = Instance.new("Animation")
hitAnimation.AnimationId = "rbxassetid://13072803055"

local RaycastHitbox = require(MiniGameExtras.RaycastHitboxV4)
local Hitbox --- to be initialized when equipped
local PunchHitBoxModel = MiniGameExtras.PunchHitBox
local CoinModel:Part = MiniGameExtras.Coin

local GotHit:RemoteEvent = MiniGameExtras.GotHit
local SpawnPlayerCoins:RemoteEvent = MiniGameExtras.SpawnPlayerCoins

local CoinArenaController = knit.CreateController({
	Name = "CoinArenaController",
})


function CoinArenaController:KnitInit()
	--// services
	self.CoinArenaService = knit.GetService("CoinArenaService")
end

function CoinArenaController:OnButton1Down()
	if self.CanPunch then
        self.PunchAnimationTrack:Play()
        self.CanPunch = false
        task.spawn(function()
            task.wait(.6)
            self.CanPunch = true
        end)
    end
   
end
function CoinArenaController:Punched(hit, humanoid)
   -- local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
    --if player then
       -- print("hit " .. player.Name)
   -- end
   if humanoid then
        print("hit " .. humanoid.Parent.Name)
        --no client to client, so have to go through server first
        GotHit:FireServer(humanoid.Parent)
    end
   
end
function CoinArenaController:KnitStart()
	
     --game stuff
     --starting coins
     self.Coins = 25
     self.CanPunch = true
    
     
    self.CoinArenaService.PrepGame:Connect(function()
        --// add ui
        self.UI = UI:Clone()
        self.UI.Parent = game.Players.LocalPlayer.PlayerGui
        self.UI.Frame.TextLabel.Text = "x" .. self.Coins

        --set player speed
        game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 22
        --anchor player
        game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = true
        --animations
        local animator = player.Character.Humanoid:WaitForChild("Animator")
        self.PunchAnimationTrack = animator:LoadAnimation(punchAnimation)
        self.HitAnimationTrack = animator:LoadAnimation(hitAnimation)
        self.HitAnimationTrack.Looped = true

        local newPunchHitBox = PunchHitBoxModel:Clone()
        newPunchHitBox.Parent = player.Character.RightHand
        local weld = Instance.new("Weld")
        weld.Part0 = newPunchHitBox
        weld.Part1 = player.Character.RightHand
        weld.Parent = newPunchHitBox

        Hitbox = RaycastHitbox.new(newPunchHitBox)
        Hitbox.DetectionMode = RaycastHitbox.DetectionMode.Default
        Hitbox.Visualizer = true
        local raycastparams:RaycastParams = RaycastParams.new()
        raycastparams.FilterDescendantsInstances = {player.Character}
        raycastparams.FilterType = Enum.RaycastFilterType.Blacklist
        Hitbox.RaycastParams = raycastparams
        Hitbox.OnHit:Connect(function(hit, humanoid)
            self:Punched(hit, humanoid)
        end)

        self.PunchAnimationTrack:GetMarkerReachedSignal("hitbox_on"):Connect(function(paramString)
            Hitbox:HitStart()
        end)
        self.PunchAnimationTrack:GetMarkerReachedSignal("hitbox_off"):Connect(function(paramString)
            Hitbox:HitStop()
        end)

        self.PunchListener = mouse.Button1Down:Connect(function()
            self:OnButton1Down()
        end)

    end)
    self.CoinArenaService.FellInWater:Connect(function()
        WaterSplashSound:Play()
        UiTransition.Transition("CircleGrow", .2, 0, Color3.new(0.023529411764705882, 0.7254901960784313, 0.9019607843137255), nil)
    end)
    self.CoinArenaService.GotCoin:Connect(function(newCoinAmount, coinsPickedUp)
       --self.Coins += 1
       --self.CoinArenaService:UpdateCoinDisplay(self.Coins)
       self.UI.Frame.TextLabel.Text = "x" .. newCoinAmount
       if coinsPickedUp > 1 then
        if CoinBagSound then
            CoinBagSound:Play()
        end
       else
            if CoinSound then
                CoinSound:Play()
            end
        end
    end)
    self.CoinArenaService.UpdateCoinAmount:Connect(function(newCoinAmount)
        if not self.UI.Frame then return end
        self.UI.Frame.TextLabel.Text = "x" .. newCoinAmount
     end)
    self.CoinArenaService.StartGame:Connect(function()
        game.Players.LocalPlayer.Character.HumanoidRootPart.Anchored = false
   end)
    self.CoinArenaService.EndGame:Connect(function()
         --set player speed
         game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
         self.UI:Destroy()
         Hitbox:Destroy()
         local punchHitBox = player.Character.RightHand:FindFirstChild("PunchHitBox")
         if punchHitBox then
            punchHitBox:Destroy()
         end
         self.PunchListener:Disconnect()

    end)
end

return CoinArenaController