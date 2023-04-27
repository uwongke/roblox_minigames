local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local knit = require(ReplicatedStorage.Packages.Knit)
local UI = ReplicatedStorage.Assets.UI.MiniGames.DropDodge.DropDodgeUI
local HitProtection = ReplicatedStorage.Assets.MiniGameExtras.DropDodge.HitProtection
local DropDodgeController = knit.CreateController({
	Name = "DropDodgeController",
})


function DropDodgeController:KnitInit()
	--// services
	self.DropDodgeService = knit.GetService("DropDodgeService")

end

function DropDodgeController:KnitStart()
	
    self.DropDodgeService.PrepGame:Connect(function()
        --// add ui
         self.UI = UI:Clone()
        self.UI.Parent = game.Players.LocalPlayer.PlayerGui
    end)
	self.DropDodgeService.PlayerHit:Connect(function(healthRemaining, hit)
		self:RemoveHealth(healthRemaining, hit)
	end)
    self.DropDodgeService.PlayerEliminated:Connect(function(healthRemaining)
		self.UI:Destroy()
	end)

end
function DropDodgeController:RemoveHealth(healthRemaining, hit)
    print("remove health")
    local imageLabel:ImageLabel = self.UI.Frame:FindFirstChild(healthRemaining+1)
    if imageLabel then
        imageLabel.ImageColor3 = Color3.new(1, 1, 1)
    end
    if healthRemaining > 0 then
        --[[
        for _, part in ipairs(game.Players.LocalPlayer.Character:GetChildren()) do
            if (part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Accessory")) and part.Name ~= "HumanoidRootPart" then
                local tweenPart = part
                    if part:IsA("Accessory") then
                        tweenPart = part.Handle
                    end
                     --// Tween Info & Goal
					local tweenInfo = TweenInfo.new(
							1.5, -- Time
							Enum.EasingStyle.Linear, -- EasingStyle
							Enum.EasingDirection.InOut, -- EasingDirection
							0, -- RepeatCount
							true, -- Reverses
							0 -- DelayTime
						)

					local tweenGoals = {Transparency = 0.6}
						
					local tween = TweenService:Create(tweenPart, tweenInfo, tweenGoals)
					tween:Play()
            end
        end
        ]]--

        local character = game.Players.LocalPlayer.Character

         --apply impulse
         local direction : Vector3 = ( character.HumanoidRootPart.Position - hit.Position).Unit
         local lookDirection: Vector3 = CFrame.lookAt(hit.Position, character.HumanoidRootPart.Position).LookVector --unit vector of the direction towards the target
         local noVertical:Vector3 = Vector3.new(lookDirection.X,0,lookDirection.Z)
         character.HumanoidRootPart:ApplyImpulse(noVertical*50000)

        --add feedback
        local newShield = HitProtection:Clone()
        newShield.Parent = character
        local weld = Instance.new("Weld")
        weld.Part0 = newShield
        weld.Part1 = character.HumanoidRootPart
        weld.Parent = newShield
        task.spawn(function()
            task.wait(3)
            newShield:Destroy()
        end)

       
    end
   

end
return DropDodgeController