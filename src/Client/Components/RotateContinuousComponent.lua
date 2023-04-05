local ReplicatedStorage = game:GetService("ReplicatedStorage")

local components = require(ReplicatedStorage.Packages.Component)


local RotateContinuousComponent = components.new({
	Tag = "RotateContinuous",
})



function RotateContinuousComponent:Start()
    self.Speed = self.Instance:GetAttribute("Speed") or 1
    self.Update = task.spawn(function()
        while true do
            if self.Instance:IsA("BasePart") then
                self.Instance.Orientation += Vector3.new(0, self.Speed, 0)
            else
                self.Instance.PrimaryPart.CFrame = self.Instance.PrimaryPart.CFrame * CFrame.Angles(0,math.rad(self.Speed),0)
            end
           
            task.wait()
        end
    end)
    
end
function RotateContinuousComponent:Stop()
    if self.Update then
        task.cancel(self.Update)
    end
end

return RotateContinuousComponent