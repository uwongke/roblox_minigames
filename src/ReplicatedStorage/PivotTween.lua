--[[
    Author: Aaron Tole(RealistEntertainment)
    Created: 11/8/2022

    Description: Makes it possible to tween the pivot function
]]

local TweenService = game:GetService("TweenService")

local PivotTween = {}

function PivotTween:TweenPivot(Object: BasePart | Model, CF: CFrame, tweenInf: TweenInfo, yielding: boolean?)
	if Object and CF and tweenInf then
		local CFrameValue = Instance.new("CFrameValue")
		CFrameValue.Value = Object:GetPivot()

		CFrameValue:GetPropertyChangedSignal("Value"):Connect(function()
			if Object then
				Object:PivotTo(CFrameValue.Value)
			end
		end)

		local tween = TweenService:Create(CFrameValue, tweenInf, { Value = CF })
		tween:Play()

		if yielding then
			tween.Completed:Wait()
			CFrameValue:Destroy()
		else
			task.spawn(function()
				tween.Completed:Wait()
				tween.Completed:Wait()
			end)
		end
	else
		warn("Failed to properly fill out arguments for TweenPivot")
	end
end

return PivotTween
