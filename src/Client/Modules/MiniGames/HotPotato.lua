local module = {}
module.__index = module

function module:Init(newJanitor)
    -- return display info
    return "Hot Potato!",
    "Tag your it! Don't be the one holding the Potato when time runs out!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    
end

function module:Destroy()
    self = nil
end

return module