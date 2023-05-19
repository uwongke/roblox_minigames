local module = {}
module.__index = module

function module:Init(newJanitor)
    -- return display info
    return "Memory Maze!",
    "A hidden path stands before you. A wrong step will have you fall and start from the beginning. How good is your memrory to remember all the correct steps to reach the end?",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    
end

function module:Destroy()
    self = nil
end

return module