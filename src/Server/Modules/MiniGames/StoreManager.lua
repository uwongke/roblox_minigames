--[[
	Author: Aaron Tole(RealistEntertainment)

	Description: This is the Store Manager minigame.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MiniGameUtils = require(script.Parent.Parent.MiniGameUtils)

local GameTemplate = ReplicatedStorage.Assets.MiniGames.StoreManager
local GameExtras = ReplicatedStorage.Assets.MiniGameExtras.StoreManager
local StoreTemplate = GameExtras.StoreTemplate

local PivotTween = require(ReplicatedStorage.PivotTween)
local Signal = require(ReplicatedStorage.Packages.Signal)

local GAME_DURATION = 60
local POINT_PER_CUSTOMER = 1

local StoreManager = {}
StoreManager.__index = StoreManager

function StoreManager:Init(Janitor, SpawnLocation, EndSignal)
	local data = MiniGameUtils.InitMiniGame(GameTemplate, SpawnLocation)
	data.ActiveStores = 0
	data.StartSignal = Signal.new()
	self.MiniGame = data
	self.Janitor = Janitor
	Janitor:Add(data.Game)
end

function StoreManager:Start()
	for player, data in self.MiniGame.Players do
		self.MiniGame.StartSignal:Fire(player)
	end
	return GAME_DURATION
end

function StoreManager:SetScore(player: Player, increment: number)
	local store = if self.MiniGame.Players[player] then self.MiniGame.Players[player].Store else nil
	print(store)
	if store then
		self.MiniGame.Players[player].Score += increment

		pcall(function()
			store.Display.SurfaceGui.TextLabel.Text = tostring(self.Players[player].Score)
		end)
	end
end

function StoreManager:CreateShop(player: Player)
	local orderSignal = Signal.new()
	local mapCF = self.MiniGame.Game:GetPivot()
	local mapSize = self.MiniGame.Game:GetExtentsSize() / 2

	-- generateShop
	local storeTemplate: Model = StoreTemplate:Clone()
	self.Janitor:Add(storeTemplate)
	storeTemplate.Parent = workspace
	self.MiniGame.ActiveStores += 1

	local storeSize = storeTemplate:GetExtentsSize()
	local canRotate: boolean = self.MiniGame.ActiveStores % 2 == 0
	local zIncrement = math.ceil(self.MiniGame.ActiveStores / 2)

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

	self.MiniGame.StartSignal:Connect(function(target)
		if player == target then
			createCustomer()
		end
	end)

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
		print(cup)
		if player and target and target:IsA("BasePart") then
			if
				cup
				and cup.Name == "Empty Cup"
				and (target.Name == "Red" or target.Name == "Blue" or target.Name == "Green")
			then
				local cup = clickedFountain(player, target.Name)
				cup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
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
		print(itemReceived)
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
		if humanoid then
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
	local emptyPopcornCupClickDetector: ClickDetector = storeTemplate["Popcorn Cup"].ClickDetector
	emptyPopcornCupClickDetector.MouseClick:Connect(function(playerWhoClicked: Player)
		local humanoid: Humanoid = if playerWhoClicked.Character
			then playerWhoClicked.Character:FindFirstChild("Humanoid")
			else nil
		if humanoid then
			local emptyCup: Tool = GameExtras["Empty Popcorn Cup"]:Clone()
			self.Janitor:Add(emptyCup)

			emptyCup.RemoteEvent.OnServerEvent:Connect(function(player: Player, target)
				popcornCupHandler(player, emptyCup, target)
			end)

			emptyCup.Parent = playerWhoClicked.Backpack
			humanoid:EquipTool(emptyCup)
		end
	end)
	MiniGameUtils.SpawnAroundPart(storeTemplate.Spawn, player.Character)

	return storeTemplate
end

function StoreManager:GetWinners()

    -- sort by players
    table.sort(self.MiniGame.Players, function(a, b)
        local a_score = self.MiniGame.Players[a].Score
        local b_score = self.MiniGame.Players[b].Score

        return a_score > b_score
    end)

    return self.MiniGame.Players, 3
end

function StoreManager:Update(dt,time)
	
end

function StoreManager:JoinGame(player)
	local store = self:CreateShop(player)

	local data = {
		Score = 0,
		Name = player.DisplayName,
		Store = store,
	}
	self.MiniGame.Players[player] = data
end

function StoreManager:Destroy()
	--clean up
	self = nil
end

return StoreManager
