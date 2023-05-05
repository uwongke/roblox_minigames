--[[
    FoamSaber.luau
    Author: Justin Kelly (Synnull)
    Description: Client-sided info for FoamSaber under the new minigame engine
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ClientComm = require(ReplicatedStorage.Packages.Comm).ClientComm
--local Template = ReplicatedStorage.Assets.UI.MiniGames.NewFishingHeroUI

local module = {}

function module:Init(newJanitor)
    -- return display info
    return "Foam Saber!", 
    "Hit other players with your saber to earn points. Avoid getting hit to earn points, too. The player with the most points wins!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    -- create ui link
    local SaberComm = ClientComm.new(game:GetService("ReplicatedStorage"), true, "SaberComm")
    local GotHitEvent = SaberComm:GetSignal("GotHitEvent")
    local GotPointsEvent = SaberComm:GetSignal("GotPointsEvent")

    janitor:Add(GotHitEvent:Connect(function()
        --flash screen red on hit
        local flash = game.Lighting:FindFirstChild("FoamSaber_ColorCorrection")
        if not flash then
            flash = Instance.new("ColorCorrectionEffect")
        end
        flash.Name = "FoamSaber_ColorCorrection"
        flash.Parent = game.Lighting
        flash.TintColor = Color3.fromRGB(255, 0, 0) -- to change the screen flash color then change 255, 0, 0 to what color you want!
        local tween = game:GetService("TweenService"):Create(flash, TweenInfo.new(0.3), {TintColor = Color3.fromRGB(255, 255, 255)}):Play()
     end))
     janitor:Add(GotPointsEvent:Connect(function(points, part)
        local scoreDisplay: BillboardGui = Instance.new("BillboardGui")
		scoreDisplay.AlwaysOnTop = true
		scoreDisplay.StudsOffset = Vector3.new(0, 3, 0)
        --make larger points bigger
        if points > 1 then
            scoreDisplay.Size = UDim2.fromScale(3.2, 1.6)
        else
            scoreDisplay.Size = UDim2.fromScale(6, 3)
        end
		

		local scoreTextLabel: TextLabel = Instance.new("TextLabel")
		scoreTextLabel.Size = UDim2.new(1, 0, 1, 0)
		scoreTextLabel.Text = "+" .. points
		scoreTextLabel.TextScaled = true

		scoreTextLabel.TextColor3 = Color3.new(0.03137254901960784, 0.5725490196078431, 0.03137254901960784)
		scoreTextLabel.BackgroundTransparency = 1
		scoreTextLabel.TextStrokeTransparency = 0
		scoreTextLabel.Parent = scoreDisplay
		scoreDisplay.Parent = part
        
        local scoreTween = TweenService:Create(scoreTextLabel, TweenInfo.new(1.5), {Position = UDim2.new(0,0,-.9,0), TextTransparency = 1})
        --local scoreTween = TweenService:Create(scoreDisplay, TweenInfo.new(2.5), {StudsOffset = Vector3.new(0,9,0)})
        scoreTween.Completed:Connect(function()
            scoreDisplay:Destroy()
        end)
        scoreTween:Play()
     end))

end

function module:Update()
    -- no need to update anything in real-time for this game
end

function module:Destroy()
    -- no need for external clean up
    local flash = game.Lighting:FindFirstChild("FoamSaber_ColorCorrection")
    if flash then
        flash:Destroy()
    end
end

return module