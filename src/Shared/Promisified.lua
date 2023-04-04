--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Promise = require(Packages.Promise)

local Promisified = {}

--- Promise version of FindFirstChild. Rejects if the parent is not an Instance
function Promisified.FindFirstChild(parent: Instance, index: string)
    if parent:IsA("Instance") then
        return Promise.try(function()
            local found = parent:FindFirstChild(index)
            return found or Promise.reject()
        end)
    else
        return Promise.reject()
    end
end

return Promisified