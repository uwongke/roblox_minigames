--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This the the LawMower minigame.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.LawnMower
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.LawnMower
local LawMowerTool: Tool = GameExtras.LawnMower

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PivotTween = require(ReplicatedStorage.PivotTween)
local Signal = require(ReplicatedStorage.Packages.Signal)

local RagdollService

local GAME_DURATION = 60

local LawnMower = {}
LawnMower.__index = LawnMower

function LawnMower.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, LawnMower)

	data.Janitor = Janitor.new()
	data.ActiveStores = 0
	data.ScoreUpdateSignal = Signal.new()

	if not RagdollService then
		RagdollService = Knit.GetService("RagdollService")
	end

	task.delay(3, function()
		data:PrepGame()
	end)

	data.Janitor:Add(data.ScoreUpdateSignal, "Destroy")
	return data
end

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

function LawnMower:Hit(Player: Player, targetPlayer: Player)
	AddForce(targetPlayer.Character, Player.Character)
	TempRagdoll(targetPlayer)
end

function LawnMower:BroadcastWinner()
	local highScore = -100
	local winner

	for player: Player, data in self.Players do
		if data and data.Score > highScore then
			winner = player
			highScore = data.Score
		end
	end

	self:SetMessage(winner.Name .. " is the winner!", nil, 3)
end

function LawnMower:CreatePlayerBillboardScore(player: Player)
	local head = if player and player.Character then player.Character:FindFirstChild("Head") else nil
	local playerData = self.Players[player]
	if head and playerData then
		local scoreDisplay: BillboardGui = Instance.new("BillboardGui")
		self.Janitor:Add(scoreDisplay)
		scoreDisplay.AlwaysOnTop = true
		scoreDisplay.StudsOffset = Vector3.new(0, 1, 0)
		scoreDisplay.Size = UDim2.fromScale(4, 2)

		local scoreTextLabel: TextLabel = Instance.new("TextLabel")
		scoreTextLabel.Size = UDim2.new(1, 0, 1, 0)
		scoreTextLabel.Text = playerData.Score
		scoreTextLabel.TextScaled = true
		scoreTextLabel.TextColor3 = Color3.new(1, 1, 1)
		scoreTextLabel.BackgroundTransparency = 1
		scoreTextLabel.TextStrokeTransparency = 0
		scoreTextLabel.Parent = scoreDisplay

		scoreDisplay.Parent = head
	end
end

function LawnMower:SetMessage(message: string?, timer: number?, yieldTime: number?)
	if message then
		self.MessageData.Message = message
	end

	if timer then
		self.MessageData.Timer = tostring(timer)
	end

	self.Message.Value = HttpService:JSONEncode(self.MessageData)

	if yieldTime then
		task.wait(yieldTime)
	end
end

function LawnMower:PrepGame()
	self.MessageData = {
		Message = "",
		Timer = "",
	}

	self.MessageTarget.Value = ""

	self.CanJoin.Value = true
	self:SetMessage(self.Game.Name .. " is ready", nil, 3)
	self:SetMessage("players have joined", nil, 3)
	self:SetMessage("GO!", nil, 1)
	self:SetMessage("")

	-- listen to score change
	self.ScoreUpdateSignal:Connect(function(player: Player)
		local BillboardGui = if player
				and player.Character
				and player.Character:FindFirstChild("Head")
			then player.Character.Head:FindFirstChildOfClass("BillboardGui")
			else nil
		local playerData = self.Players[player]
		if playerData and BillboardGui then
			BillboardGui.TextLabel.Text = tostring(playerData.Score)
		end
	end)

	-- slow areas
	local slowedPlayers = {}
	for _, slowArea: BasePart in self.Game.SlowAreas:GetChildren() do
		if slowArea:IsA("BasePart") then
			slowArea.Touched:Connect(function(otherPart)
				local isPlayer = Players:GetPlayerFromCharacter(otherPart.Parent)
				local humanoid = if isPlayer and isPlayer.Character
					then isPlayer.Character:FindFirstChild("Humanoid")
					else nil
				if humanoid and not table.find(slowedPlayers, isPlayer) then
					table.insert(slowedPlayers, isPlayer)
					humanoid.WalkSpeed = humanoid.WalkSpeed / 5
					task.delay(3, function()
						local index = table.find(slowedPlayers, isPlayer)
						if index then
							table.remove(slowedPlayers, index)
							if humanoid then
								humanoid.WalkSpeed = humanoid.WalkSpeed * 5
							end
						end
					end)
				end
			end)
		end
	end

	for player: Player, data in self.Players do
		local humanoid: Humanoid = if player
				and data
				and player.character
			then player.character:FindFirstChild("Humanoid")
			else nil

		-- disable collisions
		for _, v in ipairs(player.character:GetChildren()) do
			if v:IsA("BasePart") then
				game:GetService("PhysicsService"):SetPartCollisionGroup(v, " ") -- // useful for disabling player-player collisions
			end
		end

		if humanoid then
			local mower: Tool = LawMowerTool:Clone()
			self.Janitor:Add(mower)
			mower.Parent = player.Backpack
			humanoid:EquipTool(mower)

			-- load animations
			local animations = mower.Animations
			local swingTracks = {
				humanoid.Animator:LoadAnimation(animations.Swing),
			}

			local debounce = false
			mower.Activated:Connect(function()
				if not debounce then
					debounce = true

					-- play swing animation
					local track: AnimationTrack = swingTracks[math.random(1, #swingTracks)]
					track:Play()
					track.Stopped:Wait()
					debounce = false
				end
			end)

			local targets = {}
			local debounce = false
			mower.Handle.Touched:Connect(function(otherPart: BasePart?)
				local isPlayer: Player? = Players:GetPlayerFromCharacter(otherPart.Parent)
				print(isPlayer, table.find(targets, isPlayer))
				if not isPlayer and otherPart:IsA("BasePart") and otherPart.Name == "Grass" then
					otherPart.Name = "Dirt"
					otherPart.BrickColor = BrickColor.new("Earth yellow")

					if self.Players[player] then
						self.Players[player].Score += 1
						self.ScoreUpdateSignal:Fire(player)
					end

					task.delay(7, function()
						if otherPart then
							otherPart.Name = "Grass"
							otherPart.Color = Color3.fromRGB(19, 67, 15)
						end
					end)
				elseif isPlayer and not table.find(targets, isPlayer) and not debounce then
					debounce = true
					task.spawn(function()
						table.insert(targets, isPlayer)

						self.Players[player].Score += 1
						self:Hit(player, isPlayer)
						self.ScoreUpdateSignal:Fire(player)

						table.remove(targets, table.find(targets, player))
					end)
					task.wait(1)
					debounce = false
				end
			end)
		end
	end

	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			self:SetMessage("Times Up!", nil, 2)
			self:BroadcastWinner()
			heartbeatConn:Disconnect()
			return
		end

		self:SetMessage("", math.floor(endTime - os.time()))
	end)

	repeat
		task.wait()
	until os.time() >= endTime

	self.GameOver.Value = true
	self:SetMessage("Times Up!")
end

function LawnMower:JoinGame(player)
	if self.CanJoin.Value then
		local data = {
			Score = 0,
			Name = player.DisplayName,
		}
		self.Players[player] = data

		self:CreatePlayerBillboardScore(player)
		MiniGameUtils.SpawnAroundPart(self.Game.Spawn, player.Character)
		return true
	end
	return false
end

function LawnMower:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()
	self = nil
end

return LawnMower
