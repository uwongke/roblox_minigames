--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This is the Store Manager minigame.
]]

local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.StoreManager
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.StoreManager
local StoreTemplate = GameExtras.StoreTemplate

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PivotTween = require(ReplicatedStorage.PivotTween)

local GAME_DURATION = 60
local POINT_PER_CUSTOMER = 1

local StoreManager = {}
StoreManager.__index = StoreManager

function StoreManager.new(SpawnLocation)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	setmetatable(data, StoreManager)

	data.Janitor = Janitor.new()
	data.ActiveStores = 0

	task.delay(3, function()
		data:PrepGame()
	end)

	return data
end

function StoreManager:SetMessage(message: string?, timer: number?, yieldTime: number?)
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

function StoreManager:SetScore(player: Player, increment: number)
	local store = if self.Players[player] then self.Players[player].Store else nil
	print(store)
	if store then
		self.Players[player].Score += increment

		pcall(function()
			store.Display.SurfaceGui.TextLabel.Text = tostring(self.Players[player].Score)
		end)
	end
end

function StoreManager:CreateShop(player: Player)
	local mapCF = self.Game:GetPivot()
	local mapSize = self.Game:GetExtentsSize() / 2

	-- generateShop
	local storeTemplate: Model = StoreTemplate:Clone()
	self.Janitor:Add(storeTemplate)
	storeTemplate.Parent = workspace
	self.ActiveStores += 1

	local storeSize = storeTemplate:GetExtentsSize()
	local canRotate: boolean = self.ActiveStores % 2 == 0
	local zIncrement = math.ceil(self.ActiveStores / 2)

	if canRotate then
		storeTemplate:PivotTo(
			mapCF * CFrame.Angles(0, math.pi, 0)
				- Vector3.new(0, 0, mapSize.Z)
				+ Vector3.new(storeSize.X, storeSize.Y / 2, storeSize.Z * zIncrement)
		)
	else
		storeTemplate:PivotTo(
			mapCF - Vector3.new(0, 0, mapSize.Z) + Vector3.new(-storeSize.X, storeSize.Y / 2, storeSize.Z * zIncrement)
		)
	end
	-- soda machine
	local function clickedFountain(playerWhoClicked: Player, cupColor: "Red" | "Green" | "Blue")
		local hasEmpty = if playerWhoClicked and playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Empty", true)
			else nil

		local humanoid: Humanoid = if playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Humanoid")
			else nil

		local newCup = GameExtras:FindFirstChild(cupColor)
		if hasEmpty and newCup and humanoid then
			newCup = newCup:Clone()
			self.Janitor:Add(newCup)
			hasEmpty:Destroy()

			newCup.Parent = playerWhoClicked.Backpack
			humanoid:EquipTool(newCup)
			return newCup
		end
	end

	local function processCustomer(customer: BasePart, cup: Tool)
		local billboard: BillboardGui = if customer and customer:FindFirstChild("BillboardGui", true)
			then customer.Head.BillboardGui
			else nil
		if billboard and cup then
			cup:Destroy()
			customer.Highlight.Enabled = true
			customer.Highlight.FillColor = if billboard.TextLabel.Text == cup.Name
				then Color3.new(0, 1, 0)
				else Color3.new(1, 0, 0)
			task.wait(1.5)
			customer.Success.Value = if billboard.TextLabel.Text == cup.Name then "Success" else "Failure"
		end
	end

	-- trash bin
	local function trash(playerWhoClicked: Player)
		local hasTool = if playerWhoClicked and playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChildOfClass("Tool")
			else nil
		if hasTool then
			hasTool:Destroy()
		end
	end

	-- cup
	local function cupHandler(player: Player, cup: Tool, target)
		print(target)
		if player and target and target:IsA("BasePart") then
			if
				cup
				and cup.Name == "Empty"
				and (target.Name == "Red" or target.Name == "Blue" or target.Name == "Green")
			then
				local cup = clickedFountain(player, target.Name)
				cup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
					cupHandler(player, cup, target)
				end)
			elseif target.Name == "Trash" then
				trash(player)
			elseif target.Name == "Customer" then
				processCustomer(target.parent, cup)
			end
		end
	end

	-- empty cup giver
	local emptyCupClickDetector: ClickDetector = storeTemplate.Cups.ClickDetector
	emptyCupClickDetector.MouseClick:Connect(function(playerWhoClicked: Player)
		local humanoid: Humanoid = if playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Humanoid")
			else nil
		if self.GameOver.Value == false and humanoid then
			local emptyCup: Tool = GameExtras.Empty:Clone()
			self.Janitor:Add(emptyCup)

			emptyCup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
				cupHandler(player, emptyCup, target)
			end)

			emptyCup.Parent = playerWhoClicked.Backpack
			humanoid:EquipTool(emptyCup)
		end
	end)

	-- customer
	local customer = GameExtras.Customer

	local deskCF: CFrame = storeTemplate.Desk:GetPivot() + Vector3.new(0, customer:GetExtentsSize().Y / 2, 0)
	local startCF: CFrame = deskCF - deskCF.LookVector * 10

	local possibleOrders = { "Red", "Green", "Blue" }
	local heartbeatConn: RBXScriptConnection
	local hasActiveCustomer = false
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			heartbeatConn:Disconnect()
			return
		end

		if not hasActiveCustomer then
			hasActiveCustomer = true

			-- spawn customer
			local newCustomer = customer:Clone()
			self.Janitor:Add(newCustomer)
			newCustomer.Parent = workspace
			newCustomer:PivotTo(startCF)

			PivotTween:TweenPivot(newCustomer, startCF + startCF.LookVector * 7, TweenInfo.new(3), true)

			local billboard: BillboardGui = if newCustomer and newCustomer:FindFirstChild("Head")
				then newCustomer.Head:FindFirstChild("BillboardGui")
				else nil
			if billboard then
				local order = possibleOrders[math.random(1, #possibleOrders)]
				newCustomer.Head.BillboardGui.TextLabel.Text = order
				newCustomer.Head.BillboardGui.Enabled = true

				newCustomer.Success.Changed:Connect(function()
					if newCustomer.Success.Value == "Success" then
						self:SetScore(player, POINT_PER_CUSTOMER)
					else
						self:SetScore(player, -POINT_PER_CUSTOMER)
					end

					newCustomer:Destroy()
					hasActiveCustomer = false
				end)
			end
		end
	end)

	MiniGameUtils.SpawnAroundPart(storeTemplate.Spawn, player.Character)

	return storeTemplate
end

function StoreManager:PrepGame()
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

	local endTime = os.time() + GAME_DURATION
	local heartbeatConn: RBXScriptConnection
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
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

function StoreManager:JoinGame(player)
	if self.CanJoin.Value then
		local store = self:CreateShop(player)

		local data = {
			Score = 0,
			Name = player.DisplayName,
			Store = store,
		}
		self.Players[player] = data

		return true
	end
	return false
end

function StoreManager:Destroy()
	--clean up
	self.Janitor:Destroy()
	self.Game:Destroy()
	self = nil
end

return StoreManager
