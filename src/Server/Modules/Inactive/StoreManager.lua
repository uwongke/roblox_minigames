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
local Signal = require(ReplicatedStorage.Packages.Signal)

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

--[[

	TODO : PROJECT SCORE FROM CUSTOMER

]]

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
	local orderSignal = Signal.new()
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
			then playerWhoClicked.Character:FindFirstChild("Empty Cup", true)
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

	local function clickedButter(playerWhoClicked: Player, cupColor: "Earth Butter" | "Toothpaste Butter" | "Butter")
		local hasEmpty = if playerWhoClicked and playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Popcorn", true)
			else nil

		local humanoid: Humanoid = if playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Humanoid")
			else nil

		local newCup = GameExtras:FindFirstChild("Popcorn" .. cupColor)
		if hasEmpty and newCup and humanoid then
			newCup = newCup:Clone()
			self.Janitor:Add(newCup)
			hasEmpty:Destroy()

			newCup.Parent = playerWhoClicked.Backpack
			humanoid:EquipTool(newCup)
			return newCup
		end
	end

	-- create customer and random order
	local possibleOrders = {
		"Red Soda",
		"Blue Soda",
		"Green Soda",
		"Empty Cup",
		"Empty Popcorn Cup",
		"Popcorn",
		"Popcorn Earth Butter",
		"Popcorn Butter",
		"Popcorn ToothPaste Butter",
	}

	local customer = GameExtras.Customer
	local deskCF: CFrame = storeTemplate.Desk:GetPivot() + Vector3.new(0, customer:GetExtentsSize().Y / 2, 0)
	local startCF: CFrame = deskCF - deskCF.LookVector * 10
	local activeCustomers = {}
	local function createCustomer()
		-- spawn and position
		local newCustomer = customer:Clone()
		local orderQueue = newCustomer.Order_Queue
		self.Janitor:Add(newCustomer)
		newCustomer.Parent = workspace
		newCustomer:PivotTo(startCF)
		PivotTween:TweenPivot(newCustomer, startCF + startCF.LookVector * 7, TweenInfo.new(3), true)

		local billboard: BillboardGui = if newCustomer and newCustomer:FindFirstChild("Head")
			then newCustomer.Head:FindFirstChild("BillboardGui")
			else nil
		if billboard then
			table.insert(activeCustomers, customer)

			-- decide how many orders to give
			local orders = math.random(1, 3)
			for i = 1, orders do
				local order = possibleOrders[math.random(1, #possibleOrders)]
				local newOrderText = billboard.TextTemplate:Clone()
				self.Janitor:Add(newOrderText)
				newOrderText.Text = order
				newOrderText.Visible = true
				newOrderText.Parent = billboard.Frame

				-- add to order queue folder
				local newOrder = Instance.new("NumberValue")
				newOrder.Value = string.len(order) -- how much points they get
				newOrder.Name = order
				newOrder.Parent = orderQueue
			end
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
		if player and target and target:IsA("BasePart") then
			if
				cup
				and cup.Name == "Empty Cup"
				and (target.Name == "Red" or target.Name == "Blue" or target.Name == "Green")
			then
				local newCup = clickedFountain(player, target.Name)
				newCup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
					cupHandler(player, cup, target)
				end)
			elseif target.Name == "Trash" then
				trash(player)
			elseif target.Name == "Customer" then
				orderSignal:Fire(customer, cup.Name .. " Soda")
			end
		end
	end

	local function popcornCupHandler(player: Player, cup: Tool, target)
		if player and target and target:IsA("BasePart") then
			if
				cup
				and cup.Name == "Popcorn"
				and (target.Name == "Earth Butter" or target.Name == "Toothpaste Butter" or target.Name == "Butter")
			then
				local newPopcorn = clickedButter(player, target.Name)
				cup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
					cupHandler(player, cup, target)
				end)
			elseif cup.Name == "Empty Popcorn Cup" and target.Name == "Popcorn Machine" then
				local newPopcorn = GameExtras.Popcorn:Clone()
				self.Janitor:Add(newPopcorn)

				newPopcorn.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
					cupHandler(player, newPopcorn, target)
				end)

				newPopcorn.Parent = player.Backpack
				local humanoid: Humanoid = if player.Character then player.Character:FindFirstChild("Humanoid") else nil
				if humanoid then
					humanoid:EquipTool(newPopcorn)
				end
			elseif target.Name == "Trash" then
				trash(player)
			elseif target.Name == "Customer" then
				orderSignal:Fire(customer, cup.Name)
			end
		end
	end

	-- handle orders
	orderSignal:Connect(function(customer, itemReceived: string)
		local orderQueue = customer and customer:FindFirstChild("Order_Queue")
		if orderQueue then
			for customerIndex, order in orderQueue:GetChildren() do
				if itemReceived == order.Name then
					-- visual indication
					customer.Highlight.Enabled = true
					customer.Highlight.FillColor = Color3.new(0, 1, 0)

					task.delay(1, function()
						if customer and customer:FindFirstChild("Highlight") then
							customer.Highlight.Enabled = false
						end
					end)

					-- update score
					self:SetScore(player, order.Value)

					-- remove order and check if they have anymore
					order:Destroy()
					if #orderQueue:GetChildren() == 0 then
						customer:Destroy()
						table.remove(activeCustomers, customerIndex)
					end
				else -- if the order is not in this customer. We will remove 1.
					customer.Highlight.Enabled = true
					customer.Highlight.FillColor = Color3.new(1, 0, 0)

					task.delay(1, function()
						if customer and customer:FindFirstChild("Highlight") then
							customer.Highlight.Enabled = false
						end
					end)

					self:SetScore(player, -1)

					-- remove order and check if they have anymore
					order:Destroy()
					if #orderQueue:GetChildren() == 0 then
						customer:Destroy()
						table.remove(activeCustomers, customerIndex)
					end
				end
			end
		end
	end)

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

	-- popcorn giver
	local emptyCupClickDetector: ClickDetector = storeTemplate["Popcorn Cup"].ClickDetector
	emptyCupClickDetector.MouseClick:Connect(function(playerWhoClicked: Player)
		local humanoid: Humanoid = if playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Humanoid")
			else nil
		if self.GameOver.Value == false and humanoid then
			local emptyCup: Tool = GameExtras["Empty Popcorn Cup"]:Clone()
			self.Janitor:Add(emptyCup)

			emptyCup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
				popcornCupHandler(player, emptyCup, target)
			end)

			emptyCup.Parent = playerWhoClicked.Backpack
			humanoid:EquipTool(emptyCup)
		end
	end)

	local heartbeatConn: RBXScriptConnection
	local hasActiveCustomer = false
	local creatingCustomer = false
	heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if self.GameOver.Value == true then
			heartbeatConn:Disconnect()
			return
		end

		if #activeCustomers < 1 and not creatingCustomer then
			creatingCustomer = true
			createCustomer()
			creatingCustomer = false
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
