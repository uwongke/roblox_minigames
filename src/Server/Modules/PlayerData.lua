local module = {}
module.__index = module

local Players = nil
local PlayerCollisionGroupId = "Player"

function  module.GetPlayers()
    return Players
end

function module.ActivatePlayers(Player)
    if Player then
        local data = Players[Player]
        if data then
            data.Alive = true
        end
        return
    end
    for _, data in pairs(Players) do
        data.Alive = true
    end
end

function module.onDescendantAdded(descendant)
    -- Set collision group for any part descendant
    if descendant:IsA("BasePart") then
        descendant.CollisionGroup = PlayerCollisionGroupId
    end
end

function module.new(Player)
    local data = {}
    data.Player = Player
    Player.CharacterAdded:Connect(function(character)
        -- Process existing and new descendants for physics setup
        for _, descendant in pairs(character:GetDescendants()) do
            module.onDescendantAdded(descendant)
        end
        character.DescendantAdded:Connect(module.onDescendantAdded)

        local humanoid = character.Humanoid
        humanoid.Died:Connect(function()
            data.Alive = false
        end)
    end)
    data.Alive = false
    setmetatable(data, module)
    if Players == nil then
        Players = {}
    end
    Players[Player] = data
    return data
end

function module.GetPlayer(Player)
    return Players[Player]
end

function module.RemovePlayer(Player)
    Players[Player] = nil
end

function module.GetListOfActivePlayers(list, exclude)
    local subset = {}
    for player,data in pairs(Players) do
        if not data.Alive then
            continue
        end
        local found = true
        if list then
            local index = table.find(list,""..player.UserId)
            if index == nil then
                found = false
            end
        end
        --print(found, exclude, list,player.UserId)
        if found ~= exclude then
            subset[player] = data
        end
    end
    return subset
end

return module