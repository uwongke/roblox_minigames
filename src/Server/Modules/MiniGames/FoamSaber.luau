--[[
	Author: Aaron Tole(RealistEntertainment)
	Converted to new engine format by Justin (Synnull)

	Description: This is a minigame about a foam sword that has an incredible knock back and ragdoll effect.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.FoamArena
local FoamSaberTool = ReplicatedStorage.Assets.MiniGameExtras.FoamSaber.FoamSaber

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local ServerComm = require(ReplicatedStorage.Packages.Comm).ServerComm
local RagdollService
--comms
local SaberComm = ServerComm.new(ReplicatedStorage, "SaberComm")
local GotHitEvent = SaberComm:CreateSignal("GotHitEvent")
local GotPointsEvent = SaberComm:CreateSignal("GotPointsEvent")
--game vars
local SafetyPoints = 1  	--points awarded for not getting hit
local HitPoints = 3			--points awarded for hitting another player
local SafetyTimeReward = 3 	-- how long it takes to award SafteyPoints
local ROUND_TIME = 60
local invul_time = 3		--how long the player is immune to hits after being hit

local module = {}

local function AddForce(TargetChar, Char)
	if not Char or not TargetChar then
		return
	end
	local NewForce = Instance.new("BodyForce")
	NewForce.Force = Char:GetPrimaryPartCFrame().LookVector * 2500
	NewForce.Parent = TargetChar.PrimaryPart
	game.Debris:AddItem(NewForce, 0.2)
end
function TempRagdoll(player: Player)
	local character = player.Character
	if not character then
		return
	end

	RagdollService:SetRagdollState(player, true)

	task.wait()
	local BaseParts = {}
	for _, v in pairs(character:GetDescendants()) do --ragdoll
		if v:IsA("Motor6D") then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.CFrame = v.C0
			a1.CFrame = v.C1
			a0.Parent = v.Part0
			a1.Parent = v.Part1
			local b = Instance.new("BallSocketConstraint")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Parent = v.Part0
			v.Enabled = false
		end
	end
	for _, v in pairs(character:GetDescendants()) do --ragdoll
		if v:IsA("BasePart") then
			--[[if v.Name == "Head" then
				local OrienForce = Instance.new("BodyAngularVelocity")
				OrienForce.AngularVelocity = Vector3.new(0, 0, 0)
				OrienForce.MaxTorque = Vector3.new(50, 50, 50)
				OrienForce.Parent = v
				table.insert(BaseParts, OrienForce)
			end]]
			local Collider = Instance.new("Part")
			Collider.Size = v.Size / Vector3.new(15, 15, 15)
			Collider.CFrame = v.CFrame
			Collider.CanCollide = true
			Collider.Anchored = false
			Collider.Transparency = 1
			local w = Instance.new("Weld")
			w.Part0 = v
			w.Part1 = Collider
			w.C0 = CFrame.new()
			w.C1 = w.Part1.CFrame:ToObjectSpace(w.Part0.CFrame)
			w.Parent = Collider
			Collider.Parent = v
			table.insert(BaseParts, Collider)
		end
	end

	task.wait(1.5)
	if character then
		for _, v in pairs(character:GetDescendants()) do --unragdoll
			for _, v in pairs(BaseParts) do
				if v then
					v:Destroy()
				end
			end
			if v:IsA("Motor6D") then
				v.Enabled = true
			end
			if v.Name == "BallSocketConstraint" then
				v:Destroy()
			end
			if v.Name == "Attachment" then
				v:Destroy()
			end
		end
		BaseParts = {}
	end

	task.wait(0.3)
	RagdollService:SetRagdollState(player, false)
end

function module:Init(janitor, SpawnLocation)
    self.MiniGame = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
    janitor:Add(self.MiniGame.Game)
   
    -- should clean this up with janitor
    -- removes players that leave during the game from the pool of players
    janitor:Add(Players.PlayerRemoving:Connect(function(player)
        if self.MiniGame.Players[player] then
            self.MiniGame.Players[player] = nil
        end
    end))
   
    self._janitor = janitor

	if not RagdollService then
		RagdollService = Knit.GetService("RagdollService")
	end
    
end


function module:CreatePlayerBillboardScore(player: Player)
	local head = if player and player.Character then player.Character:FindFirstChild("Head") else nil
	local playerData = self.MiniGame.Players[player]
	if head and playerData then
		local scoreDisplay: BillboardGui = Instance.new("BillboardGui")
		self._janitor:Add(scoreDisplay)
		scoreDisplay.AlwaysOnTop = true
		scoreDisplay.StudsOffset = Vector3.new(0, 1, 0)
		scoreDisplay.Size = UDim2.fromScale(4, 2)

		local scoreTextLabel: TextLabel = Instance.new("TextLabel")
		scoreTextLabel.Size = UDim2.new(1, 0, 1, 0)
		scoreTextLabel.Text = playerData
		scoreTextLabel.TextScaled = true
		scoreTextLabel.TextColor3 = Color3.new(1, 1, 1)
		scoreTextLabel.BackgroundTransparency = 1
		scoreTextLabel.TextStrokeTransparency = 0
		scoreTextLabel.Parent = scoreDisplay

		scoreDisplay.Parent = head
	end
end
function module:SetPlayerTransparency(character: Model, transparency: number)
	for _, part in character:GetChildren() do
		if  part.Name ~= "HumanoidRootPart" then
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Transparency = transparency
			end
			if part:IsA("Accessory") then
				local handle = part.Handle
				if handle then
					handle.Transparency = transparency
				end
			end
		end
		
	end
end
function module:GetWinners()
    local highestScore = 0
    local winner = nil
    for player, score in self.MiniGame.Players do
        if score > highestScore then
            highestScore = score
            winner = player
        end
    end
    return winner
end
function module:Hit(Player: Player, targetPlayer: Player, part)
	local isHit = targetPlayer.Character:FindFirstChild("FoamSaber_IsHit")
	if not isHit then return end
	if isHit.Value == false then
		self.MiniGame.Players[Player] += HitPoints
		GotPointsEvent:Fire(Player, HitPoints, part)
		self.ScoreUpdateSignal:Fire(Player)
		isHit.Value = true
		self:SetPlayerTransparency(targetPlayer.Character, .6)
		GotHitEvent:Fire(targetPlayer)
		task.spawn(function()
			task.wait(invul_time)
			if not isHit then return end
			isHit.Value = false
			self:SetPlayerTransparency(targetPlayer.Character, 0)
		end)
		AddForce(targetPlayer.Character, Player.Character)
		TempRagdoll(targetPlayer)
	end
	
end


function module:Start()

	-- listen to score change
	self.ScoreUpdateSignal = Signal.new()
	self.ScoreUpdateSignal:Connect(function(player: Player)
		local BillboardGui = if player
				and player.Character
				and player.Character:FindFirstChild("Head")
			then player.Character.Head:FindFirstChildOfClass("BillboardGui")
			else nil
		local playerData = self.MiniGame.Players[player]
		if playerData and BillboardGui then
			BillboardGui.TextLabel.Text = tostring(playerData)
		end
	end)

	self.PointThreads = {}
	for player: Player, data in self.MiniGame.Players do
		local humanoid: Humanoid = if player
				and data
				and player.character
			then player.character:FindFirstChild("Humanoid")
			else nil

		if humanoid then
			local weapon: Tool = FoamSaberTool:Clone()
			self._janitor:Add(weapon)
			weapon.Parent = player.Backpack
			humanoid:EquipTool(weapon)

			-- load animations
			local animations = weapon.Animations
			local swingTracks = {
				humanoid.Animator:LoadAnimation(animations.Swing),
				humanoid.Animator:LoadAnimation(animations.DownSwing),
				humanoid.Animator:LoadAnimation(animations.UpSwing),
			}
			local idleAnim: AnimationTrack = humanoid.Animator:LoadAnimation(animations.Idle)

			weapon.Equipped:Connect(function()
				idleAnim:Play()
			end)

			weapon.Unequipped:Connect(function()
				idleAnim:Stop()
			end)

			self._janitor:Add(function()
				idleAnim:Stop()
			end)

			local debounce = false
			weapon.Activated:Connect(function()
				local isHit = player.character:FindFirstChild("FoamSaber_IsHit")
				if not isHit then return end
				if not debounce and isHit.Value == false then
					debounce = true

					-- play swing animation
					local track: AnimationTrack = swingTracks[math.random(1, #swingTracks)]
					track:Play()
					track.Stopped:Wait()
					idleAnim:Play()

					debounce = false
				end
			end)

			local targets = {}
			weapon.Handle.Touched:Connect(function(object)
				local isPlayer: Player? = if debounce
						and object
						and object.Parent
					then Players:GetPlayerFromCharacter(object.Parent)
					else nil
				if isPlayer and not table.find(targets, isPlayer) then
					task.spawn(function()
						table.insert(targets, isPlayer)

						
						self:Hit(player, isPlayer, object)
						

						table.remove(targets, table.find(targets, player))
					end)
				end
			end)

			--add a thread for points
			local isHit = Instance.new("BoolValue")
			isHit.Name = "FoamSaber_IsHit"
			isHit.Value = false
			isHit.Parent = player.Character
			local newPointThread = task.spawn(function()
				local time = 0
				while true do
					task.wait(1)
					if isHit.Value == false then
						time += 1
						if time >= SafetyTimeReward then
							self.MiniGame.Players[player] += SafetyPoints
							GotPointsEvent:Fire(player, SafetyPoints, player.Character.Head)
							self.ScoreUpdateSignal:Fire(player)
							time = 0
						end
					end
				end
			end)
			table.insert(self.PointThreads, newPointThread)
		end
	end

	return ROUND_TIME
end
--- Called every frame by the server during gameplay
function module:Update(players, dt, timeElapsed)
	
 end
function module:JoinGame(player)
	self.MiniGame.Players[player] = 0
	self:CreatePlayerBillboardScore(player)
	MiniGameUtils.SpawnAroundPart(self.MiniGame.Game.PrimaryPart, player.Character)
end

function module:Destroy()
	if self.PointThreads then
        for _, thread in ipairs(self.PointThreads) do
            task.cancel(thread)
        end
    end
end

return module
