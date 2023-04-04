local UGCData = {}

local data = {
    ["TestItem"] = 00000; --// replace with Roblox catalog id for an item
}

function UGCData:Get(itemId)
    if data[itemId] then
        return data[itemId]
    else
        warn("Could not find ItemId [" .. itemId .. "]")
        return nil
    end
end

return UGCData