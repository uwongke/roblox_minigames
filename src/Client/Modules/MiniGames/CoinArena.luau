--[[
    CoinArena.luau
    Author: Justin (synnull)
    Description: Client-sided stuff for coin arena
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
local Template = ReplicatedStorage.Assets.UI.MiniGames.CoinArenaUI


--extras
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.CoinArena
local CoinSound:Sound = GameExtras.CoinSound
local CoinBagSound:Sound = GameExtras.CoinBagSound
local RaycastHitbox = require(GameExtras.RaycastHitboxV4)
local Hitbox --- to be initialized when equipped
local PunchHitBoxModel = GameExtras.PunchHitBox
local WaterSplashSound:Sound = GameExtras.WaterSplash
local UiTransition= require(GameExtras.UiTransitions)

local GotHit:RemoteEvent = GameExtras.GotHit
local SpawnPlayerCoins:RemoteEvent = GameExtras.SpawnPlayerCoins

local punchAnimation:Animation = Instance.new("Animation")
punchAnimation.AnimationId = "rbxassetid://13072788048"
local hitAnimation:Animation = Instance.new("Animation")
hitAnimation.AnimationId = "rbxassetid://13072803055"

local module = {}

function module:Init(newJanitor)
    self:SetupPunch()
    -- return display info
    return "Coin Arena!", 
    "Collect the most coins. Punch other players to drop their coins.",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
   
    -- create ui link
    self.Coins = 5
    local CoinComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "CoinComm")
    local GotCoinEvent = CoinComm:GetSignal("GotCoinEvent")
    local GotHitEvent = CoinComm:GetSignal("GotHitEvent")
    local FellInWaterEvent = CoinComm:GetSignal("FellInWaterEvent")
    -- create score display
    --local GUI = Template:Clone()
    --GUI.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    --GUI.Frame.TextLabel.Text = "x" .. self.Coins
    --set player speed
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 22

    janitor:Add(GotCoinEvent:Connect(function(newCoinAmount, coinsPickedUp)
       -- GUI.Frame.TextLabel.Text = "x" .. newCoinAmount
       if coinsPickedUp > 1 then
        if CoinBagSound then
            CoinBagSound:Play()
        end
       else
            if CoinSound then
                CoinSound:Play()
            end
        end
    end))

    janitor:Add(FellInWaterEvent:Connect(function()
        WaterSplashSound:Play()
        UiTransition.Transition("CircleGrow", .2, 0, Color3.new(0.023529411764705882, 0.7254901960784313, 0.9019607843137255), nil)
    end))
    janitor:Add(GotHitEvent:Connect(function(otherPlayerRoot)
      --local otherPlayerRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
      if not otherPlayerRoot then return end
      local localRoot = game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")


      --drop 30% of coins
     -- local droppedCoinAmount = math.floor(self.Coins*.3)
      --self.Coins -= droppedCoinAmount
      --self.CoinArenaService:UpdateCoinDisplay(self.Coins)
      --self.UI.Frame.TextLabel.Text = "x" .. self.Coins
      SpawnPlayerCoins:FireServer(localRoot.Position)

      --play hit animation
      self.HitAnimationTrack:Play()
      task.spawn(function()
          task.wait(.3)
          self.HitAnimationTrack:Stop()
      end)

      --local direction : Vector3 = ( localRoot.Position - otherPlayerRoot.Position).Unit
      local lookDirection: Vector3 = CFrame.lookAt(otherPlayerRoot.Position,localRoot.Position).LookVector --unit vector of the direction towards the target
      local noVertical:Vector3 = Vector3.new(lookDirection.X,0,lookDirection.Z)
      localRoot:ApplyImpulse(noVertical*5000)
    end))


    --janitor:Add(GUI)
end

function module:SetupPunch()
    
    self.CanPunch = true
    local animator = game.Players.LocalPlayer.Character.Humanoid:WaitForChild("Animator")
        self.PunchAnimationTrack = animator:LoadAnimation(punchAnimation)
        self.HitAnimationTrack = animator:LoadAnimation(hitAnimation)
        self.HitAnimationTrack.Looped = true

        local newPunchHitBox = PunchHitBoxModel:Clone()
        newPunchHitBox.Parent = game.Players.LocalPlayer.Character.RightHand
        local weld = Instance.new("Weld")
        weld.Part0 = newPunchHitBox
        weld.Part1 = game.Players.LocalPlayer.Character.RightHand
        weld.Parent = newPunchHitBox

        Hitbox = RaycastHitbox.new(newPunchHitBox)
        Hitbox.DetectionMode = RaycastHitbox.DetectionMode.Default
        Hitbox.Visualizer = true
        local raycastparams:RaycastParams = RaycastParams.new()
        raycastparams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
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

        self.PunchListener = game.Players.LocalPlayer:GetMouse().Button1Down:Connect(function()
            self:OnButton1Down()
        end)
end
function module:Punched(hit, humanoid)
   if humanoid then
        print("hit " .. humanoid.Parent.Name)
        GotHit:FireServer(humanoid.Parent)
    end
   
end
function module:OnButton1Down()
	if self.CanPunch then
        self.PunchAnimationTrack:Play()
        self.CanPunch = false
        task.spawn(function()
            task.wait(.6)
            self.CanPunch = true
        end)
    end
   
end
function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Destroy()
    -- no need for external clean up
     --set player speed
     game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 16
     Hitbox:Destroy()
     local punchHitBox =  game.Players.LocalPlayer.Character.RightHand:FindFirstChild("PunchHitBox")
     if punchHitBox then
        punchHitBox:Destroy()
     end
     self.PunchListener:Disconnect()
end

return module