local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = {}

local animTypes = {
    BasicAttack = CollectionService:GetTagged("BasicAttack"),
    Skill = CollectionService:GetTagged("SkillAttack"),
    Finisher = CollectionService:GetTagged("FinisherAttack")
}

function Utils.deserializeEnum(enum: string, value: number): EnumItem | nil
    if Enum[enum] ~= nil then
        for _, item in ipairs(Enum[enum]:GetEnumItems()) do
            if item.Value == value then
                return item
            end
        end
    end
    return nil
end

function Utils.serializeEnum(enum: string, item: EnumItem | string): number | nil
    if typeof(item) == "EnumItem" then
        return item.Value
    end

    if Enum[enum] ~= nil then
        local enums = Enum[enum]:GetEnumItems()
        return table.find(enums, item)
    else
        return nil
    end
end
function Utils.getRandomInPart(part)
    local random = Random.new()
    local randomCFrame = part.CFrame * CFrame.new(random:NextNumber(-part.Size.X/2,part.Size.X/2), 0, random:NextNumber(-part.Size.Z/2,part.Size.Z/2))
    return randomCFrame
end

function Utils.alignWithCamera(delay_time)
    if not RunService:IsClient() then return end
    local character = game.Players.LocalPlayer.Character
    local hrp = character.PrimaryPart
    local ccf = workspace.CurrentCamera.CFrame
    local toLook = hrp.Position + Vector3.new(ccf.LookVector.X, 0, ccf.LookVector.Z)

    -- calculate lookcf
    local newcf = CFrame.lookAt(hrp.Position, toLook)

    local gyro = Instance.new("BodyGyro")
    gyro.CFrame = newcf
    gyro.MaxTorque = Vector3.new(0, 100000, 0)
    gyro.P = 10000
    gyro.Parent = hrp

    hrp.CFrame = newcf

    task.delay(delay_time, function()
        gyro:Destroy()
    end)
    return gyro
end

function Utils.raycast(origin, direction, filterList, filterType, collisionGroup)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = filterType or Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.CollisionGroup = collisionGroup or "Default"

    return workspace:Raycast(origin, direction, raycastParams)
end

function Utils.getSourceAnim(animId)
    for _, animType in pairs(animTypes) do
        for _, anim in ipairs(animType) do
            if anim.AnimationId == animId then
                return anim
            end
        end
    end
    return nil
end

function Utils.getSourceAnimByName(animName, parentName)
    for _, animType in pairs(animTypes) do
        for _, anim in ipairs(animType) do
            if anim.Name == animName and anim.Parent.Name == parentName then
                return anim
            end
        end
    end
    return nil
end

function Utils.roundNumber(num, numPlaces)
    if num % (1/10^numPlaces) < 1/10^numPlaces then 
        return math.ceil(num*(10^numPlaces))/(10^numPlaces)
    end

    local r = math.floor(num*(10^numPlaces))/(10^numPlaces)
    return r
end

function weldAttachments(attach1, attach2)
    local weld = Instance.new("Weld")
    weld.Part0 = attach1.Parent
    weld.Part1 = attach2.Parent
    weld.C0 = attach1.CFrame
    weld.C1 = attach2.CFrame
    weld.Parent = attach1.Parent
    return weld
end
 
local function buildWeld(weldName, parent, part0, part1, c0, c1)
    local weld = Instance.new("Weld")
    weld.Name = weldName
    weld.Part0 = part0
    weld.Part1 = part1
    weld.C0 = c0
    weld.C1 = c1
    weld.Parent = parent
    return weld
end
 
local function findFirstMatchingAttachment(model, name)
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("Attachment") and child.Name == name then
            return child
        elseif not child:IsA("Accoutrement") and not child:IsA("Tool") then -- Don't look in hats or tools in the character
            local foundAttachment = findFirstMatchingAttachment(child, name)
            if foundAttachment then
                return foundAttachment
            end
        end
    end
end

local RANGE_MODIFIER = 0.4
function Utils.getBoxOriginWithDirection(origin, direction, range)
    local newpos = origin + direction * (range * RANGE_MODIFIER)
    return CFrame.lookAt(
        newpos, newpos + direction * (range * 0.5)
    )
end


function getCharactersFromHits(hits)
    local characters = {}
    for _, hit in ipairs(hits) do
        local model = hit:FindFirstAncestorOfClass("Model")
        if model then
            if not table.find(characters, model) then
                if model:FindFirstChild("Humanoid") then
                    table.insert(characters, model)
                end
            end
        end
    end

    return characters
end

Utils.getCharactersFromHits = getCharactersFromHits

function Utils.getPlayersFromHits(hits)
    local characters = getCharactersFromHits(hits)
    local players = {}
    for _, character in ipairs(characters) do
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            table.insert(players, player)
        end
    end

    return players, characters
end

function Utils.addLocalAccessory(character, accoutrement)  
    accoutrement.Parent = character
    local handle = accoutrement:FindFirstChild("Handle")
    if handle then
        local accoutrementAttachment = handle:FindFirstChildOfClass("Attachment")
        if accoutrementAttachment then
            local characterAttachment = findFirstMatchingAttachment(character, accoutrementAttachment.Name)
            if characterAttachment then
                weldAttachments(characterAttachment, accoutrementAttachment)
            end
        else
            local head = character:FindFirstChild("Head")
            if head then
                local attachmentCFrame = CFrame.new(0, 0.5, 0)
                local hatCFrame = accoutrement.AttachmentPoint
                buildWeld("HeadWeld", head, head, handle, attachmentCFrame, hatCFrame)
            end
        end
    end
end

function Utils.getAllCharactersInRadius(origin, radius, localPlayer)
    local playersInRadius = {}
	-- for _, player in ipairs(game.Players:GetPlayers()) do
    --     print(player)
	-- 	local magnitude = (player.Character.HumanoidRootPart.Position - origin).Magnitude;
	-- 	if magnitude <= radius and player ~= localPlayer then
	-- 		table.insert(playersInRadius, player)
	-- 	end
	-- end

    for _, character in ipairs(CollectionService:GetTagged("TargetableCharacter")) do
		local magnitude = (character.PrimaryPart.Position - origin).Magnitude;
		if magnitude <= radius and character ~= localPlayer.Character then
			table.insert(playersInRadius, character)
		end
    end

	return playersInRadius
end

function Utils.calculateCustomVelocity(origin, direction,
    range, velocity, acceleration)

    local t = range / velocity
    local initialHeight = origin.Y
    local yVelo = (-( (t^2)*acceleration ) ) / (t*2)

    local customVelocity = Vector3.new(
        direction.X * velocity,
        yVelo,
        direction.Z * velocity
    )

    return customVelocity
end

return Utils