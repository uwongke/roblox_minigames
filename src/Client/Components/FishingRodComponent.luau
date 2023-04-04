local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Packages.Component)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RANDOM = Random.new(os.time())
local FishingRod = components.new({
	Tag = "FishingRod",
})

FishingRod.Started:Connect(function(component)
    local rod = component.Instance
end)

function FishingRod:Construct()
end

function FishingRod:Start()
    local rod = self.Instance
    self._Janitor = Janitor.new()

    local pole = rod:WaitForChild("FishingRod")
    local bobber = rod:WaitForChild("Bobber")
    local pivot = pole:FindFirstChild("Anchor").WorldCFrame
    local offset = pivot:toObjectSpace(pole.CFrame)
    self.offset = offset
    self.pivotBase = pivot
    self._timeElapsed = RANDOM:NextNumber()

    local bobberOffset = rod:WaitForChild("Bobber").CFrame:toObjectSpace(pole.CFrame)

    rod.AttributeChanged:Connect(function(attName)
        if attName == "Caught" then
            self._inCatchAnim = true
            local finalCf = pivot * CFrame.Angles(0, 0, math.rad(100)) * offset
            local bobberCf = finalCf * bobberOffset
            local ti = TweenInfo.new(
                0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut, 0, true
            )

            TweenService:Create(bobber, TweenInfo.new(
                0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true
            ), {
                CFrame = bobber.CFrame * CFrame.new(0, 15, 0)
            }):Play()

            TweenService:Create(pole, ti, {
                CFrame = finalCf
            }):Play()
            task.delay(0.5, function()
                self._inCatchAnim = false
            end)
        end
    end)
    print("Started rod!")
end

function FishingRod:Stop()
end

function FishingRod:HeartbeatUpdate(dt)
    self._timeElapsed += dt
    local rod = self.Instance
    local pole = rod:WaitForChild("FishingRod")
    local line = rod:WaitForChild("Line")
    local bobber = rod:WaitForChild("Bobber")
    if rod:GetAttribute("HasFish") and not self._inCatchAnim then
        -- rotate and stuff
        local speed = math.sin(self._timeElapsed * 20)
        local newPivot = self.pivotBase * CFrame.Angles(0, 0, speed / 20)
        pole.CFrame = newPivot * self.offset
        bobber.CFrame = bobber.CFrame * CFrame.Angles(0, math.rad(5), 0)
        if line.CurveSize0 ~= 0 then
            line.CurveSize0 = 0
        end
    elseif not self._inCatchAnim then
        if line.CurveSize0 == 0 then
            line.CurveSize0 = -1
        end
    end
end

function FishingRod:SteppedUpdate(dt)
end

function FishingRod:RenderSteppedUpdate(dt)
end

return FishingRod