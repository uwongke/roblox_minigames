local ShopData = {}

local data = {
    ["TestItem"] = {
        _id = 1;
        Price = 10;
        -- addtional info needed here
    }
}

-- // ensure that all items have a unique _id
local foundIds = {}
for i, item in data do
    if not table.find(foundIds, item._id) then
        table.insert(foundIds, item._id)
        continue
    end

    error("Item with identical internal _id found at index " .. tostring(i))
    break
end

function ShopData:Get(itemId)
    if data[itemId] then
        return data[itemId]
    else
        warn("Could not find ItemId [" .. itemId .. "]")
        return nil
    end
end

return ShopData