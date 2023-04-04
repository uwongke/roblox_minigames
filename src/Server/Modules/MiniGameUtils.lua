local module = {}

function module.SpawnAroundPart(spawnPoint, spawnObject)
	local objectSize = spawnObject:IsA("Model") and spawnObject:GetExtentsSize() or spawnObject.Size
	local heightOffset = objectSize.Y / 2
	local range = spawnPoint.Size
	local position = spawnPoint.Position - range * 0.5
	local offset = Vector3.new(math.random(0, range.X), heightOffset, math.random(0, range.z))
	if spawnObject:IsA("Model") then
		spawnObject:SetPrimaryPartCFrame(CFrame.new(position + offset))
	else
		spawnObject.Position = position + offset
	end
end

function module.InitMiniGame(gameTemplate, spawnLocation)
	local data = {}
	-- test set up
	if gameTemplate then
		if gameTemplate.Parent == workspace then
			data.Game = gameTemplate
		else
			data.Game = gameTemplate:Clone()
			data.Game.Parent = workspace
		end
		data.Game:PivotTo(spawnLocation.CFrame)
	end

	data.CanJoin = Instance.new("BoolValue")
	data.CanJoin.Name = "CanJoin"
	data.CanJoin.Parent = data.Game

	data.GameOver = Instance.new("BoolValue")
	data.GameOver.Name = "GameOver"
	data.GameOver.Parent = data.Game

	data.Message = Instance.new("StringValue")
	data.Message.Name = "Message"
	data.Message.Parent = data.Game

	data.MessageTarget = Instance.new("StringValue")
	data.MessageTarget.Name = "MessageTarget"
	data.MessageTarget.Parent = data.Game

	data.Players = {}
	data.Winners = {}
	data.Losers = {}
	return data
end

return module
