local ReplicatedStorage = game:GetService("ReplicatedStorage")

local components = require(ReplicatedStorage.Packages.Component)


local JumpPadComponent = components.new({
	Tag = "JumpPad",
})



function JumpPadComponent:Start()
    self.JumpVelocity = self.Instance:GetAttribute("JumpVelocity")
    if self.JumpVelocity then
        self.Instance.Touched:Connect(function(touch)
            local char = touch.Parent
            if game.Players:GetPlayerFromCharacter(char) and char:FindFirstChild("HumanoidRootPart") and not char:FindFirstChild("HumanoidRootPart"):FindFirstChild("BodyVelocity") then

                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Velocity = self.JumpVelocity
                bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyVelocity.P = math.huge
                
                bodyVelocity.Parent = char.HumanoidRootPart
                if self.Instance:FindFirstChild("Sound") then
                    self.Instance.Sound:Play()
                end
                task.wait(0.3)
                bodyVelocity:Destroy()		
            end
        end)
    end
    
end
function JumpPadComponent:Stop()
end

return JumpPadComponent